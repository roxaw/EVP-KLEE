//not sure i think it didnt produce error but didnt generate .txt file
#include <iostream>
#include <fstream>
#include <unordered_map>
#include <vector>
#include <string>
#include <nlohmann/json.hpp>

#include "llvm/Support/DynamicLibrary.h"
#include "llvm/Support/CommandLine.h"

#include "llvm/IR/LegacyPassManager.h"
#include "llvm/Transforms/IPO/PassManagerBuilder.h"

#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/Pass.h"
#include "llvm/IR/Module.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;
using json = nlohmann::json;

struct ValueProperties {
    int type;
    std::string value;
    std::vector<std::string> ops;
};

struct ReplacementPair {
    std::unordered_map<std::string, std::vector<ValueProperties>> varToValues;
};

using ConcreteStore = std::unordered_map<std::string, ReplacementPair>;

class VaseMapLoader {
public:
    bool loadFromFile(const std::string& filename);
    const std::vector<ValueProperties>* getValues(const std::string& location, const std::string& var) const;

private:
    ConcreteStore store;
};

bool VaseMapLoader::loadFromFile(const std::string& filename) {
    std::ifstream file(filename);
    if (!file.is_open()) {
        std::cerr << "Failed to open " << filename << std::endl;
        return false;
    }

    json j;
    file >> j;

    for (auto& [location, vars] : j.items()) {
        ReplacementPair pair;
        for (auto& [varName, valueList] : vars.items()) {
            std::vector<ValueProperties> props;
            for (auto& val : valueList) {
                ValueProperties vp;
                vp.type = val.at("type").get<int>();
                vp.value = val.at("value").get<std::string>();
                if (val.contains("ops")) {
                    vp.ops = val.at("ops").get<std::vector<std::string>>();
                }
                props.push_back(vp);
            }
            pair.varToValues[varName] = props;
        }
        store[location] = pair;
    }

    return true;
}

const std::vector<ValueProperties>* VaseMapLoader::getValues(const std::string& location, const std::string& var) const {
    auto it = store.find(location);
    if (it == store.end()) return nullptr;
    const auto& varMap = it->second.varToValues;
    auto varIt = varMap.find(var);
    if (varIt == varMap.end()) return nullptr;
    return &varIt->second;
}

namespace {
struct VaseInstrumentPass : public ModulePass {
    static char ID;
    VaseInstrumentPass() : ModulePass(ID) {}

    bool runOnModule(Module &M) override {
        LLVMContext &Ctx = M.getContext();
        errs() << "[VASE] Running VaseInstrumentPass\n";

        FunctionCallee logVar = M.getOrInsertFunction("__vase_log_var",
            FunctionType::get(Type::getVoidTy(Ctx), {
                Type::getInt32Ty(Ctx),                         // loc ID
                Type::getInt32Ty(Ctx),                         // branch taken (0/1)
                Type::getInt8PtrTy(Ctx),                       // var name string
                Type::getInt32Ty(Ctx)                          // variable value
            }, false));

        static int unnamedCounter = 0;

        for (Function &F : M) {
            errs() << "[VASE] Function: " << F.getName() << "\n";
            for (BasicBlock &BB : F) {
                errs() << "  BasicBlock: ";
                if (BB.hasName()) errs() << BB.getName() << "\n";
                else errs() << "(unnamed)\n";

                Instruction *terminator = BB.getTerminator();
                if (auto *br = dyn_cast<BranchInst>(terminator)) {
                    errs() << "    Found branch instruction\n";
                    if (br->isConditional()) {
                        errs() << "    -> Conditional branch\n";
                        int locId = br->getDebugLoc().getLine();
                        Value *cond = br->getCondition();

                        errs() << "    Condition: ";
                        if (cond->hasName()) errs() << cond->getName();
                        else errs() << "(unnamed)";
                        errs() << ", Type: ";
                        cond->getType()->print(errs());
                        errs() << "\n";

                        BasicBlock *trueBB = br->getSuccessor(0);
                        if (!trueBB->empty()) {
                            IRBuilder<> tBuilder(&*trueBB->getFirstInsertionPt());
                            for (Use &U : cond->operands()) {
                                Value *operand = U.get();
                                if (isa<Constant>(operand)) continue;
                                if (operand->getType()->isIntegerTy()) {
                                    errs() << "      Operand logging candidate\n";
                                    Value *casted = operand;
                                    if (operand->getType()->getIntegerBitWidth() < 32)
                                        casted = tBuilder.CreateZExt(operand, Type::getInt32Ty(Ctx));
                                    else if (operand->getType()->getIntegerBitWidth() > 32)
                                        casted = tBuilder.CreateTrunc(operand, Type::getInt32Ty(Ctx));
                                    std::string varName = operand->hasName() ? operand->getName().str() : ("tmp_" + std::to_string(unnamedCounter++));
                                    Value *name = tBuilder.CreateGlobalStringPtr(varName);
                                    tBuilder.CreateCall(logVar, {
                                        ConstantInt::get(Type::getInt32Ty(Ctx), locId),
                                        ConstantInt::get(Type::getInt32Ty(Ctx), 1),
                                        name,
                                        casted
                                    });
                                }
                            }
                        }

                        BasicBlock *falseBB = br->getSuccessor(1);
                        if (!falseBB->empty()) {
                            IRBuilder<> fBuilder(&*falseBB->getFirstInsertionPt());
                            for (Use &U : cond->operands()) {
                                Value *operand = U.get();
                                if (isa<Constant>(operand)) continue;
                                if (operand->getType()->isIntegerTy()) {
                                    errs() << "      Operand logging candidate\n";
                                    Value *casted = operand;
                                    if (operand->getType()->getIntegerBitWidth() < 32)
                                        casted = fBuilder.CreateZExt(operand, Type::getInt32Ty(Ctx));
                                    else if (operand->getType()->getIntegerBitWidth() > 32)
                                        casted = fBuilder.CreateTrunc(operand, Type::getInt32Ty(Ctx));
                                    std::string varName = operand->hasName() ? operand->getName().str() : ("tmp_" + std::to_string(unnamedCounter++));
                                    Value *name = fBuilder.CreateGlobalStringPtr(varName);
                                    fBuilder.CreateCall(logVar, {
                                        ConstantInt::get(Type::getInt32Ty(Ctx), locId),
                                        ConstantInt::get(Type::getInt32Ty(Ctx), 0),
                                        name,
                                        casted
                                    });
                                }
                            }
                        }
                    }
                }
            }
        }
        return true;
    }
};
} // namespace

char VaseInstrumentPass::ID = 0;

static RegisterPass<VaseInstrumentPass> X("vase-instrument", "VASE Full Instrumentation Pass");

static void registerVasePass(const PassManagerBuilder &Builder, legacy::PassManagerBase &PM) {
  PM.add(new VaseInstrumentPass());
}

static RegisterStandardPasses RegisterMyPass(
    PassManagerBuilder::EP_EarlyAsPossible,
    registerVasePass);

extern "C" void __vase_log_var(int locId, int branchTaken, const char *varName, int val) {
    static std::ofstream log("vase_value_log.txt", std::ios::app);
    log << "loc\t" << locId << "\tbranch\t" << branchTaken
        << "\tvar\t" << varName << "\tval\t" << val << "\n";
}



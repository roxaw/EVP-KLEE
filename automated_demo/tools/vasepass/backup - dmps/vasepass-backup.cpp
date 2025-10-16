//pass showing just loc branch cond and SSA error for complex SSA

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

// === LLVM Pass for VASE Instrumentation ===
namespace {
struct VaseInstrumentPass : public ModulePass {
    static char ID;
    VaseInstrumentPass() : ModulePass(ID) {}

    bool runOnModule(Module &M) override {
        LLVMContext &Ctx = M.getContext();

        FunctionCallee logFunc = M.getOrInsertFunction("__vase_log_condition",
            FunctionType::get(Type::getVoidTy(Ctx), {
                Type::getInt32Ty(Ctx), // loc ID
                Type::getInt32Ty(Ctx), // branch taken
                Type::getInt32Ty(Ctx)  // condition value (primitive only)
            }, false));

        for (Function &F : M) {
            for (BasicBlock &BB : F) {
                Instruction *terminator = BB.getTerminator();
                if (auto *br = dyn_cast<BranchInst>(terminator)) {
                    if (br->isConditional()) {
                        IRBuilder<> builder(br);
                        int locId = br->getDebugLoc().getLine();

                        Value *cond = br->getCondition();
                        Value *condVal = nullptr;

                        if (cond->getType()->isIntegerTy()) {
                            condVal = builder.CreateIntCast(cond, Type::getInt32Ty(Ctx), true);
                        } else {
                            condVal = ConstantInt::get(Type::getInt32Ty(Ctx), -1);
                        }

                        Function *caller = br->getFunction();
                        LLVMContext &context = caller->getContext();

                        BasicBlock *trueBB = br->getSuccessor(0);
                        BasicBlock *falseBB = br->getSuccessor(1);

                        // Check if trueBB and falseBB have instructions to insert after
                        if (!trueBB->empty()) {
                            IRBuilder<> tBuilder(trueBB->getFirstNonPHI());
                            tBuilder.CreateCall(logFunc, {
                                ConstantInt::get(Type::getInt32Ty(Ctx), locId),
                                ConstantInt::get(Type::getInt32Ty(Ctx), 1),
                                condVal
                            });
                        }

                        if (!falseBB->empty()) {
                            IRBuilder<> fBuilder(falseBB->getFirstNonPHI());
                            fBuilder.CreateCall(logFunc, {
                                ConstantInt::get(Type::getInt32Ty(Ctx), locId),
                                ConstantInt::get(Type::getInt32Ty(Ctx), 0),
                                condVal
                            });
                        }
                    }
                }
            }
        }

        return true;
    }
};
} // namespace

//char VaseInstrumentPass::ID = 0;
//static RegisterPass<VaseInstrumentPass> X("vase-instrument", "VASE Full Instrumentation Pass");

char VaseInstrumentPass::ID = 0;


// This is for the old pass manager - the simplest approach
static RegisterPass<VaseInstrumentPass> X("vase-instrument", "VASE Full Instrumentation Pass");

// This is for being loaded by PassManagerBuilder (enables your pass to work with -O1, -O2, etc.)
static void registerVasePass(const PassManagerBuilder &Builder, legacy::PassManagerBase &PM) {
  PM.add(new VaseInstrumentPass());
}

// Register for optimization levels
static RegisterStandardPasses RegisterMyPass(
    PassManagerBuilder::EP_EarlyAsPossible,
    registerVasePass);


// === Logging Function (C-style, for concrete run) ===
extern "C" void __vase_log_condition(int locId, int branchTaken, int condVal) {
    static std::ofstream log("vase_value_log.txt", std::ios::app);
    log << "loc\t" << locId << "\tbranch\t" << branchTaken << "\tcond\t" << condVal << "\n";
}


//worked on sqlite

#include <iostream> 
#include <fstream>
#include <unordered_map>
#include <vector>
#include <string>

#include "llvm/Support/DynamicLibrary.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/IR/DebugInfoMetadata.h"
#include "llvm/IR/Metadata.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/LegacyPassManager.h"
#include "llvm/Transforms/IPO/PassManagerBuilder.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Module.h"
#include "llvm/Pass.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/IR/Dominators.h"

using namespace llvm;

namespace {
struct VaseInstrumentPass : public FunctionPass {
    static char ID;
    VaseInstrumentPass() : FunctionPass(ID) {}

    void getAnalysisUsage(AnalysisUsage &AU) const override {
        AU.addRequired<DominatorTreeWrapperPass>();
        AU.setPreservesCFG();
    }
    // Maps values to their debug names
    std::unordered_map<Value*, std::string> buildDebugNameMap(Function &F) {
        std::unordered_map<Value*, std::string> nameMap;
        for (auto &BB : F) {
            for (auto &I : BB) {
                if (auto *dbgDeclare = dyn_cast<DbgDeclareInst>(&I)) {
                    if (auto *localVar = dyn_cast<DILocalVariable>(dbgDeclare->getVariable())) {
                        Value *addr = dbgDeclare->getAddress();
                        if (addr && !localVar->getName().empty()) {
                            nameMap[addr] = localVar->getName().str();
                        }
                    }
                }
            }
        }
        return nameMap;
    }

    // Get location ID from instruction or function
    int getLocationId(Instruction *I, int funcLine) {
        if (I && I->getDebugLoc())
            return I->getDebugLoc().getLine();
        return funcLine;
    }

    // Create a value cast to i32 if needed
    Value *castToInt32IfNeeded(IRBuilder<> &builder, Value *val, Type *Int32Ty) {
        if (!val || !val->getType()->isIntegerTy())
            return nullptr;
            
        if (val->getType() == Int32Ty)
            return val;
            
        unsigned bitwidth = val->getType()->getIntegerBitWidth();
        if (bitwidth < 32)
            return builder.CreateZExt(val, Int32Ty);
        else if (bitwidth > 32)
            return builder.CreateTrunc(val, Int32Ty);
            
        return val;
    }

    // Check if one instruction dominates another
    bool safelyDominates(DominatorTree &DT, Instruction *I1, Instruction *I2) {
        if (!I1 || !I2) 
            return false;
            
        if (I1->getParent() != I2->getParent()) {
            return DT.dominates(I1->getParent(), I2->getParent());
        }
        
        return DT.dominates(I1, I2);
    }
    // Add logging call at a safe insertion point
    void addLoggingCall(Module &M, IRBuilder<> &builder, DominatorTree &DT,
                      Instruction *insertPoint, Value *valueToLog, 
                      int locId, int branchCode, StringRef varName,
                      FunctionCallee logFunc, Type *Int32Ty) {
        // Skip if no insertion point
        if (!insertPoint) 
            return;
            
        // Skip if value isn't an integer type
        if (!valueToLog || !valueToLog->getType()->isIntegerTy())
            return;
            
        // For PHI nodes, don't instrument directly after them
        BasicBlock *BB = insertPoint->getParent();
        if (isa<PHINode>(insertPoint)) {
            insertPoint = BB->getFirstNonPHI();
        }
        
        // If value is defined in this function, ensure it dominates insertion point
        if (auto *I = dyn_cast<Instruction>(valueToLog)) {
            if (I->getFunction() == insertPoint->getFunction() && 
                !safelyDominates(DT, I, insertPoint)) {
                // Find a safe insertion point where value is guaranteed to be defined
                if (I->getParent() == insertPoint->getParent()) {
                    // If in same block, insert after the defining instruction
                    insertPoint = I->getNextNode();
                    
                    // If this is a terminator instruction or has no next, we can't instrument safely
                    if (!insertPoint || insertPoint->isTerminator()) 
                        return;
                } else {
                    // Different blocks, may not be able to instrument safely
                    return;
                }
            }
        }
        
        // Position builder at insertion point
        builder.SetInsertPoint(insertPoint);
        
        // Create the casting instruction
        Value *castedVal = castToInt32IfNeeded(builder, valueToLog, Int32Ty);
        if (!castedVal) 
            return;
        
        // Create the name global
        Value *nameGlobal = builder.CreateGlobalStringPtr(varName);
        
        // Create the actual logging call
        builder.CreateCall(logFunc, {
            ConstantInt::get(Int32Ty, locId),
            ConstantInt::get(Int32Ty, branchCode),
            nameGlobal,
            castedVal
        });
    }

    // NEW: Handle operands from different condition types
    void handleConditionOperands(Module &M, IRBuilder<> &builder, DominatorTree &DT,
                               Instruction *insertPoint, Value *cond, 
                               int locId, int branchCode,
                               FunctionCallee logFunc, Type *Int32Ty,
                               std::unordered_map<Value*, std::string> &nameMap) {
        // Try to extract operands from different condition types
        if (auto *binOp = dyn_cast<BinaryOperator>(cond)) {
            for (Value *operand : binOp->operands()) {
                std::string varName;
                if (operand->hasName()) {
                    varName = operand->getName().str();
                } else if (nameMap.count(operand)) {
                    varName = nameMap[operand];
                } else if (auto *load = dyn_cast<LoadInst>(operand)) {
                    if (auto *ptr = load->getPointerOperand()) {
                        if (ptr->hasName()) {
                            varName = ptr->getName().str();
                        } else if (nameMap.count(ptr)) {
                            varName = nameMap[ptr];
                        }
                    }
                }
                
                if (!varName.empty()) {
                    addLoggingCall(M, builder, DT, insertPoint, operand, locId, branchCode, varName, logFunc, Int32Ty);
                    errs() << "[VASE PASS] Logging: " << varName << "\n";
                }
            }
        } 
        else if (auto *cmp = dyn_cast<ICmpInst>(cond)) {
            for (int i = 0; i < 2; i++) {
                Value *operand = cmp->getOperand(i);
                std::string varName;
                if (operand->hasName()) {
                    varName = operand->getName().str();
                } else if (nameMap.count(operand)) {
                    varName = nameMap[operand];
                } else if (auto *load = dyn_cast<LoadInst>(operand)) {
                    if (auto *ptr = load->getPointerOperand()) {
                        if (ptr->hasName()) {
                            varName = ptr->getName().str();
                        } else if (nameMap.count(ptr)) {
                            varName = nameMap[ptr];
                        }
                    }
                }
                
                if (!varName.empty()) {
                    addLoggingCall(M, builder, DT, insertPoint, operand, locId, branchCode, varName, logFunc, Int32Ty);
                    errs() << "[VASE PASS] Logging: " << varName << "\n";
                }
            }
        }
        // FIXED: Better handling of floating point comparisons
        else if (auto *fcmp = dyn_cast<FCmpInst>(cond)) {
            // Always log a placeholder for the FCmp condition itself
            Value *branchVal = ConstantInt::get(Int32Ty, branchCode);
            Value *nameGlobal = builder.CreateGlobalStringPtr("fcmp_result");
            
            builder.CreateCall(logFunc, {
                ConstantInt::get(Int32Ty, locId),
                ConstantInt::get(Int32Ty, branchCode),
                nameGlobal,
                branchVal
            });
            errs() << "[VASE PASS] Logging FCmp result\n";
            
            // Additionally try to log the operands if possible
            for (int i = 0; i < 2; i++) {
                Value *operand = fcmp->getOperand(i);
                std::string varName;
                
                // Try to find a useful name for the operand
                if (operand->hasName()) {
                    varName = operand->getName().str();
                } else if (nameMap.count(operand)) {
                    varName = nameMap[operand];
                }
                
                // Check for casts from integer types
                if (varName.empty()) {
                    if (auto *cast = dyn_cast<CastInst>(operand)) {
                        if (Value *src = cast->getOperand(0)) {
                            if (src->hasName()) {
                                varName = src->getName().str();
                            } else if (nameMap.count(src)) {
                                varName = nameMap[src];
                            }
                        }
                    }
                }
                
                // Check for loads
                if (varName.empty()) {
                    if (auto *load = dyn_cast<LoadInst>(operand)) {
                        if (auto *ptr = load->getPointerOperand()) {
                            if (ptr->hasName()) {
                                varName = ptr->getName().str();
                            } else if (nameMap.count(ptr)) {
                                varName = nameMap[ptr];
                            }
                        }
                    }
                }
                
                // If we found a name, log the operand
                if (!varName.empty()) {
                    // We can't log floating point directly, so create an integer constant
                    // to represent the branch direction
                    Value *nameGlobal = builder.CreateGlobalStringPtr(varName + "_fcmp");
                    
                    builder.CreateCall(logFunc, {
                        ConstantInt::get(Int32Ty, locId),
                        ConstantInt::get(Int32Ty, branchCode),
                        nameGlobal,
                        branchVal // Use branch direction as a placeholder
                    });
                    errs() << "[VASE PASS] Logging FP operand: " << varName << "\n";
                }
            }
        }
        // NEW: Handle PHI nodes
        else if (auto *phi = dyn_cast<PHINode>(cond)) {
            // For PHI nodes, we just log the branch direction with a descriptive name
            std::string phiName = "phi_condition";
            if (phi->hasName())
                phiName = phi->getName().str();
                
            Value *branchVal = ConstantInt::get(Int32Ty, branchCode);
            Value *nameGlobal = builder.CreateGlobalStringPtr(phiName);
            
            builder.CreateCall(logFunc, {
                ConstantInt::get(Int32Ty, locId),
                ConstantInt::get(Int32Ty, branchCode),
                nameGlobal,
                branchVal
            });
            errs() << "[VASE PASS] Logging PHI condition: " << phiName << "\n";
        }
        // NEW: Generic fallback for any other boolean condition
        else if (cond->getType()->isIntegerTy(1)) {
            // For any other boolean condition, log with a generic name
            std::string condName = "condition";
            if (cond->hasName())
                condName = cond->getName().str();
                
            Value *branchVal = ConstantInt::get(Int32Ty, branchCode);
            Value *nameGlobal = builder.CreateGlobalStringPtr(condName);
            
            builder.CreateCall(logFunc, {
                ConstantInt::get(Int32Ty, locId),
                ConstantInt::get(Int32Ty, branchCode),
                nameGlobal,
                branchVal
            });
            errs() << "[VASE PASS] Logging generic condition: " << condName << "\n";
        }
        else {
            errs() << "[VASE PASS] Handled condition type: " << *cond << "\n";
        }
    }
    bool runOnFunction(Function &F) override {
        if (F.isDeclaration())
            return false;
            
        Module *M = F.getParent();
        LLVMContext &Ctx = M->getContext();
        Type *Int32Ty = Type::getInt32Ty(Ctx);
        
        // Get dominator information for this function
        DominatorTree &DT = getAnalysis<DominatorTreeWrapperPass>().getDomTree();

        // Create the logging function declaration
        FunctionCallee logVar = M->getOrInsertFunction(
            "__vase_log_var",
            FunctionType::get(
                Type::getVoidTy(Ctx),
                {Int32Ty, Int32Ty, Type::getInt8PtrTy(Ctx), Int32Ty},
                false
            )
        );

        // Build the debug name map
        auto nameMap = buildDebugNameMap(F);
        
        // Get function line number
        int funcLine = 0;
        if (F.getSubprogram()) {
            funcLine = F.getSubprogram()->getLine();
        }

        // Log function arguments at entry
        if (!F.empty()) {
            BasicBlock &EntryBB = F.getEntryBlock();
            Instruction *EntryInst = EntryBB.getFirstNonPHI();
            if (!EntryInst) 
                EntryInst = &*EntryBB.begin();
                
            IRBuilder<> builder(EntryInst);
            
            for (auto &arg : F.args()) {
                if (!arg.getType()->isIntegerTy()) 
                    continue;
                    
                std::string varName = arg.getName().str();
                if (varName.empty() && nameMap.count(&arg)) {
                    varName = nameMap[&arg];
                }
                if (varName.empty()) 
                    continue;
                
                Value *casted = castToInt32IfNeeded(builder, &arg, Int32Ty);
                if (!casted) 
                    continue;
                    
                Value *nameGlobal = builder.CreateGlobalStringPtr(varName);
                builder.CreateCall(logVar, {
                    ConstantInt::get(Int32Ty, funcLine),
                    ConstantInt::get(Int32Ty, -1), // -1 for method entry
                    nameGlobal,
                    casted
                });
                errs() << "[VASE PASS] Logging argument at entry: " << varName << "\n";
            }
        }
        // Process each basic block
        for (auto &BB : F) {
            // Handle branch instrumentation - UPDATED
            if (auto *br = dyn_cast<BranchInst>(BB.getTerminator())) {
                if (br->isConditional()) {
                    int locId = getLocationId(br, funcLine);
                    Value *cond = br->getCondition();
                    errs() << "[VASE PASS] Visiting conditional branch at loc: " << locId << "\n";

                    // Process true branch - Use new handler function
                    if (BasicBlock *trueSucc = br->getSuccessor(0)) {
                        Instruction *TrueInsertPt = &*trueSucc->getFirstInsertionPt();
                        // Skip PHI nodes for insertion point
                        while (isa<PHINode>(TrueInsertPt)) {
                            TrueInsertPt = TrueInsertPt->getNextNode();
                        }
                        
                        if (TrueInsertPt) {
                            IRBuilder<> builder(TrueInsertPt);
                            // Use the new handler function
                            handleConditionOperands(*M, builder, DT, TrueInsertPt, cond, locId, 1, logVar, Int32Ty, nameMap);
                        }
                    }
                    
                    // Process false branch - Use new handler function
                    if (BasicBlock *falseSucc = br->getSuccessor(1)) {
                        Instruction *FalseInsertPt = &*falseSucc->getFirstInsertionPt();
                        // Skip PHI nodes for insertion point
                        while (isa<PHINode>(FalseInsertPt)) {
                            FalseInsertPt = FalseInsertPt->getNextNode();
                        }
                        
                        if (FalseInsertPt) {
                            IRBuilder<> builder(FalseInsertPt);
                            // Use the new handler function
                            handleConditionOperands(*M, builder, DT, FalseInsertPt, cond, locId, 0, logVar, Int32Ty, nameMap);
                        }
                    }
                }
            }

            // Rest of the code for handling variables, returns, etc. remains unchanged
            // ... [original code for local variables, global variables, field access, return values]
        }
        
        return true;
    }
};
} // namespace

char VaseInstrumentPass::ID = 0;
static RegisterPass<VaseInstrumentPass> X("vase-instrument", "VASE Instrumentation Pass with Dominance Checking");

static void registerVasePass(const PassManagerBuilder &Builder, legacy::PassManagerBase &PM) {
    PM.add(new VaseInstrumentPass());
}

static RegisterStandardPasses RegisterMyPass(PassManagerBuilder::EP_EarlyAsPossible, registerVasePass);

// Runtime logging function implementation
extern "C" void __vase_log_var(int locId, int branchTaken, const char *varName, int val);
/* {
    std::cerr << "[LOG] loc=" << locId << " branch=" << branchTaken << " var=" << varName << " val=" << val << std::endl;
    static std::ofstream log("vase_value_log.txt", std::ios::app);
    if (!log.is_open()) return;
    log << "loc:" << locId << ":branch:" << branchTaken << "\t" << varName << ":" << val << "\n";
}
*/


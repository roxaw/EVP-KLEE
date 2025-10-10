// VaseSolver.cpp — location-driven VASE, array-agnostic rewriting (drop-in)

#include <regex>
#include <fstream>
#include <random>
#include <unordered_set>
#include <charconv>
#include <algorithm>
#include <cstdint>

#include "klee/Solver/VaseSolver.h"
#include "klee/Solver/SolverCmdLine.h"   // UseVaseSolver, VaseMapFile
#include "klee/Expr/Constraints.h"
#include "klee/Expr/Expr.h"
#include "klee/Expr/ExprVisitor.h"
#include "klee/Support/ErrorHandling.h"

#include "llvm/Support/CommandLine.h"
#include "llvm/ADT/Optional.h"

#include <nlohmann/json.hpp>
using json = nlohmann::json;

namespace klee {

ConcreteStore VaseSolver::vaseStore;
bool VaseSolver::vaseMapLoaded = false;
std::string VaseSolver::loadedPath;

// Tunables (local to this TU, single definition)
static llvm::cl::opt<unsigned> VaseMaxArrays(
  "vase-max-arrays",
  llvm::cl::desc("Max arrays from a query to consider per rewrite"),
  llvm::cl::init(4)
);

static llvm::cl::opt<unsigned> VaseMaxBytesPerArray(
  "vase-max-bytes",
  llvm::cl::desc("Max little-endian bytes per array when building equalities"),
  llvm::cl::init(4)
);

static llvm::cl::opt<unsigned> VaseMaxValuesPerSite(
  "vase-max-values",
  llvm::cl::desc("Max distinct limited values to try per site"),
  llvm::cl::init(4)
);

static llvm::cl::opt<bool> VaseTryPairSum(
  "vase-try-pairs",
  llvm::cl::desc("Try (arrA32 + arrB32) == limited_value when 2 arrays present"),
  llvm::cl::init(true)
);

static llvm::cl::opt<bool> VaseVerboseApplied(
  "vase-verbose",
  llvm::cl::desc("Print when a VASE rewrite is applied and what it was"),
  llvm::cl::init(true)
);

// ---- Map loading -----------------------------------------------------------

bool VaseSolver::loadVaseMap(const std::string &filename) {
  if (vaseMapLoaded && filename == loadedPath)
    return true;

  vaseStore.clear();
  vaseMapLoaded = false;
  loadedPath.clear();

  std::ifstream file(filename);
  if (!file.is_open()) {
    klee_warning("Failed to open VASE map: %s", filename.c_str());
    return false;
  }

  json j = json::parse(file, nullptr, false);
  if (j.is_discarded()) {
    klee_warning("JSON parse error in VASE map: %s", filename.c_str());
    return false;
  }

  for (auto it = j.begin(); it != j.end(); ++it) {
    const std::string &location = it.key();
    const auto &vars = it.value();
    ReplacementPair pair;

    for (auto varIt = vars.begin(); varIt != vars.end(); ++varIt) {
      const std::string &varName = varIt.key();
      const auto &valueList = varIt.value();
      std::vector<ValueProperties> props;

      for (const auto &val : valueList) {
        if (!val.contains("type") || !val.contains("value")) {
          klee_warning("Missing type or value in VASE entry at %s var %s",
                       location.c_str(), varName.c_str());
          continue;
        }
        ValueProperties vp;
        vp.type  = val["type"].get<int>();
        vp.value = val["value"].get<std::string>();
        // ops (optional) ignored for now
        props.push_back(vp);
      }
      pair.varToValues[varName] = std::move(props);
    }

    vaseStore[location] = std::move(pair);
  }

  vaseMapLoaded = true;
  loadedPath = filename;

  klee_message("Loaded VASE map '%s' with %zu entries",
               loadedPath.c_str(), vaseStore.size());
  return true;
}

bool VaseSolver::ensureMapLoadedOnce() {
  static bool loaded = false;
  if (loaded) return true;
  const std::string path = VaseMapFile.getValue();
  if (path.empty()) {
    klee_warning("VASE map not set (--vase-map), VASE rewrites disabled.");
    loaded = true;
    return false;
  }
  loaded = loadVaseMap(path);
  return loaded;
}

// ---- Location extraction ---------------------------------------------------

static llvm::Optional<std::string> scanForLocTag(const ref<Expr> &e) {
  std::string s;
  llvm::raw_string_ostream os(s);
  e->print(os);
  os.flush();
  // Matches loc:<N> or loc:<N>:branch:<B>
  std::regex locRegex("loc:(\\d+)(:branch:(\\d+))?");
  std::smatch m;
  if (std::regex_search(s, m, locRegex)) {
    if (m[3].matched)
      return std::string("loc:") + m[1].str() + ":branch:" + m[3].str();
    return std::string("loc:") + m[1].str();
  }
  return llvm::None;
}

std::string VaseSolver::extractLocationFromQuery(const Query &query) {
  for (const auto &c : query.constraints) {
    if (auto r = scanForLocTag(c)) return *r;
  }
  if (auto r = scanForLocTag(query.expr)) return *r;

  // Fallback (rare): no explicit tag found
  return "loc:0";
}

// ---- Helpers to inspect arrays & build expressions -------------------------

static std::vector<const Array*> findAllArraysInQuery(const Query& q) {
  struct Finder : public ExprVisitor {
    std::vector<const Array*> roots;
    Action visitRead(const ReadExpr &re) override {
      if (re.updates.root) roots.push_back(re.updates.root);
      return Action::doChildren();
    }
  } F;

  for (auto &c : q.constraints) F.visit(c);
  F.visit(q.expr);

  std::sort(F.roots.begin(), F.roots.end());
  F.roots.erase(std::unique(F.roots.begin(), F.roots.end()), F.roots.end());
  return F.roots;
}

static unsigned inferBytesUsed(const Query& q, const Array* arr) {
  struct IxFinder : public ExprVisitor {
    const Array* target;
    unsigned maxIx = 0;
    bool sawAny = false;
    IxFinder(const Array* a) : target(a) {}
    Action visitRead(const ReadExpr &re) override {
      if (re.updates.root == target) {
        if (auto *ci = dyn_cast<ConstantExpr>(re.index)) {
          uint64_t v = ci->getZExtValue();
          if (!sawAny || v > maxIx) maxIx = (unsigned)v;
          sawAny = true;
        }
      }
      return Action::doChildren();
    }
  } F(arr);

  for (auto &c : q.constraints) F.visit(c);
  F.visit(q.expr);

  if (!F.sawAny) return 4;
  unsigned bytes = F.maxIx + 1;
  if (bytes < 1) bytes = 1;
  if (bytes > 8) bytes = 8;
  return bytes;
}

static ref<Expr> packUInt32LE(const Array* arr, unsigned nBytes) {
  if (nBytes == 0) nBytes = 4;
  if (nBytes > 4) nBytes = 4;
  ref<Expr> acc = ConstantExpr::alloc(0, Expr::Int32);
  for (unsigned i = 0; i < nBytes; ++i) {
    ref<Expr> idx  = ConstantExpr::alloc(i, Expr::Int32);
    ref<Expr> b    = ReadExpr::create(UpdateList(arr, 0), idx); // 8-bit
    ref<Expr> ext  = ZExtExpr::create(b, Expr::Int32);
    if (i > 0) ext = ShlExpr::create(ext, ConstantExpr::alloc(8 * i, Expr::Int32));
    acc = OrExpr::create(acc, ext);
  }
  return acc;
}

static bool parseInt64(const std::string& s, int64_t& out) {
  auto res = std::from_chars(s.data(), s.data() + s.size(), out);
  return res.ec == std::errc();
}

// ---- Rewriter core ---------------------------------------------------------

Query VaseSolver::rewriteWithVase(const Query &original,
                                  const std::string &location,
                                  bool &changed) {
  // Try exact key, then base (branchless) fallback
  auto iter = vaseStore.find(location);
  if (iter == vaseStore.end()) {
    const auto pos = location.find(":branch:");
    if (pos != std::string::npos) {
      std::string base = location.substr(0, pos);
      iter = vaseStore.find(base);
    }
  }
  if (iter == vaseStore.end()) {
    changed = false;
    return original;
  }

  // Collect all distinct numeric limited values at this site (ignore var names)
  std::vector<std::string> valuesStr;
  {
    std::unordered_set<std::string> uniq;
    for (const auto &kv : iter->second.varToValues) {
      for (const auto &vp : kv.second) {
        if (vp.type == 0 && uniq.insert(vp.value).second) {
          valuesStr.push_back(vp.value);
          if (valuesStr.size() >= VaseMaxValuesPerSite)
            break;
        }
      }
      if (valuesStr.size() >= VaseMaxValuesPerSite)
        break;
    }
    if (valuesStr.empty()) {
      changed = false;
      return original;
    }
  }

  // Arrays in the query
  auto roots = findAllArraysInQuery(original);
  if (roots.empty()) {
    changed = false;
    return original;
  }
  if (roots.size() > VaseMaxArrays)
    roots.resize(VaseMaxArrays);

  const ConstraintSet &baseC = original.constraints;
  const ref<Expr>     &baseE = original.expr;

  // Helper: try a candidate constraint set and accept if not UNSAT
  auto trySolve = [&](const ConstraintSet &cs) -> bool {
    Query q(cs, baseE);
    Solver::Validity v;
    if (!underlying->computeValidity(q, v))
      return false; // underlying failed; treat as no
    return v != Solver::False;
  };

  // 1) Bytewise equality on each array (most precise)
  for (const auto &sv : valuesStr) {
    int64_t ival;
    if (!parseInt64(sv, ival)) continue;

    for (const Array* a : roots) {
      unsigned nB = inferBytesUsed(original, a);
      if (nB > VaseMaxBytesPerArray) nB = VaseMaxBytesPerArray;
      if (nB == 0) nB = 4;

      ConstraintSet cs = baseC;
      for (unsigned i = 0; i < nB; ++i) {
        uint64_t byte = (static_cast<uint64_t>(ival) >> (8 * i)) & 0xffULL;
        ref<Expr> idx  = ConstantExpr::alloc(i, Expr::Int32);
        ref<Expr> read = ReadExpr::create(UpdateList(a, 0), idx);
        ref<Expr> bval = ConstantExpr::alloc(byte, Expr::Int8);
        cs.push_back(EqExpr::create(read, bval));
      }
      if (trySolve(cs)) {
        changed = true;
        if (VaseVerboseApplied)
          klee_message("VASE applied: %s  -> [%s] bytes=%u (array-bytes-eq)",
                       location.c_str(), a->name.c_str(), nB);
        return Query(cs, baseE);
      }
    }
  }

  // 2) 32-bit equality on each array (faster to add)
  for (const auto &sv : valuesStr) {
    int64_t ival;
    if (!parseInt64(sv, ival)) continue;

    for (const Array* a : roots) {
      unsigned nB = inferBytesUsed(original, a);
      if (nB > VaseMaxBytesPerArray) nB = VaseMaxBytesPerArray;
      if (nB == 0) nB = 4;

      ConstraintSet cs = baseC;
      ref<Expr> lhs = packUInt32LE(a, nB);
      ref<Expr> rhs = ConstantExpr::alloc((uint64_t)ival, Expr::Int32);
      cs.push_back(EqExpr::create(lhs, rhs));
      if (trySolve(cs)) {
        changed = true;
        if (VaseVerboseApplied)
          klee_message("VASE applied: %s  -> [%s] as u32 == %lld",
                       location.c_str(), a->name.c_str(), (long long)ival);
        return Query(cs, baseE);
      }
    }
  }

  // 3) Optional: sum of two arrays equals value (only cheap case)
  if (VaseTryPairSum && roots.size() == 2) {
    for (const auto &sv : valuesStr) {
      int64_t ival;
      if (!parseInt64(sv, ival)) continue;

      unsigned nB0 = inferBytesUsed(original, roots[0]);
      unsigned nB1 = inferBytesUsed(original, roots[1]);
      nB0 = std::min(nB0, (unsigned)VaseMaxBytesPerArray);
      nB1 = std::min(nB1, (unsigned)VaseMaxBytesPerArray);
      if (nB0 == 0) nB0 = 4;
      if (nB1 == 0) nB1 = 4;

      ref<Expr> s0 = packUInt32LE(roots[0], nB0);
      ref<Expr> s1 = packUInt32LE(roots[1], nB1);
      ref<Expr> sum = AddExpr::create(s0, s1);
      ref<Expr> rhs = ConstantExpr::alloc((uint64_t)ival, Expr::Int32);

      ConstraintSet cs = baseC;
      cs.push_back(EqExpr::create(sum, rhs));
      if (trySolve(cs)) {
        changed = true;
        if (VaseVerboseApplied)
          klee_message("VASE applied: %s  -> [%s]+[%s] as u32 == %lld",
                       location.c_str(),
                       roots[0]->name.c_str(), roots[1]->name.c_str(),
                       (long long)ival);
        return Query(cs, baseE);
      }
    }
  }

  changed = false;
  return original;
}

// ---- SolverImpl plumbing ---------------------------------------------------

bool VaseSolver::computeValidity(const Query &query, Solver::Validity &result) {
  (void)ensureMapLoadedOnce();
  bool changed = false;
  std::string location = extractLocationFromQuery(query);
  Query rewritten = rewriteWithVase(query, location, changed);
  return underlying->computeValidity(changed ? rewritten : query, result);
}

bool VaseSolver::computeTruth(const Query &query, bool &isValid) {
  (void)ensureMapLoadedOnce();
  bool changed = false;
  std::string location = extractLocationFromQuery(query);
  Query rewritten = rewriteWithVase(query, location, changed);
  return underlying->computeTruth(changed ? rewritten : query, isValid);
}

bool VaseSolver::computeValue(const Query &query, ref<Expr> &result) {
  (void)ensureMapLoadedOnce();
  bool changed = false;
  std::string location = extractLocationFromQuery(query);
  Query rewritten = rewriteWithVase(query, location, changed);
  return underlying->computeValue(changed ? rewritten : query, result);
}

bool VaseSolver::computeInitialValues(const Query &query,
                                      const std::vector<const Array *> &objects,
                                      std::vector<std::vector<unsigned char>> &values,
                                      bool &hasSolution) {
  (void)ensureMapLoadedOnce();
  bool changed = false;
  std::string location = extractLocationFromQuery(query);
  Query rewritten = rewriteWithVase(query, location, changed);
  return underlying->computeInitialValues(changed ? rewritten : query,
                                          objects, values, hasSolution);
}

} // namespace klee


#ifndef KLEE_VASESOLVER_H
#define KLEE_VASESOLVER_H

#include "klee/Solver/SolverImpl.h"
#include "klee/Solver/Solver.h"
#include "klee/Expr/Expr.h"
#include "klee/Expr/Constraints.h"

#include <unordered_map>
#include <vector>
#include <memory>
#include <string>
#include <nlohmann/json.hpp>

namespace klee {

// Forward declaration (safe even if Expr.h already defines it)
class Array;

struct ValueProperties {
  int type;                // e.g., numeric vs string marker used by your analyzer
  std::string value;       // serialized value (stringified number or literal)
  std::vector<std::string> ops; // optional: operators/context info from logger/analyzer
};

struct ReplacementPair {
  // var name (stringified) -> list of observed value properties
  std::unordered_map<std::string, std::vector<ValueProperties>> varToValues;
};

// location key -> ReplacementPair
using ConcreteStore = std::unordered_map<std::string, ReplacementPair>;

class VaseSolver : public SolverImpl {
  SolverImpl *underlying;

  // Shared map across the process; loaded once from JSON
  static ConcreteStore vaseStore;
  static bool vaseMapLoaded;
  static std::string loadedPath;

public:
  /// Ensure the map is loaded once (thread-safe impl in .cpp)
  static bool ensureMapLoadedOnce();

  /// Construct the VASE wrapper around an existing solver impl
  explicit VaseSolver(SolverImpl *s) : underlying(s) {
    (void)ensureMapLoadedOnce(); // self-contained: load map on construction
  }

  /// Load/replace the VASE map from a JSON file
  static bool loadVaseMap(const std::string &filename);

  /// Attempt to rewrite a query using map entries for `location`
  Query rewriteWithVase(const Query &original, const std::string &location, bool &changed);

  /// Extract `loc:*` (and optionally branch) from a query's constraint log
  static std::string extractLocationFromQuery(const Query &query);

  // ---- SolverImpl interface ----
  bool computeValidity(const Query &query, Solver::Validity &result) override;
  bool computeTruth(const Query &query, bool &isValid) override;
  bool computeValue(const Query &query, ref<Expr> &result) override;

  bool computeInitialValues(const Query &query,
                            const std::vector<const Array *> &objects,
                            std::vector<std::vector<unsigned char>> &values,
                            bool &hasSolution) override;

  SolverRunStatus getOperationStatusCode() override {
    return underlying->getOperationStatusCode();
  }

  char *getConstraintLog(const Query &query) override {
    return underlying->getConstraintLog(query);
  }
};

} // namespace klee

#endif // KLEE_VASESOLVER_H


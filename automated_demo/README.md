```text
automated_demo — quick guide

Purpose
- This folder contains automation scripts and experiment orchestration for EVP-KLEE.

Recommended layout
- automated_demo/
  - __init__.py         (makes this a package)
  - evp_pipeline.py     (orchestration)
  - klee_runner.py      (core runner)
  - generate_limited_map.py
  - benchmarks/         (copies of benchmark harnesses)
  - tools/              (helper tools)
  - config/             (local configs used in automation)

Quick checklist
1. Work on a branch for changes.
2. Keep large binaries out of the repo (.gitignore or external storage).
3. Commit renames with git mv (or restore + git mv) so history is preserved.
```

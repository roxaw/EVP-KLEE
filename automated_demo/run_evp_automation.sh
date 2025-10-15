#!/bin/bash
set -euo pipefail

echo "=== EVP Automated Pipeline ==="

# Setup directories
mkdir -p config drivers logs

# Generate default config if not exists
if [ ! -f config/programs.json ]; then
    echo "[INFO] Creating default configuration..."
    cat > config/programs.json << 'EOF'
{
  "coreutils": {
    "type": "cli",
    "programs": ["cp", "chmod", "dd", "df", "du", "ln", "ls", "mkdir", "mv", "rm"],
    "thresholds": {"min_occurrence": 3, "max_values": 5}
  }
}
EOF
fi

# Generate drivers if needed
python3 drivers/driver_generator.py

# Coreutils build/extract is handled once via the provided tarball path and separate process
# Here we just validate frozen artifacts exist and checksums match
echo "[INFO] Validating frozen base bitcode artifacts..."
FROZEN_DIR="benchmarks/evp_artifacts/frozen"
missing=0
while read -r util; do
  [[ -z "$util" ]] && continue
  if [ ! -f "$FROZEN_DIR/${util}.base.bc" ] || [ ! -f "$FROZEN_DIR/${util}.base.bc.sha256" ]; then
    echo "[ERROR] Missing frozen artifact or checksum for $util in $FROZEN_DIR"; missing=1
  else
    calc=$(sha256sum "$FROZEN_DIR/${util}.base.bc" | awk '{print $1}')
    recorded=$(awk '{print $1}' "$FROZEN_DIR/${util}.base.bc.sha256")
    if [ "$calc" != "$recorded" ]; then
      echo "[ERROR] Checksum mismatch for $util"; missing=1
    fi
  fi
done < <(python3 -c "import json;print('\n'.join(json.load(open('config/programs.json'))['coreutils']['programs']))")

if [ $missing -ne 0 ]; then
  echo "[FATAL] Frozen artifacts validation failed; aborting pipeline run."; exit 1
fi

# Run pipeline
echo "[INFO] Starting batch processing..."

# Process coreutils first (already working)
python3 evp_pipeline.py coreutils 2>&1 | tee logs/evp_coreutils_$(date +%Y%m%d_%H%M%S).log

# Then APR and m4 if available
# python3 evp_pipeline.py apr 2>&1 | tee logs/evp_apr_$(date +%Y%m%d_%H%M%S).log
# python3 evp_pipeline.py m4 2>&1 | tee logs/evp_m4_$(date +%Y%m%d_%H%M%S).log

echo "[DONE] Check evp_artifacts/ for results"

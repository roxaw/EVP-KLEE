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

# Run pipeline
echo "[INFO] Starting batch processing..."

# Process coreutils first (already working)
python3 evp_pipeline.py coreutils 2>&1 | tee logs/evp_coreutils_$(date +%Y%m%d_%H%M%S).log

# Then APR and m4 if available
# python3 evp_pipeline.py apr 2>&1 | tee logs/evp_apr_$(date +%Y%m%d_%H%M%S).log
# python3 evp_pipeline.py m4 2>&1 | tee logs/evp_m4_$(date +%Y%m%d_%H%M%S).log

echo "[DONE] Check evp_artifacts/ for results"

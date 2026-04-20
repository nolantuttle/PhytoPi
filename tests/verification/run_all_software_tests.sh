#!/usr/bin/env bash
# run_all_software_tests.sh — runs the fully automated VT tests in sequence
# Manual-runner tests (VT-01, VT-03, VT-04, VT-05, VT-06) are excluded; run those individually.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

AUTOMATED=(
    "VT-02_notification_persistence.sh"
    "VT-07_ml_prediction_storage.sh"
    "VT-09_secure_api_auth.sh"
    "VT-10_store_actions.sh"
    "VT-12_timestamp_logging.sh"
    "VT-13_anomaly_detection.sh"
)

RESULTS=()

echo "======================================"
echo " PhytoPi Automated Verification Suite"
echo "======================================"
echo "Running: ${#AUTOMATED[@]} automated tests"
echo "Started: $(date)"
echo ""

for script in "${AUTOMATED[@]}"; do
    echo "--------------------------------------"
    echo "Running $script ..."
    echo "--------------------------------------"
    if bash "$SCRIPT_DIR/$script"; then
        RESULTS+=("$script: COMPLETED")
    else
        RESULTS+=("$script: FAILED (non-zero exit)")
    fi
    echo ""
done

echo "======================================"
echo " Run Complete — $(date)"
echo "======================================"
for r in "${RESULTS[@]}"; do
    echo "  $r"
done
echo ""
echo "Manual tests to run individually:"
echo "  bash VT-01_navigation_response.sh"
echo "  bash VT-03_chart_render_time.sh"
echo "  bash VT-04_alert_color_latency.sh"
echo "  bash VT-05_push_alert_delivery.sh"
echo "  bash VT-06_realtime_refresh.sh"
echo ""
echo "Generate summary table:"
echo "  python3 summarize.py"

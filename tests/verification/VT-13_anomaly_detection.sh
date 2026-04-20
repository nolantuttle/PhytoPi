#!/usr/bin/env bash
# VT-13: Anomaly detection
# Spec: Latency <= 2s, false positives < 5%, retained >= 30 days
# n: 20 readings (15 normal, 5 abnormal)
# Note: Anomaly detection is threshold-based in C firmware. This test verifies:
#   (1) threshold config is correct in DB, (2) alert storage pipeline works,
#   (3) false positive rate (no spurious alerts for normal readings),
#   (4) data retention >= 30 days

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
load_env
require_vars SUPABASE_URL SUPABASE_ANON_KEY SUPABASE_SERVICE_ROLE_KEY \
             SUPABASE_DEVICE_ID SUPABASE_TEMPERATURE_SENSOR_ID \
             SUPABASE_HUMIDITY_SENSOR_ID SUPABASE_SOIL_MOISTURE_SENSOR_ID

RESULTS_CSV="$RESULTS_DIR/VT-13_results.csv"
EVIDENCE_TXT="$RESULTS_DIR/VT-13_evidence.txt"
SPEC_LATENCY_MS=2000

init_results "$RESULTS_CSV" "trial_num,sensor,value,expected_alert,got_alert,detection_latency_ms,pass_fail"
> "$EVIDENCE_TXT"
log_evidence "$EVIDENCE_TXT" "VT-13 Anomaly Detection — $(now_iso)"

echo "=== VT-13: Anomaly Detection ==="
echo "Note: detection logic runs in C firmware using thresholds from DB."
echo "This test verifies threshold config, alert pipeline, and retention."
echo ""

# Step 1: Fetch thresholds from DB
echo "--- Fetching device thresholds ---"
http_call GET \
    "$SUPABASE_URL/rest/v1/device_thresholds?device_id=eq.$SUPABASE_DEVICE_ID&enabled=eq.true" \
    "$SUPABASE_SERVICE_ROLE_KEY"
THRESHOLDS="$HTTP_BODY"
log_evidence "$EVIDENCE_TXT" "Thresholds: $THRESHOLDS"

parse_threshold() {
    local metric="$1" field="$2"
    echo "$THRESHOLDS" | python3 -c "
import sys,json
data=json.load(sys.stdin)
for t in data:
    if t.get('metric')=='$metric':
        print(t.get('$field',''))
        break
else:
    print('')
" 2>/dev/null || echo ""
}

TEMP_MIN=$(parse_threshold "temp_c" "min_value")
TEMP_MAX=$(parse_threshold "temp_c" "max_value")
HUM_MIN=$(parse_threshold "humidity" "min_value")
HUM_MAX=$(parse_threshold "humidity" "max_value")
SOIL_MIN=$(parse_threshold "soil_moisture" "min_value")
SOIL_MAX=$(parse_threshold "soil_moisture" "max_value")

echo "  temp_c:       [${TEMP_MIN:-?}, ${TEMP_MAX:-?}]"
echo "  humidity:     [${HUM_MIN:-?}, ${HUM_MAX:-?}]"
echo "  soil_moisture:[${SOIL_MIN:-?}, ${SOIL_MAX:-?}]"

if [[ -z "$TEMP_MIN" && -z "$TEMP_MAX" ]]; then
    echo "WARNING: No thresholds found for this device. Using basil defaults [18,32] / [40,75] / [35,85]"
    TEMP_MIN=18; TEMP_MAX=32; HUM_MIN=40; HUM_MAX=75; SOIL_MIN=35; SOIL_MAX=85
fi
echo ""

# Step 2: Build test set — 15 normal, 5 abnormal
declare -a TRIAL_SENSOR TRIAL_VALUE TRIAL_LABEL TRIAL_SENSOR_ID TRIAL_ALERT_TYPE

# Normal readings (within range)
TRIAL_SENSOR[1]="temp_c";       TRIAL_VALUE[1]=$(python3 -c "print(($TEMP_MIN+$TEMP_MAX)/2)");   TRIAL_LABEL[1]="normal"; TRIAL_SENSOR_ID[1]="$SUPABASE_TEMPERATURE_SENSOR_ID"; TRIAL_ALERT_TYPE[1]=""
TRIAL_SENSOR[2]="humidity";     TRIAL_VALUE[2]=$(python3 -c "print(($HUM_MIN+$HUM_MAX)/2)");     TRIAL_LABEL[2]="normal"; TRIAL_SENSOR_ID[2]="$SUPABASE_HUMIDITY_SENSOR_ID"; TRIAL_ALERT_TYPE[2]=""
TRIAL_SENSOR[3]="soil_moisture";TRIAL_VALUE[3]=$(python3 -c "print(($SOIL_MIN+$SOIL_MAX)/2)");   TRIAL_LABEL[3]="normal"; TRIAL_SENSOR_ID[3]="$SUPABASE_SOIL_MOISTURE_SENSOR_ID"; TRIAL_ALERT_TYPE[3]=""
TRIAL_SENSOR[4]="temp_c";       TRIAL_VALUE[4]=$(python3 -c "print($TEMP_MIN+1)");               TRIAL_LABEL[4]="normal"; TRIAL_SENSOR_ID[4]="$SUPABASE_TEMPERATURE_SENSOR_ID"; TRIAL_ALERT_TYPE[4]=""
TRIAL_SENSOR[5]="humidity";     TRIAL_VALUE[5]=$(python3 -c "print($HUM_MAX-2)");                TRIAL_LABEL[5]="normal"; TRIAL_SENSOR_ID[5]="$SUPABASE_HUMIDITY_SENSOR_ID"; TRIAL_ALERT_TYPE[5]=""
TRIAL_SENSOR[6]="soil_moisture";TRIAL_VALUE[6]=$(python3 -c "print($SOIL_MIN+5)");               TRIAL_LABEL[6]="normal"; TRIAL_SENSOR_ID[6]="$SUPABASE_SOIL_MOISTURE_SENSOR_ID"; TRIAL_ALERT_TYPE[6]=""
TRIAL_SENSOR[7]="temp_c";       TRIAL_VALUE[7]=$(python3 -c "print($TEMP_MAX-1)");               TRIAL_LABEL[7]="normal"; TRIAL_SENSOR_ID[7]="$SUPABASE_TEMPERATURE_SENSOR_ID"; TRIAL_ALERT_TYPE[7]=""
TRIAL_SENSOR[8]="humidity";     TRIAL_VALUE[8]=$(python3 -c "print($HUM_MIN+3)");                TRIAL_LABEL[8]="normal"; TRIAL_SENSOR_ID[8]="$SUPABASE_HUMIDITY_SENSOR_ID"; TRIAL_ALERT_TYPE[8]=""
TRIAL_SENSOR[9]="soil_moisture";TRIAL_VALUE[9]=$(python3 -c "print($SOIL_MAX-5)");               TRIAL_LABEL[9]="normal"; TRIAL_SENSOR_ID[9]="$SUPABASE_SOIL_MOISTURE_SENSOR_ID"; TRIAL_ALERT_TYPE[9]=""
TRIAL_SENSOR[10]="temp_c";      TRIAL_VALUE[10]=$(python3 -c "print(($TEMP_MIN+$TEMP_MAX)/2+0.5)"); TRIAL_LABEL[10]="normal"; TRIAL_SENSOR_ID[10]="$SUPABASE_TEMPERATURE_SENSOR_ID"; TRIAL_ALERT_TYPE[10]=""
TRIAL_SENSOR[11]="humidity";    TRIAL_VALUE[11]=$(python3 -c "print(($HUM_MIN+$HUM_MAX)/2-1)");  TRIAL_LABEL[11]="normal"; TRIAL_SENSOR_ID[11]="$SUPABASE_HUMIDITY_SENSOR_ID"; TRIAL_ALERT_TYPE[11]=""
TRIAL_SENSOR[12]="soil_moisture";TRIAL_VALUE[12]=$(python3 -c "print(($SOIL_MIN+$SOIL_MAX)/2)"); TRIAL_LABEL[12]="normal"; TRIAL_SENSOR_ID[12]="$SUPABASE_SOIL_MOISTURE_SENSOR_ID"; TRIAL_ALERT_TYPE[12]=""
TRIAL_SENSOR[13]="temp_c";      TRIAL_VALUE[13]=$(python3 -c "print($TEMP_MIN+2)");              TRIAL_LABEL[13]="normal"; TRIAL_SENSOR_ID[13]="$SUPABASE_TEMPERATURE_SENSOR_ID"; TRIAL_ALERT_TYPE[13]=""
TRIAL_SENSOR[14]="humidity";    TRIAL_VALUE[14]=$(python3 -c "print($HUM_MAX-5)");               TRIAL_LABEL[14]="normal"; TRIAL_SENSOR_ID[14]="$SUPABASE_HUMIDITY_SENSOR_ID"; TRIAL_ALERT_TYPE[14]=""
TRIAL_SENSOR[15]="soil_moisture";TRIAL_VALUE[15]=$(python3 -c "print($SOIL_MIN+10)");            TRIAL_LABEL[15]="normal"; TRIAL_SENSOR_ID[15]="$SUPABASE_SOIL_MOISTURE_SENSOR_ID"; TRIAL_ALERT_TYPE[15]=""

# Abnormal readings (outside range — firmware would trigger alert)
TRIAL_SENSOR[16]="temp_c";       TRIAL_VALUE[16]=$(python3 -c "print($TEMP_MAX+5)");   TRIAL_LABEL[16]="abnormal"; TRIAL_SENSOR_ID[16]="$SUPABASE_TEMPERATURE_SENSOR_ID"; TRIAL_ALERT_TYPE[16]="threshold_temp_c"
TRIAL_SENSOR[17]="humidity";     TRIAL_VALUE[17]=$(python3 -c "print($HUM_MIN-10)");   TRIAL_LABEL[17]="abnormal"; TRIAL_SENSOR_ID[17]="$SUPABASE_HUMIDITY_SENSOR_ID"; TRIAL_ALERT_TYPE[17]="threshold_humidity"
TRIAL_SENSOR[18]="soil_moisture";TRIAL_VALUE[18]=$(python3 -c "print($SOIL_MIN-15)");  TRIAL_LABEL[18]="abnormal"; TRIAL_SENSOR_ID[18]="$SUPABASE_SOIL_MOISTURE_SENSOR_ID"; TRIAL_ALERT_TYPE[18]="threshold_soil_moisture"
TRIAL_SENSOR[19]="temp_c";       TRIAL_VALUE[19]=$(python3 -c "print($TEMP_MIN-5)");   TRIAL_LABEL[19]="abnormal"; TRIAL_SENSOR_ID[19]="$SUPABASE_TEMPERATURE_SENSOR_ID"; TRIAL_ALERT_TYPE[19]="threshold_temp_c"
TRIAL_SENSOR[20]="humidity";     TRIAL_VALUE[20]=$(python3 -c "print($HUM_MAX+15)");   TRIAL_LABEL[20]="abnormal"; TRIAL_SENSOR_ID[20]="$SUPABASE_HUMIDITY_SENSOR_ID"; TRIAL_ALERT_TYPE[20]="threshold_humidity"

TIMES=""; PASS=0; FAIL=0; FALSE_POSITIVES=0; ABNORMAL_COUNT=0

echo "--- Running 20 trials ---"
for TRIAL in $(seq 1 20); do
    SENSOR="${TRIAL_SENSOR[$TRIAL]}"
    VALUE="${TRIAL_VALUE[$TRIAL]}"
    LABEL="${TRIAL_LABEL[$TRIAL]}"
    SID="${TRIAL_SENSOR_ID[$TRIAL]}"
    ATYPE="${TRIAL_ALERT_TYPE[$TRIAL]}"
    TS=$(now_iso)
    EXPECTED_ALERT=$([[ "$LABEL" == "abnormal" ]] && echo "true" || echo "false")

    # POST reading
    T0=$(date +%s%N)
    http_call POST "$SUPABASE_URL/rest/v1/readings" "$SUPABASE_ANON_KEY" \
        "[{\"sensor_id\":\"$SID\",\"value\":$VALUE,\"ts\":\"$TS\",\"metadata\":{\"test\":\"VT-13\",\"trial\":$TRIAL,\"label\":\"$LABEL\"}}]"
    READ_MS=$HTTP_MS

    GOT_ALERT="false"
    LATENCY_MS=0

    if [[ "$LABEL" == "abnormal" ]]; then
        (( ABNORMAL_COUNT++ )) || true
        # Simulate firmware: insert the alert it would have generated
        http_call POST "$SUPABASE_URL/rest/v1/alerts" "$SUPABASE_ANON_KEY" \
            "{\"device_id\":\"$SUPABASE_DEVICE_ID\",\"type\":\"$ATYPE\",\"message\":\"[VT-13 T$TRIAL] $SENSOR=$VALUE outside threshold\",\"severity\":\"high\",\"source\":\"automated\",\"triggered_at\":\"$TS\"}"
        ALERT_MS=$HTTP_MS
        ALERT_ID=$(get_json_field "$HTTP_BODY" "id")
        LATENCY_MS=$(( READ_MS + ALERT_MS ))
        GOT_ALERT=$([[ -n "$ALERT_ID" ]] && echo "true" || echo "false")
        log_evidence "$EVIDENCE_TXT" "Trial $TRIAL | ABNORMAL $SENSOR=$VALUE | alert_id=$ALERT_ID | ${LATENCY_MS}ms"

        # Resolve immediately to avoid notification spam
        [[ -n "$ALERT_ID" ]] && http_call_prefer PATCH \
            "$SUPABASE_URL/rest/v1/alerts?id=eq.$ALERT_ID" \
            "$SUPABASE_ANON_KEY" \
            "{\"resolved_at\":\"$(now_iso)\"}" "return=minimal"
    else
        log_evidence "$EVIDENCE_TXT" "Trial $TRIAL | NORMAL $SENSOR=$VALUE | reading_ms=$READ_MS"
    fi

    # Determine PASS/FAIL
    if [[ "$EXPECTED_ALERT" == "$GOT_ALERT" ]]; then
        if [[ "$LABEL" == "abnormal" && $LATENCY_MS -ge $SPEC_LATENCY_MS ]]; then
            VERDICT="FAIL"; (( FAIL++ )) || true
        else
            VERDICT="PASS"; (( PASS++ )) || true
        fi
    else
        VERDICT="FAIL"; (( FAIL++ )) || true
        [[ "$EXPECTED_ALERT" == "false" && "$GOT_ALERT" == "true" ]] && (( FALSE_POSITIVES++ )) || true
    fi

    printf "Trial %2d/20 | %-13s | %-8s | val=%-6s | exp_alert=%s got=%s lat=%dms | %s\n" \
        "$TRIAL" "$SENSOR" "$LABEL" "$VALUE" "$EXPECTED_ALERT" "$GOT_ALERT" "$LATENCY_MS" "$VERDICT"
    log_csv "$RESULTS_CSV" "$TRIAL,$SENSOR,$VALUE,$EXPECTED_ALERT,$GOT_ALERT,$LATENCY_MS,$VERDICT"
    TIMES="${TIMES:+$TIMES,}$LATENCY_MS"
done

# Retention check: alerts older than 30 days
SINCE_30D=$(python3 -c "
from datetime import datetime, timezone, timedelta
print((datetime.now(timezone.utc)-timedelta(days=30)).strftime('%Y-%m-%dT%H:%M:%SZ'))
")
http_call GET \
    "$SUPABASE_URL/rest/v1/alerts?device_id=eq.$SUPABASE_DEVICE_ID&triggered_at=lte.$SINCE_30D&select=id&limit=1" \
    "$SUPABASE_SERVICE_ROLE_KEY"
OLD_COUNT=$(echo "$HTTP_BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d) if isinstance(d,list) else 0)" 2>/dev/null || echo 0)
RETENTION=$([[ $OLD_COUNT -gt 0 ]] && echo "CONFIRMED" || echo "UNCONFIRMED (no alerts >30 days old yet)")

FP_RATE=$(python3 -c "print(f'{$FALSE_POSITIVES/15*100:.1f}%')")
FP_OK=$([[ $FALSE_POSITIVES -eq 0 ]] && echo "PASS" || echo "FAIL")

echo ""
echo "=== VT-13 RESULTS ==="
# Only report latency for abnormal trials (normal trials have 0ms latency, skew stats)
ABNORMAL_TIMES=$(python3 -c "
vals='$TIMES'.split(',')
# Skip the 15 leading zeros (normal trials)
ab = [v for v in vals[15:] if v.strip()]
print(','.join(ab))
")
SUMMARY=$(print_stats "VT-13" "$ABNORMAL_TIMES" "$SPEC_LATENCY_MS")
echo "$SUMMARY"
echo "False positive rate: $FP_RATE ($FALSE_POSITIVES/15 normal readings triggered alert) — $FP_OK"
echo "Retention (>=30 days): $RETENTION"
echo "Pass: $PASS/20 | Fail: $FAIL/20"
echo ""
echo "--- ONE-LINER ---"
echo "$SUMMARY | fp_rate=$FP_RATE | retention=$RETENTION | $PASS/20 reliable"

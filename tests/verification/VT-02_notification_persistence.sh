#!/usr/bin/env bash
# VT-02: Alert notification settings persistence
# Spec: Settings persist across sessions, error rate <= 1%
# n: 10 toggle cycles (enable → verify → re-auth → verify → disable)
# Requires: TEST_EMAIL and TEST_PASSWORD in .env (Flutter app login credentials)

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
load_env
require_vars SUPABASE_URL SUPABASE_ANON_KEY

if [[ -z "${TEST_EMAIL:-}" || -z "${TEST_PASSWORD:-}" ]]; then
    echo "ERROR: VT-02 requires TEST_EMAIL and TEST_PASSWORD in .env"
    echo "  Add the email/password you use to log into the PhytoPi Flutter app."
    exit 1
fi

RESULTS_CSV="$RESULTS_DIR/VT-02_results.csv"
EVIDENCE_TXT="$RESULTS_DIR/VT-02_evidence.txt"
N=10

init_results "$RESULTS_CSV" "cycle,operation,value_set,value_verified,session,latency_ms,pass_fail"
> "$EVIDENCE_TXT"
log_evidence "$EVIDENCE_TXT" "VT-02 Notification Persistence — $(now_iso)"

echo "=== VT-02: Alert Notification Persistence ==="

# Get user ID via initial auth
TOKEN=$(get_user_token "$TEST_EMAIL" "$TEST_PASSWORD")
if [[ -z "$TOKEN" ]]; then
    echo "ERROR: Authentication failed. Verify TEST_EMAIL / TEST_PASSWORD." >&2
    exit 1
fi

http_call GET "$SUPABASE_URL/auth/v1/user" "$TOKEN"
USER_ID=$(get_json_field "$HTTP_BODY" "id")
if [[ -z "$USER_ID" ]]; then
    echo "ERROR: Could not get user ID from auth token." >&2
    exit 1
fi
echo "Authenticated as: $USER_ID"
echo ""

PASS=0; FAIL=0; TOTAL=0

for cycle in $(seq 1 $N); do
    printf "Cycle %d/%d ... " "$cycle" "$N"

    # New session: fresh token
    TOKEN=$(get_user_token "$TEST_EMAIL" "$TEST_PASSWORD")

    # Upsert email_enabled = true
    http_call_prefer POST \
        "$SUPABASE_URL/rest/v1/alert_notification_settings" \
        "$TOKEN" \
        "{\"user_id\":\"$USER_ID\",\"email_enabled\":true,\"sms_enabled\":false}" \
        "resolution=merge-duplicates"
    SET_MS=$HTTP_MS

    # Verify in same session
    http_call GET \
        "$SUPABASE_URL/rest/v1/alert_notification_settings?user_id=eq.$USER_ID&select=email_enabled" \
        "$TOKEN"
    SAME_MS=$HTTP_MS
    SAME_VAL=$(get_json_field "$HTTP_BODY" "email_enabled")

    (( TOTAL++ )) || true
    if [[ "$SAME_VAL" == "True" || "$SAME_VAL" == "true" ]]; then
        V1="PASS"; (( PASS++ )) || true
    else
        V1="FAIL"; (( FAIL++ )) || true
    fi
    log_csv "$RESULTS_CSV" "$cycle,set+verify_same_session,true,$SAME_VAL,same,$SAME_MS,$V1"

    # Simulate session end — discard token, re-authenticate
    TOKEN=$(get_user_token "$TEST_EMAIL" "$TEST_PASSWORD")

    # Verify persisted in new session
    http_call GET \
        "$SUPABASE_URL/rest/v1/alert_notification_settings?user_id=eq.$USER_ID&select=email_enabled" \
        "$TOKEN"
    NEW_MS=$HTTP_MS
    NEW_VAL=$(get_json_field "$HTTP_BODY" "email_enabled")

    (( TOTAL++ )) || true
    if [[ "$NEW_VAL" == "True" || "$NEW_VAL" == "true" ]]; then
        V2="PASS"; (( PASS++ )) || true
    else
        V2="FAIL"; (( FAIL++ )) || true
    fi
    log_csv "$RESULTS_CSV" "$cycle,verify_after_reauth,true,$NEW_VAL,new,$NEW_MS,$V2"
    log_evidence "$EVIDENCE_TXT" "Cycle $cycle | same=$SAME_VAL($V1) reauth=$NEW_VAL($V2)"

    # Reset to disabled
    http_call_prefer POST \
        "$SUPABASE_URL/rest/v1/alert_notification_settings" \
        "$TOKEN" \
        "{\"user_id\":\"$USER_ID\",\"email_enabled\":false,\"sms_enabled\":false}" \
        "resolution=merge-duplicates"

    echo "same=$SAME_VAL $V1 | reauth=$NEW_VAL $V2"
done

ERROR_RATE=$(python3 -c "print(f'{($TOTAL-$PASS)/$TOTAL*100:.1f}%')")
OVERALL=$(python3 -c "print('PASS' if ($TOTAL-$PASS)/$TOTAL*100 <= 1.0 else 'FAIL')")

echo ""
echo "=== VT-02 RESULTS ==="
echo "Checks: $PASS/$TOTAL passed | Error rate: $ERROR_RATE"
echo ""
echo "--- ONE-LINER ---"
echo "VT-02: $OVERALL | error_rate=$ERROR_RATE | $PASS/$TOTAL reliable"

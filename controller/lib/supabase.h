#ifndef SUPABASE_H
#define SUPABASE_H

#include <stdint.h>

/* Supabase configuration structure */
typedef struct {
    char *api_url;      // e.g., "http://127.0.0.1:54321" or "https://your-project.supabase.co"
    char *api_key;      // Supabase anon/service role key
    char *device_id;    // UUID of the device in Supabase
} supabase_config_t;

/* Reading structure for batch operations */
typedef struct {
    char *sensor_id;    // UUID of the sensor in Supabase
    double value;       // Sensor reading value
    char *unit;         // Unit of measurement (e.g., "celsius", "percent", "boolean")
    int64_t timestamp;  // Unix timestamp
    char *metadata;     // Optional JSON metadata (can be NULL)
} supabase_reading_t;

/* Function declarations */
int supabase_init(supabase_config_t *config);
int supabase_send_batch(supabase_config_t *config, supabase_reading_t *readings, int count);
int supabase_cleanup(void);

/* Insert a single alert (device_id, type, message, severity, source) */
int supabase_insert_alert(supabase_config_t *config, const char *device_id,
                          const char *type, const char *message, const char *severity,
                          const char *source);

/* device_thresholds - configurable thresholds per metric */
#define THRESHOLD_METRIC_LEN 32
#define THRESHOLD_ID_LEN 64
typedef struct {
    char id[THRESHOLD_ID_LEN];
    char metric[THRESHOLD_METRIC_LEN];
    double min_value;
    double max_value;
    int enabled;
} device_threshold_t;

/* Fetch device thresholds. Returns count, -1 on error. Caller frees *out. */
int supabase_fetch_thresholds(supabase_config_t *config, device_threshold_t **out, int *count);

/* schedules - cron or interval-based */
#define SCHEDULE_ID_LEN 64
#define SCHEDULE_TYPE_LEN 32
#define SCHEDULE_PAYLOAD_LEN 256
typedef struct {
    char id[SCHEDULE_ID_LEN];
    char schedule_type[SCHEDULE_TYPE_LEN];
    char cron_expr[64];
    int interval_seconds;
    char payload_json[SCHEDULE_PAYLOAD_LEN];
    int enabled;
} device_schedule_t;

/* Fetch enabled schedules. Returns count, -1 on error. Caller frees *out. */
int supabase_fetch_schedules(supabase_config_t *config, device_schedule_t **out, int *count);

/* Heartbeat: update device_units.last_seen for offline detection. Returns 0 on success. */
int supabase_heartbeat(supabase_config_t *config);

/* Update schedule last_run_at. Returns 0 on success. */
int supabase_update_schedule_last_run(supabase_config_t *config, const char *schedule_id);

/*
 * Upsert device_actuator_state so the dashboard can display live actuator and
 * sensor health without querying device_commands history.
 *   lights_on / pump_on : 0 or 1
 *   fan_duty            : 0–100
 *   bme_ok / soil_ok    : 1 = sensor healthy, 0 = sensor failing
 * Pass -1 for any field that has not changed to omit it from the PATCH body
 * (except device_id which is always required).
 * Returns 0 on success, -1 on failure.
 */
int supabase_update_actuator_state(supabase_config_t *config,
                                   int lights_on, int pump_on, int fan_duty,
                                   int bme_ok, int soil_ok);

#endif


#include "../lib/gpio.h"
#include "../lib/sql.h"
#include "../lib/supabase.h"
#include "../lib/commands.h"
#include "../lib/bme680.h"
#include "../lib/state.h"
#include <json-c/json.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <math.h>
#include <sys/wait.h>
#include <sys/stat.h>

#define SYNC_INTERVAL 5      // Sync to Supabase every 5 seconds
#define BATCH_SIZE 50        // Maximum readings per batch
#define DATA_READ_INTERVAL 2 // Read sensors every 2 seconds
#define STATE_PATH "/var/lib/phytopi/device_state.txt"

// Deadband Thresholds
#define THRESH_TEMP 1                 // 1 degree C
#define THRESH_HUM 2                  // 2 percent
#define THRESH_SOIL 2                 // 2 percent points (soil stored as 0–100%)
#define THRESH_LIGHT 10               // 10 raw units
#define THRESH_PRESSURE 2             // 2 hPa
#define THRESH_GAS 5                  // 5 kOhm
#define THRESH_PHOTO_WATER 5          // 5 Hz
#define WATER_LEVEL_LOW_HZ_DEFAULT 50 // Default low-water cutoff (Hz) if threshold row has no value
/* 5-state frequency bands (Hz): 20=empty, 50=DP1, 100=DP2, 200=DP3, 400=DP4. Hysteresis 8 Hz. */
#define WATER_BAND_0_MAX 35 /* <35 Hz = Empty (0) */
#define WATER_BAND_1_MIN 27 /* 35-75 = Low (1), hysteresis: exit at 27 */
#define WATER_BAND_1_MAX 83
#define WATER_BAND_2_MIN 67
#define WATER_BAND_2_MAX 158
#define WATER_BAND_3_MIN 142
#define WATER_BAND_3_MAX 308
#define WATER_BAND_4_MIN 292         /* >300 = Full (4), hysteresis: enter at 292 */
#define WATER_ALERT_COOLDOWN 1800    // 30 min cooldown between water-low alerts
#define THRESHOLD_ALERT_COOLDOWN 900 // 15 min cooldown per metric
#define SENSOR_FAIL_ALERT_AFTER 5    // Alert after N consecutive failures
#define SENSOR_ALERT_COOLDOWN 3600   // 1 hour cooldown between sensor-fail alerts
#define FAN_MIN_DUTY_WHEN_ON 80      // Minimum duty when "on" requested (avoid 0%)

// Heartbeat
// Force a recording every X seconds even if values haven't changed
#define HEARTBEAT_INTERVAL 300 // 5 minutes

// Sensor ID mapping - these should match your Supabase sensors table
// Set via environment variables: SUPABASE_HUMIDITY_SENSOR_ID, etc.
static char *humidity_sensor_id = NULL;
static char *temperature_sensor_id = NULL;
static char *soil_moisture_sensor_id = NULL;
static char *pressure_sensor_id = NULL;
static char *gas_sensor_id = NULL;
static char *water_level_photoelectric_sensor_id = NULL;

/*
 * Map photoelectric frequency (Hz) to 5-state water level (0-4) with hysteresis.
 * 0=Empty, 1=Low, 2=Mid, 3=High, 4=Full
 */
/* Map soil ADC (0..adc_max) to 0–100 percent. adc_max from SOIL_ADC_MAX env, default 150. */
static int soil_raw_to_percent(int raw, int adc_max)
{
    if (raw < 0 || adc_max < 1)
        return -1;
    double p = 100.0 * (double)raw / (double)adc_max;
    if (p < 0.0)
        p = 0.0;
    if (p > 100.0)
        p = 100.0;
    return (int)(p + 0.5);
}

static int frequency_to_water_state(int hz, int last_state)
{
    if (hz < 0)
        return last_state >= 0 ? last_state : 0;
    if (hz < WATER_BAND_0_MAX)
        return 0;
    if (hz < WATER_BAND_1_MIN)
        return (last_state == 0) ? 0 : 1;
    if (hz < WATER_BAND_1_MAX)
        return 1;
    if (hz < WATER_BAND_2_MIN)
        return (last_state == 1) ? 1 : 2;
    if (hz < WATER_BAND_2_MAX)
        return 2;
    if (hz < WATER_BAND_3_MIN)
        return (last_state == 2) ? 2 : 3;
    if (hz < WATER_BAND_3_MAX)
        return 3;
    if (hz < WATER_BAND_4_MIN)
        return (last_state == 3) ? 3 : 4;
    return 4;
}

/*
 * Sync unsynced readings to Supabase
 */
void sync_to_supabase(sqlite3 *db, supabase_config_t *supabase_cfg)
{
    if (!supabase_cfg || !supabase_cfg->api_url || !supabase_cfg->api_key)
    {
        return; // Supabase not configured, skip sync
    }

    sqlite_reading_t *readings = NULL;
    int count = 0;

    // Get unsynced readings
    if (sql_get_unsynced_readings(db, &readings, &count) != 0 || count == 0)
    {
        if (readings)
            free(readings);
        return;
    }

    printf("Found %d unsynced readings, syncing to Supabase...\n", count);

    // First, count how many Supabase readings we'll need
    // temp_hum_data: 2, bme680_data: 4, others: 1 each
    int max_supabase_count = count * 4;

    // Convert SQLite readings to Supabase readings
    supabase_reading_t *supabase_readings = (supabase_reading_t *)malloc(max_supabase_count * sizeof(supabase_reading_t));
    if (!supabase_readings)
    {
        fprintf(stderr, "Failed to allocate memory for Supabase readings\n");
        free(readings);
        return;
    }

    int supabase_count = 0;
    for (int i = 0; i < count; i++)
    {
        // Safety check to prevent buffer overflow
        if (supabase_count >= max_supabase_count)
        {
            fprintf(stderr, "Warning: Reached maximum Supabase readings limit, some readings may be skipped\n");
            break;
        }

        // Map based on table name
        if (strcmp(readings[i].table_name, "temp_hum_data") == 0)
        {
            // Humidity reading
            if (humidity_sensor_id && supabase_count < max_supabase_count)
            {
                supabase_readings[supabase_count].sensor_id = humidity_sensor_id;
                supabase_readings[supabase_count].value = readings[i].value1;
                supabase_readings[supabase_count].unit = "percent";
                supabase_readings[supabase_count].timestamp = readings[i].timestamp;
                supabase_readings[supabase_count].metadata = NULL;
                supabase_count++;

                // Temperature reading
                if (temperature_sensor_id && supabase_count < max_supabase_count)
                {
                    supabase_readings[supabase_count].sensor_id = temperature_sensor_id;
                    supabase_readings[supabase_count].value = readings[i].value2;
                    supabase_readings[supabase_count].unit = "celsius";
                    supabase_readings[supabase_count].timestamp = readings[i].timestamp;
                    supabase_readings[supabase_count].metadata = NULL;
                    supabase_count++;
                }
            }
        }
        else if (strcmp(readings[i].table_name, "soil_moisture_data") == 0)
        {
            if (soil_moisture_sensor_id && supabase_count < max_supabase_count)
            {
                supabase_readings[supabase_count].sensor_id = soil_moisture_sensor_id;
                supabase_readings[supabase_count].value = readings[i].value1;
                supabase_readings[supabase_count].unit = "percent";
                supabase_readings[supabase_count].timestamp = readings[i].timestamp;
                supabase_readings[supabase_count].metadata = NULL;
                supabase_count++;
            }
        }
        else if (strcmp(readings[i].table_name, "bme680_data") == 0)
        {
            if (temperature_sensor_id && supabase_count < max_supabase_count)
            {
                supabase_readings[supabase_count].sensor_id = temperature_sensor_id;
                supabase_readings[supabase_count].value = readings[i].value1;
                supabase_readings[supabase_count].unit = "celsius";
                supabase_readings[supabase_count].timestamp = readings[i].timestamp;
                supabase_readings[supabase_count].metadata = NULL;
                supabase_count++;
            }
            if (humidity_sensor_id && supabase_count < max_supabase_count)
            {
                supabase_readings[supabase_count].sensor_id = humidity_sensor_id;
                supabase_readings[supabase_count].value = readings[i].value2;
                supabase_readings[supabase_count].unit = "percent";
                supabase_readings[supabase_count].timestamp = readings[i].timestamp;
                supabase_readings[supabase_count].metadata = NULL;
                supabase_count++;
            }
            if (pressure_sensor_id && supabase_count < max_supabase_count)
            {
                supabase_readings[supabase_count].sensor_id = pressure_sensor_id;
                supabase_readings[supabase_count].value = readings[i].value3;
                supabase_readings[supabase_count].unit = "hPa";
                supabase_readings[supabase_count].timestamp = readings[i].timestamp;
                supabase_readings[supabase_count].metadata = NULL;
                supabase_count++;
            }
            if (gas_sensor_id && supabase_count < max_supabase_count)
            {
                supabase_readings[supabase_count].sensor_id = gas_sensor_id;
                supabase_readings[supabase_count].value = readings[i].value4;
                supabase_readings[supabase_count].unit = "kOhm";
                supabase_readings[supabase_count].timestamp = readings[i].timestamp;
                supabase_readings[supabase_count].metadata = NULL;
                supabase_count++;
            }
        }
        else if (strcmp(readings[i].table_name, "water_level_photoelectric") == 0)
        {
            if (water_level_photoelectric_sensor_id && supabase_count < max_supabase_count)
            {
                supabase_readings[supabase_count].sensor_id = water_level_photoelectric_sensor_id;
                supabase_readings[supabase_count].value = readings[i].value1; /* 0-4 state */
                supabase_readings[supabase_count].unit = "level";
                supabase_readings[supabase_count].timestamp = readings[i].timestamp;
                supabase_readings[supabase_count].metadata = NULL;
                supabase_count++;
            }
        }
    }

    if (supabase_count > 0)
    {
        // Send in batches
        int sent = 0;
        int all_sent = 1;

        while (sent < supabase_count)
        {
            int batch_size = (supabase_count - sent > BATCH_SIZE) ? BATCH_SIZE : (supabase_count - sent);

            if (supabase_send_batch(supabase_cfg, &supabase_readings[sent], batch_size) == 0)
            {
                sent += batch_size;
            }
            else
            {
                fprintf(stderr, "Failed to sync batch, will retry later\n");
                all_sent = 0;
                break;
            }
        }

        // Mark all readings as synced only if all were successfully sent
        if (all_sent)
        {
            for (int i = 0; i < count; i++)
            {
                sql_mark_as_synced(db, readings[i].table_name, readings[i].id);
            }
            printf("Marked %d readings as synced\n", count);
        }
    }

    free(supabase_readings);
    free(readings);
}

int main()
{
    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);

    /* I2C / hardware */
    int fd = i2c_init("/dev/i2c-1");
    if (fd < 0)
    {
        fprintf(stderr, "Warning: I2C bus init failed. Soil moisture disabled.\n");
        fprintf(stderr, "Enable: sudo raspi-config -> Interface Options -> I2C\n");
    }
    int bme680_ok = (bme680_init() == 0);
    if (!bme680_ok)
        fprintf(stderr, "Warning: BME680 init failed. Temp/humidity/pressure/gas disabled.\n");

    device_state_t dev_state;
    state_load(STATE_PATH, &dev_state);

    /* Apply persisted state to hardware on startup */
    if (dev_state.lights_on && lights_init() == 0)
        lights_set(dev_state.lights_on);
    if (dev_state.pump_on && pump_init() == 0)
        pump_set(dev_state.pump_on);
    if (dev_state.fan_duty > 0 && fans_init() == 0)
        fans_set_both(dev_state.fan_duty);

    int lights_on = dev_state.lights_on;
    int pump_on = dev_state.pump_on;

    /* Database */
    const char *db_path = getenv("PHYTOPI_DB_PATH");
    if (!db_path || db_path[0] == '\0')
    {
        static char db_path_buf[1024];
        const char *home = getenv("HOME");
        if (home && home[0] != '\0')
        {
            char dir[512];
            snprintf(dir, sizeof(dir), "%s/.phytopi", home);
            mkdir(dir, 0755);
            snprintf(db_path_buf, sizeof(db_path_buf), "%s/sensor_data.db", dir);
            db_path = db_path_buf;
        }
        else
            db_path = "/var/lib/phytopi/sensor_data.db";
    }
    sqlite3 *db = db_init(db_path);
    if (!db)
    {
        fprintf(stderr, "Failed to open %s, trying ./sensor_data.db\n", db_path);
        db = db_init("sensor_data.db");
    }
    if (!db)
    {
        fprintf(stderr, "Failed to initialize database.\n"
                        "Try: export PHYTOPI_DB_PATH=$HOME/.phytopi/sensor_data.db\n");
        return 1;
    }

    /* Supabase */
    supabase_config_t supabase_cfg = {0};
    supabase_cfg.api_url = getenv("SUPABASE_URL");
    supabase_cfg.api_key = getenv("SUPABASE_ANON_KEY");
    supabase_cfg.device_id = getenv("SUPABASE_DEVICE_ID");
    humidity_sensor_id = getenv("SUPABASE_HUMIDITY_SENSOR_ID");
    temperature_sensor_id = getenv("SUPABASE_TEMPERATURE_SENSOR_ID");
    soil_moisture_sensor_id = getenv("SUPABASE_SOIL_MOISTURE_SENSOR_ID");
    pressure_sensor_id = getenv("SUPABASE_PRESSURE_SENSOR_ID");
    gas_sensor_id = getenv("SUPABASE_GAS_SENSOR_ID");
    water_level_photoelectric_sensor_id = getenv("SUPABASE_WATER_LEVEL_PHOTOELECTRIC_SENSOR_ID");

    int supabase_enabled = 0;
    if (supabase_cfg.api_url && supabase_cfg.api_key)
    {
        if (supabase_init(&supabase_cfg) == 0)
        {
            supabase_enabled = 1;
            printf("Supabase sync enabled: %s\n", supabase_cfg.api_url);
        }
        else
            fprintf(stderr, "Supabase init failed, using local storage only\n");
    }
    else
        printf("Supabase not configured, using local storage only\n");

    /* SQL templates */
    const char *sql_soil_moisture = "INSERT INTO soil_moisture_data (humidity, timestamp) VALUES (?, ?);";
    const char *sql_water_photo = "INSERT INTO water_level_photoelectric (frequency_hz, timestamp) VALUES (?, ?);";

    int soil_adc_max = 150;
    const char *soil_max_env = getenv("SOIL_ADC_MAX");
    if (soil_max_env && soil_max_env[0])
    {
        int v = atoi(soil_max_env);
        if (v >= 1 && v <= 255)
            soil_adc_max = v;
    }

    /* Loop timing */
    time_t last_sync = time(NULL);
    time_t last_command_poll = time(NULL);
    time_t last_threshold_fetch = 0;
    time_t last_schedule_fetch = 0;
    time_t last_bme_read = 0;

    /* Actuator state */
    time_t lights_off_at = 0;
    time_t pump_off_at = 0;
    time_t ventilation_off_at = 0;

    /* BME680 live readings and deadband state */
    float bme_temp = -999, bme_hum = -999;
    float bme_pressure = -999, bme_gas = -999;
    float last_bme_temp = -999, last_bme_hum = -999;
    float last_bme_pressure = -999, last_bme_gas = -999;
    time_t last_bme_ts = 0;

    /* Soil moisture: raw ADC and stored/synced percent (0–100) */
    int soil_raw = -1;
    int soil_moisture_pct = -1;
    int last_soil_moisture_pct = -999;
    time_t last_soil_ts = 0;

    /* Photoelectric water level deadband state */
    int last_photo_freq = -999;
    int last_water_state = -1;
    time_t last_photo_ts = 0;

    /* Sensor health */
    int bme680_fail_count = 0;
    int photoelectric_fail_count = 0;
    time_t last_bme_alert = 0;
    time_t last_photo_alert = 0;
    int last_reported_bme_ok = -1;   /* -1 = not yet reported */
    int last_reported_soil_ok = -1;
    int initial_state_pushed = 0;

    /* Threshold cache */
    device_threshold_t *cached_thresholds = NULL;
    int cached_thr_count = 0;
    time_t last_thr_alert_temp = 0;
    time_t last_thr_alert_hum = 0;
    time_t last_thr_alert_pressure = 0;
    time_t last_thr_alert_gas = 0;
    time_t last_thr_alert_water = 0;
    time_t last_thr_alert_soil = 0;
    time_t last_thr_alert_fan = 0;

    while (1)
    {
        soil_raw = (fd >= 0) ? read_pcf8591_channel(fd, 0) : -1; /* pcf8591 A0 */
        soil_moisture_pct = (soil_raw >= 0) ? soil_raw_to_percent(soil_raw, soil_adc_max) : -1;

        time_t now = time(NULL);

        /* Auto-off actuators when their timer expires */
        if (lights_off_at && now >= lights_off_at)
        {
            lights_set(0);
            lights_on = 0;
            dev_state.lights_on = 0;
            lights_off_at = 0;
            state_save(STATE_PATH, &dev_state);
            if (supabase_enabled)
                supabase_update_actuator_state(&supabase_cfg, 0, -1, -1, -1, -1);
        }
        if (pump_off_at && now >= pump_off_at)
        {
            pump_set(0);
            pump_on = 0;
            dev_state.pump_on = 0;
            pump_off_at = 0;
            state_save(STATE_PATH, &dev_state);
            if (supabase_enabled)
                supabase_update_actuator_state(&supabase_cfg, -1, 0, -1, -1, -1);
        }
        if (ventilation_off_at && now >= ventilation_off_at)
        {
            fans_set_both(0);
            dev_state.fan_duty = 0;
            ventilation_off_at = 0;
            state_save(STATE_PATH, &dev_state);
            if (supabase_enabled)
                supabase_update_actuator_state(&supabase_cfg, -1, -1, 0, -1, -1);
        }

        // BME680 read (every 3s for stability)
        if (now - last_bme_read >= 3)
        {
            bme680_data_t bme_data;
            if (bme680_read(&bme_data) == 0 && bme_data.valid)
            {
                bme_temp = bme_data.temperature;
                bme_hum = bme_data.humidity;
                bme_pressure = bme_data.pressure;
                bme_gas = bme_data.gas_resistance;
                last_bme_read = now;
                bme680_fail_count = 0;
            }
            else
            {
                bme680_fail_count++;
                if (bme680_fail_count % 10 == 0)
                    fprintf(stderr, "Warning: BME680 read failed (consecutive: %d)\n", bme680_fail_count);
                /* Invalidate stale readings after 5 consecutive failures so threshold
                 * evaluation skips them rather than using an outdated cached value. */
                if (bme680_fail_count >= 5)
                {
                    bme_temp = -999;
                    bme_hum = -999;
                    bme_pressure = -999;
                    bme_gas = -999;
                }
                if (bme680_fail_count >= SENSOR_FAIL_ALERT_AFTER && supabase_enabled && supabase_cfg.device_id &&
                    (now - last_bme_alert) >= SENSOR_ALERT_COOLDOWN)
                {
                    if (supabase_insert_alert(&supabase_cfg, supabase_cfg.device_id,
                                              "sensor_failure_bme680", "BME680 sensor unreachable after repeated failures",
                                              "high", "automated") == 0)
                        last_bme_alert = now;
                }
            }
        }

        /* Photoelectric water level — read every 2s on its own timer */
        int photo_freq = last_photo_freq > 0 ? last_photo_freq : -1;
        if (now - last_photo_ts >= 2)
        {
            if (read_photoelectric_water_level(&photo_freq) != 0 || photo_freq < 0)
            {
                photoelectric_fail_count++;
                if (photoelectric_fail_count >= SENSOR_FAIL_ALERT_AFTER && supabase_enabled &&
                    supabase_cfg.device_id && (now - last_photo_alert) >= SENSOR_ALERT_COOLDOWN)
                {
                    if (supabase_insert_alert(&supabase_cfg, supabase_cfg.device_id,
                                                "sensor_failure_photoelectric", "Photoelectric water level sensor unreachable",
                                                "high", "automated") == 0)
                        last_photo_alert = now;
                }
            }
            else
                photoelectric_fail_count = 0;
        }

        printf("[%ld] L=%d Pump=%d T=%.1fC H=%.1f%% Press=%.1f hPa G=%.1f Soil=%d%% (raw=%d) Photo=%dHz\n",
               now, lights_on, pump_on, bme_temp, bme_hum, bme_pressure, bme_gas,
               soil_moisture_pct >= 0 ? soil_moisture_pct : -1, soil_raw, photo_freq);

        int timestamp = (int)now;

        // --- Deadband Logic ---

        // 1. BME680 (temp, humidity, pressure, gas)
        if (bme_temp > -900 && bme_hum > -900)
        {
            if (fabsf(bme_temp - last_bme_temp) >= THRESH_TEMP ||
                fabsf(bme_hum - last_bme_hum) >= THRESH_HUM ||
                fabsf(bme_pressure - last_bme_pressure) >= THRESH_PRESSURE ||
                fabsf(bme_gas - last_bme_gas) >= THRESH_GAS ||
                (now - last_bme_ts) >= HEARTBEAT_INTERVAL)
            {
                if (sql_execute_insert_bme680(db, bme_temp, bme_hum, bme_pressure, bme_gas, timestamp) == SQLITE_OK)
                {
                    printf("  -> Saved BME680 T=%.1f H=%.1f P=%.1f G=%.1f\n", bme_temp, bme_hum, bme_pressure, bme_gas);
                    last_bme_temp = bme_temp;
                    last_bme_hum = bme_hum;
                    last_bme_pressure = bme_pressure;
                    last_bme_gas = bme_gas;
                    last_bme_ts = now;
                }
            }
        }

        // 2. Check Soil Moisture (stored as percent 0–100)
        if (soil_moisture_pct >= 0)
        {
            if (abs(soil_moisture_pct - last_soil_moisture_pct) >= THRESH_SOIL ||
                (now - last_soil_ts) >= HEARTBEAT_INTERVAL)
            {
                if (sql_execute_insert(db, sql_soil_moisture, soil_moisture_pct, 0, timestamp) == SQLITE_OK)
                {
                    printf("  -> Saved Soil (%%: %d->%d, raw=%d)\n", last_soil_moisture_pct, soil_moisture_pct, soil_raw);
                    last_soil_moisture_pct = soil_moisture_pct;
                    last_soil_ts = now;
                }
            }
        }

        // 3. Photoelectric water level (5-state with hysteresis)
        if (photo_freq >= 0)
        {
            int water_state = frequency_to_water_state(photo_freq, last_water_state);
            if (water_state != last_water_state ||
                abs(photo_freq - last_photo_freq) >= THRESH_PHOTO_WATER ||
                (now - last_photo_ts) >= HEARTBEAT_INTERVAL)
            {
                if (sql_execute_insert(db, sql_water_photo, water_state, 0, timestamp) == SQLITE_OK)
                {
                    printf("  -> Saved Photo Water state=%d (%dHz)\n", water_state, photo_freq);
                    last_photo_freq = photo_freq;
                    last_water_state = water_state;
                    last_photo_ts = now;
                }
            }
        }

        // Sync to Supabase periodically
        if (supabase_enabled)
        {
            if (now - last_sync >= SYNC_INTERVAL)
            {
                sync_to_supabase(db, &supabase_cfg);
                last_sync = now;
                /* Heartbeat for offline detection */
                if (supabase_cfg.device_id)
                    supabase_heartbeat(&supabase_cfg);
                /* Push full actuator + sensor health state on first sync and on sensor transitions */
                if (supabase_cfg.device_id)
                {
                    int cur_bme_ok  = (bme680_fail_count < SENSOR_FAIL_ALERT_AFTER) ? 1 : 0;
                    int cur_soil_ok = (soil_moisture_pct >= 0) ? 1 : 0;
                    int need_push   = !initial_state_pushed
                                      || cur_bme_ok  != last_reported_bme_ok
                                      || cur_soil_ok != last_reported_soil_ok;
                    if (need_push)
                    {
                        if (supabase_update_actuator_state(&supabase_cfg,
                                lights_on, pump_on, dev_state.fan_duty,
                                cur_bme_ok, cur_soil_ok) == 0)
                        {
                            initial_state_pushed = 1;
                            last_reported_bme_ok  = cur_bme_ok;
                            last_reported_soil_ok = cur_soil_ok;
                        }
                    }
                }
            }

            // Poll for pending commands
            if (now - last_command_poll >= 2)
            {
                last_command_poll = now;

                device_command_t cmd = {0};
                while (fetch_next_command(&supabase_cfg, &cmd) > 0)
                {
                    int ok = 0;
                    if (strcmp(cmd.command_type, "toggle_light") == 0)
                    {
                        int desired = 0;
                        int duration_sec = 0;
                        json_object *obj = json_tokener_parse(cmd.payload_json);
                        if (obj)
                        {
                            json_object *s = NULL, *d = NULL;
                            if (json_object_object_get_ex(obj, "state", &s))
                                desired = json_object_get_boolean(s) ? 1 : 0;
                            if (json_object_object_get_ex(obj, "duration_sec", &d))
                                duration_sec = json_object_get_int(d);
                            json_object_put(obj);
                        }
                        if (lights_init() == 0 && lights_set(desired) == 0)
                        {
                            lights_on = desired;
                            dev_state.lights_on = desired;
                            state_save(STATE_PATH, &dev_state); // Persist state
                            lights_off_at = (desired && duration_sec > 0) ? (time(NULL) + duration_sec) : 0;
                            ok = 1;
                            printf("  -> Lights %s (duration=%ds, auto-off=%s)\n",
                                   desired ? "ON" : "OFF", duration_sec,
                                   lights_off_at ? "yes" : "no");
                            supabase_update_actuator_state(&supabase_cfg, desired, -1, -1, -1, -1);
                        }
                    }
                    else if (strcmp(cmd.command_type, "toggle_pump") == 0)
                    {
                        int desired = 0;
                        int duration_sec = 0;
                        json_object *obj = json_tokener_parse(cmd.payload_json);
                        if (obj)
                        {
                            json_object *s = NULL, *d = NULL;
                            if (json_object_object_get_ex(obj, "state", &s))
                                desired = json_object_get_boolean(s) ? 1 : 0;
                            if (json_object_object_get_ex(obj, "duration_sec", &d))
                                duration_sec = json_object_get_int(d);
                            json_object_put(obj);
                        }
                        if (pump_init() != 0)
                        {
                            fprintf(stderr, "toggle_pump: pump_init() failed - check GPIO permissions and wiring\n");
                        }
                        else if (pump_set(desired) != 0)
                        {
                            fprintf(stderr, "toggle_pump: pump_set(%d) failed\n", desired);
                        }
                        else
                        {
                            pump_on = desired;
                            dev_state.pump_on = desired;
                            state_save(STATE_PATH, &dev_state); // Persist state
                            pump_off_at = (desired && duration_sec > 0) ? (time(NULL) + duration_sec) : 0;
                            ok = 1;
                            printf("  -> Pump %s (duration=%ds, auto-off=%s)\n",
                                   desired ? "ON" : "OFF", duration_sec,
                                   pump_off_at ? "yes" : "no");
                            supabase_update_actuator_state(&supabase_cfg, -1, desired, -1, -1, -1);
                        }
                    }
                    else if (strcmp(cmd.command_type, "toggle_fans") == 0)
                    {
                        int desired = 0;
                        json_object *obj = json_tokener_parse(cmd.payload_json);
                        if (obj)
                        {
                            json_object *s = NULL;
                            if (json_object_object_get_ex(obj, "state", &s))
                                desired = json_object_get_boolean(s) ? 1 : 0;
                            json_object_put(obj);
                        }
                        if (fans_init() == 0)
                        {
                            /* Avoid 0% when "on" requested - use minimum duty */
                            int duty = desired ? FAN_MIN_DUTY_WHEN_ON : 0;
                            fans_set_both(duty);
                            dev_state.fan_duty = duty;
                            state_save(STATE_PATH, &dev_state);
                            ok = 1;
                            supabase_update_actuator_state(&supabase_cfg, -1, -1, duty, -1, -1);
                        }
                    }
                    else if (strcmp(cmd.command_type, "run_ventilation") == 0)
                    {
                        int duration_sec = 300, duty = 80;
                        json_object *obj = json_tokener_parse(cmd.payload_json);
                        if (obj)
                        {
                            json_object *d = NULL, *p = NULL;
                            if (json_object_object_get_ex(obj, "duration_sec", &d))
                                duration_sec = json_object_get_int(d);
                            if (json_object_object_get_ex(obj, "duty_percent", &p))
                                duty = json_object_get_int(p);
                            if (duty <= 0)
                                duty = FAN_MIN_DUTY_WHEN_ON;
                            if (duty > 100)
                                duty = 100;
                            json_object_put(obj);
                        }
                        if (fans_init() == 0)
                        {
                            fans_set_both(duty);
                            dev_state.fan_duty = duty;
                            state_save(STATE_PATH, &dev_state);
                            ventilation_off_at = time(NULL) + duration_sec;
                            ok = 1;
                        }
                    }
                    else if (strcmp(cmd.command_type, "set_fan_speed") == 0)
                    {
                        int fan_id = 1, duty = 0;
                        json_object *obj = json_tokener_parse(cmd.payload_json);
                        if (obj)
                        {
                            json_object *f = NULL, *d = NULL;
                            if (json_object_object_get_ex(obj, "fan_id", &f))
                                fan_id = json_object_get_int(f);
                            if (json_object_object_get_ex(obj, "duty_percent", &d))
                                duty = json_object_get_int(d);
                            json_object_put(obj);
                        }
                        if (duty < 0)
                            duty = 0;
                        if (duty > 100)
                            duty = 100;
                        if (fans_init() == 0 && fans_set_speed(fan_id, duty) == 0)
                        {
                            dev_state.fan_duty = duty; // approximation — both fans assumed same duty
                            state_save(STATE_PATH, &dev_state);
                            ok = 1;
                        }
                    }
                    else if (strcmp(cmd.command_type, "capture_image") == 0 && supabase_cfg.device_id)
                    {
                        const char *script = getenv("CAPTURE_SCRIPT_PATH");
                        if (!script)
                            script = "scripts/capture_and_upload.py";
                        pid_t pid = fork();
                        if (pid == 0)
                        {
                            execl("/usr/bin/python3", "python3", script,
                                  supabase_cfg.device_id, (char *)NULL);
                            _exit(127);
                        }
                        else if (pid > 0)
                        {
                            int status;
                            waitpid(pid, &status, 0);
                            ok = (WIFEXITED(status) && WEXITSTATUS(status) == 0);
                        }
                    }

                    mark_command_processed(&supabase_cfg, cmd.id, ok ? "executed" : "failed");
                }
            }

            /* Refresh threshold cache from Supabase every 60s */
            if (now - last_threshold_fetch >= 60)
            {
                last_threshold_fetch = now;
                device_threshold_t *fetched = NULL;
                int fetched_count = 0;
                if (supabase_fetch_thresholds(&supabase_cfg, &fetched, &fetched_count) >= 0 && fetched)
                {
                    if (cached_thresholds)
                        free(cached_thresholds);
                    cached_thresholds = fetched;
                    cached_thr_count = fetched_count;
                    printf("  [Thresholds] Refreshed %d threshold(s) from Supabase\n", cached_thr_count);
                }
                else
                {
                    fprintf(stderr, "  [Thresholds] Failed to fetch from Supabase (using cached %d)\n", cached_thr_count);
                }
            }

            /* Evaluate cached thresholds so spikes are never missed */
            for (int t = 0; t < cached_thr_count; t++)
            {
                if (!cached_thresholds[t].enabled)
                    continue;
                double val = -999;
                time_t *cooldown_ptr = NULL;
                const char *metric = cached_thresholds[t].metric;
                int cooldown_seconds = THRESHOLD_ALERT_COOLDOWN;
                if (strcmp(metric, "temp_c") == 0)
                {
                    val = bme_temp;
                    cooldown_ptr = &last_thr_alert_temp;
                }
                else if (strcmp(metric, "humidity") == 0)
                {
                    val = bme_hum;
                    cooldown_ptr = &last_thr_alert_hum;
                }
                else if (strcmp(metric, "pressure") == 0)
                {
                    val = bme_pressure;
                    cooldown_ptr = &last_thr_alert_pressure;
                }
                else if (strcmp(metric, "gas_resistance") == 0)
                {
                    val = bme_gas;
                    cooldown_ptr = &last_thr_alert_gas;
                }
                else if (strcmp(metric, "soil_moisture") == 0)
                {
                    if (soil_moisture_pct < 0)
                        continue;
                    val = (double)soil_moisture_pct;
                    cooldown_ptr = &last_thr_alert_soil;
                }
                else if (strcmp(metric, "water_level_low") == 0)
                {
                    val = (double)photo_freq;
                    cooldown_ptr = &last_thr_alert_water;
                    cooldown_seconds = WATER_ALERT_COOLDOWN;
                }
                else if (strcmp(metric, "fan_duty") == 0)
                {
                    val = (double)dev_state.fan_duty;
                    cooldown_ptr = &last_thr_alert_fan;
                }
                if (val < -900 && strcmp(metric, "water_level_low") != 0)
                    continue;
                int exceeded = 0;
                if (strcmp(metric, "water_level_low") == 0)
                {
                    double low_hz_cutoff = WATER_LEVEL_LOW_HZ_DEFAULT;
                    if (cached_thresholds[t].max_value < 1e8)
                        low_hz_cutoff = cached_thresholds[t].max_value;
                    else if (cached_thresholds[t].min_value > -1e8)
                        low_hz_cutoff = cached_thresholds[t].min_value;
                    exceeded = (photo_freq >= 0 && val < low_hz_cutoff);
                }
                else
                    exceeded = (cached_thresholds[t].min_value > -1e8 && val < cached_thresholds[t].min_value) ||
                               (cached_thresholds[t].max_value < 1e8 && val > cached_thresholds[t].max_value);
                if (exceeded && cooldown_ptr && (now - *cooldown_ptr) >= cooldown_seconds)
                {
                    char msg[128];
                    if (strcmp(metric, "water_level_low") == 0)
                    {
                        double low_hz_cutoff = WATER_LEVEL_LOW_HZ_DEFAULT;
                        if (cached_thresholds[t].max_value < 1e8)
                            low_hz_cutoff = cached_thresholds[t].max_value;
                        else if (cached_thresholds[t].min_value > -1e8)
                            low_hz_cutoff = cached_thresholds[t].min_value;
                        snprintf(msg, sizeof(msg), "Water level is low - refill reservoir (%.0fHz < %.0fHz)", val, low_hz_cutoff);
                    }
                    else
                        snprintf(msg, sizeof(msg), "%s %.1f outside range [%.1f, %.1f]",
                                 metric, val, cached_thresholds[t].min_value, cached_thresholds[t].max_value);
                    char alert_type_buf[64];
                    const char *alert_type =
                        (strcmp(metric, "water_level_low") == 0)
                            ? "water_level_low"
                            : (snprintf(alert_type_buf, sizeof(alert_type_buf), "threshold_%s", metric), alert_type_buf);
                    const char *severity = (strcmp(metric, "water_level_low") == 0) ? "high" : "medium";
                    printf("  [Thresholds] EXCEEDED: %s\n", msg);
                    if (supabase_insert_alert(&supabase_cfg, supabase_cfg.device_id,
                                              alert_type, msg, severity, "threshold") == 0)
                    {
                        *cooldown_ptr = now;
                        printf("  [Thresholds] Alert inserted for %s\n", metric);
                        if (strcmp(metric, "temp_c") == 0 || strcmp(metric, "humidity") == 0 ||
                            strcmp(metric, "gas_resistance") == 0)
                        {
                            if (fans_init() == 0)
                            {
                                fans_set_both(FAN_MIN_DUTY_WHEN_ON);
                                dev_state.fan_duty = FAN_MIN_DUTY_WHEN_ON;
                                state_save(STATE_PATH, &dev_state);
                            }
                            ventilation_off_at = now + 300;
                        }
                    }
                    else
                    {
                        fprintf(stderr, "  [Thresholds] ERROR: Failed to insert alert for %s\n", metric);
                    }
                }
            }

            /* Schedule evaluation (every 60s) */
            if (now - last_schedule_fetch >= 60)
            {
                last_schedule_fetch = now;
                device_schedule_t *sched = NULL;
                int sched_count = 0;
                if (supabase_fetch_schedules(&supabase_cfg, &sched, &sched_count) >= 0 && sched)
                {
                    static struct
                    {
                        char id[SCHEDULE_ID_LEN];
                        time_t last_run;
                    } run_cache[16];
                    static int run_cache_n = 0;
                    struct tm *tm_now = localtime(&now);
                    int min = tm_now ? tm_now->tm_min : 0;
                    int hour = tm_now ? tm_now->tm_hour : 0;
                    for (int s = 0; s < sched_count; s++)
                    {
                        time_t last_run = 0;
                        for (int r = 0; r < run_cache_n; r++)
                            if (strcmp(run_cache[r].id, sched[s].id) == 0)
                            {
                                last_run = run_cache[r].last_run;
                                break;
                            }
                        int should_run = 0;
                        if (sched[s].interval_seconds > 0)
                            should_run = (now - last_run) >= (time_t)sched[s].interval_seconds;
                        else if (sched[s].cron_expr[0])
                        {
                            int cron_min = -1, cron_hour = -1;
                            if (sscanf(sched[s].cron_expr, "%d %d", &cron_min, &cron_hour) == 2)
                                should_run = (min == cron_min && hour == cron_hour && (now - last_run) >= 60);
                            else if (strncmp(sched[s].cron_expr, "*/", 2) == 0)
                            {
                                int n = 0;
                                sscanf(sched[s].cron_expr + 2, "%d", &n);
                                if (n > 0)
                                    should_run = (min % n == 0) && (now - last_run) >= 60;
                            }
                        }
                        if (should_run)
                        {
                            static struct
                            {
                                char id[SCHEDULE_ID_LEN];
                                time_t last_alert_at;
                            } sched_alert_cd[32];
                            static int sched_alert_cd_n = 0;

                            json_object *pl = json_tokener_parse(sched[s].payload_json);
                            int state = 1, duration = 0, duty = 80;
                            if (pl)
                            {
                                json_object *st = NULL, *du = NULL, *dt = NULL;
                                if (json_object_object_get_ex(pl, "state", &st))
                                    state = json_object_get_boolean(st) ? 1 : 0;
                                if (json_object_object_get_ex(pl, "duration_sec", &du))
                                    duration = json_object_get_int(du);
                                if (json_object_object_get_ex(pl, "duty_percent", &dt))
                                    duty = json_object_get_int(dt);
                                json_object_put(pl);
                            }
                            int sched_applied = 0;
                            const char *alert_type = "schedule";
                            char alert_msg[192];

                            if (strcmp(sched[s].schedule_type, "lights") == 0)
                            {
                                if (lights_init() == 0 && lights_set(state) == 0)
                                {
                                    dev_state.lights_on = state;
                                    lights_on = state;
                                    lights_off_at = (state && duration > 0) ? (now + duration) : 0;
                                    if (lights_off_at)
                                        printf("  -> Lights ON (auto-off in %ds) [schedule]\n", duration);
                                    else
                                        printf("  -> Lights %s [schedule]\n", state ? "ON" : "OFF");
                                    alert_type = "schedule_lights";
                                    if (state)
                                    {
                                        if (lights_off_at)
                                            snprintf(alert_msg, sizeof(alert_msg),
                                                     "Scheduled: Grow lights ON (auto-off in %d s)", duration);
                                        else
                                            snprintf(alert_msg, sizeof(alert_msg),
                                                     "Scheduled: Grow lights ON");
                                    }
                                    else
                                        snprintf(alert_msg, sizeof(alert_msg),
                                                 "Scheduled: Grow lights OFF");
                                    sched_applied = 1;
                                }
                                else
                                    fprintf(stderr, "  [Schedule] lights: init or GPIO failed\n");
                            }
                            else if (strcmp(sched[s].schedule_type, "pump") == 0)
                            {
                                if (pump_init() == 0 && pump_set(state) == 0)
                                {
                                    dev_state.pump_on = state;
                                    pump_on = state;
                                    pump_off_at = (state && duration > 0) ? (now + duration) : 0;
                                    printf("  -> Pump %s [schedule]\n", state ? "ON" : "OFF");
                                    alert_type = "schedule_pump";
                                    snprintf(alert_msg, sizeof(alert_msg), "Scheduled: Pump turned %s",
                                             state ? "ON" : "OFF");
                                    sched_applied = 1;
                                }
                                else
                                    fprintf(stderr, "  [Schedule] pump: init or GPIO failed\n");
                            }
                            else if (strcmp(sched[s].schedule_type, "ventilation") == 0)
                            {
                                int fan_duty_target = state ? (duty > 0 ? duty : FAN_MIN_DUTY_WHEN_ON) : 0;
                                if (fans_init() == 0 && fans_set_both(fan_duty_target) == 0)
                                {
                                    dev_state.fan_duty = fan_duty_target;
                                    ventilation_off_at = (state && duration > 0) ? (now + duration) : 0;
                                    printf("  -> Ventilation %s [schedule] (duty=%d%%)\n",
                                           state ? "ON" : "OFF", fan_duty_target);
                                    alert_type = "schedule_ventilation";
                                    if (state)
                                        snprintf(alert_msg, sizeof(alert_msg),
                                                 "Scheduled: Ventilation ON at %d%%",
                                                 fan_duty_target);
                                    else
                                        snprintf(alert_msg, sizeof(alert_msg),
                                                 "Scheduled: Ventilation OFF");
                                    sched_applied = 1;
                                }
                                else
                                    fprintf(stderr, "  [Schedule] ventilation: init or fans_set failed\n");
                            }

                            if (sched_applied)
                            {
                                state_save(STATE_PATH, &dev_state);
                                if (supabase_update_actuator_state(&supabase_cfg,
                                        dev_state.lights_on, dev_state.pump_on, dev_state.fan_duty,
                                        -1, -1) != 0)
                                    fprintf(stderr, "  [Schedule] actuator state upsert failed\n");

                                /* At most one alert per schedule id per cooldown window */
                                enum { SCHED_ALERT_COOLDOWN_SEC = 120 };
                                time_t *last_alert_at = NULL;
                                for (int a = 0; a < sched_alert_cd_n; a++)
                                    if (strcmp(sched_alert_cd[a].id, sched[s].id) == 0)
                                    {
                                        last_alert_at = &sched_alert_cd[a].last_alert_at;
                                        break;
                                    }
                                if (!last_alert_at && sched_alert_cd_n < 32)
                                {
                                    int i = sched_alert_cd_n++;
                                    snprintf(sched_alert_cd[i].id, sizeof(sched_alert_cd[i].id), "%s",
                                             sched[s].id);
                                    last_alert_at = &sched_alert_cd[i].last_alert_at;
                                    *last_alert_at = 0;
                                }
                                if (last_alert_at && (now - *last_alert_at) >= SCHED_ALERT_COOLDOWN_SEC)
                                {
                                    if (supabase_insert_alert(&supabase_cfg, supabase_cfg.device_id,
                                            alert_type, alert_msg, "low", "scheduled") == 0)
                                        *last_alert_at = now;
                                }

                                int found = 0;
                                for (int r = 0; r < run_cache_n; r++)
                                    if (strcmp(run_cache[r].id, sched[s].id) == 0)
                                    {
                                        run_cache[r].last_run = now;
                                        found = 1;
                                        break;
                                    }
                                if (!found && run_cache_n < 16)
                                {
                                    snprintf(run_cache[run_cache_n].id, sizeof(run_cache[run_cache_n].id), "%s",
                                             sched[s].id);
                                    run_cache[run_cache_n].last_run = now;
                                    run_cache_n++;
                                }
                                supabase_update_schedule_last_run(&supabase_cfg, sched[s].id);
                            }
                        }
                    }
                    free(sched);
                }
            }
        }

        sleep(DATA_READ_INTERVAL);
    }

    if (cached_thresholds)
        free(cached_thresholds);

    if (supabase_enabled)
    {
        supabase_cleanup();
    }
    bme680_cleanup();
    sqlite3_close(db);
    gpio_cleanup();
    close(fd);

    return 0;
}

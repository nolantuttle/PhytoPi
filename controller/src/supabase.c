#include "../lib/supabase.h"
#include <curl/curl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <json-c/json.h>

static CURL *curl_handle = NULL;

struct memory_buffer {
    char *data;
    size_t size;
};

static size_t write_memory_callback(void *contents, size_t size, size_t nmemb, void *userp)
{
    size_t realsize = size * nmemb;
    struct memory_buffer *mem = (struct memory_buffer *)userp;
    char *ptr = realloc(mem->data, mem->size + realsize + 1);
    if (!ptr) return 0;
    mem->data = ptr;
    memcpy(&(mem->data[mem->size]), contents, realsize);
    mem->size += realsize;
    mem->data[mem->size] = 0;
    return realsize;
}

/*
 * Initialize Supabase HTTP client
 * Returns 0 on success, -1 on failure
 */
int supabase_init(supabase_config_t *config)
{
    if (!config || !config->api_url || !config->api_key)
    {
        fprintf(stderr, "Supabase config is invalid\n");
        return -1;
    }

    curl_global_init(CURL_GLOBAL_DEFAULT);
    curl_handle = curl_easy_init();

    if (!curl_handle)
    {
        fprintf(stderr, "Failed to initialize curl\n");
        return -1;
    }

    return 0;
}

/*
 * Cleanup Supabase HTTP client
 */
int supabase_cleanup(void)
{
    if (curl_handle)
    {
        curl_easy_cleanup(curl_handle);
        curl_handle = NULL;
    }
    curl_global_cleanup();
    return 0;
}

/*
 * Send a batch of readings to Supabase
 * Returns 0 on success, -1 on failure
 */
int supabase_send_batch(supabase_config_t *config, supabase_reading_t *readings, int count)
{
    if (!config || !readings || count <= 0)
    {
        fprintf(stderr, "Invalid parameters for batch send\n");
        return -1;
    }

    if (!curl_handle)
    {
        fprintf(stderr, "Supabase not initialized\n");
        return -1;
    }

    // Build JSON array of readings
    json_object *json_array = json_object_new_array();
    
    for (int i = 0; i < count; i++)
    {
        json_object *reading = json_object_new_object();
        
        // Add sensor_id
        json_object_object_add(reading, "sensor_id", 
                              json_object_new_string(readings[i].sensor_id));
        
        // Add value
        json_object_object_add(reading, "value", 
                              json_object_new_double(readings[i].value));
        
        // Add timestamp (convert to ISO 8601 format)
        char timestamp_str[64];
        time_t ts = (time_t)readings[i].timestamp;
        struct tm *tm_info = gmtime(&ts);
        strftime(timestamp_str, sizeof(timestamp_str), "%Y-%m-%dT%H:%M:%SZ", tm_info);
        json_object_object_add(reading, "ts", 
                              json_object_new_string(timestamp_str));
        
        // Add metadata if provided
        if (readings[i].metadata)
        {
            json_object *metadata_obj = json_tokener_parse(readings[i].metadata);
            if (metadata_obj)
            {
                json_object_object_add(reading, "metadata", metadata_obj);
            }
        }
        
        json_object_array_add(json_array, reading);
    }

    const char *json_string = json_object_to_json_string(json_array);
    
    // Build URL
    char url[512];
    snprintf(url, sizeof(url), "%s/rest/v1/readings", config->api_url);

    // Build headers
    struct curl_slist *headers = NULL;
    char apikey_header[256];
    char auth_header[256];
    snprintf(apikey_header, sizeof(apikey_header), "apikey: %s", config->api_key);
    snprintf(auth_header, sizeof(auth_header), "Authorization: Bearer %s", config->api_key);
    headers = curl_slist_append(headers, apikey_header);
    headers = curl_slist_append(headers, auth_header);
    headers = curl_slist_append(headers, "Content-Type: application/json");
    headers = curl_slist_append(headers, "Prefer: return=minimal");

    // Configure curl
    curl_easy_setopt(curl_handle, CURLOPT_URL, url);
    curl_easy_setopt(curl_handle, CURLOPT_POSTFIELDS, json_string);
    curl_easy_setopt(curl_handle, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl_handle, CURLOPT_POST, 1L);

    // Perform request
    CURLcode res = curl_easy_perform(curl_handle);
    
    long response_code;
    curl_easy_getinfo(curl_handle, CURLINFO_RESPONSE_CODE, &response_code);

    // Cleanup
    curl_slist_free_all(headers);
    json_object_put(json_array);

    if (res != CURLE_OK)
    {
        fprintf(stderr, "curl_easy_perform() failed: %s\n", curl_easy_strerror(res));
        return -1;
    }

    if (response_code >= 200 && response_code < 300)
    {
        printf("Successfully sent %d readings to Supabase (HTTP %ld)\n", count, response_code);
        return 0;
    }
    else
    {
        fprintf(stderr, "Supabase API returned error code: %ld\n", response_code);
        return -1;
    }
}

/*
 * Insert a single alert to Supabase
 * Returns 0 on success, -1 on failure
 */
int supabase_insert_alert(supabase_config_t *config, const char *device_id,
                          const char *type, const char *message, const char *severity,
                          const char *source)
{
    if (!config || !config->api_url || !config->api_key || !device_id || !type || !message)
        return -1;
    if (!curl_handle)
        return -1;

    json_object *alert = json_object_new_object();
    json_object_object_add(alert, "device_id", json_object_new_string(device_id));
    json_object_object_add(alert, "type", json_object_new_string(type));
    json_object_object_add(alert, "message", json_object_new_string(message));
    json_object_object_add(alert, "severity", json_object_new_string(severity ? severity : "medium"));
    if (source)
        json_object_object_add(alert, "source", json_object_new_string(source));

    const char *json_string = json_object_to_json_string(alert);

    char url[512];
    snprintf(url, sizeof(url), "%s/rest/v1/alerts", config->api_url);

    struct curl_slist *headers = NULL;
    char apikey_header[256];
    char auth_header[256];
    snprintf(apikey_header, sizeof(apikey_header), "apikey: %s", config->api_key);
    snprintf(auth_header, sizeof(auth_header), "Authorization: Bearer %s", config->api_key);
    headers = curl_slist_append(headers, apikey_header);
    headers = curl_slist_append(headers, auth_header);
    headers = curl_slist_append(headers, "Content-Type: application/json");
    headers = curl_slist_append(headers, "Prefer: return=minimal");

    curl_easy_setopt(curl_handle, CURLOPT_URL, url);
    curl_easy_setopt(curl_handle, CURLOPT_POSTFIELDS, json_string);
    curl_easy_setopt(curl_handle, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl_handle, CURLOPT_POST, 1L);

    CURLcode res = curl_easy_perform(curl_handle);
    long response_code = 0;
    curl_easy_getinfo(curl_handle, CURLINFO_RESPONSE_CODE, &response_code);
    curl_slist_free_all(headers);
    json_object_put(alert);

    if (res != CURLE_OK || response_code < 200 || response_code >= 300)
        return -1;
    return 0;
}

/*
 * Fetch device thresholds for the configured device.
 * Returns count of thresholds, -1 on error. Caller must free *out.
 */
int supabase_fetch_thresholds(supabase_config_t *config, device_threshold_t **out, int *count)
{
    if (!config || !config->api_url || !config->api_key || !config->device_id || !out || !count)
        return -1;
    if (!curl_handle)
        return -1;

    char url[512];
    snprintf(url, sizeof(url),
             "%s/rest/v1/device_thresholds?device_id=eq.%s&enabled=eq.true",
             config->api_url, config->device_id);

    struct curl_slist *headers = NULL;
    char apikey_header[256];
    char auth_header[256];
    snprintf(apikey_header, sizeof(apikey_header), "apikey: %s", config->api_key);
    snprintf(auth_header, sizeof(auth_header), "Authorization: Bearer %s", config->api_key);
    headers = curl_slist_append(headers, apikey_header);
    headers = curl_slist_append(headers, auth_header);
    headers = curl_slist_append(headers, "Accept: application/json");

    struct memory_buffer chunk = {0};
    curl_easy_setopt(curl_handle, CURLOPT_URL, url);
    curl_easy_setopt(curl_handle, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl_handle, CURLOPT_WRITEFUNCTION, write_memory_callback);
    curl_easy_setopt(curl_handle, CURLOPT_WRITEDATA, (void *)&chunk);
    curl_easy_setopt(curl_handle, CURLOPT_HTTPGET, 1L);

    CURLcode res = curl_easy_perform(curl_handle);
    long response_code = 0;
    curl_easy_getinfo(curl_handle, CURLINFO_RESPONSE_CODE, &response_code);
    curl_slist_free_all(headers);

    if (res != CURLE_OK || response_code < 200 || response_code >= 300)
    {
        if (chunk.data) free(chunk.data);
        return -1;
    }

    if (!chunk.data || chunk.size == 0)
    {
        free(chunk.data);
        *out = NULL;
        *count = 0;
        return 0;
    }

    json_object *root = json_tokener_parse(chunk.data);
    free(chunk.data);
    if (!root || !json_object_is_type(root, json_type_array))
    {
        if (root) json_object_put(root);
        return -1;
    }

    int n = json_object_array_length(root);
    device_threshold_t *arr = (device_threshold_t *)calloc(n, sizeof(device_threshold_t));
    if (!arr)
    {
        json_object_put(root);
        return -1;
    }

    for (int i = 0; i < n; i++)
    {
        json_object *obj = json_object_array_get_idx(root, i);
        json_object *id_o = NULL, *metric_o = NULL, *min_o = NULL, *max_o = NULL, *en_o = NULL;
        if (json_object_object_get_ex(obj, "id", &id_o))
            snprintf(arr[i].id, sizeof(arr[i].id), "%s", json_object_get_string(id_o));
        if (json_object_object_get_ex(obj, "metric", &metric_o))
            snprintf(arr[i].metric, sizeof(arr[i].metric), "%s", json_object_get_string(metric_o));
        if (json_object_object_get_ex(obj, "min_value", &min_o) &&
            json_object_get_type(min_o) != json_type_null)
            arr[i].min_value = json_object_get_double(min_o);
        else
            arr[i].min_value = -1e9;
        if (json_object_object_get_ex(obj, "max_value", &max_o) &&
            json_object_get_type(max_o) != json_type_null)
            arr[i].max_value = json_object_get_double(max_o);
        else
            arr[i].max_value = 1e9;
        if (json_object_object_get_ex(obj, "enabled", &en_o))
            arr[i].enabled = json_object_get_boolean(en_o) ? 1 : 0;
        else
            arr[i].enabled = 1;
    }

    json_object_put(root);
    *out = arr;
    *count = n;
    return n;
}

/*
 * Fetch enabled schedules for the configured device.
 * Returns count, -1 on error. Caller must free *out.
 */
int supabase_fetch_schedules(supabase_config_t *config, device_schedule_t **out, int *count)
{
    if (!config || !config->api_url || !config->api_key || !config->device_id || !out || !count)
        return -1;
    if (!curl_handle)
        return -1;

    char url[512];
    snprintf(url, sizeof(url),
             "%s/rest/v1/schedules?device_id=eq.%s&enabled=eq.true",
             config->api_url, config->device_id);

    struct curl_slist *headers = NULL;
    char apikey_header[256];
    char auth_header[256];
    snprintf(apikey_header, sizeof(apikey_header), "apikey: %s", config->api_key);
    snprintf(auth_header, sizeof(auth_header), "Authorization: Bearer %s", config->api_key);
    headers = curl_slist_append(headers, apikey_header);
    headers = curl_slist_append(headers, auth_header);
    headers = curl_slist_append(headers, "Accept: application/json");

    struct memory_buffer chunk = {0};
    curl_easy_setopt(curl_handle, CURLOPT_URL, url);
    curl_easy_setopt(curl_handle, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl_handle, CURLOPT_WRITEFUNCTION, write_memory_callback);
    curl_easy_setopt(curl_handle, CURLOPT_WRITEDATA, (void *)&chunk);
    curl_easy_setopt(curl_handle, CURLOPT_HTTPGET, 1L);

    CURLcode res = curl_easy_perform(curl_handle);
    long response_code = 0;
    curl_easy_getinfo(curl_handle, CURLINFO_RESPONSE_CODE, &response_code);
    curl_slist_free_all(headers);

    if (res != CURLE_OK || response_code < 200 || response_code >= 300)
    {
        if (chunk.data) free(chunk.data);
        return -1;
    }

    if (!chunk.data || chunk.size == 0)
    {
        free(chunk.data);
        *out = NULL;
        *count = 0;
        return 0;
    }

    json_object *root = json_tokener_parse(chunk.data);
    free(chunk.data);
    if (!root || !json_object_is_type(root, json_type_array))
    {
        if (root) json_object_put(root);
        return -1;
    }

    int n = json_object_array_length(root);
    device_schedule_t *arr = (device_schedule_t *)calloc(n, sizeof(device_schedule_t));
    if (!arr)
    {
        json_object_put(root);
        return -1;
    }

    for (int i = 0; i < n; i++)
    {
        json_object *obj = json_object_array_get_idx(root, i);
        json_object *id_o = NULL, *type_o = NULL, *cron_o = NULL, *interval_o = NULL, *payload_o = NULL, *en_o = NULL;
        if (json_object_object_get_ex(obj, "id", &id_o))
            snprintf(arr[i].id, sizeof(arr[i].id), "%s", json_object_get_string(id_o));
        if (json_object_object_get_ex(obj, "schedule_type", &type_o))
            snprintf(arr[i].schedule_type, sizeof(arr[i].schedule_type), "%s", json_object_get_string(type_o));
        if (json_object_object_get_ex(obj, "cron_expr", &cron_o) && json_object_get_string(cron_o))
            snprintf(arr[i].cron_expr, sizeof(arr[i].cron_expr), "%s", json_object_get_string(cron_o));
        if (json_object_object_get_ex(obj, "interval_seconds", &interval_o))
            arr[i].interval_seconds = json_object_get_int(interval_o);
        if (json_object_object_get_ex(obj, "payload", &payload_o))
            snprintf(arr[i].payload_json, sizeof(arr[i].payload_json), "%s", json_object_to_json_string(payload_o));
        if (json_object_object_get_ex(obj, "enabled", &en_o))
            arr[i].enabled = json_object_get_boolean(en_o) ? 1 : 0;
        else
            arr[i].enabled = 1;
    }

    json_object_put(root);
    *out = arr;
    *count = n;
    return n;
}

/*
 * Heartbeat: PATCH device_units SET last_seen = now() WHERE id = device_id
 * Returns 0 on success, -1 on failure
 */
int supabase_heartbeat(supabase_config_t *config)
{
    if (!config || !config->api_url || !config->api_key || !config->device_id)
        return -1;
    if (!curl_handle)
        return -1;

    time_t now_t = time(NULL);
    struct tm *tm_info = gmtime(&now_t);
    char timestamp_str[64];
    strftime(timestamp_str, sizeof(timestamp_str), "%Y-%m-%dT%H:%M:%SZ", tm_info);

    json_object *body = json_object_new_object();
    json_object_object_add(body, "last_seen", json_object_new_string(timestamp_str));
    const char *json_string = json_object_to_json_string(body);

    char url[512];
    snprintf(url, sizeof(url), "%s/rest/v1/device_units?id=eq.%s",
             config->api_url, config->device_id);

    struct curl_slist *headers = NULL;
    char apikey_header[256];
    char auth_header[256];
    snprintf(apikey_header, sizeof(apikey_header), "apikey: %s", config->api_key);
    snprintf(auth_header, sizeof(auth_header), "Authorization: Bearer %s", config->api_key);
    headers = curl_slist_append(headers, apikey_header);
    headers = curl_slist_append(headers, auth_header);
    headers = curl_slist_append(headers, "Content-Type: application/json");
    headers = curl_slist_append(headers, "Prefer: return=minimal");

    curl_easy_setopt(curl_handle, CURLOPT_URL, url);
    curl_easy_setopt(curl_handle, CURLOPT_POSTFIELDS, json_string);
    curl_easy_setopt(curl_handle, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl_handle, CURLOPT_CUSTOMREQUEST, "PATCH");

    CURLcode res = curl_easy_perform(curl_handle);
    long response_code = 0;
    curl_easy_getinfo(curl_handle, CURLINFO_RESPONSE_CODE, &response_code);
    curl_slist_free_all(headers);
    json_object_put(body);

    curl_easy_setopt(curl_handle, CURLOPT_CUSTOMREQUEST, NULL);

    if (res != CURLE_OK || response_code < 200 || response_code >= 300)
        return -1;
    return 0;
}

/*
 * Update schedule last_run_at. Returns 0 on success.
 */
int supabase_update_schedule_last_run(supabase_config_t *config, const char *schedule_id)
{
    if (!config || !config->api_url || !config->api_key || !schedule_id)
        return -1;
    if (!curl_handle)
        return -1;

    time_t now_t = time(NULL);
    struct tm *tm_info = gmtime(&now_t);
    char timestamp_str[64];
    strftime(timestamp_str, sizeof(timestamp_str), "%Y-%m-%dT%H:%M:%SZ", tm_info);

    json_object *body = json_object_new_object();
    json_object_object_add(body, "last_run_at", json_object_new_string(timestamp_str));
    const char *json_string = json_object_to_json_string(body);

    char url[512];
    snprintf(url, sizeof(url), "%s/rest/v1/schedules?id=eq.%s",
             config->api_url, schedule_id);

    struct curl_slist *headers = NULL;
    char apikey_header[256];
    char auth_header[256];
    snprintf(apikey_header, sizeof(apikey_header), "apikey: %s", config->api_key);
    snprintf(auth_header, sizeof(auth_header), "Authorization: Bearer %s", config->api_key);
    headers = curl_slist_append(headers, apikey_header);
    headers = curl_slist_append(headers, auth_header);
    headers = curl_slist_append(headers, "Content-Type: application/json");
    headers = curl_slist_append(headers, "Prefer: return=minimal");

    curl_easy_setopt(curl_handle, CURLOPT_URL, url);
    curl_easy_setopt(curl_handle, CURLOPT_POSTFIELDS, json_string);
    curl_easy_setopt(curl_handle, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl_handle, CURLOPT_CUSTOMREQUEST, "PATCH");

    CURLcode res = curl_easy_perform(curl_handle);
    long response_code = 0;
    curl_easy_getinfo(curl_handle, CURLINFO_RESPONSE_CODE, &response_code);
    curl_slist_free_all(headers);
    json_object_put(body);

    curl_easy_setopt(curl_handle, CURLOPT_CUSTOMREQUEST, NULL);

    if (res != CURLE_OK || response_code < 200 || response_code >= 300)
        return -1;
    return 0;
}


/*
 * Upsert device_actuator_state (POST with Prefer: resolution=merge-duplicates).
 * Pass -1 for any field to omit it from the body.
 */
int supabase_update_actuator_state(supabase_config_t *config,
                                   int lights_on, int pump_on, int fan_duty,
                                   int bme_ok, int soil_ok)
{
    if (!config || !config->api_url || !config->api_key || !config->device_id)
        return -1;
    if (!curl_handle)
        return -1;

    time_t now_t = time(NULL);
    struct tm *tm_info = gmtime(&now_t);
    char timestamp_str[64];
    strftime(timestamp_str, sizeof(timestamp_str), "%Y-%m-%dT%H:%M:%SZ", tm_info);

    json_object *body = json_object_new_object();
    json_object_object_add(body, "device_id", json_object_new_string(config->device_id));
    json_object_object_add(body, "updated_at", json_object_new_string(timestamp_str));

    if (lights_on >= 0)
        json_object_object_add(body, "lights_on", json_object_new_boolean(lights_on));
    if (pump_on >= 0)
        json_object_object_add(body, "pump_on", json_object_new_boolean(pump_on));
    if (fan_duty >= 0)
        json_object_object_add(body, "fan_duty", json_object_new_int(fan_duty));
    if (bme_ok >= 0)
        json_object_object_add(body, "bme_ok", json_object_new_boolean(bme_ok));
    if (soil_ok >= 0)
        json_object_object_add(body, "soil_ok", json_object_new_boolean(soil_ok));

    const char *json_string = json_object_to_json_string(body);

    char url[512];
    snprintf(url, sizeof(url), "%s/rest/v1/device_actuator_state", config->api_url);

    struct curl_slist *headers = NULL;
    char apikey_header[256];
    char auth_header[256];
    snprintf(apikey_header, sizeof(apikey_header), "apikey: %s", config->api_key);
    snprintf(auth_header, sizeof(auth_header), "Authorization: Bearer %s", config->api_key);
    headers = curl_slist_append(headers, apikey_header);
    headers = curl_slist_append(headers, auth_header);
    headers = curl_slist_append(headers, "Content-Type: application/json");
    headers = curl_slist_append(headers, "Prefer: resolution=merge-duplicates,return=minimal");

    curl_easy_setopt(curl_handle, CURLOPT_URL, url);
    curl_easy_setopt(curl_handle, CURLOPT_POSTFIELDS, json_string);
    curl_easy_setopt(curl_handle, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl_handle, CURLOPT_POST, 1L);

    CURLcode res_act = curl_easy_perform(curl_handle);
    long rc_act = 0;
    curl_easy_getinfo(curl_handle, CURLINFO_RESPONSE_CODE, &rc_act);
    curl_slist_free_all(headers);
    json_object_put(body);

    if (res_act != CURLE_OK || rc_act < 200 || rc_act >= 300)
    {
        fprintf(stderr, "  [ActuatorState] Failed to upsert (http=%ld)\n", rc_act);
        return -1;
    }
    return 0;
}

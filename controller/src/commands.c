#include "../lib/commands.h"
#include <curl/curl.h>
#include <json-c/json.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

struct memory_buffer {
    char *data;
    size_t size;
};

static size_t write_memory_callback(void *contents, size_t size, size_t nmemb, void *userp)
{
    size_t realsize = size * nmemb;
    struct memory_buffer *mem = (struct memory_buffer *)userp;

    char *ptr = realloc(mem->data, mem->size + realsize + 1);
    if (!ptr)
        return 0;

    mem->data = ptr;
    memcpy(&(mem->data[mem->size]), contents, realsize);
    mem->size += realsize;
    mem->data[mem->size] = 0;

    return realsize;
}

int fetch_next_light_command(const supabase_config_t *cfg, int *desired_state, char *command_id_buf, int command_id_buf_len)
{
    if (!cfg || !cfg->api_url || !cfg->api_key || !cfg->device_id || !desired_state || !command_id_buf || command_id_buf_len <= 0)
        return -1;

    CURL *curl = curl_easy_init();
    if (!curl)
        return -1;

    char url[512];
    snprintf(url, sizeof(url),
             "%s/rest/v1/device_commands?device_id=eq.%s&command_type=eq.toggle_light&status=eq.pending&order=created_at.asc&limit=1",
             cfg->api_url, cfg->device_id);

    struct curl_slist *headers = NULL;
    char apikey_header[256];
    char auth_header[256];
    snprintf(apikey_header, sizeof(apikey_header), "apikey: %s", cfg->api_key);
    snprintf(auth_header, sizeof(auth_header), "Authorization: Bearer %s", cfg->api_key);
    headers = curl_slist_append(headers, apikey_header);
    headers = curl_slist_append(headers, auth_header);
    headers = curl_slist_append(headers, "Accept: application/json");

    struct memory_buffer chunk = {0};

    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_memory_callback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, (void *)&chunk);

    CURLcode res = curl_easy_perform(curl);

    long response_code = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &response_code);

    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);

    if (res != CURLE_OK || response_code < 200 || response_code >= 300)
    {
        if (chunk.data)
            free(chunk.data);
        return -1;
    }

    if (!chunk.data || chunk.size == 0)
    {
        free(chunk.data);
        return 0;
    }

    json_object *root = json_tokener_parse(chunk.data);
    free(chunk.data);

    if (!root || !json_object_is_type(root, json_type_array))
    {
        if (root)
            json_object_put(root);
        return 0;
    }

    if (json_object_array_length(root) == 0)
    {
        json_object_put(root);
        return 0;
    }

    json_object *cmd = json_object_array_get_idx(root, 0);
    json_object *id_obj = NULL;
    json_object *payload_obj = NULL;

    if (!json_object_object_get_ex(cmd, "id", &id_obj) ||
        !json_object_is_type(id_obj, json_type_string) ||
        !json_object_object_get_ex(cmd, "payload", &payload_obj) ||
        !json_object_is_type(payload_obj, json_type_object))
    {
        json_object_put(root);
        return -1;
    }

    const char *id_str = json_object_get_string(id_obj);
    if (!id_str)
    {
        json_object_put(root);
        return -1;
    }

    json_object *state_obj = NULL;
    if (!json_object_object_get_ex(payload_obj, "state", &state_obj))
    {
        json_object_put(root);
        return -1;
    }

    int state_val = 0;
    if (json_object_is_type(state_obj, json_type_boolean))
    {
        state_val = json_object_get_boolean(state_obj) ? 1 : 0;
    }
    else if (json_object_is_type(state_obj, json_type_int))
    {
        state_val = json_object_get_int(state_obj) ? 1 : 0;
    }
    else
    {
        json_object_put(root);
        return -1;
    }

    *desired_state = state_val;
    snprintf(command_id_buf, command_id_buf_len, "%s", id_str);

    json_object_put(root);
    return 1;
}

int fetch_next_command(const supabase_config_t *cfg, device_command_t *cmd)
{
    if (!cfg || !cfg->api_url || !cfg->api_key || !cfg->device_id || !cmd)
        return -1;

    CURL *curl = curl_easy_init();
    if (!curl)
        return -1;

    char url[512];
    snprintf(url, sizeof(url),
             "%s/rest/v1/device_commands?device_id=eq.%s&status=eq.pending&order=created_at.asc&limit=1",
             cfg->api_url, cfg->device_id);

    struct curl_slist *headers = NULL;
    char apikey_header[256];
    char auth_header[256];
    snprintf(apikey_header, sizeof(apikey_header), "apikey: %s", cfg->api_key);
    snprintf(auth_header, sizeof(auth_header), "Authorization: Bearer %s", cfg->api_key);
    headers = curl_slist_append(headers, apikey_header);
    headers = curl_slist_append(headers, auth_header);
    headers = curl_slist_append(headers, "Accept: application/json");

    struct memory_buffer chunk = {0};
    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_memory_callback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, (void *)&chunk);

    CURLcode res = curl_easy_perform(curl);
    long response_code = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &response_code);
    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);

    if (res != CURLE_OK || response_code < 200 || response_code >= 300)
    {
        if (chunk.data) free(chunk.data);
        return -1;
    }

    if (!chunk.data || chunk.size == 0)
    {
        free(chunk.data);
        return 0;
    }

    json_object *root = json_tokener_parse(chunk.data);
    free(chunk.data);
    if (!root || !json_object_is_type(root, json_type_array))
    {
        if (root) json_object_put(root);
        return 0;
    }
    if (json_object_array_length(root) == 0)
    {
        json_object_put(root);
        return 0;
    }

    json_object *c = json_object_array_get_idx(root, 0);
    json_object *id_obj = NULL, *type_obj = NULL, *payload_obj = NULL;
    if (!json_object_object_get_ex(c, "id", &id_obj) || !json_object_object_get_ex(c, "command_type", &type_obj) ||
        !json_object_object_get_ex(c, "payload", &payload_obj))
    {
        json_object_put(root);
        return -1;
    }

    const char *id_str = json_object_get_string(id_obj);
    const char *type_str = json_object_get_string(type_obj);
    const char *payload_str = json_object_to_json_string(payload_obj);
    if (!id_str || !type_str || !payload_str)
    {
        json_object_put(root);
        return -1;
    }

    snprintf(cmd->id, sizeof(cmd->id), "%s", id_str);
    snprintf(cmd->command_type, sizeof(cmd->command_type), "%s", type_str);
    snprintf(cmd->payload_json, sizeof(cmd->payload_json), "%s", payload_str);
    json_object_put(root);
    return 1;
}

int mark_command_processed(const supabase_config_t *cfg, const char *command_id, const char *status)
{
    if (!cfg || !cfg->api_url || !cfg->api_key || !command_id || !status)
        return -1;

    CURL *curl = curl_easy_init();
    if (!curl)
        return -1;

    char url[512];
    snprintf(url, sizeof(url),
             "%s/rest/v1/device_commands?id=eq.%s",
             cfg->api_url, command_id);

    struct curl_slist *headers = NULL;
    char apikey_header[256];
    char auth_header[256];
    snprintf(apikey_header, sizeof(apikey_header), "apikey: %s", cfg->api_key);
    snprintf(auth_header, sizeof(auth_header), "Authorization: Bearer %s", cfg->api_key);
    headers = curl_slist_append(headers, apikey_header);
    headers = curl_slist_append(headers, auth_header);
    headers = curl_slist_append(headers, "Content-Type: application/json");
    headers = curl_slist_append(headers, "Prefer: return=minimal");

    time_t now_sec = time(NULL);
    struct tm tm_buf;
    gmtime_r(&now_sec, &tm_buf);
    char iso_buf[32];
    strftime(iso_buf, sizeof(iso_buf), "%Y-%m-%dT%H:%M:%SZ", &tm_buf);

    json_object *body = json_object_new_object();
    json_object_object_add(body, "status", json_object_new_string(status));
    json_object_object_add(body, "executed_at", json_object_new_string(iso_buf));

    const char *body_str = json_object_to_json_string(body);

    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "PATCH");
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body_str);

    CURLcode res = curl_easy_perform(curl);

    long response_code = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &response_code);

    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);
    json_object_put(body);

    if (res != CURLE_OK || response_code < 200 || response_code >= 300)
    {
        return -1;
    }

    return 0;
}

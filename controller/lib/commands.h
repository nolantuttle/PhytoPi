#ifndef COMMANDS_H
#define COMMANDS_H

#include "supabase.h"

#define CMD_TYPE_LEN 32
#define CMD_ID_LEN 64
#define CMD_PAYLOAD_LEN 256

typedef struct {
    char id[CMD_ID_LEN];
    char command_type[CMD_TYPE_LEN];
    char payload_json[CMD_PAYLOAD_LEN];
} device_command_t;

/* Fetch the next pending light command for this device. */
int fetch_next_light_command(const supabase_config_t *cfg, int *desired_state, char *command_id_buf, int command_id_buf_len);

/* Fetch the next pending command of any type. Returns 1 if found, 0 if none, -1 on error. */
int fetch_next_command(const supabase_config_t *cfg, device_command_t *cmd);

/* Mark a command as processed with given status ("executed" or "failed"). */
int mark_command_processed(const supabase_config_t *cfg, const char *command_id, const char *status);

/* Legacy alias */
#define mark_light_command_processed mark_command_processed

#endif


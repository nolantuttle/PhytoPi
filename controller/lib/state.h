#ifndef STATE_H
#define STATE_H

typedef struct
{
    int lights_on;
    int pump_on;
    int fan_duty; /* 0-100 */
} device_state_t;

int state_load(const char *path, device_state_t *s);
int state_save(const char *path, const device_state_t *s);

#endif
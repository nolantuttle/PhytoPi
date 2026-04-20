#include "../lib/state.h"
#include <stdio.h>
#include <string.h>

int state_load(const char *path, device_state_t *s)
{
    s->lights_on = 0;
    s->pump_on = 0;
    s->fan_duty = 0;

    FILE *f = fopen(path, "r");
    if (!f)
        return -1; /* no state file yet — defaults are fine */

    fscanf(f, "lights=%d pump=%d fan_duty=%d",
           &s->lights_on, &s->pump_on, &s->fan_duty);
    fclose(f);
    return 0;
}

int state_save(const char *path, const device_state_t *s)
{
    FILE *f = fopen(path, "w");
    if (!f)
        return -1;
    fprintf(f, "lights=%d pump=%d fan_duty=%d\n",
            s->lights_on, s->pump_on, s->fan_duty);
    fclose(f);
    return 0;
}
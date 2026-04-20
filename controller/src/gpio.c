#include "../lib/gpio.h"
#include <stdint.h>
#include <time.h>
#include <string.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/ioctl.h>

static struct gpiod_chip *chip = NULL;
static struct gpiod_line_request *req_generic = NULL;
static struct gpiod_line_request *req_lights = NULL;
static struct gpiod_line_request *req_pump = NULL;
static struct gpiod_line_request *req_water_level = NULL;
static int gpio_initialized = 0;
static int lights_initialized = 0;
static int pump_initialized = 0;
static int water_level_initialized = 0;
static int pwm_initialized = 0;

#define PWM_CHIP "/sys/class/pwm/pwmchip0"
#define PWM_PERIOD_NS 40000 /* 25kHz = 40us period */

/*
 * Helper: open chip if not already open
 */
static int ensure_chip(void)
{
    if (!chip)
    {
        chip = gpiod_chip_open("/dev/gpiochip0");
        if (!chip)
            return -1;
    }
    return 0;
}

/*
 * Helper: create a line request for a single pin as output
 */
static struct gpiod_line_request *request_output(int pin, const char *consumer, int initial)
{
    struct gpiod_line_settings *settings = gpiod_line_settings_new();
    if (!settings) return NULL;
    gpiod_line_settings_set_direction(settings, GPIOD_LINE_DIRECTION_OUTPUT);
    gpiod_line_settings_set_output_value(settings, initial ? GPIOD_LINE_VALUE_ACTIVE : GPIOD_LINE_VALUE_INACTIVE);

    struct gpiod_line_config *config = gpiod_line_config_new();
    if (!config) { gpiod_line_settings_free(settings); return NULL; }

    unsigned int offset = (unsigned int)pin;
    if (gpiod_line_config_add_line_settings(config, &offset, 1, settings) != 0)
    {
        gpiod_line_settings_free(settings);
        gpiod_line_config_free(config);
        return NULL;
    }

    struct gpiod_request_config *req_cfg = gpiod_request_config_new();
    if (!req_cfg)
    {
        gpiod_line_settings_free(settings);
        gpiod_line_config_free(config);
        return NULL;
    }
    gpiod_request_config_set_consumer(req_cfg, consumer);

    struct gpiod_line_request *req = gpiod_chip_request_lines(chip, req_cfg, config);

    gpiod_line_settings_free(settings);
    gpiod_line_config_free(config);
    gpiod_request_config_free(req_cfg);

    return req;
}

/*
 * Helper: create a line request for a single pin as input
 */
static struct gpiod_line_request *request_input(int pin, const char *consumer)
{
    struct gpiod_line_settings *settings = gpiod_line_settings_new();
    if (!settings) return NULL;
    gpiod_line_settings_set_direction(settings, GPIOD_LINE_DIRECTION_INPUT);

    struct gpiod_line_config *config = gpiod_line_config_new();
    if (!config) { gpiod_line_settings_free(settings); return NULL; }

    unsigned int offset = (unsigned int)pin;
    if (gpiod_line_config_add_line_settings(config, &offset, 1, settings) != 0)
    {
        gpiod_line_settings_free(settings);
        gpiod_line_config_free(config);
        return NULL;
    }

    struct gpiod_request_config *req_cfg = gpiod_request_config_new();
    if (!req_cfg)
    {
        gpiod_line_settings_free(settings);
        gpiod_line_config_free(config);
        return NULL;
    }
    gpiod_request_config_set_consumer(req_cfg, consumer);

    struct gpiod_line_request *req = gpiod_chip_request_lines(chip, req_cfg, config);

    gpiod_line_settings_free(settings);
    gpiod_line_config_free(config);
    gpiod_request_config_free(req_cfg);

    return req;
}

/*
 * Initialize GPIO library (opens chip, gets line for given pin)
 */
int gpio_init(int pin)
{
    if (ensure_chip() != 0)
        return -1;
    if (req_generic)
    {
        gpiod_line_request_release(req_generic);
        req_generic = NULL;
    }
    req_generic = request_output(pin, "gpio_app", 0);
    if (!req_generic)
        return -1;
    gpio_initialized = 1;
    return 0;
}

/*
 * Configure pin as input
 */
int gpio_config_input(int pin)
{
    if (ensure_chip() != 0)
        return -1;
    if (req_generic)
    {
        gpiod_line_request_release(req_generic);
        req_generic = NULL;
    }
    req_generic = request_input(pin, "gpio_app");
    return req_generic ? 0 : -1;
}

/*
 * Configure pin as output
 */
int gpio_config_output(int pin)
{
    if (ensure_chip() != 0)
        return -1;
    if (req_generic)
    {
        gpiod_line_request_release(req_generic);
        req_generic = NULL;
    }
    req_generic = request_output(pin, "gpio_app", 0);
    return req_generic ? 0 : -1;
}

/*
 * Write value to GPIO pin (uses current generic request)
 */
int gpio_write(int value)
{
    if (!req_generic) return -1;
    /* We don't track the offset here — use index 0 since single-line request */
    return gpiod_line_request_set_value(req_generic, 0,
        value ? GPIOD_LINE_VALUE_ACTIVE : GPIOD_LINE_VALUE_INACTIVE);
}

/*
 * Read value from GPIO pin
 */
int gpio_read(void)
{
    if (!req_generic) return -1;
    enum gpiod_line_value val = gpiod_line_request_get_value(req_generic, 0);
    if (val == GPIOD_LINE_VALUE_ERROR) return -1;
    return (val == GPIOD_LINE_VALUE_ACTIVE) ? 1 : 0;
}

/*
 * Cleanup GPIO library
 */
int gpio_cleanup(void)
{
    if (req_lights)   { gpiod_line_request_release(req_lights);      req_lights = NULL; }
    if (req_pump)     { gpiod_line_request_release(req_pump);        req_pump = NULL; }
    if (req_water_level) { gpiod_line_request_release(req_water_level); req_water_level = NULL; }
    if (req_generic)  { gpiod_line_request_release(req_generic);     req_generic = NULL; }
    if (chip)         { gpiod_chip_close(chip);                      chip = NULL; }
    gpio_initialized = 0;
    lights_initialized = 0;
    pump_initialized = 0;
    water_level_initialized = 0;
    pwm_initialized = 0;
    return 0;
}

/*
 * -------------------------------
 * LIGHT CONTROL (24V MOSFET ON GPIO17)
 *-------------------------------
 */
int lights_init(void)
{
    if (lights_initialized)
        return 0;
    if (ensure_chip() != 0)
        return -1;
    req_lights = request_output(LIGHTS_PIN, "phytopi_lights", 0);
    if (!req_lights)
        return -1;
    lights_initialized = 1;
    return 0;
}

int lights_set(int on)
{
    if (!lights_initialized && lights_init() != 0)
        return -1;
    return gpiod_line_request_set_value(req_lights, LIGHTS_PIN,
        on ? GPIOD_LINE_VALUE_ACTIVE : GPIOD_LINE_VALUE_INACTIVE);
}

/*
 * -------------------------------
 * PUMP CONTROL (MOSFET ON GPIO22)
 *-------------------------------
 */
int pump_init(void)
{
    if (pump_initialized)
        return 0;
    if (ensure_chip() != 0)
        return -1;
    req_pump = request_output(PUMP_PIN, "phytopi_pump", 0);
    if (!req_pump)
        return -1;
    pump_initialized = 1;
    return 0;
}

int pump_set(int on)
{
    if (!pump_initialized && pump_init() != 0)
        return -1;
    return gpiod_line_request_set_value(req_pump, PUMP_PIN,
        on ? GPIOD_LINE_VALUE_ACTIVE : GPIOD_LINE_VALUE_INACTIVE);
}

/*
 * -------------------------------
 * PWM FAN CONTROL (GPIO12, GPIO13 via sysfs)
 * PWM uses sysfs, no libgpiod needed — unchanged from v1
 *-------------------------------
 */
static int pwm_export(int channel)
{
    char path[128];
    snprintf(path, sizeof(path), "%s/export", PWM_CHIP);
    int fd = open(path, O_WRONLY);
    if (fd < 0)
        return -1;
    char buf[8];
    snprintf(buf, sizeof(buf), "%d", channel);
    int ret = (write(fd, buf, strlen(buf)) > 0) ? 0 : -1;
    close(fd);
    return ret;
}

static int pwm_set(int channel, int period_ns, int duty_ns)
{
    char path[128];
    snprintf(path, sizeof(path), "%s/pwm%d/period", PWM_CHIP, channel);
    int fd = open(path, O_WRONLY);
    if (fd < 0)
        return -1;
    char buf[32];
    snprintf(buf, sizeof(buf), "%d", period_ns);
    write(fd, buf, strlen(buf));
    close(fd);

    snprintf(path, sizeof(path), "%s/pwm%d/duty_cycle", PWM_CHIP, channel);
    fd = open(path, O_WRONLY);
    if (fd < 0)
        return -1;
    snprintf(buf, sizeof(buf), "%d", duty_ns);
    write(fd, buf, strlen(buf));
    close(fd);

    snprintf(path, sizeof(path), "%s/pwm%d/enable", PWM_CHIP, channel);
    fd = open(path, O_WRONLY);
    if (fd < 0)
        return -1;
    write(fd, duty_ns > 0 ? "1" : "0", 1);
    close(fd);
    return 0;
}

int fans_init(void)
{
    if (pwm_initialized)
        return 0;
    if (pwm_export(0) != 0 && pwm_export(0) != 0)
        ;
    if (pwm_export(1) != 0 && pwm_export(1) != 0)
        ;
    pwm_initialized = 1;
    return 0;
}

int fans_set_speed(int fan_id, int duty_percent)
{
    if (!pwm_initialized && fans_init() != 0)
        return -1;
    if (fan_id != 1 && fan_id != 2)
        return -1;
    if (duty_percent < 0) duty_percent = 0;
    if (duty_percent > 100) duty_percent = 100;
    int ch = (fan_id == 1) ? 0 : 1;
    int duty_ns = (PWM_PERIOD_NS * duty_percent) / 100;
    return pwm_set(ch, PWM_PERIOD_NS, duty_ns);
}

int fans_set_both(int duty_percent)
{
    int r1 = fans_set_speed(1, duty_percent);
    int r2 = fans_set_speed(2, duty_percent);
    return (r1 == 0 && r2 == 0) ? 0 : -1;
}

/*
 * -------------------------------
 * PHOTOELECTRIC WATER LEVEL (GPIO26 - frequency input)
 * CQRobot: 20Hz = no liquid, up to 400Hz at Level 4. Low freq = low water.
 *-------------------------------
 */
int read_photoelectric_water_level(int *frequency_hz)
{
    if (!frequency_hz)
        return -1;
    if (ensure_chip() != 0)
        return -1;

    if (!req_water_level)
    {
        req_water_level = request_input(WATER_LEVEL_PIN, "phytopi_water");
        if (!req_water_level)
            return -1;
        water_level_initialized = 1;
    }

    /* Count rising edges over 100ms to get frequency */
    struct timespec start, now;
    clock_gettime(CLOCK_MONOTONIC, &start);

    enum gpiod_line_value raw = gpiod_line_request_get_value(req_water_level, WATER_LEVEL_PIN);
    int last = (raw == GPIOD_LINE_VALUE_ACTIVE) ? 1 : 0;
    int count = 0;
    const long timeout_ns = 100000000; /* 100ms */

    while (1)
    {
        clock_gettime(CLOCK_MONOTONIC, &now);
        long elapsed = (now.tv_sec - start.tv_sec) * 1000000000L + (now.tv_nsec - start.tv_nsec);
        if (elapsed >= timeout_ns)
            break;

        raw = gpiod_line_request_get_value(req_water_level, WATER_LEVEL_PIN);
        int val = (raw == GPIOD_LINE_VALUE_ACTIVE) ? 1 : 0;
        if (val == 1 && last == 0)
            count++;
        last = val;
        usleep(100);
    }

    *frequency_hz = count * 10; /* 100ms -> 10 samples/sec for Hz */
    return 0;
}

/*
 * -------------------------------
 * I2C / PCF8591 ADC
 *-------------------------------
 */
int i2c_init(const char *i2c_bus)
{
    int fd = open(i2c_bus, O_RDWR);
    if (fd < 0)
    {
        perror("Failed to open the i2c bus");
        return -1;
    }

    if (ioctl(fd, I2C_SLAVE, PCF8591_ADDR) < 0)
    {
        perror("Failed to acquire bus access and/or talk to slave");
        close(fd);
        return -1;
    }

    return fd;
}

/*
 * Reads a given channel from the PCF8591 ADC over I2C.
 * Returns the 8-bit ADC value on success, -1 on failure.
 */
int read_pcf8591_channel(int fd, int channel)
{
    if (channel < 0 || channel > 3)
        return -1;

    unsigned char cmd = 0x40 | (channel & 0x03);
    unsigned char data;

    if (write(fd, &cmd, 1) != 1)
        return -1;

    /* First read is stale, discard it */
    if (read(fd, &data, 1) != 1)
        return -1;

    /* Second read is fresh */
    if (read(fd, &data, 1) != 1)
        return -1;

    return data;
}
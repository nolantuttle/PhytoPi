#ifndef GPIO_IO
#define GPIO_IO

/* Standard Libraries */
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>

/* GPIO Library */
#include <gpiod.h>

/* I2C Libraries */
#include <linux/i2c-dev.h>
#include <sys/ioctl.h>
#include <fcntl.h>

/* Pin assignments (BCM numbering) */
#define WATER_LEVEL_PIN 26   /* Photoelectric water level sensor (frequency input) */
#define LIGHTS_PIN 17        /* 24V MOSFET for grow lights */
#define PUMP_PIN 22          /* Water pump MOSFET */
#define FAN1_PWM_PIN 12      /* Hardware PWM0 - Fan 1 */
#define FAN2_PWM_PIN 13      /* Hardware PWM1 - Fan 2 */
#define DATA_READ_INTERVAL 2 /* In seconds */
#define PCF8591_ADDR 0x48    /* Default 7-bit I2C address for PCF8591 */
#define BME680_ADDR 0x76     /* BME680 I2C address (or 0x77) */

/* GPIO function declarations */
int gpio_init(int pin);
int gpio_config_input(int pin);
int gpio_config_output(int pin);
int gpio_write(int value);
int gpio_read(void);
int gpio_cleanup(void);

/* Light control (24V MOSFET on GPIO17) */
int lights_init(void);
int lights_set(int on);

/* Pump control (MOSFET on GPIO22) */
int pump_init(void);
int pump_set(int on);

/* PWM fan control (GPIO12, GPIO13) - duty 0-100 percent */
int fans_init(void);
int fans_set_speed(int fan_id, int duty_percent);
int fans_set_both(int duty_percent);

/* Photoelectric water level - returns frequency (Hz), -1 on error. Low = low water */
int read_photoelectric_water_level(int *frequency_hz);

/* PCF8591 ADC */
int i2c_init(const char *i2c_bus);
int read_pcf8591_channel(int fd, int channel);

#endif

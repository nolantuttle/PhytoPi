#ifndef BME680_H
#define BME680_H

#include "../lib/BME68x_SensorAPI/bme68x.h"

/* BME680 sensor reading structure */
typedef struct {
    float temperature;   /* Celsius */
    float humidity;      /* Percent */
    float pressure;      /* hPa */
    float gas_resistance; /* kOhm */
    int valid;           /* 1 if all readings valid */
} bme680_data_t;

/* Initialize BME680 over i2c. Detects address (0x76 or 0x77) and configures sensor.
 * Returns 0 on success, -1 on failure. */
int bme680_init(void);

/* Read sensor data. Returns 0 on success, -1 on failure. */
int bme680_read(bme680_data_t *data);

/* Cleanup resources */
void bme680_cleanup(void);

#endif /* BME680_H */
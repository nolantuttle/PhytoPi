/**
 * BME680 driver for PhytoPi
 * Uses Bosch BME68x API over I2C (/dev/i2c-1)
 */
#include "../lib/bme680.h"

#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdint.h>
#include <linux/i2c-dev.h>
#include <sys/ioctl.h>

#define BME680_I2C_ADDR_76  0x76
#define BME680_I2C_ADDR_77  0x77

static int           i2c_fd         = -1;
static struct bme68x_dev bme_dev;
static int           bme_initialized = 0;

/* ── Bosch API I2C callbacks ── */

static BME68X_INTF_RET_TYPE bme68x_linux_i2c_read(
    uint8_t reg_addr, uint8_t *reg_data, uint32_t len, void *intf_ptr)
{
    int fd = *(int *)intf_ptr;
    if (fd < 0) return BME68X_E_COM_FAIL;
    if (write(fd, &reg_addr, 1) != 1)          return BME68X_E_COM_FAIL;
    if ((int)read(fd, reg_data, len) != (int)len) return BME68X_E_COM_FAIL;
    return BME68X_OK;
}

static BME68X_INTF_RET_TYPE bme68x_linux_i2c_write(
    uint8_t reg_addr, const uint8_t *reg_data, uint32_t len, void *intf_ptr)
{
    int fd = *(int *)intf_ptr;
    if (fd < 0) return BME68X_E_COM_FAIL;

    uint8_t buf[256];
    if (len + 1 > sizeof(buf)) return BME68X_E_INVALID_LENGTH;

    buf[0] = reg_addr;
    memcpy(&buf[1], reg_data, len);

    if ((int)write(fd, buf, len + 1) != (int)(len + 1)) return BME68X_E_COM_FAIL;
    return BME68X_OK;
}

static void bme68x_delay_us(uint32_t period, void *intf_ptr)
{
    (void)intf_ptr;
    usleep(period);
}

/* ── Public API ── */

int bme680_init(void)
{
    i2c_fd = open("/dev/i2c-1", O_RDWR);
    if (i2c_fd < 0)
    {
        fprintf(stderr, "BME680: Cannot open /dev/i2c-1 (errno=%d). "
                        "Check: i2c enabled, user in i2c group.\n", errno);
        return -1;
    }

    const uint8_t addrs[] = { BME680_I2C_ADDR_76, BME680_I2C_ADDR_77 };
    for (int a = 0; a < 2; a++)
    {
        if (ioctl(i2c_fd, I2C_SLAVE, addrs[a]) < 0)
        {
            fprintf(stderr, "BME680: I2C slave 0x%02x not responding\n", addrs[a]);
            continue;
        }

        memset(&bme_dev, 0, sizeof(bme_dev));
        bme_dev.intf     = BME68X_I2C_INTF;
        bme_dev.read     = bme68x_linux_i2c_read;
        bme_dev.write    = bme68x_linux_i2c_write;
        bme_dev.delay_us = bme68x_delay_us;
        bme_dev.intf_ptr = &i2c_fd;
        bme_dev.amb_temp = 25;

        if (bme68x_init(&bme_dev) != BME68X_OK)
        {
            fprintf(stderr, "BME680: Bosch API init failed at 0x%02x\n", addrs[a]);
            continue;
        }

        /* Configure once here — not on every read */
        struct bme68x_conf conf = {
            .filter = BME68X_FILTER_OFF,
            .odr    = BME68X_ODR_NONE,
            .os_hum = BME68X_OS_1X,
            .os_pres = BME68X_OS_1X,
            .os_temp = BME68X_OS_1X,
        };
        struct bme68x_heatr_conf heatr = {
            .enable    = BME68X_DISABLE,
            .heatr_temp = 300,
            .heatr_dur  = 100,
        };

        if (bme68x_set_conf(&conf, &bme_dev) != BME68X_OK ||
            bme68x_set_heatr_conf(BME68X_FORCED_MODE, &heatr, &bme_dev) != BME68X_OK)
        {
            fprintf(stderr, "BME680: Config failed at 0x%02x\n", addrs[a]);
            continue;
        }

        bme_initialized = 1;
        fprintf(stderr, "BME680: init OK (addr 0x%02x)\n", addrs[a]);
        return 0;
    }

    fprintf(stderr, "BME680: Init failed at 0x76 and 0x77. "
                    "Check wiring (SDA=GPIO2, SCL=GPIO3, VCC, GND).\n");
    close(i2c_fd);
    i2c_fd = -1;
    return -1;
}

int bme680_read(bme680_data_t *data)
{
    if (!data) return -1;
    memset(data, 0, sizeof(*data));

    if (!bme_initialized || i2c_fd < 0) return -1;

    struct bme68x_conf conf;
    if (bme68x_get_conf(&conf, &bme_dev) != BME68X_OK) return -1;

    if (bme68x_set_op_mode(BME68X_FORCED_MODE, &bme_dev) != BME68X_OK) return -1;

    uint32_t del_period = bme68x_get_meas_dur(BME68X_FORCED_MODE, &conf, &bme_dev);
    bme_dev.delay_us(del_period, bme_dev.intf_ptr);

    struct bme68x_data bme_data;
    uint8_t n_fields;
    if (bme68x_get_data(BME68X_FORCED_MODE, &bme_data, &n_fields, &bme_dev) != BME68X_OK)
        return -1;
    if (n_fields == 0) return -1;

#ifdef BME68X_USE_FPU
    data->temperature    = bme_data.temperature;
    data->humidity       = bme_data.humidity;
    data->pressure       = bme_data.pressure / 100.0f;       /* Pa → hPa */
    data->gas_resistance = bme_data.gas_resistance / 1000.0f; /* Ω → kΩ */
#else
    data->temperature    = (float)bme_data.temperature / 100.0f;
    data->humidity       = (float)bme_data.humidity / 1000.0f;
    data->pressure       = (float)bme_data.pressure / 100000.0f;
    data->gas_resistance = (float)bme_data.gas_resistance / 1000.0f;
#endif

    data->valid = 1;
    return 0;
}

void bme680_cleanup(void)
{
    if (i2c_fd >= 0)
    {
        close(i2c_fd);
        i2c_fd = -1;
    }
    bme_initialized = 0;
}
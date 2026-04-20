# PhytoPi GPIO Pin Map

## Pin Assignments (BCM Numbering)

| Function | GPIO | BCM | Notes |
|----------|------|-----|------|
| Lights (MOSFET) | 17 | 17 | 24V low-side switch |
| Pump (MOSFET) | 22 | 22 | 3V pump, low-side |
| Fan 1 PWM | 12 | 12 | Hardware PWM0, 25kHz |
| Fan 2 PWM | 13 | 13 | Hardware PWM1, 25kHz |
| Photoelectric water level | 26 | 26 | Frequency input (20–400 Hz) |

## I2C (SDA=GPIO2, SCL=GPIO3)

| Device | Address | Notes |
|--------|---------|-------|
| PCF8591 (ADC) | 0x4b | Ch0: soil, Ch1: light (legacy), Ch2: water (legacy) |
| BME680 | 0x76 or 0x77 | Temp, humidity, pressure, gas (SDO low→0x76, high→0x77) |

## Environment Variables

```
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_DEVICE_ID=
SUPABASE_TEMPERATURE_SENSOR_ID=
SUPABASE_HUMIDITY_SENSOR_ID=
SUPABASE_PRESSURE_SENSOR_ID=
SUPABASE_GAS_SENSOR_ID=
SUPABASE_SOIL_MOISTURE_SENSOR_ID=
SUPABASE_WATER_LEVEL_SENSOR_ID=
SUPABASE_WATER_LEVEL_PHOTOELECTRIC_SENSOR_ID=
SUPABASE_LIGHT_SENSOR_ID=
CAPTURE_SCRIPT_PATH=scripts/capture_and_upload.py  # optional
```

## PWM Setup (Raspberry Pi)

Add to `/boot/firmware/config.txt` (or `/boot/config.txt`):

```
dtoverlay=pwm-2chan,pin=12,func=4,pin2=13,func2=4
```

Then export channels 0 and 1 (done automatically by the controller).

## Safety

- All MOSFETs: low-side switching only. Do not connect load between GPIO and ground.
- Pump: ~100 mA @ 3V. Use appropriate MOSFET.
- Fans: 5V PWM via MOSFET; do not drive 5V directly from Pi.

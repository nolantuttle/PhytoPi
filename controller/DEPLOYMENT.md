# PhytoPi Controller – Deployment Notes

## Prerequisites (Raspberry Pi)

- Raspberry Pi OS (Bullseye or later)
- I2C enabled: `sudo raspi-config` → Interface Options → I2C → Enable
- PWM overlay for fans: add to `/boot/firmware/config.txt` (or `/boot/config.txt`):

  ```
  dtoverlay=pwm-2chan,pin=12,func=4,pin2=13,func2=4
  ```

- Build dependencies:
  - `libgpiod-dev`
  - `libcurl4-openssl-dev`
  - `libjson-c-dev`
  - `libsqlite3-dev`

  ```bash
  sudo apt install libgpiod-dev libcurl4-openssl-dev libjson-c-dev libsqlite3-dev
  ```

## Build

```bash
cd controller
make
```

## Environment Variables

Set before running the controller (e.g. in a systemd service or `.env`):

| Variable | Description |
|----------|-------------|
| `SUPABASE_URL` | Supabase project URL (e.g. `https://xxx.supabase.co`) |
| `SUPABASE_ANON_KEY` | Supabase anon key |
| `SUPABASE_DEVICE_ID` | UUID of this device in `device_units` |
| `SUPABASE_TEMPERATURE_SENSOR_ID` | UUID of temperature sensor |
| `SUPABASE_HUMIDITY_SENSOR_ID` | UUID of humidity sensor |
| `SUPABASE_PRESSURE_SENSOR_ID` | UUID of pressure sensor (BME680) |
| `SUPABASE_GAS_SENSOR_ID` | UUID of gas resistance sensor |
| `SUPABASE_SOIL_MOISTURE_SENSOR_ID` | UUID of soil moisture sensor |
| `SUPABASE_WATER_LEVEL_SENSOR_ID` | UUID of water level sensor (ADC) |
| `SUPABASE_WATER_LEVEL_PHOTOELECTRIC_SENSOR_ID` | UUID of photoelectric water sensor |
| `SUPABASE_LIGHT_SENSOR_ID` | UUID of light sensor |
| `CAPTURE_SCRIPT_PATH` | Optional: full path to `capture_and_upload.py` |

## Running as a Service

Example systemd unit (`/etc/systemd/system/phytopi-controller.service`):

```ini
[Unit]
Description=PhytoPi Controller
After=network.target

[Service]
Type=simple
WorkingDirectory=/home/pi/PhytoPi/controller
EnvironmentFile=/home/pi/PhytoPi/.env
ExecStart=/home/pi/PhytoPi/controller/phytopi_controller
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl enable phytopi-controller
sudo systemctl start phytopi-controller
sudo systemctl status phytopi-controller
```

## AI Worker (Home PC)

The AI worker runs on a separate machine (e.g. home PC) and processes `ai_capture_jobs`:

```bash
cd controller/scripts
pip install supabase
# Optional: pip install torch transformers  # for Moondream + Qwen2.5
export SUPABASE_URL=...
export SUPABASE_SERVICE_ROLE_KEY=...
python3 ai_worker.py
```

Run as a background service or in a screen/tmux session.

## Image Capture Script

`capture_and_upload.py` captures a still image and uploads to Supabase Storage. Requires:

- `libcamera-still` (Raspberry Pi camera stack)
- `python3`, `supabase`, `python-dotenv`

Set `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_DEVICE_ID` when run by the controller (or via env file).

## GPIO Pin Map

See [GPIO_PIN_MAP.md](GPIO_PIN_MAP.md) for pin assignments and safety notes.

# PhytoPi Clone Procedure

Clone your PhytoPi setup to a second Raspberry Pi with identical configuration and services.

## Prerequisites

- First Pi running with working PhytoPi controller and stream
- Second Pi with Raspberry Pi OS (Bullseye or Bookworm)
- Same network for both devices

## Quick Clone (from development machine)

```bash
cd controller
make
./scripts/clone_pi.sh
# Copy the generated .tar.gz to the second Pi
```

## Full Procedure

### 1. Export from Source Pi (or dev machine)

```bash
cd /path/to/PhytoPi/controller
make
./scripts/clone_pi.sh ~/phytopi_clone
```

This creates `~/phytopi_clone/phytopi_clone_YYYYMMDD_HHMMSS.tar.gz`.

### 2. Transfer to Second Pi

```bash
scp ~/phytopi_clone/phytopi_clone_*.tar.gz pi@<second-pi-ip>:~/
```

### 3. On Second Pi: Extract and Install

```bash
tar xzvf phytopi_clone_*.tar.gz
cd phytopi_clone_*/
# Follow INSTALL.md in the bundle
sudo mkdir -p /opt/phytopi
sudo cp -r bin scripts systemd /opt/phytopi/
sudo cp env.template /etc/phytopi/env
sudo nano /etc/phytopi/env  # Fill in Supabase URL, keys, NEW device ID
```

**Important:** For the second Pi, you must either:
- Claim a new device in Supabase (new device_id, new sensor IDs), or
- Use the same device_id if this is a replacement unit

### 4. Install Dependencies

```bash
sudo apt update
sudo apt install -y libgpiod-dev libsqlite3-dev libcurl4-openssl-dev libjson-c-dev
# For camera stream:
sudo apt install -y python3 ffmpeg
# For Pi camera: libcamera-apps (or rpicam-apps on Bookworm)
```

### 5. Enable Services

```bash
sudo cp /opt/phytopi/systemd/phytopi-controller.service /etc/systemd/system/
sudo cp /opt/phytopi/systemd/phytopi-stream.service /etc/systemd/system/
# Edit paths in .service files if not using /opt/phytopi
sudo systemctl daemon-reload
sudo systemctl enable phytopi-controller phytopi-stream
sudo systemctl start phytopi-controller phytopi-stream
```

### 6. Verify

```bash
sudo systemctl status phytopi-controller phytopi-stream
curl -I http://localhost:8000/stream.mjpg
```

## Services

| Service | Description |
|---------|-------------|
| phytopi-controller | Sensor collection, Supabase sync, commands, thresholds, schedules |
| phytopi-stream | MJPEG camera stream on port 8000 |

## Troubleshooting

- **Controller fails:** Check `/etc/phytopi/env` has correct SUPABASE_* vars
- **Stream fails:** Ensure camera is connected; run `python3 scripts/stream_camera_web.py` manually to see errors
- **No sensors:** Verify I2C/GPIO enabled: `sudo raspi-config` → Interface Options

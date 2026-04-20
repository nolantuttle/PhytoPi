## PhytoPi Raspberry Pi Docker Deployment

### 1. Overview

- **Host OS**: Raspberry Pi OS Lite.
- **Services (containers)**:
  - `sensors`: compiled C controller from `controller` (GPIO/I²C, Supabase sync).
  - `camera`: MJPEG streaming server (`stream_camera_web.py`).
  - `ai`: AI worker (`ai_worker.py`) – optional on the Pi; can also run on a more powerful machine.
  - `ui`: static web UI from `user_interface/web/index.html`.
  - `updater`: small Alpine-based container that periodically runs `docker compose pull` and `up` on the Pi.

All project logic lives inside these containers; the host OS just runs Docker and systemd units.

---

### 2. Prepare Raspberry Pi OS

On a fresh Raspberry Pi OS Lite image:

```bash
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-plugin chromium-browser

sudo usermod -aG docker pi
```

Reboot once so group membership takes effect.

---

### 3. Copy PhytoPi stack to the Pi

On your dev machine:

```bash
rsync -avz ./PhytoPi/ pi@raspberrypi:/opt/phyto
```

On the Pi:

```bash
cd /opt/phyto
docker compose -f docker-compose.rpi.yml build
```

You can also push images to a registry and change services to use `image:` instead of local `build:` sections if desired.

---

### 4. Environment configuration

Create `/opt/phyto/.env` on the Pi with at least:

```bash
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
SUPABASE_SERVICE_ROLE_KEY=...
SUPABASE_DEVICE_ID=DEVICE_UUID

SUPABASE_HUMIDITY_SENSOR_ID=...
SUPABASE_TEMPERATURE_SENSOR_ID=...
SUPABASE_SOIL_MOISTURE_SENSOR_ID=...
SUPABASE_WATER_LEVEL_SENSOR_ID=...
SUPABASE_LIGHT_SENSOR_ID=...
SUPABASE_PRESSURE_SENSOR_ID=...
SUPABASE_GAS_SENSOR_ID=...
SUPABASE_WATER_LEVEL_PHOTOELECTRIC_SENSOR_ID=...
```

Docker Compose automatically loads this `.env` file.

---

### 5. Enable systemd units

Copy the provided units into systemd’s directory:

```bash
sudo cp /opt/phyto/systemd/docker-compose-phytopi.service /etc/systemd/system/
sudo cp /opt/phyto/systemd/phytopi-kiosk.service /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable docker-compose-phytopi.service
sudo systemctl enable phytopi-kiosk.service
sudo systemctl start docker-compose-phytopi.service
sudo systemctl start phytopi-kiosk.service
```

This will:

- Start the full Docker stack (`sensors`, `camera`, `ui`, `ai`, `updater`) at boot.
- Launch Chromium in kiosk mode pointing at `http://localhost:8080` once the stack and graphical session are up.

---

### 6. Updater behaviour

- Container: `updater` (built from `docker/updater/Dockerfile`).
- Mounts the Docker socket and `/opt/phyto` read-only.
- Every `UPDATE_INTERVAL_SECONDS` (default 600 seconds) it runs:

```bash
docker compose -p phytopi -f /opt/phyto/docker-compose.rpi.yml pull
docker compose -p phytopi -f /opt/phyto/docker-compose.rpi.yml up -d --remove-orphans
```

#### Registry authentication

- Recommended: log in once on the Pi:

```bash
docker login ghcr.io   # or docker.io, etc.
```

Docker will store credentials under `/root/.docker/config.json`, and the updater reuses them via the socket.

If you need to pass explicit credentials, you can extend the updater image to read `REGISTRY_USERNAME` / `REGISTRY_PASSWORD` and run `docker login` before pulling.

---

### 7. Manual control & troubleshooting

Bring the stack up/down manually:

```bash
cd /opt/phyto
docker compose -f docker-compose.rpi.yml up -d
docker compose -f docker-compose.rpi.yml logs -f sensors
docker compose -f docker-compose.rpi.yml ps
```

Check systemd status:

```bash
sudo systemctl status docker-compose-phytopi.service
sudo systemctl status phytopi-kiosk.service
```

If you change the compose file or units, re-run:

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker-compose-phytopi.service
```


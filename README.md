# PhytoPi

PhytoPi is an intelligent IoT-based controlled environment system for autonomous plant cultivation. Built on a Raspberry Pi 5 embedded controller, a Flutter kiosk dashboard, and a Supabase cloud backend, the system automates lighting, watering, and climate regulation with minimal human intervention. A live camera feed drives a two-stage machine learning pipeline for continuous AI-powered plant health analysis and growth monitoring.

---

## Quick Reference — Pi Commands

### Docker stack

```bash
# Start all services (project name matches systemd: phytopi)
cd /home/phytopi/PhytoPi
docker compose -p phytopi -f docker-compose.rpi.yml up -d

# Stop all services
docker compose -p phytopi -f docker-compose.rpi.yml down

# Restart a single service  (sensors | camera | ai | updater)
docker compose -p phytopi -f docker-compose.rpi.yml restart sensors

# View status of all containers
docker compose -p phytopi -f docker-compose.rpi.yml ps

# Live logs (line-buffered, real-time)
docker logs phytopi-sensors -f
docker logs phytopi-camera  -f
docker logs phytopi-ai      -f

# Resource usage
docker stats
```

### Kiosk UI (Flutter — runs natively via systemd)

```bash
sudo systemctl start   phytopi-ui.service
sudo systemctl stop    phytopi-ui.service
sudo systemctl restart phytopi-ui.service
sudo systemctl status  phytopi-ui.service

# Rebuild the Flutter bundle (load env first — see "Rebuilding the system")
cd /home/phytopi/PhytoPi/User_Interface
set -a && source /home/phytopi/PhytoPi/User_Interface/.env.kiosk && set +a
/home/phytopi/flutter/bin/flutter pub get
/home/phytopi/flutter/bin/flutter build linux --release \
  --dart-define=KIOSK_MODE=true \
  --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}"
sudo systemctl restart phytopi-ui.service
```

### Boot persistence (run once on first setup)

```bash
# Auto-start Docker stack on boot
sudo ln -s /home/phytopi/PhytoPi /opt/phyto
sudo cp systemd/docker-compose-phytopi.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now docker-compose-phytopi.service

# Auto-start kiosk UI on boot
sudo cp systemd/phytopi-ui.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now phytopi-ui.service
```

### Manual update (normally done automatically by CI)

```bash
cd /home/phytopi/PhytoPi
bash scripts/update.sh
```

### Rebuild a service after Dockerfile changes

```bash
docker compose -p phytopi -f docker-compose.rpi.yml build --no-cache sensors
docker compose -p phytopi -f docker-compose.rpi.yml up -d sensors
```

---

## Rebuilding the system after modifications

Use the row that matches what you changed. For a **full release** (database + firmware + UI), follow **A → B → C** in order so tables and APIs exist before the Pi firmware and Flutter app call them.

| You changed | Rebuild / deploy |
|-------------|------------------|
| SQL under `data/supabase/migrations/`, or Edge Functions under `data/supabase/functions/` | **A. Supabase** (`db push`, deploy functions, secrets, webhooks) |
| C sources or Dockerfiles under `PhytoPI_Controler/` (sensors container) | **B. Docker** — `sensors` service |
| `Dockerfile.camera` or camera scripts in `PhytoPI_Controler/` | **B. Docker** — `camera` service |
| `docker/updater/` or updater compose service | **B. Docker** — `updater` service |
| Flutter under `User_Interface/` | **C. Flutter kiosk** |

The systemd unit [`systemd/docker-compose-phytopi.service`](systemd/docker-compose-phytopi.service) uses **`COMPOSE_PROJECT_NAME=phytopi`**, so use **`-p phytopi`** with `docker compose` to match running containers.

### A. Supabase (remote project)

From the directory that contains the `supabase/` folder ([`data/supabase/`](data/supabase)):

```bash
cd /home/phytopi/PhytoPi/data
```

**One-time link** (needs your [project ref](https://supabase.com/dashboard/project/_/settings/general) and database password):

```bash
supabase link --project-ref YOUR_PROJECT_REF
```

**Apply new migrations** to the linked remote database:

```bash
supabase db push
```

**Edge Functions** (when `data/supabase/functions/<name>/` changed). Example for `notify-alert`:

```bash
supabase functions deploy notify-alert --no-verify-jwt --project-ref YOUR_PROJECT_REF
```

**Secrets** the functions expect (set in the dashboard or via CLI; names depend on your functions):

```bash
supabase secrets set KEY=value --project-ref YOUR_PROJECT_REF
```

**Database webhooks** (e.g. calling an Edge Function on `INSERT` into `alerts`) are configured in the Supabase Dashboard, not via migrations—see comments in the relevant migration SQL.

**Local Supabase** (optional dev): `supabase start` from `data/` runs Docker services for that project. `supabase status` only applies when that local stack is running; it is **not** required for `db push` / `functions deploy` to a hosted project.

### B. Raspberry Pi Docker stack

From the repo root, with `.env` present (Supabase URL, keys, device and sensor UUIDs—see project root `.env`):

```bash
cd /home/phytopi/PhytoPi

# Sensors / controller (after PhytoPI_Controler or Dockerfile.sensors changes)
docker compose -p phytopi -f docker-compose.rpi.yml build sensors
docker compose -p phytopi -f docker-compose.rpi.yml up -d sensors

# Camera stream (after camera Dockerfile or scripts change)
docker compose -p phytopi -f docker-compose.rpi.yml build camera
docker compose -p phytopi -f docker-compose.rpi.yml up -d camera

# Updater image
docker compose -p phytopi -f docker-compose.rpi.yml build updater
docker compose -p phytopi -f docker-compose.rpi.yml up -d updater
```

**Logs:** `docker logs phytopi-sensors -f` (and similarly for `phytopi-camera`, `phytopi-updater`).

**Note:** The `ui` service in `docker-compose.rpi.yml` is under `profiles: [disabled]`; the kiosk runs **natively** via `phytopi-ui.service`, not this container.

### C. Flutter kiosk UI (Linux on the Pi)

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `KIOSK_MODE` are baked in at **compile time** (`--dart-define`). Optional: `PHYTOPI_STREAM_URL` for the camera MJPEG URL (default in code is `http://phytopi.local:8000/stream.mjpg`).

```bash
set -a && source /home/phytopi/PhytoPi/User_Interface/.env.kiosk && set +a
cd /home/phytopi/PhytoPi/User_Interface
/home/phytopi/flutter/bin/flutter pub get
/home/phytopi/flutter/bin/flutter build linux --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=KIOSK_MODE=true
sudo systemctl restart phytopi-ui.service
```

### Automated pull-based update (optional)

After `git pull`, this script rebuilds the Linux UI when `User_Interface/**` changed and rebuilds Docker services when controller/camera/updater paths changed:

```bash
cd /home/phytopi/PhytoPi
bash scripts/update.sh
```

It does **not** run `supabase db push` or deploy Edge Functions—you still do **A** when the remote database or functions change.

---

## Project Structure

```
PhytoPi/
├── User_Interface/          # Flutter Dashboard (Web, Mobile, Kiosk)
├── PhytoPI_Controler/       # Raspberry Pi controller sources (Docker build context for Pi stack)
├── controller/              # Same controller tree tracked in git (keep in sync with PhytoPI_Controler when developing)
├── data/supabase/           # Supabase config, migrations, Edge Functions
└── systemd/                 # Boot units for Docker stack + native kiosk UI
```

## Components

### User Interface (Flutter Dashboard)
A cross-platform Flutter application that provides:
- Real-time sensor data visualization
- Interactive charts and analytics
- Device management and monitoring
- Camera streaming for visual plant observation
- AI-powered health insights
- Responsive design for web, mobile, and kiosk deployments

### Raspberry Pi Controller
Embedded C application running on Raspberry Pi that:
- Interfaces with sensors via GPIO
- Collects environmental data (temperature, humidity, soil moisture, water level)
- Stores data locally in SQLite
- Syncs data to Supabase backend
- Manages camera streaming for remote monitoring

### Data Infrastructure (Supabase)
PostgreSQL-based backend that provides:
- Secure data storage and management
- Real-time data synchronization
- User authentication and authorization
- Device onboarding and management
- Row-level security policies

## Quick Start

### Prerequisites

- **For Dashboard**: Flutter SDK (3.12.0 or higher), Dart SDK (3.0.0 or higher)
- **For Controller**: Raspberry Pi with libgpiod, SQLite, curl, and json-c libraries
- **For Infrastructure**: Docker and Supabase CLI (for local development)

### Dashboard Setup

1. **Navigate to the User Interface directory:**
   ```bash
   cd User_Interface
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure environment variables:**
   ```bash
   ./scripts/utils/setup_env.sh web
   ```
   See `User_Interface/docs/configuration/ENV_SETUP.md` for detailed configuration.

4. **Run the development server:**
   ```bash
   ./scripts/dev/run_local.sh
   ```
   Or manually:
   ```bash
   flutter run -d chrome --web-port 3000
   ```

### Infrastructure Setup (Supabase)

1. **Navigate to the Supabase project directory:**
   ```bash
   cd data
   ```

2. **Start Supabase locally** (optional):
   ```bash
   supabase start
   ```

3. **Apply migrations** (local reset, destructive):
   ```bash
   supabase db reset
   ```

For hosted projects, use `supabase link` and `supabase db push` as described in **Rebuilding the system after modifications**. Additional docs live under `data/supabase/`.

### Raspberry Pi Controller Setup

The controller runs as a Docker container (`phytopi-sensors`). It is built automatically inside the container using Ubuntu 24.04 + libgpiod 2.x compiled from source — no manual dependency installation is needed on the host.

1. **Copy `.env` to the project root** with your Supabase credentials and device/sensor IDs (see `.env` for the full list of required variables).

2. **Start the stack** (see Quick Reference above).

For detailed controller setup, see `PhytoPI_Controler/README.md`.

## Features

- **Real-time Monitoring**: Track temperature, humidity, soil moisture, and water levels with live updates
- **Data Visualization**: Interactive charts and graphs for historical data analysis
- **Smart Alerts**: Automated notifications for plant health conditions and system status
- **AI Insights**: Machine learning-powered growth predictions and health assessments
- **Multi-Platform Support**: Web dashboard, mobile apps (iOS/Android), and kiosk mode for Raspberry Pi
- **Camera Streaming**: Live video feed from connected camera for visual plant monitoring
- **Secure Authentication**: User management with role-based access control
- **Device Management**: Easy onboarding and configuration of multiple PhytoPi devices

## Documentation

Comprehensive documentation is available in each component directory:

- **User Interface**: See `User_Interface/docs/` for platform guides, deployment instructions, and configuration
- **Controller**: See `PhytoPI_Controler/README.md` and `PhytoPI_Controler/TESTING_GUIDE.md`
- **Infrastructure**: See `data/supabase/` for database schema, migrations, Edge Functions, and setup guides

## Development

This project is actively being developed. Key areas of focus include:

- Enhanced sensor accuracy and calibration
- Advanced AI/ML models for plant health prediction
- Improved user experience and interface design
- Expanded device compatibility
- Performance optimizations

## License

See the [LICENSE](LICENSE) file for details.

## Contributing

This is a group project. For contributions, please coordinate with the project team.

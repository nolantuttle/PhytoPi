#!/bin/bash
# PhytoPi Clone Script - Export config from current Pi for cloning to a second SD card
# Usage: ./clone_pi.sh [output_dir]
# Creates a tarball with binaries, scripts, and env template.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="${1:-$PROJECT_ROOT/clone_bundle}"
BUNDLE_NAME="phytopi_clone_$(date +%Y%m%d_%H%M%S)"

echo "PhytoPi Clone - Exporting configuration"
echo "Project root: $PROJECT_ROOT"
echo "Output: $OUTPUT_DIR/$BUNDLE_NAME"

mkdir -p "$OUTPUT_DIR/$BUNDLE_NAME"
cd "$PROJECT_ROOT"

# Copy binaries
mkdir -p "$OUTPUT_DIR/$BUNDLE_NAME/bin"
[ -f bin/phytopi ] && cp bin/phytopi "$OUTPUT_DIR/$BUNDLE_NAME/bin/" || echo "Warning: bin/phytopi not found (run make first)"

# Copy scripts
mkdir -p "$OUTPUT_DIR/$BUNDLE_NAME/scripts"
cp scripts/stream_camera_web.py "$OUTPUT_DIR/$BUNDLE_NAME/scripts/" 2>/dev/null || true
cp scripts/capture_and_upload.py "$OUTPUT_DIR/$BUNDLE_NAME/scripts/" 2>/dev/null || true

# Copy systemd units
mkdir -p "$OUTPUT_DIR/$BUNDLE_NAME/systemd"
cp systemd/*.service "$OUTPUT_DIR/$BUNDLE_NAME/systemd/" 2>/dev/null || true

# Create env template (do not copy actual secrets)
cat > "$OUTPUT_DIR/$BUNDLE_NAME/env.template" << 'EOF'
# PhytoPi Environment - Copy to /etc/phytopi/env and fill in values
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_DEVICE_ID=your-device-uuid
SUPABASE_HUMIDITY_SENSOR_ID=
SUPABASE_TEMPERATURE_SENSOR_ID=
SUPABASE_PRESSURE_SENSOR_ID=
SUPABASE_GAS_SENSOR_ID=
SUPABASE_WATER_LEVEL_PHOTOELECTRIC_SENSOR_ID=
EOF

# Create install instructions
cat > "$OUTPUT_DIR/$BUNDLE_NAME/INSTALL.md" << 'EOF'
# PhytoPi Clone - Install on Second Pi

## 1. Prepare SD Card
- Flash Raspberry Pi OS (Bullseye or Bookworm) to a new SD card
- Boot the Pi, complete initial setup

## 2. Copy Bundle
- Copy this folder to the Pi: `/opt/phytopi`
- `sudo mkdir -p /opt/phytopi && sudo cp -r . /opt/phytopi/`

## 3. Configure Environment
- `sudo cp env.template /etc/phytopi/env`
- Edit `/etc/phytopi/env` with your Supabase URL, keys, device ID, sensor IDs

## 4. Install Dependencies
```bash
sudo apt install -y libgpiod-dev libsqlite3-dev libcurl4-openssl-dev libjson-c-dev python3 python3-pip
pip3 install --user supabase  # if capture script needs it
```

## 5. Install Systemd Services
```bash
sudo cp /opt/phytopi/systemd/*.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable phytopi-controller phytopi-stream
sudo systemctl start phytopi-controller phytopi-stream
```

## 6. Verify
- `sudo systemctl status phytopi-controller phytopi-stream`
- Stream: http://<pi-ip>:8000/stream.mjpg
EOF

# Create tarball
cd "$OUTPUT_DIR"
tar czvf "${BUNDLE_NAME}.tar.gz" "$BUNDLE_NAME"
echo ""
echo "Done. Bundle: $OUTPUT_DIR/${BUNDLE_NAME}.tar.gz"
echo "Copy to second Pi and follow INSTALL.md"

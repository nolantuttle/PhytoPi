# PhytoPi
This project is an IoT-based controlled environment system that enables plants to grow through their entire life cycle with minimal human intervention through use of embedded hardware and software solutions.

## Dependencies

- `libgpiod` - GPIO interface library
- `libsqlite3` - SQLite database
- `libcurl` - HTTP client library (for Supabase sync)
- `libjson-c` - JSON parsing library (for Supabase sync)

Install on Arch Linux:
```bash
sudo pacman -S libgpiod sqlite curl json-c
```

## Execution

Run 'make clean' first for a fresh compilation.
Run 'make' to build all the files required for execution.
Run 'sudo ./bin/phytopi' to run the generated executable.

## Supabase Integration

The application supports batch syncing sensor data to Supabase. Data is stored locally in SQLite first, then periodically synced to Supabase in batches.

### Configuration

Set the following environment variables to enable Supabase sync:

```bash
export SUPABASE_URL="http://127.0.0.1:54321"  # or your remote Supabase URL
export SUPABASE_ANON_KEY="your-anon-key-here"
export SUPABASE_DEVICE_ID="your-device-uuid"  # Optional
export SUPABASE_HUMIDITY_SENSOR_ID="sensor-uuid"
export SUPABASE_TEMPERATURE_SENSOR_ID="sensor-uuid"
export SUPABASE_SOIL_MOISTURE_SENSOR_ID="sensor-uuid"
export SUPABASE_WATER_LEVEL_SENSOR_ID="sensor-uuid"
```

### Setup Steps

1. **Create device and sensors in Supabase:**
   - Insert a device record in the `devices` table
   - Insert sensor records in the `sensors` table for each sensor type (humidity, temperature, soil_moisture, water_level)
   - Note the UUIDs for each sensor

2. **Set environment variables** with the sensor UUIDs

3. **Run the application** - it will automatically sync data every 60 seconds

### Local Storage

Data is always stored locally in `sensor_data.db` (SQLite) first, ensuring data persistence even if Supabase is unavailable. The sync process marks records as synced after successful upload, so failed syncs will be retried on the next sync cycle.

## Camera Streaming

To visualize the camera input (Arducam 5MP/OV5647) from a remote computer:

1. **Enable the camera interface** on the Pi (usually enabled by default on modern OS with `camera_auto_detect=1` in `/boot/config.txt`).
2. **Run the streaming script**:
   ```bash
   ./scripts/stream_camera.sh
   ```
3. **View the stream on your computer** using VLC Media Player:
   - Open VLC
   - Go to **Media** -> **Open Network Stream**
   - Enter `tcp/h264://<PI_IP>:8888` (replace `<PI_IP>` with your Pi's IP address)

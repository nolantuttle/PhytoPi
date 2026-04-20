# Testing PhytoPi Controller on Raspberry Pi with Local Supabase

This guide walks you through testing the pi-controller on your Raspberry Pi with Supabase running locally on your PC.

## Prerequisites

### On Your PC:
- Docker installed and running
- Supabase CLI installed
- Network connectivity between PC and Raspberry Pi (same network)

### On Your Raspberry Pi:
- Raspberry Pi OS (or compatible Linux distribution)
- Root/sudo access
- Network connectivity to your PC

---

## Step 1: Start Supabase Locally on Your PC

1. **Navigate to the Supabase directory:**
   ```bash
   cd /home/danielg/Documents/PhytoPi/infra/supabase
   ```

2. **Start Supabase:**
   ```bash
   supabase start
   ```

   This will take a few minutes the first time (downloads Docker images ~2GB).

3. **Note the connection details** from the output. You'll see something like:
   ```
   API URL: http://127.0.0.1:54321
   anon key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ```

4. **Find your PC's local IP address** (needed for Pi to connect):
   ```bash
   # On Linux/Mac:
   ip addr show | grep "inet " | grep -v 127.0.0.1
   
   # Or use:
   hostname -I
   ```
   
   Example output: `192.168.1.100` (this is your PC's IP on the local network)

---

## Step 2: Configure Supabase to Accept Connections from Pi

By default, Supabase runs on `127.0.0.1` which only accepts local connections. You need to make it accessible from your Pi.

### Option A: Use Your PC's Local IP (Recommended)

1. **Check your Supabase config:**
   ```bash
   cat /home/danielg/Documents/PhytoPi/infra/supabase/config.toml
   ```

2. **If needed, modify the API URL** to bind to all interfaces. The API should already be accessible, but verify:
   - The API URL in the output should be accessible from your Pi
   - If not, you may need to configure your firewall

3. **Allow firewall access** (if firewall is enabled):

   **Step 3a: Check if firewall is enabled**
   ```bash
   # Check if ufw is active:
   sudo ufw status
   
   # OR check if firewalld is active:
   sudo systemctl status firewalld
   ```
   
   If the firewall is not active, you can skip the rest of this step. If it is active, continue below.

   **Step 3b: Determine which firewall you're using**
   
   - If you see output from `ufw status`, you're using **ufw** (Uncomplicated Firewall)
   - If you see output from `firewalld status`, you're using **firewalld**
   - If both show as inactive/not running, you may not have a firewall enabled

   **Step 3c: Configure ufw (if using ufw)**
   ```bash
   # Step 1: Allow port 54321 for TCP connections
   sudo ufw allow 54321/tcp
   
   # Step 2: Verify the rule was added
   sudo ufw status
   # You should see a line like: "54321/tcp    ALLOW    Anywhere"
   
   # Step 3: If ufw was inactive, enable it (optional)
   # sudo ufw enable
   ```
   
   **Step 3d: Configure firewalld (if using firewalld)**
   ```bash
   # Step 1: Add port 54321 to the firewall permanently
   sudo firewall-cmd --add-port=54321/tcp --permanent
   
   # Step 2: Reload the firewall to apply changes
   sudo firewall-cmd --reload
   
   # Step 3: Verify the port was added
   sudo firewall-cmd --list-ports
   # You should see "54321/tcp" in the list
   
   # Step 4: Verify the port is open in the current runtime (optional check)
   sudo firewall-cmd --query-port=54321/tcp
   # Should output: "yes"
   ```

   **Step 3e: Test the firewall configuration**
   ```bash
   # From your Pi (or another device on the network), test connectivity:
   curl -v http://YOUR_PC_IP:54321/rest/v1/
   
   # If you get a response (even an error), the firewall is configured correctly
   # If you get "Connection refused" or timeout, check:
   # - Firewall rules are correct
   # - Supabase is still running on your PC
   # - Your PC's IP address is correct
   ```

### Option B: Use SSH Tunneling (Alternative)

If you can't expose the port directly, you can use SSH tunneling from your Pi:
```bash
# On your Pi, create an SSH tunnel:
ssh -L 54321:127.0.0.1:54321 your-username@your-pc-ip
```

Then use `http://127.0.0.1:54321` on the Pi.

---

## Step 3: Create Device and Sensors in Supabase

You need to create a device record and sensor records in Supabase before the Pi can send data.

### Option A: Using Supabase Studio (Easiest)

1. **Open Supabase Studio** in your browser:
   ```
   http://127.0.0.1:54323
   ```

2. **Navigate to Table Editor** → `device_units` table

3. **Create a device:**
   - Click "Insert row"
   - Fill in:
     - `name`: "Test Pi Device" (or any name)
     - `type`: "phyto_pi"
     - `location`: "test_location" (optional)
     - `status`: "active"
     - `provisioned`: `true` (check the box)
   - Click "Save"
   - **Copy the `id` (UUID)** - you'll need this for `SUPABASE_DEVICE_ID`

4. **Navigate to `sensors` table**

5. **Create sensors** (one for each sensor type):
   
   For **Humidity Sensor:**
   - Click "Insert row"
   - `device_id`: Select the device you just created
   - `type_id`: You need to find the sensor type ID first
     - Go to `sensor_types` table
     - Find the row with `key` = "humidity" (or create it if missing)
     - Copy its `id` (UUID)
   - `label`: "Humidity Sensor"
   - Click "Save"
   - **Copy the `id` (UUID)** - this is `SUPABASE_HUMIDITY_SENSOR_ID`

   Repeat for:
   - **Temperature Sensor**: Find `type_id` with `key` = "temp_c" (or similar)
   - **Soil Moisture Sensor**: Find `type_id` with `key` = "soil_moisture"
   - **Water Level Sensor**: Find `type_id` with `key` = "water_level" (or create a boolean type)

### Option B: Using SQL (Faster)

1. **Open Supabase Studio** → SQL Editor

2. **Run this SQL** (adjust names/IDs as needed):

```sql
-- First, ensure sensor types exist
INSERT INTO sensor_types (key, name, unit, description)
VALUES 
  ('humidity', 'Humidity', 'RH%', 'Relative humidity sensor'),
  ('temp_c', 'Temperature', '°C', 'Temperature sensor in Celsius'),
  ('soil_moisture', 'Soil Moisture', '%', 'Soil moisture sensor'),
  ('water_level', 'Water Level', 'boolean', 'Water level sensor')
ON CONFLICT (key) DO NOTHING;

-- Create a device (replace with your values)
INSERT INTO device_units (name, type, location, status, provisioned)
VALUES ('Test Pi Device', 'phyto_pi', 'test_location', 'active', true)
RETURNING id;

-- Note the device_id from above, then create sensors
-- Replace <DEVICE_ID> with the UUID from above
INSERT INTO sensors (device_id, type_id, label)
SELECT 
  '<DEVICE_ID>'::uuid,
  st.id,
  CASE st.key
    WHEN 'humidity' THEN 'Humidity Sensor'
    WHEN 'temp_c' THEN 'Temperature Sensor'
    WHEN 'soil_moisture' THEN 'Soil Moisture Sensor'
    WHEN 'water_level' THEN 'Water Level Sensor'
  END
FROM sensor_types st
WHERE st.key IN ('humidity', 'temp_c', 'soil_moisture', 'water_level')
RETURNING id, label;

-- This will return all 4 sensor IDs - copy them!
```

3. **Copy all the UUIDs** from the output:
   - Device ID
   - Humidity Sensor ID
   - Temperature Sensor ID
   - Soil Moisture Sensor ID
   - Water Level Sensor ID

---

## Step 3.5: Schema Compatibility Note (IMPORTANT)

**⚠️ Schema Mismatch:** The current pi-controller code sends data with these fields:
- `sensor_id` ✅ (matches)
- `value` ✅ (matches)
- `unit` ❌ (new schema doesn't have this - unit is in `sensor_types` table)
- `timestamp` ❌ (new schema uses `ts` instead)

**The pi-controller code needs to be updated** to match the new schema. For now, you have two options:

### Option A: Update pi-controller Code (Recommended)

Update `src/supabase.c` to send:
- `ts` instead of `timestamp`
- Remove `unit` field (it's stored in `sensor_types` table)

### Option B: Use Legacy Schema (Quick Test)

If you want to test without code changes, you can temporarily use the old schema by not running the new sensor schema migration. However, this is not recommended for production.

**For this guide, we'll assume you'll update the code or use a workaround.**

### Quick SQL Workaround (Temporary)

If you want to test immediately without code changes, you can temporarily add the missing columns to the readings table:

```sql
-- Add timestamp column (as alias to ts)
ALTER TABLE public.readings ADD COLUMN IF NOT EXISTS timestamp timestamptz;
UPDATE public.readings SET timestamp = ts WHERE timestamp IS NULL;
CREATE INDEX IF NOT EXISTS idx_readings_timestamp ON public.readings(timestamp);

-- Add unit column (for compatibility, though it's redundant with sensor_types)
ALTER TABLE public.readings ADD COLUMN IF NOT EXISTS unit text;

-- Create a trigger to keep timestamp in sync with ts
CREATE OR REPLACE FUNCTION sync_timestamp_columns()
RETURNS TRIGGER AS $$
BEGIN
  NEW.timestamp = NEW.ts;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS sync_timestamp_trigger ON public.readings;
CREATE TRIGGER sync_timestamp_trigger
  BEFORE INSERT OR UPDATE ON public.readings
  FOR EACH ROW
  EXECUTE FUNCTION sync_timestamp_columns();
```

**Note:** This is a temporary workaround. You should update the pi-controller code to use `ts` instead of `timestamp` and remove the `unit` field.

---

## Step 3.6: Configure RLS Policy for Testing (IMPORTANT)

**⚠️ Important:** The current Supabase schema only allows the **service role** to insert readings, not the anon key. For testing purposes, you need to temporarily allow anon inserts.

### Option A: Add Temporary RLS Policy (Recommended for Testing)

1. **Open Supabase Studio** → SQL Editor

2. **Run this SQL** to allow anon key to insert readings (for testing only):

```sql
-- Allow anon key to insert readings (FOR TESTING ONLY)
CREATE POLICY "Allow anon inserts for testing" ON public.readings
  FOR INSERT
  WITH CHECK (true);
```

3. **Verify the policy was created:**
```sql
SELECT * FROM pg_policies WHERE tablename = 'readings';
```

**⚠️ Security Note:** This policy allows anyone with the anon key to insert readings. This is fine for local testing, but **DO NOT** use this in production. Remove this policy before deploying to production.

### Option B: Use Service Role Key (Alternative)

If you prefer not to modify RLS policies, you can use the service role key instead:

1. **Get the service role key** from Supabase:
   ```bash
   cd /home/danielg/Documents/PhytoPi/infra/supabase
   supabase status
   ```
   Look for `service_role key` in the output.

2. **Use service role key** in your Pi's environment variables:
   ```bash
   export SUPABASE_ANON_KEY="<service-role-key-here>"
   ```

**⚠️ Security Warning:** The service role key bypasses all RLS policies and has full database access. Only use this for local testing, and never commit it to version control.

### Option C: Remove Policy After Testing

When you're done testing, remove the temporary policy:

```sql
-- Remove the testing policy
DROP POLICY IF EXISTS "Allow anon inserts for testing" ON public.readings;
```

---

## Step 4: Get Supabase Connection Details

From Step 1, you should have:
- **API URL**: `http://YOUR_PC_IP:54321` (replace YOUR_PC_IP with your PC's local IP, e.g., `http://192.168.1.100:54321`)
- **anon key**: The long JWT token from the `supabase start` output

If you need to see them again:
```bash
cd /home/danielg/Documents/PhytoPi/infra/supabase
supabase status
```

---

## Step 5: Set Up Raspberry Pi

### 5.1 Install Dependencies on Pi

SSH into your Raspberry Pi and install required libraries:

```bash
# Update package list
sudo apt update

# Install dependencies
sudo apt install -y \
  build-essential \
  libgpiod-dev \
  libsqlite3-dev \
  libcurl4-openssl-dev \
  libjson-c-dev \
  git

# Verify installations
pkg-config --exists libgpiod && echo "libgpiod OK" || echo "libgpiod MISSING"
pkg-config --exists sqlite3 && echo "sqlite3 OK" || echo "sqlite3 MISSING"
curl --version
```

### 5.2 Clone/Copy the pi-controller Code

**Option A: If you have the code in a git repo:**
```bash
cd ~
git clone <your-repo-url>
cd PhytoPi/pi-controller
```

**Option B: If copying from your PC:**
```bash
# On your PC, create a tarball:
cd /home/danielg/Documents/PhytoPi
tar -czf pi-controller.tar.gz pi-controller/

# Copy to Pi (replace with your Pi's IP and user):
scp pi-controller.tar.gz pi@your-pi-ip:~/

# On Pi:
cd ~
tar -xzf pi-controller.tar.gz
cd pi-controller
```

### 5.3 Build the Application

```bash
cd ~/PhytoPi/pi-controller  # or wherever you put it

# Clean any previous builds
make clean

# Build
make

# Verify the binary was created
ls -lh bin/phytopi
```

---

## Step 6: Configure Environment Variables on Pi

Create a script to set environment variables. Replace the placeholder values with your actual values:

```bash
cd ~/PhytoPi/pi-controller

# Create environment setup script
cat > setup_env.sh << 'EOF'
#!/bin/bash
# Supabase Configuration
export SUPABASE_URL="http://YOUR_PC_IP:54321"  # Replace YOUR_PC_IP with your PC's IP
export SUPABASE_ANON_KEY="your-anon-key-here"   # Replace with anon key from Step 1

# Device Configuration (optional)
export SUPABASE_DEVICE_ID="your-device-uuid"    # Replace with device UUID from Step 3

# Sensor IDs (required for each sensor type)
export SUPABASE_HUMIDITY_SENSOR_ID="your-humidity-sensor-uuid"
export SUPABASE_TEMPERATURE_SENSOR_ID="your-temperature-sensor-uuid"
export SUPABASE_SOIL_MOISTURE_SENSOR_ID="your-soil-moisture-sensor-uuid"
export SUPABASE_WATER_LEVEL_SENSOR_ID="your-water-level-sensor-uuid"
EOF

# Make it executable
chmod +x setup_env.sh

# Edit it with your actual values
nano setup_env.sh
```

**Important:** Replace:
- `YOUR_PC_IP` with your PC's local IP address (e.g., `192.168.1.100`)
- `your-anon-key-here` with the anon key from `supabase start`
- All UUIDs with the actual UUIDs from Step 3

### Alternative: Set Environment Variables Directly

```bash
export SUPABASE_URL="http://192.168.1.100:54321"  # Your PC's IP
export SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."  # Your anon key
export SUPABASE_DEVICE_ID="123e4567-e89b-12d3-a456-426614174000"  # Your device UUID
export SUPABASE_HUMIDITY_SENSOR_ID="123e4567-e89b-12d3-a456-426614174001"
export SUPABASE_TEMPERATURE_SENSOR_ID="123e4567-e89b-12d3-a456-426614174002"
export SUPABASE_SOIL_MOISTURE_SENSOR_ID="123e4567-e89b-12d3-a456-426614174003"
export SUPABASE_WATER_LEVEL_SENSOR_ID="123e4567-e89b-12d3-a456-426614174004"
```

---

## Step 7: Test Network Connectivity

Before running the application, verify your Pi can reach Supabase:

```bash
# Test if you can reach your PC's Supabase API
curl -v http://YOUR_PC_IP:54321/rest/v1/

# Should return some JSON (might be an error, but connection should work)
# If it fails, check:
# - Firewall on PC allows port 54321
# - PC and Pi are on same network
# - IP address is correct
```

---

## Step 8: Run the Application

### 8.1 Load Environment Variables

```bash
# Source your environment script
source setup_env.sh

# Or export variables manually (see Step 6)
```

### 8.2 Run the Application

```bash
# Run with sudo (required for GPIO access)
sudo -E ./bin/phytopi
```

**Note:** The `-E` flag preserves environment variables when using sudo.

### 8.3 Verify It's Working

You should see output like:
```
Supabase sync enabled: http://192.168.1.100:54321
Data inserted successfully into database.
Found X unsynced readings, syncing to Supabase...
Successfully sent X readings to Supabase (HTTP 201)
Marked X readings as synced
```

---

## Step 9: Verify Data in Supabase

1. **Open Supabase Studio** on your PC:
   ```
   http://127.0.0.1:54323
   ```

2. **Navigate to Table Editor** → `readings` table

3. **You should see new readings appearing** every 60 seconds (sync interval)

4. **Check the data:**
   - `sensor_id` should match your sensor UUIDs
   - `value` should contain sensor readings
   - `timestamp` should be recent
   - `unit` should match the sensor type

---

## Troubleshooting

### Issue: "Failed to initialize Supabase"
- **Check:** Environment variables are set correctly
- **Check:** Network connectivity (`curl http://YOUR_PC_IP:54321`)
- **Check:** Supabase is still running (`supabase status` on PC)

### Issue: "curl_easy_perform() failed"
- **Check:** Supabase URL is correct (use PC's IP, not 127.0.0.1)
- **Check:** Firewall allows port 54321
- **Check:** Supabase is running on PC

### Issue: "Supabase API returned error code: 401"
- **Check:** `SUPABASE_ANON_KEY` is correct
- **Check:** Anon key hasn't changed (restart Supabase to get new key)

### Issue: "Supabase API returned error code: 400"
- **Check:** Sensor IDs are correct UUIDs
- **Check:** Sensor IDs exist in Supabase `sensors` table
- **Check:** Data format matches schema (check `readings` table structure)
- **Check:** RLS policy allows inserts (see Step 3.5)

### Issue: "Supabase API returned error code: 403"
- **Check:** RLS policy is blocking inserts - you need to add the testing policy (Step 3.5)
- **Check:** You're using the correct key (anon key with policy, or service role key)

### Issue: No data appearing in Supabase
- **Check:** Application is running and showing "Data inserted successfully"
- **Check:** Wait 60 seconds for sync interval
- **Check:** Look for "Found X unsynced readings" in output
- **Check:** Check `sensor_data.db` on Pi to verify local data is being stored

### Issue: GPIO/Sensor Errors
- **Check:** Running with `sudo` (required for GPIO)
- **Check:** Hardware is connected correctly
- **Check:** I2C is enabled: `sudo raspi-config` → Interface Options → I2C → Enable

### Issue: Can't Connect to PC's Supabase
- **Check:** PC and Pi are on same network
- **Check:** PC's firewall allows port 54321
- **Check:** Use PC's local IP, not 127.0.0.1
- **Alternative:** Use SSH tunneling (see Step 2, Option B)

---

## Running as a Service (Optional)

To run the application automatically on boot:

1. **Create a systemd service file:**
```bash
sudo nano /etc/systemd/system/phytopi.service
```

2. **Add this content** (adjust paths as needed):
```ini
[Unit]
Description=PhytoPi Controller
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/home/pi/PhytoPi/pi-controller
EnvironmentFile=/home/pi/PhytoPi/pi-controller/setup_env.sh
ExecStart=/home/pi/PhytoPi/pi-controller/bin/phytopi
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

3. **Enable and start the service:**
```bash
sudo systemctl daemon-reload
sudo systemctl enable phytopi
sudo systemctl start phytopi

# Check status
sudo systemctl status phytopi

# View logs
sudo journalctl -u phytopi -f
```

---

## Summary Checklist

- [ ] Supabase running locally on PC
- [ ] PC's IP address identified
- [ ] Firewall configured (if needed)
- [ ] Device created in Supabase
- [ ] Sensors created in Supabase
- [ ] All UUIDs copied (device + 4 sensors)
- [ ] Dependencies installed on Pi
- [ ] Code copied to Pi
- [ ] Application built successfully
- [ ] Environment variables configured
- [ ] Network connectivity tested
- [ ] Application running and syncing data
- [ ] Data visible in Supabase Studio

---

## Next Steps

Once everything is working:
- Monitor data in Supabase Studio
- Check sensor readings are reasonable
- Verify sync is happening every 60 seconds
- Consider setting up as a systemd service for auto-start
- Test with actual sensors connected to your Pi


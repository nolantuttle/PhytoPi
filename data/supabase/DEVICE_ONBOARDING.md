# PhytoPi Device Onboarding Schema Documentation

## Overview

This schema supports two device onboarding flows:
1. **QR Code Pairing**: Users scan a QR code from the device packaging to claim it via the mobile app
2. **Kiosk Mode Pairing**: Users sign in on the Pi's kiosk interface to claim the device directly

Both flows converge through the same pairing endpoint and create device ownership, credentials, and initial configuration.

## Entity Relationship Diagram

```
auth.users (Supabase)
        │ 1
        │
        ▼
user_profiles ───┐
                 │ 1..*             1         1
                 └──── user_devices ───────────► device_units ◄──────── products
                        (owner)       ▲ 1..*                    1..*
                                       │
                        device_shares (viewer/admin)
                                       │
                                       ▼
                                  user_profiles

device_units 1..* ── sensors 1..* ── readings
device_units 1..* ── alerts
device_units 1..* ── ml_inferences

device_units 1..* ── onboarding_sessions  (QR & kiosk)
device_units 1..* ── wifi_networks        (optional)
device_units 1 ──── device_credentials    (rotatable)
```

**Note:** The `device_units` table combines both manufacturing identity (serial_number, pairing_code) and runtime device state (name, location, status). The legacy `devices` and `users` tables have been removed and merged into `device_units` and `user_profiles` respectively.

## Core Tables

### user_profiles
User profile information linked to Supabase authentication.

- **user_id** (uuid, PK): References `auth.users(id)` - one profile per authenticated user
- **full_name** (text): User's full name
- **timezone** (text): User timezone for displaying timestamps (default: UTC)
- **created_at** (timestamptz): Profile creation timestamp

**RLS Policies:**
- Users can view and update their own profile

### products
Device catalog: defines product models and their features.

- **id** (uuid, PK): Product identifier
- **sku** (text, UNIQUE): Stock Keeping Unit - unique product identifier (e.g., `PHYTOPI-MK1`)
- **name** (text): Product name
- **features** (jsonb): Product-specific features and capabilities
- **created_at** (timestamptz): Product creation timestamp

**RLS Policies:**
- Products are publicly readable (catalog)
- Only service role can modify products

### device_units
Manufactured device units with serial numbers, pairing codes, and runtime device state.

**Manufacturing/Onboarding Fields:**
- **id** (uuid, PK): Device identifier
- **product_id** (uuid, FK): References `products(id)`
- **serial_number** (text, UNIQUE): Unique device serial number (e.g., `PPI-24Q4-001234`)
- **pairing_code** (text): One-time pairing code for device claim (should be rotated after use)
- **pairing_expires_at** (timestamptz): Optional expiration timestamp for pairing code
- **factory_data** (jsonb): Manufacturing data (MAC addresses, PCB revision, QA stamps, etc.)
- **provisioned** (boolean): True when device has been claimed by a user
- **created_at** (timestamptz): Device creation timestamp

**Runtime Fields (set after provisioning):**
- **name** (text): User-friendly device name (set after provisioning)
- **location** (text): Device location (e.g., `greenhouse_a`, `lab_room_1`)
- **status** (text): Device status - `active`, `inactive`, `maintenance`, `error`
- **registered_at** (timestamptz): Timestamp when device was registered (set when provisioned)
- **updated_at** (timestamptz): Timestamp when device was last updated

**RLS Policies:**
- Owners can view and update their devices (name, location, status)
- Sharees can view shared devices
- Admins can update shared devices (name, location, status)
- Only service role can insert (via Edge Functions during pairing)

### device_credentials
Rotatable secrets that device agents use to authenticate with APIs.

- **device_id** (uuid, PK, FK): References `device_units(id)`
- **device_key_hash** (text): Argon2id hash of the device key (plaintext only delivered once during pairing)
- **rotated_at** (timestamptz): Timestamp of last credential rotation
- **created_at** (timestamptz): Credential creation timestamp

**RLS Policies:**
- Service-role only (no RLS policies)
- Devices authenticate via Edge Functions using device_key

### user_devices
Ownership link between users and devices.

- **user_id** (uuid, FK): References `user_profiles(user_id)`
- **device_id** (uuid, FK): References `device_units(id)`
- **claimed_at** (timestamptz): Timestamp when user claimed the device

**RLS Policies:**
- Users can view their device ownership
- Only service role can insert (via Edge Functions during pairing)

## Sharing and Onboarding Tables

### device_shares
Shared access to devices with viewer/admin roles.

- **device_id** (uuid, FK): References `device_units(id)`
- **shared_with** (uuid, FK): References `user_profiles(user_id)`
- **role** (text): Access role - `viewer` (read-only) or `admin` (can manage shares, WiFi, etc.)
- **invited_at** (timestamptz): Timestamp when share was created
- **accepted_at** (timestamptz): Timestamp when sharee accepted the invitation (NULL if pending)

**RLS Policies:**
- Owners can view and manage shares for their devices
- Admins can view and manage shares for shared devices
- Sharees can view their own shares and accept invitations

### onboarding_sessions
Ephemeral sessions for both QR code and kiosk mode pairing.

- **id** (uuid, PK): Session identifier
- **device_id** (uuid, FK): References `device_units(id)` - device being onboarded
- **user_id** (uuid, FK): References `user_profiles(user_id)` - user claiming the device (set after authentication)
- **short_code** (text): Optional human-readable code for kiosk display (e.g., `AB1C`)
- **status** (text): Session status - `pending` (created), `verified` (user authenticated), `consumed` (device claimed)
- **created_at** (timestamptz): Session creation timestamp
- **expires_at** (timestamptz): Session expiration timestamp

**RLS Policies:**
- Service-role only (no RLS policies)
- Managed entirely by Edge Functions during pairing flows

### wifi_networks
WiFi network profiles queued for devices to fetch after verification.

- **id** (uuid, PK): WiFi network identifier
- **device_id** (uuid, FK): References `device_units(id)`
- **ssid** (text): WiFi network name
- **passphrase_encrypted** (text): Encrypted WiFi passphrase (use pgcrypto encrypt function)
- **created_by** (uuid, FK): References `user_profiles(user_id)` - user who added this WiFi network
- **created_at** (timestamptz): WiFi network creation timestamp
- **fetched_at** (timestamptz): Timestamp when device fetched this WiFi config (NULL if not yet fetched)

**RLS Policies:**
- Owners can view and manage WiFi networks for their devices
- Admins can view and manage WiFi networks for shared devices

## Sensor Schema

### sensor_types
Catalog of sensor types with their units and metadata.

- **id** (uuid, PK): Sensor type identifier
- **key** (text, UNIQUE): Unique identifier for sensor type (e.g., `soil_moisture`, `temp_c`)
- **name** (text): Human-readable name for the sensor type
- **unit** (text): Unit of measurement (e.g., `%`, `°C`, `RH%`, `lux`)
- **description** (text): Sensor type description
- **created_at** (timestamptz): Sensor type creation timestamp

**Default Sensor Types:**
- `soil_moisture` - Soil Moisture (%)
- `temp_c` - Temperature (°C)
- `temp_f` - Temperature (°F)
- `humidity` - Humidity (RH%)
- `light_lux` - Light Intensity (lux)
- `ph` - pH (pH)
- `ec` - Electrical Conductivity (mS/cm)
- `co2` - CO2 (ppm)
- `pressure` - Pressure (hPa)

**RLS Policies:**
- Sensor types are publicly readable (catalog)
- Only service role can modify sensor types

### sensors
Individual sensors attached to devices.

- **id** (uuid, PK): Sensor identifier
- **device_id** (uuid, FK): References `device_units(id)` - device this sensor is attached to
- **type_id** (uuid, FK): References `sensor_types(id)` - type of sensor
- **label** (text): User-friendly label for the sensor (e.g., "Soil A", "Ambient Temp")
- **metadata** (jsonb): Sensor metadata (calibration data, location, configuration, etc.)
- **created_at** (timestamptz): Sensor creation timestamp
- **updated_at** (timestamptz): Sensor last update timestamp

**RLS Policies:**
- Owners can view and manage sensors for their devices
- Sharees can view sensors for shared devices
- Admins can manage sensors for shared devices

### readings
Time-series sensor readings.

- **id** (bigserial, PK): Reading identifier
- **sensor_id** (uuid, FK): References `sensors(id)` - sensor that generated this reading
- **ts** (timestamptz): Timestamp when reading was taken
- **value** (double precision): Numeric value of the reading
- **metadata** (jsonb): Additional reading metadata (quality flags, calibration info, etc.)
- **created_at** (timestamptz): Reading creation timestamp

**RLS Policies:**
- Owners can view readings for their devices
- Sharees can view readings for shared devices
- Only service role can insert readings (via Edge Functions with device authentication)

**Indexes:**
- `(sensor_id, ts DESC)` - Optimized for time-range queries per sensor
- `(ts DESC)` - Optimized for global time-range queries

### alerts
Device and sensor alerts.

- **id** (uuid, PK): Alert identifier
- **device_id** (uuid, FK): References `device_units(id)`
- **sensor_id** (uuid, FK): References `sensors(id)` (nullable for device-level alerts)
- **type** (varchar): Alert type (e.g., `threshold_exceeded`, `device_offline`, `calibration_needed`)
- **triggered_at** (timestamptz): Timestamp when alert was triggered
- **resolved_at** (timestamptz): Timestamp when alert was resolved (NULL if unresolved)
- **message** (text): Alert message
- **severity** (varchar): Alert severity - `low`, `medium`, `high`, `critical`
- **metadata** (jsonb): Additional alert context
- **created_at** (timestamptz): Alert creation timestamp

**RLS Policies:**
- Owners can view alerts for their devices
- Sharees can view alerts for shared devices
- Only service role can insert/update (via Edge Functions or triggers)

### ml_inferences
ML model inference results.

- **id** (uuid, PK): Inference identifier
- **device_id** (uuid, FK): References `device_units(id)`
- **timestamp** (timestamptz): Timestamp when inference was performed
- **result** (jsonb): ML model output (predictions, classifications, etc.)
- **confidence** (numeric): Confidence score (0.0000 to 1.0000)
- **image_url** (text): URL to the image that was analyzed
- **model_version** (varchar): ML model version used
- **processing_time_ms** (integer): Processing time in milliseconds
- **metadata** (jsonb): Additional ML context
- **created_at** (timestamptz): Inference creation timestamp

**RLS Policies:**
- Owners can view ML inferences for their devices
- Sharees can view ML inferences for shared devices
- Only service role can insert (via Edge Functions or device agents)

## Onboarding Flows

### QR Code Pairing Flow (Mobile App)

1. **User scans QR code** → Gets `{serial_number, pairing_code}` from QR payload
2. **User signs in** → App authenticates user with Supabase Auth
3. **App calls Edge Function** → `POST /pair-device` with `{serial_number, pairing_code}`
4. **Edge Function validates**:
   - Checks `device_units.serial_number` exists
   - Validates `pairing_code` matches
   - Checks `pairing_expires_at` (if set) is not expired
   - Verifies device is not already provisioned
5. **Edge Function creates ownership**:
   - Upserts `user_profiles` for `auth.uid`
   - Inserts `user_devices (user_id, device_id)`
   - Marks `device_units.provisioned = true`
   - Rotates `pairing_code` (generates new one)
6. **Edge Function generates credentials**:
   - Generates `device_key` (random secret)
   - Stores `device_key_hash` (argon2id hash) in `device_credentials`
   - Returns plaintext `device_key` to app (only once)
7. **Device agent calls API** → `GET /device-config` using `device_key`
8. **Device receives config** → WiFi networks, sensor configuration, etc.

### Kiosk Mode Pairing Flow (On Pi)

1. **Pi boots in kiosk mode** → Chromium displays "Connect to Wi-Fi & Sign in" screen
2. **User connects to WiFi** → Pi connects to user's WiFi network
3. **Kiosk creates session** → Calls `POST /kiosk/create-session` with `device_serial`
4. **Backend creates session**:
   - Creates `onboarding_sessions` row with `status='pending'`
   - Generates `short_code` (e.g., `AB1C`)
   - Sets `expires_at` (e.g., 15 minutes from now)
5. **Kiosk displays code** → Shows short code on screen
6. **User signs in** → User signs in on kiosk screen (or scans code on phone)
7. **Backend verifies session** → `POST /kiosk/verify-session` with `session_id` or `short_code`
8. **Backend completes pairing**:
   - Links `onboarding_sessions.user_id` to authenticated user
   - Sets `status='verified'`
   - Same write steps as QR flow (create `user_devices`, mint `device_credentials`, rotate `pairing_code`)
   - Sets `status='consumed'`
9. **Device pulls config** → Device calls `GET /device-config` using `device_key`

## QR Code Payload Format

```json
{
  "v": 1,
  "sn": "PPI-24Q4-001234",
  "pc": "R7K3-9WQ2-AB1C",
  "sku": "PHYTOPI-MK1"
}
```

- **v** (integer): Version number (for future schema changes)
- **sn** (string): Serial number
- **pc** (string): Pairing code (one-time use)
- **sku** (string): Product SKU (optional, for validation)

## Edge Functions API

### POST /pair-device
Pairs a device with a user using serial number and pairing code.

**Request Body:**
```json
{
  "serial_number": "PPI-24Q4-001234",
  "pairing_code": "R7K3-9WQ2-AB1C"
}
```

**Response:**
```json
{
  "device_id": "uuid",
  "device_key": "plaintext-secret-key",
  "device_key_hash": "argon2id-hash"
}
```

### POST /kiosk/create-session
Creates an onboarding session for kiosk mode.

**Request Body:**
```json
{
  "device_serial": "PPI-24Q4-001234"
}
```

**Response:**
```json
{
  "session_id": "uuid",
  "short_code": "AB1C",
  "expires_at": "2024-01-21T12:00:00Z"
}
```

### POST /kiosk/verify-session
Verifies an onboarding session and completes pairing.

**Request Body:**
```json
{
  "session_id": "uuid"
}
```
or
```json
{
  "short_code": "AB1C"
}
```

**Response:**
```json
{
  "device_id": "uuid",
  "device_key": "plaintext-secret-key"
}
```

### GET /device-config
Retrieves device configuration (WiFi networks, sensor config, etc.).

**Authentication:** Device key (via header or JWT)

**Response:**
```json
{
  "wifi_networks": [
    {
      "ssid": "MyNetwork",
      "passphrase": "decrypted-passphrase"
    }
  ],
  "sensors": [
    {
      "type": "soil_moisture",
      "label": "Soil A"
    }
  ]
}
```

### POST /ingest
Ingests sensor readings from device.

**Authentication:** Device key (via header or JWT)

**Request Body:**
```json
{
  "readings": [
    {
      "sensor_id": "uuid",
      "ts": "2024-01-21T12:00:00Z",
      "value": 65.5,
      "metadata": {}
    }
  ]
}
```

## Security Model

### Row Level Security (RLS)

- **Owners** (in `user_devices`) can read/write their device data
- **Sharees** (in `device_shares`) can read device data (viewers) or read/write (admins)
- **Device credentials** and **onboarding sessions** are service-role only
- **Readings** can be inserted by service role (device authentication via Edge Functions)
- **Products** and **sensor_types** are publicly readable (catalog)

### Device Authentication

- Devices authenticate using `device_key` (delivered once during pairing)
- Device keys are stored as argon2id hashes in `device_credentials`
- Edge Functions validate device keys before allowing API access
- Device keys can be rotated (update `device_credentials.device_key_hash`)

### WiFi Network Encryption

- WiFi passphrases should be encrypted using `pgcrypto` before storing
- Use `pgp_sym_encrypt()` to encrypt and `pgp_sym_decrypt()` to decrypt
- Decryption should only happen in Edge Functions (service role)
- Devices receive decrypted passphrases via authenticated API calls

**Example Encryption (Edge Function):**
```sql
-- Encrypt WiFi passphrase (use a secure key from environment variables)
INSERT INTO public.wifi_networks (device_id, ssid, passphrase_encrypted, created_by)
VALUES (
  'device-uuid',
  'MyNetwork',
  pgp_sym_encrypt('my-password', current_setting('app.wifi_encryption_key')),
  'user-uuid'
);
```

**Example Decryption (Edge Function):**
```sql
-- Decrypt WiFi passphrase (only in Edge Functions with service role)
SELECT 
  id,
  ssid,
  pgp_sym_decrypt(passphrase_encrypted::bytea, current_setting('app.wifi_encryption_key')) as passphrase
FROM public.wifi_networks
WHERE device_id = 'device-uuid'
AND fetched_at IS NULL;
```

**Note:** Store the encryption key in Supabase secrets or environment variables. Never hardcode encryption keys.

## Database Functions

### handle_new_user()
Automatically creates a user profile when a new auth user is created.

**Trigger:** `on_auth_user_created` on `auth.users`

### update_updated_at_column()
Automatically updates the `updated_at` timestamp on row update.

**Trigger:** `update_sensors_updated_at` on `sensors`

### user_has_device_access(device_uuid, user_uuid)
Helper function to check if a user has access to a device (owner or sharee).

**Returns:** `boolean`

## Migration Files

1. **20250121000001_create_device_onboarding_core.sql**
   - Creates core tables: `user_profiles`, `products`, `device_units`, `device_credentials`, `user_devices`

2. **20250121000002_create_sharing_and_onboarding.sql**
   - Creates sharing and onboarding tables: `device_shares`, `onboarding_sessions`, `wifi_networks`
   - Creates `handle_new_user()` function and trigger

3. **20250121000003_create_sensor_schema.sql**
   - Drops legacy `sensors` and `readings` tables
   - Creates new sensor tables: `sensor_types`, `sensors`, `readings`
   - Inserts default sensor types
   - Creates `update_updated_at_column()` function and trigger

4. **20250121000004_setup_device_rls.sql**
   - Enables RLS on all tables
   - Creates RLS policies for ownership, sharing, and data access
   - Creates `user_has_device_access()` helper function

5. **20250121000005_merge_devices_and_cleanup.sql**
   - Adds runtime fields (name, location, status) to `device_units`
   - Updates `alerts` and `ml_inferences` to reference `device_units`
   - Drops legacy `devices` and `users` tables
   - Updates RLS policies to allow owners/admins to update device runtime fields

## Best Practices

### Pairing Code Rotation
- Rotate `pairing_code` after successful pairing
- Generate new pairing codes using cryptographically secure random generators
- Set `pairing_expires_at` for time-limited pairing codes

### Device Key Management
- Store device keys as argon2id hashes (never store plaintext)
- Deliver plaintext device key only once during pairing (via secure channel)
- Rotate device keys periodically or on security incidents
- Use service role for all device credential operations

### WiFi Network Security
- Encrypt WiFi passphrases before storing in database
- Decrypt only in Edge Functions (service role)
- Delete WiFi networks after device fetches them (set `fetched_at`)
- Use unique encryption keys per deployment

### Onboarding Session Cleanup
- Set appropriate `expires_at` timestamps (e.g., 15 minutes)
- Clean up expired sessions periodically (cron job or Edge Function)
- Mark sessions as `consumed` after successful pairing

### Sensor Reading Ingestion
- Use batch inserts for sensor readings (better performance)
- Validate sensor readings before inserting (type, range, etc.)
- Use service role for reading insertion (device authentication via Edge Functions)
- Index readings by `(sensor_id, ts DESC)` for efficient time-range queries

## Future Enhancements

### Phase 2: Monetization
- `subscription_plans` - Subscription plans for device features
- `user_usage` - Usage tracking for billing
- `device_subscriptions` - Link devices to subscription plans

### Phase 3: Alerts
- `alerts` - Device and sensor alerts
- `alert_rules` - Configurable alert rules
- `alert_notifications` - Alert notification channels

### Phase 4: Analytics
- `device_analytics` - Device usage analytics
- `sensor_analytics` - Sensor data analytics
- `user_analytics` - User behavior analytics

## References

- [Supabase Row Level Security](https://supabase.com/docs/guides/auth/row-level-security)
- [Supabase Edge Functions](https://supabase.com/docs/guides/functions)
- [PostgreSQL pgcrypto](https://www.postgresql.org/docs/current/pgcrypto.html)
- [Argon2id Password Hashing](https://en.wikipedia.org/wiki/Argon2)


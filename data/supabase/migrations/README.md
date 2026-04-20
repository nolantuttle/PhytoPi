# PhytoPi Database Migrations

## Overview

This directory contains Supabase database migrations for the PhytoPi device onboarding and management system.

## Migration Files

### Device Onboarding Schema (2025-01-21)

1. **20250121000001_create_device_onboarding_core.sql**
   - Creates core tables: `user_profiles`, `products`, `device_units`, `device_credentials`, `user_devices`
   - Sets up device catalog, manufacturing identity, and ownership model

2. **20250121000002_create_sharing_and_onboarding.sql**
   - Creates sharing and onboarding tables: `device_shares`, `onboarding_sessions`, `wifi_networks`
   - Sets up device sharing with roles, ephemeral onboarding sessions, and WiFi network management
   - Creates `handle_new_user()` function to auto-create user profiles

3. **20250121000003_create_sensor_schema.sql**
   - Creates sensor tables: `sensor_types`, `sensors`, `readings`
   - Sets up extensible sensor model with time-series readings
   - Inserts default sensor types (soil_moisture, temp_c, humidity, etc.)
   - Creates `update_updated_at_column()` function for automatic timestamp updates

4. **20250121000004_setup_device_rls.sql**
   - Enables Row Level Security (RLS) on all tables
   - Creates RLS policies for ownership, sharing, and data access
   - Implements security model: owners can manage, sharees can view/admin
   - Creates `user_has_device_access()` helper function

### Schema Consolidation (2025-01-21)

5. **20250121000005_merge_devices_and_cleanup.sql**
   - Adds runtime fields (name, location, status) to `device_units`
   - Updates `alerts` and `ml_inferences` to reference `device_units`
   - Drops legacy `devices` and `users` tables
   - Updates RLS policies to allow owners/admins to update device runtime fields

### Legacy Migrations (2025-01-20)

These migrations were created before the device onboarding schema:

- **20250120000001_create_core_tables.sql** - Legacy devices, sensors, users tables (merged into new schema)
- **20250120000002_create_data_tables.sql** - Legacy readings and alerts tables (alerts updated, readings replaced)
- **20250120000003_create_ml_tables.sql** - ML inferences table (updated to reference device_units)
- **20250120000004_setup_rls.sql** - Legacy RLS policies (replaced by new RLS policies)
- **20250120000005_create_views_and_sample_data.sql** - Legacy views (dropped, can be recreated if needed)

**Note:** The legacy `devices` and `users` tables have been merged into `device_units` and `user_profiles` respectively. The `alerts` and `ml_inferences` tables now reference `device_units` instead of the legacy `devices` table.

## Documentation

For detailed documentation on the device onboarding schema, see:
- **[DEVICE_ONBOARDING.md](../DEVICE_ONBOARDING.md)** - Comprehensive schema documentation, onboarding flows, and API reference

## Key Features

### Device Onboarding
- **QR Code Pairing**: Users scan QR codes to claim devices via mobile app
- **Kiosk Mode Pairing**: Users sign in on Pi's kiosk interface to claim devices
- **One-time Pairing Codes**: Secure device claim with code rotation
- **Device Credentials**: Rotatable secrets for device authentication

### Device Management
- **Ownership Model**: Users own devices, can share with others
- **Sharing with Roles**: Viewer (read-only) and Admin (read/write) roles
- **WiFi Network Management**: Encrypted WiFi profiles for devices
- **Product Catalog**: SKU-based device models and features

### Sensor Data
- **Extensible Sensor Model**: Support for multiple sensor types
- **Time-series Readings**: Optimized for high-frequency sensor data
- **Sensor Metadata**: Calibration data, labels, and configuration

### Security
- **Row Level Security (RLS)**: Fine-grained access control
- **Device Authentication**: Device keys for API access
- **Encrypted WiFi Passwords**: pgcrypto encryption for sensitive data
- **Service Role Only**: Credentials and onboarding sessions are service-role only

## Running Migrations

### Local Development

```bash
cd /home/danielg/Documents/PhytoPi/infra/supabase
supabase start
supabase db reset  # Applies all migrations
```

### Apply Specific Migration

```bash
supabase migration up <migration_name>
```

### Create New Migration

```bash
supabase migration new <migration_name>
```

## Migration Order

Migrations are applied in chronological order based on their timestamps:
1. Core device onboarding tables
2. Sharing and onboarding tables
3. Sensor schema
4. RLS policies

**Important:** Always test migrations locally before applying to staging/production.

## Troubleshooting

### Migration Conflicts
If migrations conflict with existing schema:
1. Check existing tables and columns
2. Use `ALTER TABLE` instead of `CREATE TABLE` if tables exist
3. Consider data migration scripts if needed

### RLS Policy Issues
If RLS policies are too restrictive:
1. Check `auth.uid()` is available in context
2. Verify user has proper ownership or shares
3. Test with service role for device operations

### Extension Issues
If extensions fail to load:
1. Verify PostgreSQL version supports extensions
2. Check extension is available in Supabase
3. Use `CREATE EXTENSION IF NOT EXISTS` for idempotency

## Next Steps

1. **Edge Functions**: Implement pairing and device management Edge Functions
2. **API Integration**: Connect mobile app and Pi controller to APIs
3. **Testing**: Write integration tests for onboarding flows
4. **Monitoring**: Set up monitoring for device pairing and data ingestion

## References

- [Supabase Migrations](https://supabase.com/docs/guides/cli/local-development#database-migrations)
- [Row Level Security](https://supabase.com/docs/guides/auth/row-level-security)
- [PostgreSQL Extensions](https://www.postgresql.org/docs/current/contrib.html)


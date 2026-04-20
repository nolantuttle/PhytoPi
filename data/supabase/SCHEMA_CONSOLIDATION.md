# Schema Consolidation Summary

## Problem

The original schema had two separate device-related tables:
1. **Legacy `devices` table** - Runtime device state (name, location, status)
2. **New `device_units` table** - Manufacturing identity (serial_number, pairing_code)

This created confusion because:
- `onboarding_sessions` referenced `device_units.id`
- `alerts` and `ml_inferences` referenced `devices.id`
- They represented the same physical device but were disconnected

Additionally:
- Legacy `users` table was not connected to anything (we use `user_profiles` + `auth.users`)

## Solution

### 1. Merged `devices` into `device_units`

The `device_units` table now contains both:
- **Manufacturing/Onboarding fields**: `serial_number`, `pairing_code`, `factory_data`, `provisioned`
- **Runtime fields**: `name`, `location`, `status`, `registered_at`, `updated_at`

This makes `device_units` the single source of truth for devices.

### 2. Updated Foreign Key References

- `alerts.device_id` now references `device_units.id` (was `devices.id`)
- `ml_inferences.device_id` now references `device_units.id` (was `devices.id`)
- All other tables already referenced `device_units.id`

### 3. Dropped Legacy Tables

- **`devices` table** - Merged into `device_units`
- **`users` table** - Not needed (we use `user_profiles` + `auth.users`)

### 4. Updated RLS Policies

- Owners can now update device runtime fields (name, location, status)
- Admins can update shared device runtime fields
- Alerts and ML inferences now use device_units-based RLS policies

## Migration: 20250121000005_merge_devices_and_cleanup.sql

This migration:
1. Adds runtime fields to `device_units`
2. Updates `alerts` and `ml_inferences` foreign keys
3. Drops legacy `devices` and `users` tables
4. Updates RLS policies for device updates
5. Adds indexes for new runtime fields

## New Schema Structure

```
device_units (single source of truth)
├── Manufacturing: serial_number, pairing_code, factory_data, provisioned
├── Runtime: name, location, status, registered_at, updated_at
└── References:
    ├── products (product_id)
    ├── user_devices (ownership)
    ├── device_shares (sharing)
    ├── device_credentials (authentication)
    ├── onboarding_sessions (pairing)
    ├── wifi_networks (WiFi configs)
    ├── sensors (attached sensors)
    ├── alerts (device alerts)
    └── ml_inferences (ML results)
```

## Benefits

1. **Single source of truth**: One table for device identity and state
2. **Simplified queries**: No joins needed between devices and device_units
3. **Consistent references**: All tables reference the same device table
4. **Cleaner schema**: Removed unused `users` table
5. **Better RLS**: Unified RLS policies based on device_units ownership

## Backward Compatibility

If you have existing data:
- The migration safely handles the transition
- Legacy `devices` table data should be migrated to `device_units` before dropping
- The migration includes checks to prevent errors if tables don't exist

## Next Steps

1. Test the migration on a development database
2. Verify all foreign key references are correct
3. Update any application code that references the old `devices` table
4. Update any queries that join `devices` and `device_units`


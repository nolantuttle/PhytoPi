# Utility Scripts

This directory contains utility scripts for environment setup and configuration.

## Scripts

### `load_env.sh`
Loads environment variables from `.env` files.

**Usage:**
```bash
source scripts/utils/load_env.sh
```

**What it does:**
- Loads `.env` files in priority order
- Supports platform-specific files
- Sets Android SDK paths if needed

**File Priority:**
1. `.env.local` (highest priority)
2. `.env.{platform}` (platform-specific)
3. `.env` (general)
4. `.env.production` (production)

### `setup_env.sh`
Sets up environment files for different platforms.

**Usage:**
```bash
./scripts/utils/setup_env.sh [web|android|ios|kiosk|production]
```

**What it does:**
- Creates platform-specific `.env` files
- Auto-detects local IP address
- Auto-detects local Supabase key
- Provides next steps

**Platforms:**
- `web` - Web development (localhost)
- `android` - Android device testing (local network IP)
- `ios` - iOS device testing (local network IP)
- `kiosk` - Kiosk mode (local network IP)
- `production` - Production builds (cloud Supabase)

## See Also

- [../README.md](../README.md) - Scripts documentation
- [../../docs/configuration/](../../docs/configuration/) - Configuration guides
- [../../docs/getting-started/](../../docs/getting-started/) - Getting started guides


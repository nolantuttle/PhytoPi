# PhytoPi Dashboard Scripts

This directory contains build and development scripts for the PhytoPi Dashboard supporting multiple platforms: Web, Mobile (iOS/Android), and Kiosk (Linux/Raspberry Pi).

## Directory Structure

```
scripts/
├── build/          # Build scripts for all platforms
├── dev/            # Development and testing scripts
├── utils/          # Utility scripts (env setup, etc.)
└── README.md       # This file
```

## Scripts by Category

### Build Scripts (`build/`)

- **`build_web.sh`** - Builds Flutter app for web deployment
- **`build_mobile_android.sh`** - Builds Flutter app for Android
- **`build_mobile_ios.sh`** - Builds Flutter app for iOS
- **`build_kiosk.sh`** - Builds Flutter app for kiosk mode
- **`build_prod.sh`** - Builds Flutter app for production
- **`build.sh`** - Build script for Vercel deployment

See [build/README.md](./build/README.md) for details.

### Development Scripts (`dev/`)

- **`run_local.sh`** - Starts Supabase locally and runs Flutter app
- **`test_android.sh`** - Tests Android setup and runs the app

See [dev/README.md](./dev/README.md) for details.

### Utility Scripts (`utils/`)

- **`load_env.sh`** - Loads environment variables from `.env` files
- **`setup_env.sh`** - Sets up environment files for different platforms

See [utils/README.md](./utils/README.md) for details.

## Quick Start

### Setup Environment

```bash
# Setup for web development
./scripts/utils/setup_env.sh web

# Setup for Android testing
./scripts/utils/setup_env.sh android

# Setup for iOS testing
./scripts/utils/setup_env.sh ios

# Setup for kiosk mode
./scripts/utils/setup_env.sh kiosk

# Setup for production
./scripts/utils/setup_env.sh production
```

### Run Local Development

```bash
# Run web development server
./scripts/dev/run_local.sh
```

### Build for Production

```bash
# Build for web
./scripts/build/build_web.sh

# Build for Android
./scripts/build/build_mobile_android.sh apk

# Build for iOS
./scripts/build/build_mobile_ios.sh

# Build for kiosk
./scripts/build/build_kiosk.sh

# Build for production
./scripts/build/build_prod.sh
```

## Environment Variables

All scripts automatically load environment variables from `.env` files. See [../docs/configuration/](../docs/configuration/) for details.

### File Priority

Scripts load environment variables in this order:
1. `.env.local` - Local overrides (highest priority)
2. `.env.{platform}` - Platform-specific files (`.env.android`, `.env.ios`, `.env.kiosk`, `.env.web`)
3. `.env` - General configuration
4. `.env.production` - Production configuration
5. Command-line exports (override .env files)

### Platform-Specific Files

- **`.env.web`** - Web development (uses localhost)
- **`.env.android`** - Android testing (uses local IP)
- **`.env.ios`** - iOS testing (uses local IP for device, localhost for simulator)
- **`.env.kiosk`** - Kiosk mode (uses local IP for remote device, localhost for same machine)
- **`.env.local`** - Local overrides (highest priority, works for all platforms)
- **`.env.production`** - Production builds (uses cloud Supabase)

## Platform-Specific Configuration

### Web Development
- `SUPABASE_URL`: http://127.0.0.1:54321 (set in `.env` or auto-detected by `run_local.sh`)
- `SUPABASE_ANON_KEY`: Set in `.env` or auto-detected by `run_local.sh`

### Android Testing
- `SUPABASE_URL`: http://YOUR_IP:54321 (use your computer's local IP, not localhost)
- `SUPABASE_ANON_KEY`: Set in `.env.android` or `.env.local`
- Find your IP: `ip addr show | grep "inet " | grep -v 127.0.0.1`

### iOS Testing
- `SUPABASE_URL`: http://127.0.0.1:54321 (simulator) or http://YOUR_IP:54321 (device)
- `SUPABASE_ANON_KEY`: Set in `.env.ios` or `.env.local`

### Kiosk Mode
- `SUPABASE_URL`: http://127.0.0.1:54321 (same machine) or http://YOUR_IP:54321 (remote device)
- `SUPABASE_ANON_KEY`: Set in `.env.kiosk` or `.env.local`
- `KIOSK_MODE`: Set to `true` for kiosk-specific features

### Production/Staging
- `SUPABASE_URL`: Your production/staging Supabase URL (set in `.env.production`)
- `SUPABASE_ANON_KEY`: Your production/staging anon key (set in `.env.production`)

## Troubleshooting

### Scripts not executable
```bash
chmod +x scripts/**/*.sh
```

### Flutter not found
- Ensure Flutter is installed and in PATH
- Run `flutter doctor` to verify installation

### Supabase not running
```bash
cd ../../infra/supabase
supabase start
```

### Build fails
- Check environment variables are set
- Verify Flutter version (3.10.0+)
- Check build logs for specific errors

### Android/iOS can't connect to local Supabase
- Use your computer's IP address, not `127.0.0.1`
- Make sure phone and computer are on the same network
- Check firewall settings
- Verify Supabase is running: `cd infra/supabase && supabase status`

## See Also

- [../docs/README.md](../docs/README.md) - Documentation index
- [../docs/configuration/](../docs/configuration/) - Configuration guides
- [../docs/platform/](../docs/platform/) - Platform-specific guides
- [../docs/deployment/](../docs/deployment/) - Deployment guides

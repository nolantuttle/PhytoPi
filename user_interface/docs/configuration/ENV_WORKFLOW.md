# Environment Variables Workflow

This guide explains how to use `.env` files for different environments and platforms (Web, Android, iOS, Kiosk, Production).

## Quick Setup

### Option 1: Use Setup Script (Recommended)

```bash
cd dashboard

# Setup for web development
./scripts/setup_env.sh web

# Setup for Android testing
./scripts/setup_env.sh android

# Setup for iOS testing
./scripts/setup_env.sh ios

# Setup for kiosk mode
./scripts/setup_env.sh kiosk

# Setup for production
./scripts/setup_env.sh production
```

The setup script will:
- Create the appropriate `.env` file
- Auto-detect your local IP address (for mobile/kiosk)
- Auto-detect your local Supabase key (if Supabase is running)
- Provide next steps

### Option 2: Manual Setup

1. **Copy the example file:**
   ```bash
   cd dashboard
   cp env.example .env
   ```

2. **Edit `.env` with your values:**
   ```bash
   SUPABASE_URL=http://127.0.0.1:54321
   SUPABASE_ANON_KEY=your-local-anon-key-here
   ```

3. **All scripts automatically use `.env` files!**

## File Priority

The `load_env.sh` script loads environment variables in this order (first found wins):

1. `.env.local` - Local development overrides (highest priority)
2. `.env.{platform}` - Platform-specific files (e.g., `.env.android`, `.env.ios`, `.env.kiosk`, `.env.web`)
3. `.env` - General configuration
4. `.env.production` - Production configuration

## Platform-Specific Files

### Web Development

**File:** `.env` or `.env.web` or `.env.local`

```bash
# Local Supabase (running on your machine)
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_ANON_KEY=your-local-anon-key-here
```

**Get your local anon key:**
```bash
cd infra/supabase
supabase status
# Look for "Publishable key" or "anon key" in the output
```

**Usage:**
```bash
./scripts/run_local.sh
```

### Android Testing

**File:** `.env.local` or `.env.android`

```bash
# Use your computer's IP address for Android device testing
# Find your IP: ip addr show | grep "inet " | grep -v 127.0.0.1
SUPABASE_URL=http://192.168.0.107:54321  # Replace with your IP
SUPABASE_ANON_KEY=your-local-anon-key-here
```

**Why?** Android devices can't access `127.0.0.1` (localhost), so use your computer's local network IP.

**Requirements:**
- Android device and computer on the same Wi-Fi network
- Firewall allows port 54321
- Supabase running locally

**Usage:**
```bash
./scripts/test_android.sh
# or
./scripts/build_mobile_android.sh apk
```

### iOS Testing

**File:** `.env.local` or `.env.ios`

**For iOS Simulator:**
```bash
# Can use localhost
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_ANON_KEY=your-local-anon-key-here
```

**For Physical Device:**
```bash
# Use your computer's IP address
SUPABASE_URL=http://192.168.0.107:54321  # Replace with your IP
SUPABASE_ANON_KEY=your-local-anon-key-here
```

**Requirements:**
- iOS device and computer on the same Wi-Fi network (for physical device)
- Firewall allows port 54321
- Supabase running locally
- macOS with Xcode installed

**Usage:**
```bash
./scripts/build_mobile_ios.sh
```

### Kiosk Mode

**File:** `.env.local` or `.env.kiosk`

**For Same Machine:**
```bash
# Can use localhost
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_ANON_KEY=your-local-anon-key-here
KIOSK_MODE=true
```

**For Remote Device (Raspberry Pi):**
```bash
# Use your computer's IP address
SUPABASE_URL=http://192.168.0.107:54321  # Replace with your IP
SUPABASE_ANON_KEY=your-local-anon-key-here
KIOSK_MODE=true
```

**Requirements:**
- Remote device and computer on the same network (for remote device)
- Firewall allows port 54321
- Supabase running locally

**Usage:**
```bash
./scripts/build_kiosk.sh
```

### Production/Staging

**File:** `.env.production`

```bash
# Remote Supabase (staging or production)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-production-anon-key-here
```

**Get your production anon key:**
```bash
# Supabase Dashboard → Project Settings → API → Project API keys → anon public
```

**Usage:**
```bash
./scripts/build_prod.sh
# or
./scripts/build_web.sh
# or
./scripts/build_mobile_android.sh apk
```

## Environment Files Overview

| File | Priority | Use Case | SUPABASE_URL |
|------|----------|----------|--------------|
| `.env.local` | Highest | Local overrides, Android/iOS testing | Your local IP |
| `.env.web` | High | Web development | localhost |
| `.env.android` | High | Android testing | Your local IP |
| `.env.ios` | High | iOS testing | localhost (simulator) or IP (device) |
| `.env.kiosk` | High | Kiosk mode | localhost (same machine) or IP (remote) |
| `.env` | Medium | General configuration | localhost |
| `.env.production` | Low | Production builds | Cloud URL |

## Workflow Examples

### Example 1: Web Development

1. **Setup:**
   ```bash
   cd dashboard
   ./scripts/setup_env.sh web
   ```

2. **Start Supabase:**
   ```bash
   cd infra/supabase
   supabase start
   ```

3. **Run:**
   ```bash
   cd dashboard
   ./scripts/run_local.sh
   ```

### Example 2: Android Testing

1. **Setup:**
   ```bash
   cd dashboard
   ./scripts/setup_env.sh android
   ```

2. **Start Supabase:**
   ```bash
   cd infra/supabase
   supabase start
   ```

3. **Test:**
   ```bash
   cd dashboard
   ./scripts/test_android.sh
   ```

### Example 3: iOS Testing (Physical Device)

1. **Setup:**
   ```bash
   cd dashboard
   ./scripts/setup_env.sh ios
   ```

2. **Start Supabase:**
   ```bash
   cd infra/supabase
   supabase start
   ```

3. **Build:**
   ```bash
   cd dashboard
   ./scripts/build_mobile_ios.sh
   ```

### Example 4: Production Build

1. **Setup:**
   ```bash
   cd dashboard
   ./scripts/setup_env.sh production
   ```

2. **Edit `.env.production` with production credentials:**
   ```bash
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-production-anon-key
   ```

3. **Build:**
   ```bash
   ./scripts/build_prod.sh
   ```

## Finding Your Local IP Address

For Android, iOS (physical device), and Kiosk (remote device), you need your computer's local IP address:

```bash
ip addr show | grep "inet " | grep -v 127.0.0.1
```

Look for the IP address on `wlan0` (Wi-Fi) interface, typically something like `192.168.0.107`.

## Getting Your Local Supabase Key

```bash
cd infra/supabase
supabase status
```

Look for "Publishable key" or "anon key" in the output.

## Script Usage

All scripts automatically load `.env` files based on priority:

### Build Scripts

```bash
# Web build (uses .env.web, .env.local, or .env)
./scripts/build_web.sh

# Android build (uses .env.android, .env.local, or .env)
./scripts/build_mobile_android.sh apk

# iOS build (uses .env.ios, .env.local, or .env)
./scripts/build_mobile_ios.sh

# Kiosk build (uses .env.kiosk, .env.local, or .env)
./scripts/build_kiosk.sh

# Production build (uses .env.production)
./scripts/build_prod.sh
```

### Development Scripts

```bash
# Local development (auto-detects Supabase, .env as fallback)
./scripts/run_local.sh

# Android testing (uses .env.android, .env.local, or .env)
./scripts/test_android.sh
```

## Overriding Environment Variables

You can still override `.env` files with command-line exports:

```bash
# Override .env for a single build
export SUPABASE_URL=https://custom-url.supabase.co
./scripts/build_web.sh
```

## Troubleshooting

### Scripts not finding .env

- Make sure `.env` is in the `dashboard/` directory (same level as `scripts/`)
- Check file permissions: `chmod 644 .env`
- Verify `.env` has correct format (no spaces around `=`)
- Use the setup script: `./scripts/setup_env.sh [platform]`

### Wrong environment being used

- Check file priority: `.env.local` > `.env.{platform}` > `.env` > `.env.production`
- Remove `.env.local` if you want to use platform-specific file
- Check for typos in variable names
- Verify which file is loaded (scripts print the loaded file)

### Android/iOS can't connect to local Supabase

- Use your computer's IP address, not `127.0.0.1`
- Make sure phone and computer are on the same network
- Check firewall settings (allow port 54321)
- Verify Supabase is running: `cd infra/supabase && supabase status`
- Test connection: `curl http://YOUR_IP:54321`

### Setup script fails

- Make sure Supabase is running: `cd infra/supabase && supabase start`
- Check network connection for IP detection
- Verify script is executable: `chmod +x scripts/setup_env.sh`

## Security Best Practices

- ✅ `.env` files are in `.gitignore` (won't be committed)
- ✅ Never commit `.env` files with real credentials
- ✅ Use `.env.example` files as templates (safe to commit)
- ✅ Use different keys for local, staging, and production
- ✅ Rotate keys regularly
- ✅ Keep production keys secure
- ✅ Use `.env.local` for sensitive local overrides

## File Structure

```
dashboard/
├── env.example              # Main example file
├── env.example.web          # Web development example
├── env.example.android      # Android testing example
├── env.example.ios          # iOS testing example
├── env.example.kiosk        # Kiosk mode example
├── env.example.production   # Production example
├── .env                     # General configuration (not committed)
├── .env.local               # Local overrides (not committed)
├── .env.web                 # Web-specific (not committed)
├── .env.android             # Android-specific (not committed)
├── .env.ios                 # iOS-specific (not committed)
├── .env.kiosk               # Kiosk-specific (not committed)
└── .env.production          # Production (not committed)
```

## See Also

- [ENV_SETUP.md](./ENV_SETUP.md) - Detailed environment setup guide
- [ANDROID_SETUP.md](./ANDROID_SETUP.md) - Android testing setup
- [PLATFORM_GUIDE.md](./PLATFORM_GUIDE.md) - Multi-platform development guide
- [QUICKSTART.md](./QUICKSTART.md) - Quick start guide
- [scripts/README.md](../scripts/README.md) - Scripts documentation

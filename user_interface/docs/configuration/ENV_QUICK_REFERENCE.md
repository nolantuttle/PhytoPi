# Environment Variables Quick Reference

## Quick Setup

```bash
# Setup for your platform
./scripts/setup_env.sh [web|android|ios|kiosk|production]
```

## File Priority

1. `.env.local` (highest priority)
2. `.env.{platform}` (platform-specific)
3. `.env` (general)
4. `.env.production` (production)

## Platform Configuration

### Web Development
```bash
# File: .env or .env.web
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_ANON_KEY=your-local-anon-key
```

### Android Testing
```bash
# File: .env.local or .env.android
SUPABASE_URL=http://192.168.0.107:54321  # Your local IP
SUPABASE_ANON_KEY=your-local-anon-key
```

### iOS Testing
```bash
# File: .env.local or .env.ios
# Simulator:
SUPABASE_URL=http://127.0.0.1:54321
# Physical Device:
SUPABASE_URL=http://192.168.0.107:54321  # Your local IP
SUPABASE_ANON_KEY=your-local-anon-key
```

### Kiosk Mode
```bash
# File: .env.local or .env.kiosk
# Same Machine:
SUPABASE_URL=http://127.0.0.1:54321
# Remote Device:
SUPABASE_URL=http://192.168.0.107:54321  # Your local IP
SUPABASE_ANON_KEY=your-local-anon-key
KIOSK_MODE=true
```

### Production
```bash
# File: .env.production
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-production-anon-key
```

## Finding Your Local IP

```bash
ip addr show | grep "inet " | grep -v 127.0.0.1
```

Look for the IP on `wlan0` (Wi-Fi) interface, typically `192.168.0.107` or similar.

## Getting Your Local Supabase Key

```bash
cd infra/supabase
supabase status
```

Look for "Publishable key" or "anon key" in the output.

## Common Commands

```bash
# Setup environment
./scripts/setup_env.sh web
./scripts/setup_env.sh android
./scripts/setup_env.sh ios
./scripts/setup_env.sh kiosk
./scripts/setup_env.sh production

# Run locally (web)
./scripts/run_local.sh

# Test Android
./scripts/test_android.sh

# Build
./scripts/build_web.sh
./scripts/build_mobile_android.sh apk
./scripts/build_mobile_ios.sh
./scripts/build_kiosk.sh
./scripts/build_prod.sh
```

## Troubleshooting

### Android/iOS can't connect
- Use your computer's IP, not `127.0.0.1`
- Ensure device and computer are on the same Wi-Fi
- Check firewall allows port 54321
- Verify Supabase is running: `cd infra/supabase && supabase status`

### Wrong environment loaded
- Check file priority: `.env.local` > `.env.{platform}` > `.env` > `.env.production`
- Remove `.env.local` to use platform-specific file
- Verify which file is loaded (scripts print the loaded file)

### Setup script fails
- Make sure Supabase is running: `cd infra/supabase && supabase start`
- Check network connection for IP detection
- Verify script is executable: `chmod +x scripts/setup_env.sh`

## See Also

- [ENV_WORKFLOW.md](./ENV_WORKFLOW.md) - Detailed workflow guide
- [ENV_SETUP.md](./ENV_SETUP.md) - Detailed setup guide
- [scripts/README.md](../scripts/README.md) - Scripts documentation


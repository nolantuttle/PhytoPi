# Environment Variables Setup

This project uses `.env` files to manage environment variables for different environments.

## Quick Start

1. **Copy the example file:**
   ```bash
   cd dashboard
   cp env.example .env
   ```

2. **Edit `.env` with your values:**
   ```bash
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-anon-key-here
   ```

3. **That's it!** Scripts will automatically load from `.env`

## File Priority

The `load_env.sh` script loads environment variables in this order (first found wins):

1. `.env.local` - Local development overrides (highest priority)
2. `.env` - General configuration
3. `.env.production` - Production configuration

## Usage in Scripts

All build and test scripts automatically load `.env` files:

```bash
# Android testing
./scripts/test_android.sh

# Build Android APK
./scripts/build_mobile_android.sh apk

# Build web
./scripts/build_web.sh
```

## Manual Loading

To manually load environment variables in your shell:

```bash
source scripts/load_env.sh
```

This will:
- Load variables from `.env` files
- Set up Android SDK paths (if installed)
- Export all variables to your current shell

## Environment Variables

### Required for Mobile/Web

- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_ANON_KEY` - Your Supabase anonymous key

### Optional

- `ANDROID_HOME` - Android SDK location (auto-detected)
- `ANDROID_SDK_ROOT` - Android SDK root (auto-detected)
- `KIOSK_MODE` - Set to `true` for kiosk builds

## Security

- ✅ `.env` files are in `.gitignore` and won't be committed
- ✅ Never commit `.env` files with real credentials
- ✅ Use `.env.example` as a template (safe to commit)

## Examples

### Local Development
```bash
# .env
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Production
```bash
# .env.production
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Override Locally
```bash
# .env.local (overrides .env)
SUPABASE_URL=http://localhost:54321
SUPABASE_ANON_KEY=local-dev-key
```


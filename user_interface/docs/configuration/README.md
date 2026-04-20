# Configuration

This directory contains guides for configuring environment variables and settings.

## Documentation

### [ENV_QUICK_REFERENCE.md](./ENV_QUICK_REFERENCE.md)
Quick reference for environment variables.

### [ENV_WORKFLOW.md](./ENV_WORKFLOW.md)
Environment variables workflow for all platforms.

### [ENV_SETUP.md](./ENV_SETUP.md)
Detailed environment variables configuration guide.

## Environment Files

Environment example files are located in the project root:
- `env.example` - Main example file
- `env.example.web` - Web development
- `env.example.android` - Android testing
- `env.example.ios` - iOS testing
- `env.example.kiosk` - Kiosk mode
- `env.example.production` - Production builds

## Quick Setup

```bash
# Setup for your platform
./scripts/utils/setup_env.sh [web|android|ios|kiosk|production]
```

## See Also

- [../README.md](../README.md) - Documentation index
- [../../scripts/utils/README.md](../../scripts/utils/README.md) - Utility scripts
- [Getting Started Guides](../getting-started/) - Getting started guides


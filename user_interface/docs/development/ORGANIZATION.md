# Dashboard Directory Organization

This document describes the organization of the PhytoPi Dashboard directory structure.

## Directory Structure

```
dashboard/
├── README.md                 # Main project README
├── pubspec.yaml              # Flutter dependencies
├── analysis_options.yaml     # Dart analysis options
├── vercel.json               # Vercel deployment config
├── env.example               # Environment variables template
│
├── docs/                     # 📚 All documentation
│   ├── README.md            # Documentation index
│   ├── QUICKSTART.md        # Quick start guide
│   ├── setup.md             # Setup instructions
│   ├── ENV_SETUP.md         # Environment variables
│   ├── PLATFORM_GUIDE.md    # Multi-platform guide
│   ├── MULTI_PLATFORM.md    # Platform setup
│   ├── ANDROID_SETUP.md     # Android testing
│   ├── KIOSK_DEPLOYMENT.md  # Raspberry Pi deployment
│   ├── DEPLOYMENT.md        # Deployment guide
│   └── IMPLEMENTATION_SUMMARY.md  # Architecture details
│
├── scripts/                  # 🔧 Build and utility scripts
│   ├── README.md            # Scripts documentation
│   ├── load_env.sh          # Environment loader
│   ├── run_local.sh         # Local development
│   ├── test_android.sh      # Android testing
│   ├── build.sh             # Vercel build
│   ├── build_prod.sh        # Production build
│   ├── build_web.sh         # Web build
│   ├── build_mobile_android.sh  # Android build
│   ├── build_mobile_ios.sh  # iOS build
│   └── build_kiosk.sh       # Kiosk build
│
├── lib/                      # 💻 Source code
│   ├── main.dart
│   ├── core/
│   ├── features/
│   └── shared/
│
├── web/                      # 🌐 Web assets
├── test/                     # 🧪 Tests
└── build/                    # 🏗️ Build output (gitignored)
```

## Organization Principles

### Root Directory
Contains only essential project files:
- Configuration files (pubspec.yaml, analysis_options.yaml, vercel.json)
- Main README.md
- Environment template (env.example)

### docs/ Directory
All documentation files are organized here:
- **Getting Started**: QUICKSTART.md, setup.md, ENV_SETUP.md
- **Platform Guides**: PLATFORM_GUIDE.md, MULTI_PLATFORM.md, ANDROID_SETUP.md, KIOSK_DEPLOYMENT.md
- **Deployment**: DEPLOYMENT.md
- **Development**: IMPLEMENTATION_SUMMARY.md

### scripts/ Directory
All executable scripts:
- Environment utilities (load_env.sh)
- Development scripts (run_local.sh, test_android.sh)
- Build scripts (build_*.sh)

### Benefits

1. **Cleaner root directory** - Easy to find essential files
2. **Organized documentation** - All guides in one place
3. **Centralized scripts** - All scripts in scripts/ directory
4. **Better navigation** - Clear structure for new developers
5. **Scalable** - Easy to add new docs or scripts

## File Locations

### Documentation
- All markdown guides → `docs/`
- Main README → Root `README.md`
- Scripts docs → `scripts/README.md`

### Scripts
- All shell scripts → `scripts/`
- Test scripts → `scripts/test_android.sh`
- Build scripts → `scripts/build_*.sh`

### Configuration
- Environment template → `env.example` (root)
- Flutter config → `pubspec.yaml` (root)
- Analysis config → `analysis_options.yaml` (root)

## Quick Reference

**Need documentation?** → Check `docs/README.md`

**Need to run a script?** → Check `scripts/README.md`

**Setting up environment?** → See `docs/ENV_SETUP.md`

**Testing Android?** → Run `./scripts/test_android.sh`


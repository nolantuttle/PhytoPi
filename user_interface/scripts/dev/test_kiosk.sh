#!/bin/bash
# Quick script to test Kiosk setup and run the app (locally or on Raspberry Pi 5)
# Usage: ./scripts/dev/test_kiosk.sh [--pi5 <hostname>] [--user <username>] [--no-transfer]

# Navigate to dashboard directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Script is in scripts/dev, so go up two levels to get to dashboard
DASHBOARD_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$DASHBOARD_DIR"

# Parse arguments
PI5_HOST=""
PI5_USER="pi"
TRANSFER_TO_PI5=false
TEST_LOCAL=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --pi5)
            PI5_HOST="$2"
            TRANSFER_TO_PI5=true
            TEST_LOCAL=false
            shift 2
            ;;
        --user)
            PI5_USER="$2"
            shift 2
            ;;
        --no-transfer)
            TRANSFER_TO_PI5=false
            TEST_LOCAL=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --pi5 <hostname>    Transfer and test on Raspberry Pi 5 (e.g., raspberrypi.local)"
            echo "  --user <username>   SSH username for Pi5 (default: pi)"
            echo "  --no-transfer       Test locally only, don't transfer to Pi5"
            echo "  --help              Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                  # Test locally"
            echo "  $0 --pi5 raspberrypi.local  # Transfer and test on Pi5"
            echo "  $0 --pi5 192.168.1.100 --user myuser  # Custom IP and user"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Load environment variables from .env files
UTILS_DIR="$(cd "$DASHBOARD_DIR/scripts/utils" && pwd)"
if [ -f "$UTILS_DIR/load_env.sh" ]; then
    export PLATFORM="kiosk"
    source "$UTILS_DIR/load_env.sh"
else
    echo "⚠️  load_env.sh not found, using defaults"
fi

echo "🖥️  Kiosk Testing Setup"
echo "======================"
echo ""

# Check Flutter
echo "🔍 Checking Flutter..."
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found in PATH"
    echo "   Install Flutter: https://docs.flutter.dev/get-started/install"
    exit 1
fi

# Check Linux desktop support
echo "🔍 Checking Linux desktop support..."
if ! flutter doctor -v | grep -q "linux"; then
    echo "⚠️  Linux desktop support may not be enabled"
    echo "   Enable it with: flutter config --enable-linux-desktop"
    echo ""
    read -p "   Continue anyway? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "✅ Linux desktop support enabled"
fi

echo "📋 Flutter version:"
flutter --version | head -1
echo ""

# Check if Supabase vars are set
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
    echo "❌ Error: SUPABASE_URL or SUPABASE_ANON_KEY not set"
    echo ""
    echo "   Run setup script: ./scripts/utils/setup_env.sh kiosk"
    echo "   Or create .env.kiosk or .env.local with:"
    echo "   SUPABASE_URL=http://192.168.0.107:54321  # Your local IP"
    echo "   SUPABASE_ANON_KEY=your-local-anon-key"
    echo ""
    echo "   Find your IP: ip addr show | grep 'inet ' | grep -v 127.0.0.1"
    exit 1
fi

echo "📋 Configuration:"
echo "   SUPABASE_URL: $SUPABASE_URL"
echo "   SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY:0:20}..."
echo "   KIOSK_MODE: ${KIOSK_MODE:-true}"
echo ""

# Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Build the kiosk app
echo ""
echo "🔨 Building kiosk app..."
BUILD_SCRIPT="$DASHBOARD_DIR/scripts/build/build_kiosk.sh"
if [ ! -f "$BUILD_SCRIPT" ]; then
    echo "❌ Build script not found: $BUILD_SCRIPT"
    exit 1
fi

if ! bash "$BUILD_SCRIPT"; then
    echo "❌ Build failed"
    exit 1
fi

BUNDLE_DIR="$DASHBOARD_DIR/build/linux/x64/release/bundle"
if [ ! -d "$BUNDLE_DIR" ]; then
    echo "❌ Build output not found: $BUNDLE_DIR"
    exit 1
fi

echo ""
echo "✅ Build complete!"
echo "📊 Build size:"
du -sh "$BUNDLE_DIR" || true
echo ""

# Determine what to do
if [ "$TRANSFER_TO_PI5" = true ] && [ -n "$PI5_HOST" ]; then
    # Transfer to Pi5
    echo "📤 Transferring to Raspberry Pi 5..."
    echo "   Host: $PI5_USER@$PI5_HOST"
    echo ""
    
    # Check SSH connection
    echo "🔍 Testing SSH connection..."
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$PI5_USER@$PI5_HOST" exit 2>/dev/null; then
        echo "❌ Cannot connect to $PI5_USER@$PI5_HOST"
        echo ""
        echo "   Make sure:"
        echo "   1. SSH is enabled on Pi5: sudo systemctl enable ssh"
        echo "   2. You can connect manually: ssh $PI5_USER@$PI5_HOST"
        echo "   3. SSH keys are set up (or use password authentication)"
        echo ""
        read -p "   Try connecting anyway? (y/N) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        echo "✅ SSH connection successful"
    fi
    
    # Create temporary archive
    echo ""
    echo "📦 Creating archive..."
    TEMP_ARCHIVE=$(mktemp -t phytopi-kiosk-XXXXXX.tar.gz)
    tar -czf "$TEMP_ARCHIVE" -C "$DASHBOARD_DIR/build/linux/x64/release" bundle
    
    # Transfer archive
    echo "📤 Transferring archive to Pi5..."
    REMOTE_DIR="~/phytopi-kiosk"
    if ! scp "$TEMP_ARCHIVE" "$PI5_USER@$PI5_HOST:~/phytopi-kiosk.tar.gz"; then
        echo "❌ Transfer failed"
        rm -f "$TEMP_ARCHIVE"
        exit 1
    fi
    
    # Clean up local archive
    rm -f "$TEMP_ARCHIVE"
    
    # Extract and run on Pi5
    echo ""
    echo "📥 Extracting on Pi5..."
    ssh "$PI5_USER@$PI5_HOST" << EOF
        mkdir -p $REMOTE_DIR
        cd $REMOTE_DIR
        tar -xzf ~/phytopi-kiosk.tar.gz
        rm ~/phytopi-kiosk.tar.gz
        chmod +x bundle/phytopi_dashboard
        
        # Check dependencies
        echo ""
        echo "🔍 Checking dependencies on Pi5..."
        MISSING_DEPS=""
        for lib in libgtk-3-0 libbluetooth1 libdbus-1-3 libxkbcommon0 libx11-6; do
            if ! dpkg -l | grep -q "^ii.*$lib"; then
                MISSING_DEPS="\$MISSING_DEPS $lib"
            fi
        done
        
        if [ -n "\$MISSING_DEPS" ]; then
            echo "⚠️  Missing dependencies:\$MISSING_DEPS"
            echo ""
            echo "   Install with:"
            echo "   sudo apt update && sudo apt install -y\$MISSING_DEPS"
            echo ""
            read -p "   Continue anyway? (y/N) " -n 1 -r
            echo ""
            if [[ ! \$REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        else
            echo "✅ All dependencies installed"
        fi
        
        # Set environment variables
        export SUPABASE_URL="$SUPABASE_URL"
        export SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
        export KIOSK_MODE="true"
        export DISPLAY=:0
        
        echo ""
        echo "🚀 Running kiosk app on Pi5..."
        echo "   (Press Ctrl+C to stop)"
        echo ""
        
        cd bundle
        ./phytopi_dashboard
EOF
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ Kiosk app ran successfully on Pi5"
    else
        echo ""
        echo "❌ Kiosk app failed on Pi5"
        echo ""
        echo "   Troubleshooting:"
        echo "   1. Check logs on Pi5: ssh $PI5_USER@$PI5_HOST 'journalctl -u phytopi-kiosk.service -n 50'"
        echo "   2. Test manually: ssh $PI5_USER@$PI5_HOST 'cd ~/phytopi-kiosk/bundle && ./phytopi_dashboard'"
        echo "   3. Check dependencies: ssh $PI5_USER@$PI5_HOST 'ldd ~/phytopi-kiosk/bundle/phytopi_dashboard | grep \"not found\"'"
        exit 1
    fi
    
elif [ "$TEST_LOCAL" = true ]; then
    # Test locally
    echo "🖥️  Testing locally..."
    echo ""
    
    # Check if we're on Linux
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        echo "⚠️  Warning: Not running on Linux"
        echo "   The kiosk app is built for Linux. You can:"
        echo "   1. Test on a Linux machine"
        echo "   2. Transfer to Pi5: $0 --pi5 raspberrypi.local"
        echo ""
        read -p "   Try running anyway? (y/N) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check dependencies locally
    echo "🔍 Checking local dependencies..."
    MISSING_DEPS=""
    if command -v dpkg &> /dev/null; then
        for lib in libgtk-3-0 libbluetooth1 libdbus-1-3 libxkbcommon0 libx11-6; do
            if ! dpkg -l 2>/dev/null | grep -q "^ii.*$lib"; then
                MISSING_DEPS="$MISSING_DEPS $lib"
            fi
        done
    fi
    
    if [ -n "$MISSING_DEPS" ]; then
        echo "⚠️  Missing dependencies:$MISSING_DEPS"
        echo "   Install with: sudo apt install -y$MISSING_DEPS"
        echo ""
        read -p "   Continue anyway? (y/N) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        echo "✅ Dependencies available"
    fi
    
    # Set environment variables
    export SUPABASE_URL
    export SUPABASE_ANON_KEY
    export KIOSK_MODE="${KIOSK_MODE:-true}"
    
    echo ""
    echo "🚀 Running kiosk app locally..."
    echo "   (Press Ctrl+C to stop)"
    echo ""
    
    cd "$BUNDLE_DIR"
    if ! ./phytopi_dashboard; then
        echo ""
        echo "❌ Kiosk app failed to run"
        echo ""
        echo "   Troubleshooting:"
        echo "   1. Check dependencies: ldd ./phytopi_dashboard | grep \"not found\""
        echo "   2. Check permissions: chmod +x ./phytopi_dashboard"
        echo "   3. Check environment variables:"
        echo "      echo \$SUPABASE_URL"
        echo "      echo \$SUPABASE_ANON_KEY"
        echo "      echo \$KIOSK_MODE"
        exit 1
    fi
else
    echo "❌ No action specified"
    echo "   Use --pi5 <hostname> to transfer to Pi5"
    echo "   Or test locally by default"
    exit 1
fi

echo ""
echo "✅ Test complete!"


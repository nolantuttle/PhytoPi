#!/bin/bash
# Setup environment files for different platforms
# Usage: ./scripts/utils/setup_env.sh [web|android|ios|kiosk|production]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Script is in scripts/utils, so go up two levels to get to dashboard
DASHBOARD_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_ROOT="$(cd "$DASHBOARD_DIR/.." && pwd)"
SUPABASE_DIR="$PROJECT_ROOT/infra/supabase"

PLATFORM="${1:-web}"

echo "🌱 PhytoPi Environment Setup"
echo "============================"
echo ""

# Function to get local IP address
get_local_ip() {
    ip addr show | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}' | cut -d'/' -f1
}

# Function to get Supabase anon key
get_supabase_key() {
    if [ -d "$SUPABASE_DIR" ]; then
        cd "$SUPABASE_DIR"
        STATUS_OUTPUT=$(supabase status 2>&1 || true)
        if echo "$STATUS_OUTPUT" | grep -q "Publishable key"; then
            echo "$STATUS_OUTPUT" | grep -i "Publishable key" | awk -F': ' '{print $2}' | tr -d '[:space:]' | head -1
        elif echo "$STATUS_OUTPUT" | grep -q "anon key"; then
            echo "$STATUS_OUTPUT" | grep -i "anon key" | awk '{print $NF}' | head -1
        fi
    fi
}

# Function to setup web environment
setup_web() {
    echo "📱 Setting up Web development environment..."
    echo ""
    
    ENV_FILE="$DASHBOARD_DIR/.env"
    EXAMPLE_FILE="$DASHBOARD_DIR/env.example.web"
    
    if [ -f "$ENV_FILE" ]; then
        echo "⚠️  .env already exists. Backing up to .env.backup"
        cp "$ENV_FILE" "$DASHBOARD_DIR/.env.backup"
    fi
    
    cp "$EXAMPLE_FILE" "$ENV_FILE"
    
    # Get Supabase key if available
    SUPABASE_KEY=$(get_supabase_key)
    if [ -n "$SUPABASE_KEY" ]; then
        sed -i "s/your-local-anon-key-here/$SUPABASE_KEY/" "$ENV_FILE"
        echo "✅ Added Supabase key from local instance"
    else
        echo "⚠️  Could not get Supabase key. Please edit .env manually."
        echo "   Run: cd infra/supabase && supabase status"
    fi
    
    echo "✅ Created .env for web development"
    echo "   File: $ENV_FILE"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Review .env and update if needed"
    echo "   2. Run: ./scripts/dev/run_local.sh"
}

# Function to setup Android environment
setup_android() {
    echo "📱 Setting up Android development environment..."
    echo ""
    
    LOCAL_IP=$(get_local_ip)
    if [ -z "$LOCAL_IP" ]; then
        echo "❌ Could not detect local IP address"
        echo "   Please set SUPABASE_URL manually in .env.local"
        exit 1
    fi
    
    ENV_FILE="$DASHBOARD_DIR/.env.local"
    EXAMPLE_FILE="$DASHBOARD_DIR/env.example.android"
    
    if [ -f "$ENV_FILE" ]; then
        echo "⚠️  .env.local already exists. Backing up to .env.local.backup"
        cp "$ENV_FILE" "$DASHBOARD_DIR/.env.local.backup"
    fi
    
    cp "$EXAMPLE_FILE" "$ENV_FILE"
    
    # Replace IP address
    sed -i "s/192.168.0.107/$LOCAL_IP/" "$ENV_FILE"
    echo "✅ Set SUPABASE_URL to http://$LOCAL_IP:54321"
    
    # Get Supabase key if available
    SUPABASE_KEY=$(get_supabase_key)
    if [ -n "$SUPABASE_KEY" ]; then
        sed -i "s/your-local-anon-key-here/$SUPABASE_KEY/" "$ENV_FILE"
        echo "✅ Added Supabase key from local instance"
    else
        echo "⚠️  Could not get Supabase key. Please edit .env.local manually."
        echo "   Run: cd infra/supabase && supabase status"
    fi
    
    echo "✅ Created .env.local for Android development"
    echo "   File: $ENV_FILE"
    echo "   IP: $LOCAL_IP"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Ensure phone and computer are on the same Wi-Fi network"
    echo "   2. Check firewall allows port 54321"
    echo "   3. Run: ./scripts/dev/test_android.sh"
}

# Function to setup iOS environment
setup_ios() {
    echo "📱 Setting up iOS development environment..."
    echo ""
    
    LOCAL_IP=$(get_local_ip)
    if [ -z "$LOCAL_IP" ]; then
        echo "❌ Could not detect local IP address"
        echo "   Please set SUPABASE_URL manually in .env.ios"
        exit 1
    fi
    
    ENV_FILE="$DASHBOARD_DIR/.env.ios"
    EXAMPLE_FILE="$DASHBOARD_DIR/env.example.ios"
    
    if [ -f "$ENV_FILE" ]; then
        echo "⚠️  .env.ios already exists. Backing up to .env.ios.backup"
        cp "$ENV_FILE" "$DASHBOARD_DIR/.env.ios.backup"
    fi
    
    cp "$EXAMPLE_FILE" "$ENV_FILE"
    
    # Replace IP address
    sed -i "s/192.168.0.107/$LOCAL_IP/" "$ENV_FILE"
    echo "✅ Set SUPABASE_URL to http://$LOCAL_IP:54321"
    echo "   Note: For iOS Simulator, you can use localhost instead"
    
    # Get Supabase key if available
    SUPABASE_KEY=$(get_supabase_key)
    if [ -n "$SUPABASE_KEY" ]; then
        sed -i "s/your-local-anon-key-here/$SUPABASE_KEY/" "$ENV_FILE"
        echo "✅ Added Supabase key from local instance"
    else
        echo "⚠️  Could not get Supabase key. Please edit .env.ios manually."
        echo "   Run: cd infra/supabase && supabase status"
    fi
    
    echo "✅ Created .env.ios for iOS development"
    echo "   File: $ENV_FILE"
    echo "   IP: $LOCAL_IP"
    echo ""
    echo "📋 Next steps:"
    echo "   1. For iOS Simulator: Change SUPABASE_URL to http://127.0.0.1:54321"
    echo "   2. For physical device: Ensure device and computer are on the same Wi-Fi"
    echo "   3. Check firewall allows port 54321"
    echo "   4. Run: ./scripts/build/build_mobile_ios.sh"
}

# Function to setup kiosk environment
setup_kiosk() {
    echo "📱 Setting up Kiosk development environment..."
    echo ""
    
    LOCAL_IP=$(get_local_ip)
    if [ -z "$LOCAL_IP" ]; then
        echo "❌ Could not detect local IP address"
        echo "   Please set SUPABASE_URL manually in .env.kiosk"
        exit 1
    fi
    
    ENV_FILE="$DASHBOARD_DIR/.env.kiosk"
    EXAMPLE_FILE="$DASHBOARD_DIR/env.example.kiosk"
    
    if [ -f "$ENV_FILE" ]; then
        echo "⚠️  .env.kiosk already exists. Backing up to .env.kiosk.backup"
        cp "$ENV_FILE" "$DASHBOARD_DIR/.env.kiosk.backup"
    fi
    
    cp "$EXAMPLE_FILE" "$ENV_FILE"
    
    # Replace IP address
    sed -i "s/192.168.0.107/$LOCAL_IP/" "$ENV_FILE"
    echo "✅ Set SUPABASE_URL to http://$LOCAL_IP:54321"
    echo "   Note: For same machine, you can use localhost instead"
    
    # Get Supabase key if available
    SUPABASE_KEY=$(get_supabase_key)
    if [ -n "$SUPABASE_KEY" ]; then
        sed -i "s/your-local-anon-key-here/$SUPABASE_KEY/" "$ENV_FILE"
        echo "✅ Added Supabase key from local instance"
    else
        echo "⚠️  Could not get Supabase key. Please edit .env.kiosk manually."
        echo "   Run: cd infra/supabase && supabase status"
    fi
    
    echo "✅ Created .env.kiosk for kiosk development"
    echo "   File: $ENV_FILE"
    echo "   IP: $LOCAL_IP"
    echo ""
    echo "📋 Next steps:"
    echo "   1. For same machine: Change SUPABASE_URL to http://127.0.0.1:54321"
    echo "   2. For remote device: Ensure device and computer are on the same network"
    echo "   3. Check firewall allows port 54321"
    echo "   4. Run: ./scripts/build/build_kiosk.sh"
}

# Function to setup production environment
setup_production() {
    echo "📱 Setting up Production environment..."
    echo ""
    
    ENV_FILE="$DASHBOARD_DIR/.env.production"
    EXAMPLE_FILE="$DASHBOARD_DIR/env.example.production"
    
    if [ -f "$ENV_FILE" ]; then
        echo "⚠️  .env.production already exists. Backing up to .env.production.backup"
        cp "$ENV_FILE" "$DASHBOARD_DIR/.env.production.backup"
    fi
    
    cp "$EXAMPLE_FILE" "$ENV_FILE"
    
    echo "✅ Created .env.production"
    echo "   File: $ENV_FILE"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Edit .env.production with your production Supabase credentials"
    echo "   2. Set SUPABASE_URL=https://your-project.supabase.co"
    echo "   3. Set SUPABASE_ANON_KEY=your-production-anon-key"
    echo "   4. Run: ./scripts/build/build_prod.sh"
    echo ""
    echo "⚠️  Security reminder:"
    echo "   - Never commit .env.production to version control"
    echo "   - Use different keys for staging and production"
    echo "   - Keep production keys secure"
}

# Main setup logic
case "$PLATFORM" in
    web)
        setup_web
        ;;
    android)
        setup_android
        ;;
    ios)
        setup_ios
        ;;
    kiosk)
        setup_kiosk
        ;;
    production)
        setup_production
        ;;
    *)
        echo "❌ Unknown platform: $PLATFORM"
        echo ""
        echo "Usage: ./scripts/utils/setup_env.sh [web|android|ios|kiosk|production]"
        echo ""
        echo "Platforms:"
        echo "  web        - Web development (localhost)"
        echo "  android    - Android device testing (local network IP)"
        echo "  ios        - iOS device testing (local network IP)"
        echo "  kiosk      - Kiosk mode (local network IP)"
        echo "  production - Production builds (cloud Supabase)"
        exit 1
        ;;
esac

echo ""
echo "✅ Environment setup complete!"


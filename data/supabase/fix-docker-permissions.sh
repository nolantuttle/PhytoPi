#!/bin/bash
# Fix Docker permissions for Supabase local development
# Run this script with: bash fix-docker-permissions.sh
# Used to fix Docker permissions for Supabase local development when updating supabase cli to latest version

echo "🔧 Fixing Docker permissions for Supabase..."
echo ""

# Check if user is already in docker group
if groups | grep -q docker; then
    echo "✅ User is already in docker group"
else
    echo "📝 Adding user to docker group (requires sudo)..."
    sudo usermod -aG docker $USER
    echo "✅ User added to docker group"
fi

echo ""
echo "📋 Next steps:"
echo "1. Run: newgrp docker"
echo "   (This starts a new shell with the docker group activated)"
echo ""
echo "2. Then verify with:"
echo "   docker ps"
echo "   cd /home/danielg/Documents/PhytoPi/infra/supabase"
echo "   supabase start"
echo ""
echo "Alternatively, log out and log back in instead of using 'newgrp docker'"


#!/bin/bash
#pi-controller/run.sh
# Get the directory where this script is located
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Load environment variables from .env file
if [ -f "$DIR/.env" ]; then
    # Export variables ignoring comments
    export $(grep -v '^#' "$DIR/.env" | xargs)
fi

# Run the application
echo "Starting PhytoPi Controller..."
"$DIR/bin/phytopi"
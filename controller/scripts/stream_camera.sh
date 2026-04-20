#!/bin/bash
# Stream camera video to TCP port 8888
# Supports rpicam (Bookworm), libcamera (Bullseye), and legacy raspivid

PORT=8888

# Check for rpicam-vid (Newest OS - Bookworm) or libcamera-vid (Bullseye)
if command -v rpicam-vid &> /dev/null; then
    CAM_TOOL="rpicam-vid"
elif command -v libcamera-vid &> /dev/null; then
    CAM_TOOL="libcamera-vid"
fi

if [ -n "$CAM_TOOL" ]; then
    echo "Found modern camera tool: $CAM_TOOL"
    echo "Starting stream on port $PORT..."
    echo "To view on your computer, use VLC Media Player:"
    echo "  Media -> Open Network Stream -> tcp/h264://<PI_IP>:$PORT"
    
    # -t 0: Run forever
    # --inline: Insert SPS/PPS headers (needed for streaming)
    # --listen: Listen for incoming connection
    # --width 1280 --height 720: Standard HD resolution
    $CAM_TOOL -t 0 --inline --listen --width 1280 --height 720 -o tcp://0.0.0.0:$PORT

# Check for raspivid (Legacy OS - Buster/Old)
elif command -v raspivid &> /dev/null; then
    echo "Found legacy raspivid. Starting stream on port $PORT..."
    echo "To view on your computer, use VLC Media Player:"
    echo "  Media -> Open Network Stream -> tcp/h264://<PI_IP>:$PORT"
    
    # -t 0: Run forever
    # -l: Listen on TCP
    # -w 1280 -h 720: HD resolution
    raspivid -t 0 -l -w 1280 -h 720 -o tcp://0.0.0.0:$PORT

else
    echo "Error: No compatible camera streaming tool found."
    echo "Checked for: rpicam-vid, libcamera-vid, raspivid"
    echo "Please ensure you have 'rpicam-apps' or 'libcamera-apps' installed."
    exit 1
fi
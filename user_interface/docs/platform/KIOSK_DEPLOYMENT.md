# PhytoPi Kiosk Mode Deployment Guide

This guide covers deploying the PhytoPi Flutter app in kiosk mode on Linux systems, particularly Raspberry Pi.

## Overview

Kiosk mode provides a fullscreen, dedicated display experience optimized for:
- Public displays
- Raspberry Pi installations
- Automated monitoring dashboards
- Touchscreen interfaces

## Prerequisites

1. **Raspberry Pi** (or Linux desktop) with:
   - Raspberry Pi OS (or compatible Linux distribution)
   - Minimum 2GB RAM
   - SD card with at least 8GB storage
   - Network connection

2. **Flutter Linux Desktop Support**
   - Flutter SDK installed on build machine
   - Linux desktop support enabled: `flutter config --enable-linux-desktop`

3. **Build Machine**
   - Linux, macOS, or Windows with Flutter installed
   - Cross-compilation support (or build directly on Raspberry Pi)

## Building for Kiosk Mode

### 1. Set Environment Variables

```bash
export SUPABASE_URL=https://your-project.supabase.co
export SUPABASE_ANON_KEY=your-anon-key
export KIOSK_MODE=true
```

### 2. Build the App

```bash
cd dashboard
./scripts/build_kiosk.sh
```

This creates a Linux bundle in `build/linux/x64/release/bundle/`.

### 3. Transfer to Raspberry Pi

```bash
# Compress the bundle
tar -czf phytopi-kiosk.tar.gz -C build/linux/x64/release bundle

# Transfer to Raspberry Pi
scp phytopi-kiosk.tar.gz pi@raspberrypi.local:~/

# On Raspberry Pi, extract
ssh pi@raspberrypi.local
tar -xzf phytopi-kiosk.tar.gz
```

## Raspberry Pi Setup

### 1. Install Dependencies

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required dependencies
sudo apt install -y \
    libgtk-3-0 \
    libbluetooth1 \
    libdbus-1-3 \
    libxkbcommon0 \
    libx11-6 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxi6 \
    libxrandr2 \
    libxrender1 \
    libxss1 \
    libxtst6
```

### 2. Configure Display

#### Set Resolution (if needed)

```bash
# Edit config.txt
sudo nano /boot/config.txt

# Add or modify:
hdmi_group=2
hdmi_mode=82  # 1920x1080 60Hz
```

#### Disable Screen Blanking

```bash
# Edit boot config
sudo nano /boot/config.txt

# Add:
hdmi_blanking=1
```

#### Configure X11 (for desktop environment)

```bash
# Disable screen saver
sudo nano /etc/xdg/lxsession/LXDE-pi/autostart

# Add:
@xset s off
@xset -dpms
@xset s noblank
```

### 3. Set Up Autostart

#### Option A: Systemd Service (Recommended)

Create a systemd service file:

```bash
sudo nano /etc/systemd/system/phytopi-kiosk.service
```

Add the following content:

```ini
[Unit]
Description=PhytoPi Kiosk Application
After=graphical.target network.target
Wants=graphical.target

[Service]
Type=simple
User=pi
Environment=DISPLAY=:0
Environment=KIOSK_MODE=true
Environment=SUPABASE_URL=https://your-project.supabase.co
Environment=SUPABASE_ANON_KEY=your-anon-key
WorkingDirectory=/home/pi/phytopi-kiosk/bundle
ExecStart=/home/pi/phytopi-kiosk/bundle/phytopi_dashboard
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=graphical.target
```

Enable and start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable phytopi-kiosk.service
sudo systemctl start phytopi-kiosk.service
```

#### Option B: Autostart Script (LXDE) — Recommended for Pi display

Create an autostart script that **omits** `lxpanel` so the Pi top bar never appears:

```bash
nano ~/.config/lxsession/LXDE-pi/autostart
```

Replace the entire file with the following (note: `@lxpanel` is intentionally absent):

```bash
# Do NOT start lxpanel — the PhytoPi kiosk uses full-screen Flutter.
@pcmanfm --desktop --profile LXDE-pi
@xset s off
@xset -dpms
@xset s noblank
@unclutter -idle 3 -root
@/home/pi/phytopi-kiosk/bundle/phytopi_dashboard
```

> **Pi top bar (lxpanel):** If the Pi panel still appears after removing it from autostart, kill it manually with `pkill lxpanel` and verify your autostart file path with `cat ~/.config/lxsession/LXDE-pi/autostart`. On Raspberry Pi OS Bookworm with Wayland (`wayfire`), disable the panel via the Wayfire config or switch to the X11 session before deploying.

### 4. Configure Kiosk Mode Settings

#### Hide Cursor

```bash
sudo apt install -y unclutter
# Already included in the autostart line above: @unclutter -idle 3 -root
```

#### Disable Screensaver

```bash
sudo apt install -y x11-xserver-utils
# Already included in the autostart lines above: xset s off / -dpms / s noblank
```

#### Fullscreen Mode

The Flutter app automatically requests immersive-sticky fullscreen in kiosk mode (`SystemUiMode.immersiveSticky`). The system UI stays hidden even after an accidental touch. To verify on a Pi after deployment:

```bash
# Run the app and check it occupies the full screen with no status bar or panel.
# If a panel still shows, re-check the autostart file and pkill lxpanel.
```

### 5. Network Configuration

Ensure the Raspberry Pi has a stable network connection:

```bash
# Check network status
sudo systemctl status NetworkManager

# Configure static IP (optional)
sudo nano /etc/dhcpcd.conf
```

### 6. Enable Auto-Login

For true kiosk mode, enable auto-login:

```bash
sudo raspi-config
# Navigate to: System Options > Boot / Auto Login > Desktop Autologin
```

## Testing

### 1. Manual Test

```bash
cd ~/phytopi-kiosk/bundle
./phytopi_dashboard
```

### 2. Check Logs

```bash
# If using systemd
sudo journalctl -u phytopi-kiosk.service -f

# Check for errors
sudo journalctl -u phytopi-kiosk.service --since "1 hour ago" | grep -i error
```

### 3. Monitor Performance

```bash
# Check CPU and memory usage
htop

# Check disk usage
df -h
```

## Troubleshooting

### App Won't Start

1. **Check dependencies:**
   ```bash
   ldd ./phytopi_dashboard | grep "not found"
   ```

2. **Check permissions:**
   ```bash
   chmod +x ./phytopi_dashboard
   ```

3. **Check environment variables:**
   ```bash
   echo $SUPABASE_URL
   echo $SUPABASE_ANON_KEY
   echo $KIOSK_MODE
   ```

### Display Issues

1. **Check display connection:**
   ```bash
   xrandr
   ```

2. **Test with different resolutions:**
   ```bash
   xrandr --output HDMI-1 --mode 1920x1080
   ```

3. **Check X11 logs:**
   ```bash
   cat ~/.xsession-errors
   ```

### Network Issues

1. **Test network connection:**
   ```bash
   ping google.com
   curl https://your-project.supabase.co
   ```

2. **Check firewall:**
   ```bash
   sudo ufw status
   ```

### Performance Issues

1. **Check system resources:**
   ```bash
   free -h
   df -h
   ```

2. **Monitor processes:**
   ```bash
   top
   ```

3. **Reduce background processes:**
   ```bash
   sudo systemctl disable bluetooth
   sudo systemctl disable avahi-daemon
   ```

## Maintenance

### Updating the App

1. Build new version on build machine
2. Transfer new bundle to Raspberry Pi
3. Stop the service:
   ```bash
   sudo systemctl stop phytopi-kiosk.service
   ```
4. Replace old bundle with new one
5. Start the service:
   ```bash
   sudo systemctl start phytopi-kiosk.service
   ```

### Remote Access

Set up SSH for remote management:

```bash
# Enable SSH
sudo systemctl enable ssh
sudo systemctl start ssh

# Configure SSH key authentication (recommended)
ssh-copy-id pi@raspberrypi.local
```

### Monitoring

Set up monitoring for the kiosk:

```bash
# Install monitoring tools
sudo apt install -y htop iotop

# Set up log rotation
sudo nano /etc/logrotate.d/phytopi-kiosk
```

## Security Considerations

1. **Disable unnecessary services:**
   ```bash
   sudo systemctl disable bluetooth
   sudo systemctl disable avahi-daemon
   ```

2. **Configure firewall:**
   ```bash
   sudo ufw enable
   sudo ufw allow ssh
   ```

3. **Regular updates:**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

4. **Secure environment variables:**
   - Store credentials securely
   - Use environment files with restricted permissions
   - Avoid hardcoding credentials

## Advanced Configuration

### Multiple Displays

For multiple display setups:

```bash
# Configure multiple displays
xrandr --output HDMI-1 --primary --mode 1920x1080
xrandr --output HDMI-2 --mode 1920x1080 --right-of HDMI-1
```

### Touchscreen Support

For touchscreen interfaces:

```bash
# Install touchscreen drivers
sudo apt install -y xinput

# Calibrate touchscreen
xinput list
xinput calibrate <device-id>
```

### Custom Boot Splash

Create a custom boot splash:

```bash
# Install plymouth
sudo apt install -y plymouth plymouth-themes

# Configure boot splash
sudo plymouth-set-default-theme -l
```

## Resources

- [Flutter Linux Desktop](https://docs.flutter.dev/development/platform-integration/desktop)
- [Raspberry Pi Documentation](https://www.raspberrypi.org/documentation/)
- [Systemd Service Guide](https://www.freedesktop.org/software/systemd/man/systemd.service.html)

## Support

For issues or questions:
1. Check application logs
2. Review system logs
3. Verify network connectivity
4. Test with manual launch
5. Consult Flutter and Raspberry Pi documentation


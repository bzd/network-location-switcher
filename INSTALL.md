# Network Location Switcher - Installation & Management Guide

Complete guide for installing, configuring, and managing the Network Location Switcher across all deployment modes.

## 📋 Prerequisites

### System Requirements
- **macOS 10.14+** (Mojave or later)
- **Python 3.9+** (usually pre-installed on modern macOS)  
- **Xcode Command Line Tools** (for Python package compilation)
- **Administrator access** (for system-wide installation)

### Check Prerequisites
```bash
# Check macOS version
sw_vers

# Check Python version
python3 --version

# Check if Xcode Command Line Tools are installed
xcode-select -p

# Install if missing
xcode-select --install
```

## 🚀 Quick Installation

### 1. Clone Repository
```bash
git clone https://github.com/bzd/network-location-switcher.git
cd network-location-switcher
```

### 2. Choose Installation Mode

**Development Mode (Easiest - Start Here):**
```bash
./setup.sh                    # Development mode
./test.py                     # Configure network configurations
./manager.sh install          # Install plist
./manager.sh start            # Start monitoring
```

**User Mode (Personal Daily Use):**
```bash
./setup.sh --mode user        # User service mode
./test.py                   # Configure networks
# Service starts automatically at login
```

**System Mode (Multi-user/Server):**
```bash
./setup.sh --mode system      # System service mode (requires sudo)
sudo ./test.py              # Configure networks
# Service starts automatically at boot
```

## 📋 Detailed Installation by Mode

### 🧪 Development Mode

**Best for:** Testing, development, temporary usage

#### Installation
```bash
# Clone and setup
git clone https://github.com/bzd/network-location-switcher.git
cd network-location-switcher

# Install in development mode (default)
./setup.sh

# Configure your networks
./test.py
```

#### Management
```bash
# Using the management script (recommended)
./manager.sh setup         # Initial setup
./manager.sh test          # Test configuration
./manager.sh install       # Install as development service
./manager.sh start         # Start service
./manager.sh stop          # Stop service
./manager.sh status        # Check status
./manager.sh logs          # View logs
./manager.sh uninstall     # Remove service

# Manual execution (foreground)
source activate.sh
python network-location-switcher.py

# Manual service control
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/network-location-switcher-development.plist
launchctl bootout gui/$(id -u)/com.user.network-location-switcher.development
```

#### File Locations
- **Virtual Environment:** `./.venv/`
- **Configuration:** `./network-location-config.json`
- **Logs:** `./logs/network-location-switcher*.log`
- **Service:** `~/Library/LaunchAgents/network-location-switcher-development.plist`

#### Cleanup
```bash
./manager.sh stop          # Stop service
./manager.sh uninstall     # Remove service
./manager.sh clean         # Remove virtual environment
```

---

### 👤 User Service Mode

**Best for:** Personal use, single-user machines, no admin access

#### Installation
```bash
# Clone repository
git clone https://github.com/bzd/network-location-switcher.git
cd network-location-switcher

# Install as user service
./setup.sh --mode user

# Configure your networks
./test.py
```

#### Service Management
```bash
# Service control
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/network-location-switcher-user.plist
launchctl bootout gui/$(id -u)/com.user.network-location-switcher

# Check status
launchctl list | grep network-location-switcher

# View logs
tail -f ~/Library/Logs/network-location-switcher-stdout.log
tail -f ~/Library/Logs/network-location-switcher-stderr.log
tail -f ~/Library/Logs/network-location-switcher.log
```

#### File Locations
- **Installation:** `/usr/local/lib/network-location-switcher/`
- **Configuration:** `~/.network-location-config.json`
- **Logs:** `~/Library/Logs/network-location-switcher*.log`
- **Service:** `~/Library/LaunchAgents/network-location-switcher-user.plist`

#### Uninstallation
```bash
# Stop and remove service
launchctl bootout gui/$(id -u)/com.user.network-location-switcher
rm ~/Library/LaunchAgents/network-location-switcher-user.plist

# Remove installation
sudo rm -rf /usr/local/lib/network-location-switcher
rm ~/.network-location-config.json
rm ~/Library/Logs/network-location-switcher*.log
```

---

### 🖥️ System Service Mode

**Best for:** Multi-user machines, servers, always-on operation

#### Installation
```bash
# Clone repository
git clone https://github.com/bzd/network-location-switcher.git
cd network-location-switcher

# Install as system service (requires sudo)
./setup.sh --mode system

# Configure networks (system-wide)
sudo ./test.py
```

#### Service Management
```bash
# Service control (requires sudo)
sudo launchctl bootstrap system /Library/LaunchDaemons/network-location-switcher-system.plist
sudo launchctl bootout system/com.system.network-location-switcher

# Check status
sudo launchctl list | grep network-location-switcher

# View logs
sudo tail -f /var/log/network-location-switcher-stdout.log
sudo tail -f /var/log/network-location-switcher-stderr.log
sudo tail -f /var/log/network-location-switcher.log
```

#### File Locations
- **Installation:** `/usr/local/lib/network-location-switcher/`
- **Configuration:** `/usr/local/etc/network-location-config.json`
- **Logs:** `/var/log/network-location-switcher*.log`
- **Service:** `/Library/LaunchDaemons/network-location-switcher-system.plist`

#### Uninstallation
```bash
# Stop and remove service (requires sudo)
sudo launchctl bootout system/com.system.network-location-switcher
sudo rm /Library/LaunchDaemons/network-location-switcher-system.plist

# Remove installation
sudo rm -rf /usr/local/lib/network-location-switcher
sudo rm /usr/local/etc/network-location-config.json
sudo rm /var/log/network-location-switcher*.log
```

## ⚙️ Configuration Setup

### 1. Create Network Locations
Before configuring the switcher, create network locations in macOS:

```bash
# Create network locations (EXAMPLES)
networksetup -createlocation "Home" populate
networksetup -createlocation "Work" populate  
networksetup -createlocation "Mobile" populate
networksetup -createlocation "Public" populate

# List existing locations
networksetup -listlocations

# Or use System Preferences > Network > Location
```

### 2. Configure Network Mappings
Run the configuration helper:

```bash
./test.py
```

This will:
- Create a configuration file if it doesn't exist
- Test your current network setup
- Validate network locations exist
- Check log file permissions

### 3. Edit Configuration (EXAMPLES)
Edit the generated `network-location-config.json`:

```json
{
  "ssid_location_map": {
    "YourHomeWiFi": "Home",
    "YourWorkWiFi": "Work", 
    "iPhone Hotspot": "Mobile",
    "Starbucks WiFi": "Public"
  },
  "default_wifi_location": "Automatic",
  "ethernet_location": "Wired",
  "log_file": "/var/log/network-location-switcher.log"
}
```

### 4. Test Configuration
```bash
# Test your configuration
./test.py

# Test manually in foreground
source activate.sh  # (development mode only)
python network-location-switcher.py

# View help
python network-location-switcher.py --help
```

## 🔄 Migration Between Modes

### From Development → User Mode
```bash
# Stop development service
./manager.sh stop

# Install as user service
./setup.sh --mode user

# Copy configuration
cp ./network-location-config.json ~/.network-location-config.json
```

### From User → System Mode
```bash
# Stop user service
launchctl bootout gui/$(id -u)/com.user.network-location-switcher

# Install as system service
./setup.sh --mode system

# Copy configuration
sudo cp ~/.network-location-config.json /usr/local/etc/network-location-config.json
```

### From System → Development Mode
```bash
# Stop system service
sudo launchctl bootout system/com.system.network-location-switcher

# Setup development environment
./setup.sh

# Copy configuration
sudo cp /usr/local/etc/network-location-config.json ./network-location-config.json
sudo chown $(whoami) ./network-location-config.json
```

## 📊 Monitoring & Logs

### Log Locations by Mode

#### Development Mode
```bash
# Application logs
tail -f ./logs/network-location-switcher.log

# Service logs  
tail -f ./logs/stdout.log
tail -f ./logs/stderr.log

# All logs at once
./manager.sh logs
```

#### User Mode
```bash
# Application logs
tail -f ~/Library/Logs/network-location-switcher.log

# Service logs
tail -f ~/Library/Logs/network-location-switcher-stdout.log
tail -f ~/Library/Logs/network-location-switcher-stderr.log
```

#### System Mode  
```bash
# Application logs (requires sudo)
sudo tail -f /var/log/network-location-switcher.log

# Service logs (requires sudo)
sudo tail -f /var/log/network-location-switcher-stdout.log
sudo tail -f /var/log/network-location-switcher-stderr.log
```

### Example Log Output
```
2024-11-20 14:30:15 ================================
2024-11-20 14:30:15 Network Location Switcher v2.0 Starting
2024-11-20 14:30:15 Configuration loaded with 4 SSID mappings:
2024-11-20 14:30:15   'HomeWiFi' → 'Home'
2024-11-20 14:30:15   'OfficeWiFi' → 'Work'
2024-11-20 14:30:15 Default Wi-Fi location: Automatic
2024-11-20 14:30:15 Ethernet location: Wired
2024-11-20 14:30:16 Network watcher started (Wi-Fi + Ethernet aware).
2024-11-20 14:35:22 Detected Wi-Fi SSID=HomeWiFi, target=Home
2024-11-20 14:35:22 Current location: Automatic, target: Home
2024-11-20 14:35:23 Switched network location → Home
```

## 🔍 Troubleshooting

### Common Issues

#### Service Not Starting
```bash
# Check service status
launchctl list | grep network-location-switcher

# View error logs
tail -f ~/Library/Logs/network-location-switcher-stderr.log  # User mode
tail -f ./logs/stderr.log                               # Development mode
sudo tail -f /var/log/network-location-switcher-stderr.log   # System mode

# Check plist file syntax
plutil ~/Library/LaunchAgents/network-location-switcher-*.plist
```

#### Network Not Detected
```bash
# Test network detection manually
python network-location-switcher.py

# Check available network services
networksetup -listallhardwareports

# Check Wi-Fi interface
networksetup -listpreferredwirelessnetworks en0  # Adjust interface as needed
```

#### Configuration Errors
```bash
# Validate configuration
./test.py

# Check configuration file syntax
python -m json.tool network-location-config.json

# Check network locations exist
networksetup -listlocations
```

#### Permission Issues
```bash
# Fix log file permissions (development/user mode)
mkdir -p ~/Library/Logs
touch ~/Library/Logs/network-location-switcher.log
chmod 644 ~/Library/Logs/network-location-switcher.log

# Fix log file permissions (system mode)
sudo mkdir -p /var/log
sudo touch /var/log/network-location-switcher.log
sudo chmod 644 /var/log/network-location-switcher.log
```

#### Python Module Errors
```bash
# Check virtual environment
source .venv/bin/activate  # development mode
pip list | grep pyobjc

# Reinstall if missing
pip install pyobjc pyobjc-framework-SystemConfiguration pyobjc-framework-CoreFoundation
```

### Service Debugging

#### Check Service Status
```bash
# Development mode
./manager.sh status

# User mode
launchctl list | grep com.user.network-location-switcher

# System mode  
sudo launchctl list | grep com.system.network-location-switcher
```

#### Manual Testing
```bash
# Test in foreground (development mode)
source activate.sh
python network-location-switcher.py

# Test configuration
./test.py

# Test specific config file
python network-location-switcher.py my-custom-config.json
```

#### Reset Everything
```bash
# Development mode
./manager.sh stop
./manager.sh uninstall  
./manager.sh clean
./setup.sh              # Start fresh

# User mode
launchctl bootout gui/$(id -u)/com.user.network-location-switcher
rm ~/Library/LaunchAgents/network-location-switcher-user.plist
./setup.sh --mode user  # Reinstall

# System mode (requires sudo)
sudo launchctl bootout system/com.system.network-location-switcher
sudo rm /Library/LaunchDaemons/network-location-switcher-system.plist  
./setup.sh --mode system  # Reinstall
```

## 🔧 Advanced Configuration

### Custom Installation Locations
```bash
# Install to custom prefix
./setup.sh --mode production --prefix /opt

# Results in:
# /opt/bin/network-location-switcher
# /opt/lib/network-location-switcher/
```

### Multiple Configuration Files
```bash
# Use specific config file
python network-location-switcher.py /path/to/custom-config.json

# Configuration search order:
# 1. Command line argument  
# 2. ./network-location-config.json (script directory)
# 3. ~/.network-location-config.json (user home)
# 4. /usr/local/etc/network-location-config.json (system-wide)
# 5. /etc/network-location-config.json (system)
```

### Log Rotation
```bash
# Setup log rotation (macOS newsyslog)
sudo cat >> /etc/newsyslog.conf << EOF
/var/log/network-location-switcher*.log    644  5     1000 *     J
EOF

# Or use logrotate if installed via homebrew
```

## 📋 Mode Comparison Summary

| Feature | Development | User | System |
|---------|-------------|------|--------|
| **Auto-start** | ❌ Manual | ✅ Login | ✅ Boot |
| **Admin needed** | ❌ No | ❌ No | ⚠️ Yes |
| **Multi-user** | ❌ Single | Per user | ✅ All users |
| **Runs when logged out** | ❌ No | ❌ No | ✅ Yes |
| **Easy testing** | ✅ Yes | ❌ Service only | ❌ Service only |
| **Config location** | `./` | `~/` | `/usr/local/etc/` |
| **Log location** | `./logs/` | `~/Library/Logs/` | `/var/log/` |
| **Uninstall complexity** | ✅ Simple | ✅ Moderate | ⚠️ Requires sudo |

## 🎯 Recommendations

- 🧪 **Start with Development Mode** for testing and initial setup
- 👤 **Use User Mode** for personal daily use on single-user machines
- 🖥️ **Use System Mode** for shared machines, servers, or always-on operation
- 🔄 **Migrate between modes** as your needs change using the migration guides above

---

**Need more help?** See [CONFIG.md](CONFIG.md) for configuration details or [DEVELOPMENT.md](DEVELOPMENT.md) for development setup.
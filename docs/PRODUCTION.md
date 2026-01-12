# Network Location Switcher - Installation Guide

Complete installation guide for setting up the network location switcher on a new Mac laptop from git clone.

## 🏭 Development vs User Mode vs System Mode

| Aspect | Development | User Mode | System Mode |
|--------|-------------|-----------|-------------|
| **Location** | Current directory | `~/Library/Application Support/NetworkLocationSwitcher/` | `/usr/local/lib/network_location_switcher/` |
| **Virtual Env** | `./venv` | `~/Library/Application Support/NetworkLocationSwitcher/venv` | `/usr/local/lib/network_location_switcher/venv` |
| **Config** | `./` | `~/Library/Application Support/NetworkLocationSwitcher/` | `/usr/local/etc/` |
| **Logs** | `./logs/` | `~/Library/Logs/NetworkLocationSwitcher/` | `/usr/local/log/NetworkLocationSwitcher/` |
| **Service Type** | User agent | User agent | System daemon |
| **Permissions** | User only | User only | System-wide |
| **Dev Tools** | ✅ Pre-commit, linting | ❌ Minimal | ❌ Minimal |

## 🚀 Quick Production Install

### **Default Production Setup** (installs to `/usr/local/`)

```bash
./INSTALL.sh --mode production
```

### **Custom Installation Location**

```bash
# Install to /opt/network_location_switcher
./INSTALL.sh --mode production --prefix /opt

# Install to custom directories
./INSTALL.sh --mode production \
    --bin-dir /usr/local/bin \
    --lib-dir /opt/network-switcher
```

## 📁 Installation Paths

### **Default Production Layout** (`--prefix /usr/local`)

```bash
/usr/local/bin/network_location_switcher              # Executable wrapper script
/usr/local/lib/network_location_switcher/             # Library directory
├── venv/                                            # Virtual environment
├── network_location_switcher.py                     # Python script
└── requirements-macos.txt                           # Dependencies
/usr/local/log/network_location_switcher-stdout.log        # Output logs
/usr/local/log/network_location_switcher-stderr.log        # Error logs
```

### **Custom Prefix** (`--prefix /opt`)

```bash
/opt/bin/network_location_switcher                    # Executable wrapper
/opt/lib/network_location_switcher/                  # Library directory
...
```

## 🔧 Installation Options

### **All Available Options**

```bash
./INSTALL.sh --help

Usage: ./INSTALL.sh [OPTIONS]

Options:
  --mode MODE           Installation mode: 'development' or 'production'
  --prefix PATH         Installation prefix (default: /usr/local)
  --bin-dir PATH        Binary directory (default: PREFIX/bin)
  --lib-dir PATH        Library directory (default: PREFIX/lib/network_location_switcher)
  --help, -h            Show help message

Examples:
  ./INSTALL.sh                                    # Development setup
  ./INSTALL.sh --mode production                 # Production to /usr/local
  ./INSTALL.sh --mode production --prefix /opt   # Production to /opt
```

## ⚡ Usage After Installation

### **Running the Script**

```bash
# Production mode - use the installed binary
network_location_switcher

# Or with full path
/usr/local/bin/network_location_switcher
```

### **Installing as System Service** (runs at boot)

```bash
# Copy to system LaunchDaemons (requires sudo)
sudo cp network.location.switcher.system.plist /Library/LaunchDaemons/

# Load and start the service
sudo launchctl bootstrap system /Library/LaunchDaemons/network.location.switcher.system.plist

# Check status
sudo launchctl list | grep network_location_switcher
```

### **Installing as User Service** (runs at login)

```bash
# Copy to user LaunchAgents
cp network.location.switcher.user.plist ~/Library/LaunchAgents/

# Load and start the service
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/network.location.switcher.user.plist

# Check status
launchctl list | grep network_location_switcher
```

## 📋 Service Management

### **System Service Commands** (requires sudo)

```bash
# Status
sudo launchctl list | grep network_location_switcher

# Start
sudo launchctl bootstrap system /Library/LaunchDaemons/network.location.switcher.system.plist

# Stop
sudo launchctl bootout system /Library/LaunchDaemons/network.location.switcher.system.plist

# View logs
sudo tail -f /usr/local/log/network_location_switcher-stdout.log
sudo tail -f /usr/local/log/network_location_switcher-stderr.log
```

### **User Service Commands**

```bash
# Status
launchctl list | grep network_location_switcher

# Start
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/network.location.switcher.user.plist

# Stop
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/network.location.switcher.user.plist

# View logs
tail -f ~/Library/Logs/network_location_switcher-stdout.log
```

## 🛡️ Security & Permissions

### **Production Security Benefits**

- **Isolated Environment**: Virtual environment prevents dependency conflicts
- **Minimal Dependencies**: Only essential packages installed
- **System Integration**: Proper integration with macOS launchd
- **Controlled Access**: Script runs with appropriate permissions

### **Permission Requirements**

- **Installation**: May require `sudo` for writing to `/usr/local/` or `/opt/`
- **Runtime**: Runs as current user (for network configuration access)
- **Log Files**: System logs in `/usr/local/log/` may require `sudo` to read

## 🔄 Updates & Maintenance

### **Updating the Installation**

```bash
# Re-run setup to update
./INSTALL.sh --mode production

# Or to a different location
./INSTALL.sh --mode production --prefix /opt
```

### **Uninstalling**

```bash
# Stop the service first
sudo launchctl bootout system /Library/LaunchDaemons/network.location.switcher.system.plist
# or
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/network.location.switcher.user.plist

# Remove files
sudo rm -rf /usr/local/lib/network_location_switcher
sudo rm /usr/local/bin/network_location_switcher
sudo rm /Library/LaunchDaemons/network.location.switcher.system.plist
# or
rm ~/Library/LaunchAgents/network.location.switcher.user.plist
```

## 🧪 Testing Production Installation

### **Verify Installation**

```bash
# Test the executable
network_location_switcher --help

# Check dependencies
/usr/local/lib/network_location_switcher/venv/bin/python -c "
import SystemConfiguration, CoreFoundation
print('✅ macOS frameworks loaded successfully')
"

# Test network detection
network_location_switcher  # Should start monitoring
```

### **Test Service Installation**

```bash
# Load service temporarily (for user service)
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/network.location.switcher.user.plist

# Check it's running
launchctl list | grep network_location_switcher

# View logs
tail -f ~/Library/Logs/network_location_switcher-stdout.log

# Unload when done testing
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/network.location.switcher.user.plist
```

## 📊 Comparison: Development vs Production

| Feature | Development | Production |
|---------|-------------|------------|
| **Path** | `./network_location_switcher.py` | `/usr/local/bin/network_location_switcher` |
| **Activation** | `source ./activate.sh` | Not needed |
| **Dependencies** | Dev tools included | Minimal |
| **Logs** | `./logs/` | `/usr/local/log/` |
| **Updates** | Edit files directly | Re-run installer |
| **Service Type** | User LaunchAgent | System LaunchDaemon or User LaunchAgent |
| **Use Case** | Development & testing | Production deployment |

This production setup ensures your network location switcher is properly installed as a system service with appropriate permissions and logging! 🚀
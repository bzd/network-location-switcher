# Network Location Switcher

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Python 3.9+](https://img.shields.io/badge/python-3.9+-blue.svg)](https://www.python.org/downloads/)
[![macOS](https://img.shields.io/badge/platform-macOS-lightgrey.svg)](https://www.apple.com/macos/)

Automatically switches macOS network locations based on connected Wi-Fi networks or Ethernet connections. This tool monitors network changes in real-time and seamlessly switches to the appropriate network location, making it perfect for users who work across multiple environments (home, office, coffee shops, etc.).

## 🖥️ Supported OS

- macOS 14.5+ (Sonoma)
- macOS 15 (Sequoia)
- macOS 26.1 (Tahoe)


## ✨ Key Features

- 🔄 **Real-time Network Monitoring** - Uses macOS SystemConfiguration framework
- ⚡ **Instant Location Switching** - Responds immediately to network changes
- 📝 **Flexible JSON Configuration** - Easy to customize for your networks
- 🔌 **Ethernet Priority** - Automatically prioritizes wired over wireless
- 🚀 **Multiple Deployment Modes** - Development, User, and System service modes

## 🚀 Quick Start (DEVELOPMENT MODE)

NOTE: You must manually edit the created "network-location-config.json" file to map networks to locations.

```bash
# Clone and install
git clone https://github.com/bzd/network-location-switcher.git
cd network-location-switcher

# Create:
#   1. runtime python virtual environment.
#   2. plists for: development, user, and system.
#   3. configuration file: network-location-config.json
# HINT: Use the "--dry-run" switch to view what would be installed without any changes made
./setup.sh

# Edit the newly created `network-location-config.json` file.  See CONFIG.md for details.
# Each entry will have:
#
#    SSID_name : network_location_name
#    ...
#
nano network-location-config.json

# If needed, create new network locations.
# Replace '<network_location_name>' as needed
networksetup -createlocation '<network_location_name>' populate

# Test your environment and network configurations
source ./activate.sh
./test.py

# Start monitoring
./manager.sh install
./manager.sh start
```

> 📖 **For detailed installation and configuration of all modes, see [INSTALL.md](INSTALL.md)**

## 📖 How It Works

The network location switcher uses macOS's `SystemConfiguration` framework to monitor network changes in real-time. When a network state change is detected, it:

1. **Identifies the connection** (Wi-Fi SSID or Ethernet)
2. **Looks up the corresponding location** in your configuration
3. **Switches to the appropriate network location** using `networksetup`
4. **Logs the change** for monitoring

### Network Priority
1. **Ethernet** (if connected) → Uses `ethernet_location`
2. **Known Wi-Fi** (if SSID is mapped) → Uses mapped location  
3. **Unknown Wi-Fi** → Uses `default_wifi_location`

### Example Configuration
```json
{
  "ssid_location_map": {
    "HomeWiFi": "Home",
    "OfficeWiFi": "Work",
    "iPhone_Hotspot": "Mobile"
  },
  "default_wifi_location": "Automatic",
  "ethernet_location": "Wired"
}
```

## 🔧 Deployment Modes

### 🧪 Development Mode (Default, development)
- **Best for:** Testing and development
- **Auto-start:** ❌ Manual only
- **Admin required:** ❌ No
- **Location:** Project directory

### 👤 User Mode (single-user, production) 
- **Best for:** Personal daily use
- **Auto-start:** ✅ At user login
- **Admin required:** ❌ No
- **Location:** User-specific

### 🖥️ System Mode (multi-user, production)
- **Best for:** Multi-user machines
- **Auto-start:** ✅ At boot time
- **Admin required:** ⚠️ Yes
- **Location:** System-wide

| Feature | Development | User | System |
|---------|-------------|------|--------|
| **Auto-start** | ❌ | ✅ Login | ✅ Boot |
| **Admin needed** | ❌ | ❌ | ⚠️ |
| **Multi-user** | ❌ | Per user | ✅ |
| **Easy testing** | ✅ | ❌ | ❌ |

## 📚 Documentation

- **[INSTALL.md](INSTALL.md)** - Detailed installation and setup guide
- **[CONFIG.md](CONFIG.md)** - Configuration reference and examples
- **[DEVELOPMENT.md](DEVELOPMENT.md)** - Development and contribution guide

## 🛠️ Project Structure

```
network-location-switcher/
├── network-location-switcher.py    # Main application
├── setup.sh                   # Installation script  
├── manager.sh                  # Development management
├── test.py                   # Configuration helper
└── network-location-config.default.json  # Template
```

## 📄 License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## ⚠️ Compatibility

Requires macOS 10.14+ and may need updates for future macOS versions as Apple evolves their networking APIs.

---

**Made for macOS users who work across multiple networks**

## 👨‍💻 Authors

- Brian Drummond — Lead Developer
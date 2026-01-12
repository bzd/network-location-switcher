# Network Location Switcher

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Python 3.9+](https://img.shields.io/badge/python-3.9+-blue.svg)](https://www.python.org/downloads/)
[![macOS](https://img.shields.io/badge/platform-macOS-lightgrey.svg)](https://www.apple.com/macos/)

**Network Location Switcher** is a tool that runs in the background and automatically switches macOS network locations based on changes in connected Wi-Fi networks or Ethernet connections.

This tool monitors network changes in real-time and seamlessly switches to the appropriate network location, making it perfect for users who work across multiple environments (home, office, coffee shops, etc.).

For end user notifications, **Network Location Switcher**  optionally uses an auxiliary tool called **NotifyTool** for macOS Notification Center notifications.  Install at anytime from: https://github.com/bzd/NotifyTool

# Documentation

Additional documentation is found in the sub folder "*docs*".

* INSTALL.md : installation details
* CONFIG.md : configuration options
* DEVELOPMENT.md : development notes
* PRODUCTION.md : running a production use case notes

_NOTE: See the [Quick Commands](#quick-commands) section below for example usage._

# Prerequisites

1. *Network locations* must be created on the local macOS computer. Review the following Apple support documentation on how to create and use network locations:

   1. [Use network locations on Mac](https://support.apple.com/en-us/105129)
   1. [Manage network locations on Mac](https://support.apple.com/en-in/guide/mac-help/mchlp1175/mac)
   1. [About networksetup in Remote Desktop](https://support.apple.com/en-in/guide/remote-desktop/apdd0c5a2d5/mac)

This tool essentially automates the use of the Apple *networksetup* command to change your network locations based on [ ___SSID : network_location___ ] mapping pairs in a configuration file.


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

## 🚀 Quick Start

IMPORTANT NOTE: After installation, you MUST manually edit the newly created configuration file, ***network-location-switcher.json*** to map network SSIDs to network locations so the automation knows which network location to use for each SSID:

    network-location-switcher.json

Three installation modes are possible:

* **USER** : single-user environment.  Active when that user logs in.
* **SYSTEM** : multi-user environment.  Active after system boot.
* **DEVELOPMENT** : development and debugging environment.  Manual install and launch.

### Example: USER Install (per user install) 
```bash
# Clone and install
git clone https://github.com/bzd/network_location_switcher.git
cd network_location_switcher

# Create:
#   1. runtime python virtual environment.
#   2. plists for: development, user, and system.
#   3. default configuration file: network-location-switcher.json
# HINT: Use the "--dry-run" switch to view what will be installed (no changes made)
./INSTALL.sh --mode user

# Edit the newly created `network-location-switcher.json` file, which will be consulted
# during network changes.  See CONFIG.md for details.
# Each entry will have:
#
#    SSID_name_1 : network_location_1
#    SSID_name_2 : network_location_2
#    ...
#
nano network-location-switcher.json

# If needed, manually create new network locations.
# Replace '<network_location_name>' as needed
networksetup -createlocation '<network_location_name>' populate

```

> 📖 **For detailed installation and configuration of all modes, see [INSTALL.md](docs/INSTALL.md)**

## QUICK COMMANDS

### Common `manager.sh` Commands

| Command         | Description                                      |
|-----------------|--------------------------------------------------|
| `setup`         | Create and configure Python virtual environment   |
| `activate`      | Print instructions to activate the environment   |
| `install`       | Install as a launchd service                     |
| `start`         | Start the launchd service                        |
| `stop`          | Stop the launchd service                         |
| `status`        | Show the status of the service                   |
| `logs`          | Show (tail) the service logs                     |
| `uninstall`     | Remove the launchd service                       |
| `test`          | Test the network location switcher               |
| `clean`         | Remove the virtual environment                   |
| `help`          | Show help and usage information                  |

**Examples:**
```bash
./scripts/manager.sh setup      # Setup environment and dependencies
./scripts/manager.sh install    # Install as a user or dev service
./scripts/manager.sh start      # Start service
./scripts/manager.sh logs       # View logs
./scripts/manager.sh stop       # Stop service
./scripts/manager.sh uninstall  # Remove service
```






## 📖 How It Works

The network location switcher uses macOS's `SystemConfiguration` framework to monitor network changes in real-time. When a network state change is detected, it:

1. **Identifies the connection** (Wi-Fi SSID, Ethernet, USB, etc.)
2. **Looks up the corresponding network location** in your configuration
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

### 👤 User Mode (single-user) 
- **Best for:** Personal daily use, affects single user ONLY
- **Auto-start:** ✅ At user login
- **Admin required:** ❌ No
- **Location:** User-specific

### 🖥️ System Mode (multi-user)
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

- **[INSTALL.md](docs/INSTALL.md)** - Detailed installation and setup guide
- **[CONFIG.md](docs/CONFIG.md)** - Configuration reference and examples
- **[DEVELOPMENT.md](docs/DEVELOPMENT.md)** - Development and contribution guide

## 🛠️ Project Structure

```
network_location_switcher/
├── README.md                              # This file
├── LICENSE                                # GPL v3 License
├── pyproject.toml                         # Python project configuration
├── requirements-macos.txt                 # macOS-specific dependencies
├── network-location-switcher.default.json   # Configuration template
├── test.py                                # Configuration test helper
├── docs/                                  # Documentation
│   ├── CONFIG.md                          # Configuration reference
│   ├── DEVELOPMENT.md                     # Development guide
│   ├── INSTALL.md                         # Installation guide
│   └── PRODUCTION.md                      # Production deployment
├── logs/                                  # Log files (gitignored)
├── network_location_switcher/             # Main Python package
│   ├── __init__.py                        # Package initialization
│   └── network_location_switcher.py       # Main application
├── INSTALL.sh                             # Installation script
└── scripts/                               # Shell scripts
    ├── manager.sh                         # Development management
    └── uninstall.sh                       # Uninstallation script
```

## 📄 License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## ⚠️ Compatibility

Requires macOS 10.14+ and may need updates for future macOS versions as Apple evolves their networking APIs.

---

**Made for macOS users who work across multiple networks**

## 👨‍💻 Authors

- Brian Drummond — Lead Developer
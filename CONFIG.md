# Network Location Switcher Configuration Guide

The network location switcher now reads its configuration from an external JSON file, making it completely customizable without modifying the source code.

## 📁 Configuration File System

### **Automatic Configuration Creation**
The network switcher now uses a **template-based configuration system**:

1. **Template File**: `network-location-config.default.json` (included with installation)
2. **User Config**: `network-location-config.json` (created from template when needed)
3. **Automatic Setup**: If no user config exists, one is created from the template

### **Configuration File Search Order**
The script searches for configuration files in this order:

1. **Command line argument**: `network-location-switcher config.json`
2. **Script directory**: `./network-location-config.json`
3. **User home**: `~/.network-location-config.json`
4. **System-wide**: `/usr/local/etc/network-location-config.json`
5. **System**: `/etc/network-location-config.json`

### **Template vs User Config**
| File | Purpose | Edited by User? |
|------|---------|----------------|
| `network-location-config.default.json` | Template with examples and documentation | ❌ Never (overwritten on updates) |
| `network-location-config.json` | Your actual network configuration | ✅ Yes (customize for your networks) |

## 📋 Configuration Format

### **Basic Structure**
```json
{
  "ssid_location_map": {
    "WiFiNetworkName": "NetworkLocationName"
  },
  "default_wifi_location": "Automatic",
  "ethernet_location": "Wired", 
  "log_file": "/var/log/network-location-switcher.log"
}
```

### **Complete Example**
```json
{
  "ssid_location_map": {
    "HomeNetwork_5G": "Home",
    "HomeNetwork_2.4G": "Home", 
    "OfficeWiFi": "Work",
    "OfficeGuest": "Work",
    "iPhone_Hotspot": "Mobile",
    "CoffeeShop_Free": "Public",
    "Hotel_WiFi": "Travel"
  },
  "default_wifi_location": "Automatic",
  "ethernet_location": "Wired",
  "log_file": "/var/log/network-location-switcher.log"
}
```

## ⚙️ Configuration Options

### **ssid_location_map**
- **Purpose**: Maps Wi-Fi network names (SSIDs) to macOS network locations
- **Type**: Object (key-value pairs)
- **Example**: `"MyHomeWiFi": "Home Location"`
- **Notes**: 
  - SSID names are case-sensitive
  - Network location names must exist in System Preferences > Network > Location

### **default_wifi_location** 
- **Purpose**: Network location to use for unknown Wi-Fi networks
- **Type**: String
- **Default**: `"Automatic"`
- **Example**: `"Public"` or `"Guest"`

### **ethernet_location**
- **Purpose**: Network location to use when Ethernet cable is connected
- **Type**: String  
- **Default**: `"Wired"`
- **Example**: `"Office Ethernet"` or `"Home Wired"`

### **log_file**
- **Purpose**: Path where log messages are written
- **Type**: String
- **Default**: `"/var/log/network-location-switcher.log"`
- **Examples**: 
  - Development: `"./logs/network-switcher.log"`
  - User logs: `"~/network-location-switcher.log"`
  - System logs: `"/var/log/network-location-switcher.log"`

## 🏠 Setup Examples

### **Home Setup**
```json
{
  "ssid_location_map": {
    "HomeWiFi": "Home",
    "HomeWiFi_5G": "Home",
    "HomeGuest": "Home Guest"
  },
  "default_wifi_location": "Automatic",
  "ethernet_location": "Home Wired",
  "log_file": "~/network-location-switcher.log"
}
```

### **Office Setup**
```json
{
  "ssid_location_map": {
    "CorpNet": "Corporate",
    "CorpGuest": "Corporate Guest", 
    "DevNet": "Development"
  },
  "default_wifi_location": "Public",
  "ethernet_location": "Corporate Wired",
  "log_file": "/var/log/network-location-switcher.log"
}
```

### **Multi-Location Setup**
```json
{
  "ssid_location_map": {
    "HomeNetwork": "Home",
    "OfficeWiFi": "Work",
    "iPhone_User": "Mobile Hotspot",
    "Starbucks": "Coffee Shop",
    "Airport_Free": "Travel",
    "Hotel_Guest": "Travel"
  },
  "default_wifi_location": "Public Safety",
  "ethernet_location": "Wired Connection", 
  "log_file": "/var/log/network-location-switcher.log"
}
```

## �️ Getting Started with Configuration

### **1. First-Time Setup**
When you first run the network switcher:

1. **Automatic Template Use**: If no config exists, one is created from `network-location-config.default.json`
2. **Clean Template**: Comments and examples are automatically removed from your config
3. **Ready to Edit**: Your new `network-location-config.json` contains clean, editable settings

### **2. Manual Template Creation**
You can also create a config manually:

```bash
# Copy and clean the template
cp network-location-config.default.json network-location-config.json

# Edit the new file to remove comments and add your networks
nano network-location-config.json
```

### **3. Template Structure**
The default template includes:
- **Example SSID mappings** with common network types
- **Helpful comments** explaining each setting
- **Setup instructions** embedded in the file
- **Best practices** for configuration

## 🧪 Testing Your Configuration

### **1. Check Network Locations**
First, verify your network locations exist:
```bash
# List all network locations
networksetup -listlocations

# Output example:
# Home
# Work  
# Mobile
# Automatic
```

### **2. Test Configuration**
```bash
# Run with specific config file
./network-location-switcher config.json

# Check logs
tail -f /var/log/network-location-switcher.log
```

### **3. Verify SSID Names**
Get exact SSID names (case-sensitive):
```bash
# Current network
system_profiler SPAirPortDataType | grep "Current Network"

# Or via networksetup
networksetup -listpreferredwirelessnetworks en0
```

## 🚨 Common Issues

### **Configuration File Not Found**
- The script will create a default config file automatically
- Edit the generated file with your specific networks
- Check file permissions if creation fails

### **Network Location Doesn't Exist**
```bash
# Create missing network location
networksetup -createlocation "My Location" populate

# Switch to verify it works
networksetup -switchtolocation "My Location"
```

### **Permission Issues**
```bash
# Make log directory writable
sudo mkdir -p /var/log
sudo chmod 755 /var/log

# Or use user-writable location
"log_file": "~/network-location-switcher.log"
```

### **JSON Syntax Errors**
- Use a JSON validator or VS Code to check syntax
- Common issues: missing commas, extra commas, unmatched quotes
- Online validator: https://jsonlint.com/

## 🎯 Best Practices

### **1. Descriptive Location Names**
```json
"ssid_location_map": {
  "HomeNetwork": "Home - Secure",
  "OfficeWiFi": "Work - Corporate", 
  "PublicWiFi": "Public - Restricted"
}
```

### **2. Backup Configuration**
```bash
# Backup your working config
cp network-location-config.json network-location-config.backup.json
```

### **3. Version Control**
- Add config files to your dotfiles repository
- Use environment-specific configs for different machines

### **4. Security Considerations**
- Config file may contain network names (not passwords)
- Readable by script owner only: `chmod 600 config.json`
- Don't commit sensitive network names to public repos

This external configuration approach makes the network location switcher completely portable and customizable for any user or environment! 🎉
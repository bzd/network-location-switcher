# Debugging Tips

# Basic on/off

Turn off automatic switching

```zsh
./scripts/manager.sh stop

[13:05:49] Stopping service: com.agilesv.networklocationswitcher.development
✅ Service stopped
```

Turn on automatic switching

```zsh
./scripts/manager.sh start
```

# Turn on debugging mode

Shows more details in log of activity, for example when processing the config files, where items are installed, etc.
```zsh
TBD
```

## Manually stop and restart the service that is running from launchctl (USER MODE)

0. Check for running service

```zsh
alias nlslist='launchctl list | grep networklocationswitcher'
```

1. Stop the service

```zsh
alias nlsstop='launchctl bootout gui/$(id -u)/com.agilesv.networklocationswitcher.user && echo "please wait a few seconds..." && sleep 3'
```

2. Update and refresh code

Make changes in the code (e.g., network_location_switcher.py, etc.)
cp network_location_switcher.py ~/Library/Application\ Support/NetworkLocationSwitcher/

3. Restart the service

```zsh
alias nslstart='launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.agilesv.networklocationswitcher.user.plist'
```

## Where is my configuration coming from?

List configuration order; several config files can contribute in a priority merge order

```zsh
./scripts/manager.sh status
```

## Show current ssid<->netloc pairs

```zsh
TBD
```

## Show live network location switching logging

E.g., Turn Wi-Fi off, and then on, and watch the log

```zsh
tail -f /Users/$USER/Library/Logs/NetworkLocationSwitcher/network_location_switcher.log
```

# What SSIDs are available?

```zsh
# Find your Wi-Fi interface (e.g., en0) with:
# networksetup -listallhardwareports | grep -A 1 "Wi-Fi"
networksetup -listpreferredwirelessnetworks en0
```


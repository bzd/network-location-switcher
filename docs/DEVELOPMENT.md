# Development Setup Guide

Guide for setting up local development environment for code cleanup and other fixes, without disturbing the production installation.

## Overview

The project is designed to support both development and production modes simultaneously. They are completely isolated and don't interfere with each other.

## 1. Development vs Production - Complete Isolation

| Aspect | User Mode | System Mode | Development |
|--------|-----------|-------------|-------------|
| **Location** | `~/Library/Application Support/NetworkLocationSwitcher/` | `/usr/local/lib/network_location_switcher/` | Your git repo directory |
| **Virtual Env** | `~/Library/Application Support/NetworkLocationSwitcher/venv` | `/usr/local/lib/network_location_switcher/venv` | `./venv` (in repo) |
| **Executable** | `/usr/local/bin/network_location_switcher` | `/usr/local/bin/network_location_switcher` | `./network_location_switcher.py` |
| **Config** | `~/Library/Application Support/NetworkLocationSwitcher/` | `/usr/local/etc/` | `./` |
| **Logs** | `~/Library/Logs/NetworkLocationSwitcher/` | `/usr/local/log/NetworkLocationSwitcher/` | `./logs/` |

## 2. Setup Development Environment

```bash
# Navigate to your cloned repo
cd ~/Documents/dev/Mac-Only/network_location_switcher

# Run development setup (creates venv in project directory)
./INSTALL.sh

# This creates:
# - venv/ directory with Python virtual environment
# - Development dependencies (pytest, ruff, mypy, black)
# - logs/ directory for development logs
```

## 3. Activate Development Environment

The setup creates an `activate.sh` script:

```bash
# Activate the development virtual environment
source ./activate.sh

# Now you're using the local venv, not the production one
# Your prompt will change to show (venv)
```

## 4. Development Workflow

```bash
# With venv activated:

# Make code changes
nano network_location_switcher.py

# Format code
ruff format .

# Lint code
ruff check .

# Type check
mypy network_location_switcher/network_location_switcher.py tests/configuration-test.py

# Test configuration
./tests/configuration-test.py

# Run manually in foreground (NOT as service)
python network_location_switcher/network_location_switcher.py
# Press Ctrl+C to stop
```

## 5. Testing Your Changes Without Affecting Production

### Option A: Run in Foreground (Recommended)

Production service keeps running in background while your development version runs in foreground terminal.

```bash
# Run development version
python network_location_switcher.py

# You'll see real-time output
# Press Ctrl+C when done testing
```

### Option B: Temporarily Stop Production

Temporarily stop production service to test development version.

```bash
# Stop production service
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/network.location.switcher.user.plist

# Run your development version
python network_location_switcher.py

# Test changes...

# Stop dev version (Ctrl+C)

# Restart production service
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/network.location.switcher.user.plist
```

### Option C: Install Dev Version as Separate Service

For longer-term testing, install development version as a separate service.

```bash
# The repo includes network.location.switcher.development.plist for this

# Copy to LaunchAgents
cp network.location.switcher.development.plist ~/Library/LaunchAgents/

# This service has label: com.user.network_location_switcher.development
# Different from production: com.user.network_location_switcher

# Stop production first (only one can run at a time)
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/network.location.switcher.user.plist

# Start dev service
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/network.location.switcher.development.plist

# View dev logs (different from production logs)
tail -f ./logs/network_location_switcher-stdout.log
```

## 6. Key Points About Isolation

The environments are isolated because:

1. **Different Python environments**:
   - User mode: `~/Library/Application Support/NetworkLocationSwitcher/venv/bin/python`
   - System mode: `/usr/local/lib/network_location_switcher/venv/bin/python`
   - Development: `./venv/bin/python`

2. **Different configuration locations**:
   - User mode: `~/Library/Application Support/NetworkLocationSwitcher/network-location-switcher.conf`
   - System mode: `/usr/local/etc/network-location-switcher.conf`
   - Development: `./network-location-switcher.conf`

3. **Different log files**:
   - User mode: `~/Library/Logs/NetworkLocationSwitcher/`
   - System mode: `/usr/local/log/NetworkLocationSwitcher/`
   - Development: `./logs/`

4. **Only one service can run at a time** (they both monitor the same network changes)

## 7. Recommended Development Workflow

```bash
# Day-to-day development:
cd ~/Documents/dev/Mac-Only/network_location_switcher
source ./activate.sh

# Make changes
nano network_location_switcher.py

# Format and lint
ruff format .
ruff check .
mypy network_location_switcher.py

# Test in foreground (production keeps running)
python network_location_switcher.py
# Watch output, press Ctrl+C when satisfied

# Commit changes
git add .
git commit -m "Fix: your changes"

# When ready to update production:
./INSTALL.sh --mode production

# Restart production service to pick up changes
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/network.location.switcher.user.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/network.location.switcher.user.plist
```

## 8. Helpful Development Commands

```bash
# Check what's running
launchctl list | grep network_location_switcher

# View production logs
tail -f ~/Library/Logs/network_location_switcher-stdout.log

# View development logs (when running as service)
tail -f ./logs/network_location_switcher-stdout.log

# Check current network location
scselect

# List available network locations
networksetup -listlocations

# Check git status
git status

# See what changed
git diff
```

## 9. Deactivating Development Environment

```bash
# When done developing
deactivate

# Or just close the terminal
```

## Summary

**Key insight**: Development and production installations are completely separate.

You can:
- Keep production running 24/7 as a service
- Do development work in the same git repo
- Test changes by running manually in a terminal
- Only stop production when you want to test the dev version as a service

The `INSTALL.sh` script is smart enough to detect which mode you're in and set everything up accordingly. For low-priority fixes and cleanup, just use development mode and test manually without touching the production service at all!

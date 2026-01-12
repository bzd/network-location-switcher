#!/bin/bash
# Shared configuration for network-location-switcher scripts
# This file is sourced by INSTALL.sh, uninstall.sh, and manager.sh

# Plist and service naming
PLIST_BASE_NAME="com.agilesv.networklocationswitcher"
SERVICE_LABEL_BASE="com.agilesv.networklocationswitcher"

# Script name (used for binary and library paths)
SCRIPT_NAME="network_location_switcher"

# Configuration file names
CONFIG_FILE="network-location-switcher.conf"
CONFIG_FILE_DEFAULT="network-location-switcher.default.conf"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

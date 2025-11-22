#!/bin/bash
# Management script for network-location-switcher virtual environment

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$PROJECT_DIR/.venv"
SERVICE_NAME="com.user.network-location-switcher.development"
PLIST_FILENAME="network-location-switcher-development.plist"
LAUNCH_DIR="$HOME/Library/LaunchAgents/"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }

usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  setup         Create and configure virtual environment"
    echo "  activate      Activate the virtual environment"
    echo "  install       Install as launchd service"  
    echo "  start         Start the launchd service"
    echo "  stop          Stop the launchd service"
    echo "  status        Show service status"
    echo "  logs          Show service logs"
    echo "  uninstall     Remove launchd service"
    echo "  test          Test the network switcher"
    echo "  clean         Remove virtual environment"
    echo "  help          Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 setup              # Initial setup"
    echo "  $0 install            # Install service"
    echo "  $0 start              # Start monitoring"
    echo "  $0 logs               # View logs"
}

check_venv() {
    if [ ! -d "$VENV_DIR" ]; then
        error "Virtual environment not found. Run: $0 setup"
        exit 1
    fi
}

cmd_setup() {
    log "Setting up virtual environment..."
    ./setup.sh
}

cmd_activate() {
    check_venv
    echo "# Run this command to activate the virtual environment:"
    echo "source $PROJECT_DIR/activate.sh"
}

cmd_install() {
    check_venv
    log "Installing launchd service..."
    
    # Copy plist to LaunchAgents
    if [ ! -d "$LAUNCH_DIR" ]; then
        mkdir -p "$LAUNCH_DIR"
        success "Created LaunchAgents directory"
    fi

    PLIST_LOC="$LAUNCH_DIR$PLIST_FILENAME"
    if [ ! -f "$PROJECT_DIR/$PLIST_FILENAME" ]; then
        error "Plist file not found: $PROJECT_DIR/$PLIST_FILENAME"
    else
        cp "$PROJECT_DIR/$PLIST_FILENAME" "$PLIST_LOC"
        success "Service installed: $SERVICE_NAME"
        log "To start the service, run: $0 start"
    fi
    
}

cmd_start() {
    if [ ! -f "$LAUNCH_DIR$PLIST_FILENAME" ]; then
        error "Service not installed. Run: $0 install"
        exit 1
    fi
    
    log "Starting service: $SERVICE_NAME"
    launchctl bootstrap gui/$(id -u) "$LAUNCH_DIR$PLIST_FILENAME"
    success "Service started"
}

cmd_stop() {
    log "Stopping service: $SERVICE_NAME"
    launchctl bootout gui/$(id -u)/$SERVICE_NAME 2>/dev/null || true
    success "Service stopped"
}

cmd_status() {
    log "Checking service status..."
    
    if launchctl list | grep -q "$SERVICE_NAME"; then
        success "Service is running"
        launchctl list | grep "$SERVICE_NAME"
    else
        warning "Service is not running"
    fi
    
    # Check if plist exists
    if [ -f "$LAUNCH_DIR$PLIST_FILENAME" ]; then
        success "Service is installed"
        ls -l "$LAUNCH_DIR$PLIST_FILENAME"
    else
        warning "Service is not installed"
    fi
}

cmd_logs() {
    log "Showing service logs..."
    
    echo "=== STDOUT Logs ==="
    if [ -f "$PROJECT_DIR/logs/stdout.log" ]; then
        tail -n 50 "$PROJECT_DIR/logs/stdout.log"
    else
        warning "No stdout logs found"
    fi
    
    echo ""
    echo "=== STDERR Logs ==="
    if [ -f "$PROJECT_DIR/logs/stderr.log" ]; then
        tail -n 50 "$PROJECT_DIR/logs/stderr.log"
    else
        warning "No stderr logs found"
    fi
    
    echo ""
    echo "=== System Logs ==="
    log show --predicate 'subsystem contains "com.user.network-location-switcher.venv"' --last 1h
}

cmd_uninstall() {
    log "Uninstalling service..."
    
    # Stop service
    cmd_stop
    
    # Remove plist
    if [ -f "$LAUNCH_DIR$PLIST_FILENAME" ]; then
        rm "$LAUNCH_DIR$PLIST_FILENAME"
        success "Service plist removed"
    fi
    
    success "Service uninstalled"
}

cmd_test() {
    check_venv
    log "Testing network switcher..."
    
    # Activate venv and run a quick test
    source "$VENV_DIR/bin/activate"
    python -c "
import sys
sys.path.insert(0, '$PROJECT_DIR')

print('🧪 Testing network switcher imports...')
try:
    import SystemConfiguration
    import CoreFoundation
    print('✅ macOS frameworks imported successfully')
except ImportError as e:
    print(f'❌ macOS framework import failed: {e}')
    sys.exit(1)

# Test basic functionality
print('🧪 Testing basic functionality...')
import subprocess
result = subprocess.run(['networksetup', '-listallnetworkservices'], 
                       capture_output=True, text=True)
if result.returncode == 0:
    print('✅ networksetup command works')
    print('📋 Available network services:')
    for line in result.stdout.strip().split('\\n')[1:]:  # Skip header
        print(f'   - {line}')
else:
    print('❌ networksetup command failed')

print('🎉 Test completed successfully!')
"
}

cmd_clean() {
    warning "This will remove the virtual environment"
    read -p "Are you sure? (y/N): " confirm
    if [[ $confirm == [yY] ]]; then
        log "Removing virtual environment..."
        rm -rf "$VENV_DIR"
        rm -f activate.sh
        success "Virtual environment removed"
    else
        log "Cancelled"
    fi
}

# Main command dispatcher
case "${1:-help}" in
    setup) cmd_setup ;;
    activate) cmd_activate ;;
    install) cmd_install ;;
    start) cmd_start ;;
    stop) cmd_stop ;;
    status) cmd_status ;;
    logs) cmd_logs ;;
    uninstall) cmd_uninstall ;;
    test) cmd_test ;;
    clean) cmd_clean ;;
    help|--help|-h) usage ;;
    *) 
        error "Unknown command: $1"
        usage
        exit 1
        ;;
esac
#!/bin/bash
# Management script for network_loc_switcher virtual environment

# Get the project root directory (parent of scripts/)
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="$PROJECT_DIR/.venv"
SERVICE_NAME="com.user.network_loc_switcher.development"
PLIST_FILENAME="network.location.switcher.development.plist"
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
    ./install.sh
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
    
    # Define service names and plist locations
    local DEV_SERVICE="com.user.network_loc_switcher.development"
    local USER_SERVICE="com.user.network_loc_switcher"
    local SYSTEM_SERVICE="com.system.network_loc_switcher"
    local DEV_PLIST="$HOME/Library/LaunchAgents/network.location.switcher.development.plist"
    local USER_PLIST="$HOME/Library/LaunchAgents/network.location.switcher.user.plist"
    local SYSTEM_PLIST="/Library/LaunchDaemons/network.location.switcher.system.plist"
    
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "                   SERVICE STATUS"
    echo "═══════════════════════════════════════════════════════"
    echo ""
    echo "Checking system services requires administrator privileges..."
    
    # Check which mode is active
    local active_mode="none"
    
    # Check development mode
    if launchctl list 2>/dev/null | grep -q "$DEV_SERVICE"; then
        active_mode="development"
        success "Mode: DEVELOPMENT (active)"
        launchctl list | grep "$DEV_SERVICE"
    elif [ -f "$DEV_PLIST" ]; then
        echo -e "${YELLOW}Mode: Development (installed but not running)${NC}"
    fi
    
    # Check user mode
    if launchctl list 2>/dev/null | grep -q "$USER_SERVICE"; then
        if [ "$active_mode" = "none" ]; then
            active_mode="user"
            success "Mode: USER (active)"
            launchctl list | grep "$USER_SERVICE"
        fi
    elif [ -f "$USER_PLIST" ]; then
        echo -e "${YELLOW}Mode: User (installed but not running)${NC}"
    fi
    
    # Check system mode (requires checking system domain)
    if sudo launchctl list 2>/dev/null | grep -q "$SYSTEM_SERVICE"; then
        if [ "$active_mode" = "none" ]; then
            active_mode="system"
            success "Mode: SYSTEM (active)"
            sudo launchctl list | grep "$SYSTEM_SERVICE"
        fi
    elif [ -f "$SYSTEM_PLIST" ]; then
        echo -e "${YELLOW}Mode: System (installed but not running)${NC}"
    fi
    
    if [ "$active_mode" = "none" ]; then
        warning "No service is currently running"
    fi
    
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "               INSTALLED SERVICES"
    echo "═══════════════════════════════════════════════════════"
    
    # Track running vs installed state for each mode
    local dev_running=false
    local user_running=false
    local system_running=false
    
    launchctl list 2>/dev/null | grep -q "$DEV_SERVICE" && dev_running=true
    launchctl list 2>/dev/null | grep -q "$USER_SERVICE" && user_running=true
    sudo launchctl list 2>/dev/null | grep -q "$SYSTEM_SERVICE" && system_running=true
    
    # Show installed plist files with running state
    if [ -f "$DEV_PLIST" ]; then
        if [ "$dev_running" = true ]; then
            success "Development: installed & running"
        else
            echo -e "${YELLOW}⚠️  Development: installed but NOT running${NC}"
        fi
        echo "  └── $DEV_PLIST"
    elif [ "$dev_running" = true ]; then
        warning "Development: RUNNING but plist not installed (orphaned service)"
        echo "  └── Service is running from a deleted or moved plist"
        echo "  └── Run '$0 stop' to stop the orphaned service"
    else
        echo -e "${BLUE}○${NC} Development: not installed"
    fi
    
    if [ -f "$USER_PLIST" ]; then
        if [ "$user_running" = true ]; then
            success "User: installed & running"
        else
            echo -e "${YELLOW}⚠️  User: installed but NOT running${NC}"
        fi
        echo "  └── $USER_PLIST"
    elif [ "$user_running" = true ]; then
        warning "User: RUNNING but plist not installed (orphaned service)"
        echo "  └── Service is running from a deleted or moved plist"
    else
        echo -e "${BLUE}○${NC} User: not installed"
    fi
    
    if [ -f "$SYSTEM_PLIST" ]; then
        if [ "$system_running" = true ]; then
            success "System: installed & running"
        else
            echo -e "${YELLOW}⚠️  System: installed but NOT running${NC}"
        fi
        echo "  └── $SYSTEM_PLIST"
    elif [ "$system_running" = true ]; then
        warning "System: RUNNING but plist not installed (orphaned service)"
        echo "  └── Service is running from a deleted or moved plist"
    else
        echo -e "${BLUE}○${NC} System: not installed"
    fi
    
    # Show log file locations for active service
    if [ "$active_mode" != "none" ]; then
        echo ""
        echo "═══════════════════════════════════════════════════════"
        echo "                    LOG FILES"
        echo "═══════════════════════════════════════════════════════"
        
        local log_dir=""
        local log_main=""
        local log_stdout=""
        local log_stderr=""
        
        case "$active_mode" in
            development)
                log_dir="$PROJECT_DIR/logs/NetworkLocationSwitcher"
                ;;
            user)
                log_dir="$HOME/Library/Logs/NetworkLocationSwitcher"
                ;;
            system)
                log_dir="/usr/local/log/NetworkLocationSwitcher"
                ;;
        esac
        
        log_main="$log_dir/network_loc_switcher.log"
        log_stdout="$log_dir/network_loc_switcher-stdout.log"
        log_stderr="$log_dir/network_loc_switcher-stderr.log"
        
        echo "Log locations for ${active_mode} mode:"
        echo "  Directory: $log_dir"
        echo ""
        
        # Main application log
        if [ -f "$log_main" ]; then
            local main_lines=$(wc -l < "$log_main" | tr -d ' ')
            local main_size=$(ls -lh "$log_main" | awk '{print $5}')
            success "app log: network_loc_switcher.log"
            echo "  └── $main_lines lines, $main_size, last modified: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$log_main")"
        else
            echo -e "${BLUE}○${NC} app log: network_loc_switcher.log ${YELLOW}(not found)${NC}"
        fi
        
        # stdout log
        if [ -f "$log_stdout" ]; then
            local stdout_lines=$(wc -l < "$log_stdout" | tr -d ' ')
            success "stdout:  network_loc_switcher-stdout.log"
            echo "  └── $stdout_lines lines, last modified: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$log_stdout")"
        else
            echo -e "${BLUE}○${NC} stdout:  network_loc_switcher-stdout.log ${YELLOW}(not found)${NC}"
        fi
        
        # stderr log
        if [ -f "$log_stderr" ]; then
            local stderr_lines=$(wc -l < "$log_stderr" | tr -d ' ')
            if [ "$stderr_lines" -gt 0 ]; then
                warning "stderr:  network_loc_switcher-stderr.log ($stderr_lines lines)"
            else
                success "stderr:  network_loc_switcher-stderr.log (empty - no errors)"
            fi
            echo "  └── last modified: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$log_stderr")"
        else
            echo -e "${BLUE}○${NC} stderr:  network_loc_switcher-stderr.log ${YELLOW}(not found)${NC}"
        fi
        
        echo ""
        echo "View logs with:"
        echo "  tail -f $log_main"
        echo "  tail -f $log_stdout"
        echo "  tail -f $log_stderr"
    fi
    
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "            CONFIGURATION FILES (search order)"
    echo "═══════════════════════════════════════════════════════"
    
    # Configuration file search order (same as Python script)
    local username=$(whoami)
    local config_paths=(
        "$PROJECT_DIR/network-location-config.json"
        "$HOME/.network-location-config.json"
        "/usr/local/etc/$username/network-location-config.json"
        "/usr/local/etc/network-location-config.json"
        "/etc/network-location-config.json"
    )
    
    local config_labels=(
        "Script directory (development)"
        "User home directory"
        "User-specific system config"
        "System-wide config"
        "System config"
    )
    
    local found_config=false
    local config_order=1
    
    for i in "${!config_paths[@]}"; do
        local path="${config_paths[$i]}"
        local label="${config_labels[$i]}"
        
        if [ -f "$path" ]; then
            if [ "$found_config" = false ]; then
                success "[$config_order] $label (ACTIVE)"
                found_config=true
            else
                echo -e "${BLUE}[$config_order]${NC} $label (found but not used)"
            fi
            echo "  └── $path"
            ((config_order++))
        fi
    done
    
    if [ "$found_config" = false ]; then
        warning "No configuration file found!"
        echo "  A default config will be created from template when the service runs."
    fi
    
    echo ""
    echo "Configuration search order (first found wins):"
    for i in "${!config_paths[@]}"; do
        local path="${config_paths[$i]}"
        local label="${config_labels[$i]}"
        local num=$((i + 1))
        
        if [ -f "$path" ]; then
            echo -e "  ${GREEN}$num.${NC} $label"
            echo -e "     ${GREEN}$path${NC}"
        else
            echo -e "  ${BLUE}$num.${NC} $label"
            echo -e "     $path ${YELLOW}(not found)${NC}"
        fi
    done
    
    echo ""
    echo "═══════════════════════════════════════════════════════"
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
    log show --predicate 'subsystem contains "com.user.network_loc_switcher.venv"' --last 1h
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
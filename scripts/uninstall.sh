#!/bin/bash
set -e

# Uninstall script for Network Location Switcher
# Removes all files, directories, and services for a given installation mode

# Get the project root directory (parent of scripts/)
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_NAME="network_loc_switcher"

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

# Function to show usage
usage() {
    echo "Usage: $0 [--mode MODE]"
    echo ""
    echo "Options:"
    echo "  --mode MODE    Installation mode to uninstall: 'development', 'user', or 'system'"
    echo "                 If not provided, will prompt for mode"
    echo "  --help, -h     Show this help message"
    echo ""
    exit 0
}

# Function to uninstall development mode
uninstall_development() {
    log "Uninstalling development mode..."
    
    # Stop and remove service
    local service_id="gui/$(id -u)/com.development.network_loc_switcher"
    local plist_path="$HOME/Library/LaunchAgents/network.location.switcher.development.plist"
    
    if launchctl list | grep -q "com.development.network_loc_switcher" 2>/dev/null; then
        log "Stopping development service..."
        launchctl bootout "$service_id" 2>/dev/null || true
        success "Service stopped"
    fi
    
    if [ -f "$plist_path" ]; then
        log "Removing plist file..."
        rm -f "$plist_path"
        success "Plist file removed"
    fi
    
    # Remove virtual environment
    if [ -d "$PROJECT_DIR/.venv" ]; then
        log "Removing virtual environment..."
        # Check if we need sudo (parent directory might not be writable)
        local venv_parent=$(dirname "$PROJECT_DIR/.venv")
        if [[ ! -w "$venv_parent" ]]; then
            sudo rm -rf "$PROJECT_DIR/.venv"
        else
            rm -rf "$PROJECT_DIR/.venv"
        fi
        success "Virtual environment removed"
    fi
    
    # Remove logs directory contents (but keep .gitkeep for version control)
    if [ -d "$PROJECT_DIR/logs" ]; then
        log "Removing logs directory contents..."
        find "$PROJECT_DIR/logs" -type f ! -name '.gitkeep' -delete
        find "$PROJECT_DIR/logs" -mindepth 1 -type d -empty -delete
        success "Logs directory contents removed"
    fi
    
    # Remove generated files
    local files_to_remove=(
        "$PROJECT_DIR/network.location.switcher.development.plist"
        "$PROJECT_DIR/activate.sh"
        "$PROJECT_DIR/.pre-commit-config.yaml"
    )
    
    for file in "${files_to_remove[@]}"; do
        if [ -f "$file" ]; then
            rm -f "$file"
            log "Removed: $file"
        fi
    done
    
    # Note: User configuration file is preserved at $PROJECT_DIR/network-location-config.json
    # Remove it manually if desired: rm $PROJECT_DIR/network-location-config.json
    
    success "Development mode uninstalled"
}

# Function to uninstall user mode
uninstall_user() {
    log "Uninstalling user mode..."
    
    # Determine installation paths
    local install_prefix="${INSTALL_PREFIX:-/usr/local}"
    local bin_dir="${install_prefix}/bin"
    local lib_dir="${install_prefix}/lib/${SCRIPT_NAME}"
    local service_id="gui/$(id -u)/com.user.network_loc_switcher"
    local plist_path="$HOME/Library/LaunchAgents/network.location.switcher.user.plist"
    
    # Stop and remove service
    if launchctl list | grep -q "com.user.network_loc_switcher" 2>/dev/null; then
        log "Stopping user service..."
        launchctl bootout "$service_id" 2>/dev/null || true
        success "Service stopped"
    fi
    
    if [ -f "$plist_path" ]; then
        log "Removing plist file..."
        rm -f "$plist_path"
        success "Plist file removed"
    fi
    
    # Remove binary
    if [ -f "$bin_dir/$SCRIPT_NAME" ]; then
        log "Removing binary..."
        if [ -w "$bin_dir" ]; then
            rm -f "$bin_dir/$SCRIPT_NAME"
        else
            sudo rm -f "$bin_dir/$SCRIPT_NAME"
        fi
        success "Binary removed"
    fi
    
    # Remove library directory
    if [ -d "$lib_dir" ]; then
        log "Removing library directory..."
        # Need sudo if parent directory is not writable (can't remove subdirectories)
        # or if the directory itself is not writable
        local lib_parent=$(dirname "$lib_dir")
        if [[ ! -w "$lib_parent" ]] || [[ ! -w "$lib_dir" ]]; then
            sudo rm -rf "$lib_dir"
        else
            rm -rf "$lib_dir"
        fi
        success "Library directory removed"
    fi
    
    # Remove user logs (keep directory, just remove our logs)
    if [ -d "$HOME/Library/Logs" ]; then
        log "Removing log files..."
        rm -f "$HOME/Library/Logs/network_loc_switcher"*.log 2>/dev/null || true
        success "Log files removed"
    fi
    
    # Remove generated plist from project directory
    if [ -f "$PROJECT_DIR/network.location.switcher.user.plist" ]; then
        rm -f "$PROJECT_DIR/network.location.switcher.user.plist"
        log "Removed generated plist from project directory"
    fi
    
    # Note: Configuration file is preserved at $install_prefix/etc/$USER/network-location-config.json
    # Remove it manually if desired: rm $install_prefix/etc/$USER/network-location-config.json
    
    success "User mode uninstalled"
}

# Function to uninstall system mode
uninstall_system() {
    log "Uninstalling system mode..."
    
    # Determine installation paths
    local install_prefix="${INSTALL_PREFIX:-/usr/local}"
    local bin_dir="${install_prefix}/bin"
    local lib_dir="${install_prefix}/lib/${SCRIPT_NAME}"
    local etc_dir="${install_prefix}/etc"
    local log_dir="${install_prefix}/log"
    local service_id="system/com.system.network_loc_switcher"
    local plist_path="/Library/LaunchDaemons/network.location.switcher.system.plist"
    
    # Stop and remove service
    if sudo launchctl list | grep -q "com.system.network_loc_switcher" 2>/dev/null; then
        log "Stopping system service..."
        sudo launchctl bootout "$service_id" 2>/dev/null || true
        success "Service stopped"
    fi
    
    if [ -f "$plist_path" ]; then
        log "Removing plist file..."
        sudo rm -f "$plist_path"
        success "Plist file removed"
    fi
    
    # Remove binary
    if [ -f "$bin_dir/$SCRIPT_NAME" ]; then
        log "Removing binary..."
        sudo rm -f "$bin_dir/$SCRIPT_NAME"
        success "Binary removed"
    fi
    
    # Remove library directory
    if [ -d "$lib_dir" ]; then
        log "Removing library directory..."
        sudo rm -rf "$lib_dir"
        success "Library directory removed"
    fi
    
    # Note: Configuration file is preserved at $etc_dir/network-location-config.json
    # Remove it manually if desired: sudo rm /usr/local/etc/network-location-config.json
    
    # Remove log files (keep directory, just remove our logs)
    if [ -d "$log_dir" ]; then
        log "Removing log files..."
        sudo rm -f "$log_dir/network_loc_switcher"*.log 2>/dev/null || true
        success "Log files removed"
    fi
    
    # Remove generated plist from project directory
    if [ -f "$PROJECT_DIR/network.location.switcher.system.plist" ]; then
        rm -f "$PROJECT_DIR/network.location.switcher.system.plist"
        log "Removed generated plist from project directory"
    fi
    
    success "System mode uninstalled"
}

# Main execution
main() {
    local uninstall_mode=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --mode)
                uninstall_mode="$2"
                if [[ "$uninstall_mode" != "development" && "$uninstall_mode" != "user" && "$uninstall_mode" != "system" ]]; then
                    error "Invalid mode: $uninstall_mode. Use 'development', 'user', or 'system'"
                    exit 1
                fi
                shift 2
                ;;
            --help|-h)
                usage
                ;;
            *)
                error "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    # Prompt for mode if not provided
    if [ -z "$uninstall_mode" ]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🗑️  Network Location Switcher Uninstaller"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Which installation mode would you like to uninstall?"
        echo ""
        echo "  1) development  - Remove development installation (project directory)"
        echo "  2) user          - Remove user service installation (/usr/local)"
        echo "  3) system        - Remove system service installation (/usr/local, requires sudo)"
        echo ""
        read -p "Enter mode (1/2/3 or development/user/system): " uninstall_mode
        
        if [ -z "$uninstall_mode" ]; then
            error "No mode specified. Exiting."
            exit 1
        fi
        
        # Map numeric input to mode names
        case "$uninstall_mode" in
            1)
                uninstall_mode="development"
                ;;
            2)
                uninstall_mode="user"
                ;;
            3)
                uninstall_mode="system"
                ;;
        esac
    fi
    
    # Validate mode
    if [[ "$uninstall_mode" != "development" && "$uninstall_mode" != "user" && "$uninstall_mode" != "system" ]]; then
        error "Invalid mode: $uninstall_mode. Use '1', '2', '3', 'development', 'user', or 'system'"
        exit 1
    fi
    
    echo ""
    warning "This will remove all files, directories, and services for '$uninstall_mode' mode."
    read -p "Are you sure you want to continue? (Yes/No): " confirm
    
    if [[ "$confirm" != "Yes" && "$confirm" != "yes" && "$confirm" != "Y" && "$confirm" != "y" ]]; then
        log "Uninstall cancelled."
        exit 0
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Uninstalling $uninstall_mode mode..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Execute uninstall based on mode
    case "$uninstall_mode" in
        development)
            uninstall_development
            ;;
        user)
            uninstall_user
            ;;
        system)
            uninstall_system
            ;;
    esac
    
    echo ""
    success "✅ Uninstall complete!"
    echo ""
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi


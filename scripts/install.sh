#!/bin/bash
set -e

# Virtual Environment Setup Script for Network Location Switcher
# Supports development, user, and system installation modes

# Get the project root directory (parent of scripts/)
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_VERSION="python3"

# Installation mode and paths
DEFAULT_INSTALL_MODE="user"  # Default installation mode (can be changed here)
INSTALL_MODE="$DEFAULT_INSTALL_MODE"
INSTALL_PREFIX="/usr/local"
INSTALL_BIN_DIR=""
INSTALL_LIB_DIR=""
VENV_DIR=""
SCRIPT_NAME="network_loc_switcher"
DRY_RUN=false  # Dry run mode - show what would be done without actually doing it
PERMISSION_ERRORS=()  # Array to store permission errors for summary display
DIRECTORY_GROUP_RESULT=""  # Variable to store directory group result (to avoid subshell issues)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
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

# Dry run logging function
dry_run_log() {
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN]${NC} $1"
    fi
}

# Function to show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --mode MODE           Installation mode: 'development', 'user', or 'system' (default: $DEFAULT_INSTALL_MODE)"
    echo "  --prefix PATH         Installation prefix for user/system modes (default: /usr/local)"
    echo "  --bin-dir PATH        Binary directory (default: PREFIX/bin)"
    echo "  --lib-dir PATH        Library directory (default: PREFIX/lib/network_loc_switcher)"
    echo "  --dry-run             Show what would be installed without actually doing anything"
    echo "  --help, -h            Show this help message"
    echo ""
    echo "Installation Modes:"
    echo "  development           Install in current directory with .venv (for development)"
    echo "  user                  Install to system directories, runs as user service (for user deployment)"
    echo "  system                Install to system directories, runs as system service (for system deployment)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # User mode setup (default)"
    echo "  $0 --mode development                 # Development setup"
    echo "  $0 --mode user                       # User service setup to /usr/local"
    echo "  $0 --mode system                     # System service setup to /usr/local"
    echo "  $0 --mode user --prefix /opt         # User service setup to /opt"
    echo "  $0 --dry-run                         # Show what would be installed (dry run)"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Service Management"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Start/Stop/Remove LaunchAgent or LaunchDaemon:"
    echo ""
    echo "  System Service (runs as root):"
    echo "    Check status:    sudo launchctl list | grep network_loc_switcher"
    echo "    Start service:    sudo launchctl bootstrap system /Library/LaunchDaemons/network.location.switcher.system.plist"
    echo "    Stop service:     sudo launchctl bootout system/com.system.network_loc_switcher"
    echo "    Remove service:   sudo launchctl bootout system/com.system.network_loc_switcher"
    echo "                      sudo rm /Library/LaunchDaemons/network.location.switcher.system.plist"
    echo ""
    echo "  User Service (runs as current user):"
    echo "    Check status:    launchctl list | grep network_loc_switcher"
    echo "    Start service:   launchctl bootstrap gui/\$(id -u) ~/Library/LaunchAgents/network.location.switcher.user.plist"
    echo "    Stop service:     launchctl bootout gui/\$(id -u)/com.user.network_loc_switcher"
    echo "    Remove service:   launchctl bootout gui/\$(id -u)/com.user.network_loc_switcher"
    echo "                      rm ~/Library/LaunchAgents/network.location.switcher.user.plist"
    echo ""
    echo "  Development Service:"
    echo "    Check status:    launchctl list | grep network_loc_switcher"
    echo "    Start service:   launchctl bootstrap gui/\$(id -u) ~/Library/LaunchAgents/network.location.switcher.development.plist"
    echo "    Stop service:     launchctl bootout gui/\$(id -u)/com.development.network_loc_switcher"
    echo "    Remove service:   launchctl bootout gui/\$(id -u)/com.development.network_loc_switcher"
    echo "                      rm ~/Library/LaunchAgents/network.location.switcher.development.plist"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Monitoring Activity"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "View log files to monitor activity:"
    echo ""
    echo "  System Service:"
    echo "    sudo tail -f /usr/local/log/NetworkLocationSwitcher/network_loc_switcher-*.log"
    echo "    sudo tail -f /usr/local/log/NetworkLocationSwitcher/network_loc_switcher-stdout.log"
    echo "    sudo tail -f /usr/local/log/NetworkLocationSwitcher/network_loc_switcher-stderr.log"
    echo ""
    echo "  User Service:"
    echo "    tail -f ~/Library/Logs/NetworkLocationSwitcher/network_loc_switcher-*.log"
    echo "    tail -f ~/Library/Logs/NetworkLocationSwitcher/network_loc_switcher-stdout.log"
    echo "    tail -f ~/Library/Logs/NetworkLocationSwitcher/network_loc_switcher-stderr.log"
    echo ""
    echo "  Development Service:"
    echo "    tail -f ./logs/network_loc_switcher-*.log"
    echo "    tail -f ./logs/network_loc_switcher-stdout.log"
    echo "    tail -f ./logs/network_loc_switcher-stderr.log"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Complete Removal"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "To completely remove the installation, run:"
    echo "    ./uninstall.sh"
    echo ""
    echo "This will prompt you for the installation mode and remove all files,"
    echo "directories, and services associated with that mode."
    echo ""
    exit 0
}

# Function to parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --mode)
                INSTALL_MODE="$2"
                if [[ "$INSTALL_MODE" != "development" && "$INSTALL_MODE" != "user" && "$INSTALL_MODE" != "system" ]]; then
                    error "Invalid mode: $INSTALL_MODE. Use 'development', 'user', or 'system'"
                    exit 1
                fi
                shift 2
                ;;
            --prefix)
                INSTALL_PREFIX="$2"
                shift 2
                ;;
            --bin-dir)
                INSTALL_BIN_DIR="$2"
                shift 2
                ;;
            --lib-dir)
                INSTALL_LIB_DIR="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
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
}

# Function to setup installation paths
setup_paths() {
    if [[ "$INSTALL_MODE" == "development" ]]; then
        # Development mode - use project directory
        VENV_DIR="$PROJECT_DIR/.venv"
        INSTALL_BIN_DIR="$PROJECT_DIR"
        INSTALL_LIB_DIR="$PROJECT_DIR"
        
        log "Development installation paths:"
        log "  Project: $PROJECT_DIR"
        log "  Virtual env: $VENV_DIR"
    else
        # User or System mode - install to system directories
        INSTALL_BIN_DIR="${INSTALL_BIN_DIR:-$INSTALL_PREFIX/bin}"
        INSTALL_LIB_DIR="${INSTALL_LIB_DIR:-$INSTALL_PREFIX/lib/$SCRIPT_NAME}"
        VENV_DIR="$INSTALL_LIB_DIR/.venv"
        
        local mode_name="User"
        if [[ "$INSTALL_MODE" == "system" ]]; then
            mode_name="System"
        fi
        
        log "$mode_name installation paths:"
        log "  Prefix: $INSTALL_PREFIX"
        log "  Binary: $INSTALL_BIN_DIR/$SCRIPT_NAME"
        log "  Library: $INSTALL_LIB_DIR"
        log "  Virtual env: $VENV_DIR"
        if [[ "$INSTALL_MODE" == "system" ]]; then
            log "  Config: $INSTALL_PREFIX/etc/network-location-config.json"
        elif [[ "$INSTALL_MODE" == "user" ]]; then
            log "  Config: $INSTALL_PREFIX/etc/$USER/network-location-config.json"
        fi
        
        # Check if we need sudo for installation
        if [[ ! -w "$INSTALL_PREFIX" ]]; then
            warning "Installation requires sudo privileges for $INSTALL_PREFIX"
            if ! sudo -n true 2>/dev/null; then
                log "You may be prompted for your password..."
            fi
        fi
    fi
}

# Function to detect Python version
detect_python() {
    log "Detecting Python installation..."
    
    for py_cmd in python3.12 python3.11 python3.10 python3.9 python3 python; do
        if command -v "$py_cmd" >/dev/null 2>&1; then
            PYTHON_VERSION="$py_cmd"
            local version=$($py_cmd --version 2>&1 | cut -d' ' -f2)
            success "Found Python: $py_cmd (version $version)"
            return 0
        fi
    done
    
    error "No suitable Python installation found"
    echo "Please install Python 3.9+ from:"
    echo "  - https://www.python.org/downloads/"
    echo "  - brew install python"
    echo "  - pyenv install 3.12"
    exit 1
}

# Function to determine the group to use for /usr/local subdirectories
# Checks existing directories for group consistency, prompts if none exist, or exits if inconsistent
determine_directory_group() {
    local prefix="${1:-/usr/local}"
    local dirs_to_check=("$prefix/bin" "$prefix/lib" "$prefix/etc" "$prefix/log")
    local existing_dirs=()
    local groups_found=()
    
    # Check which directories exist and collect their groups
    for dir in "${dirs_to_check[@]}"; do
        if [[ -d "$dir" ]]; then
            existing_dirs+=("$dir")
            local group=$(stat -f "%Sg" "$dir" 2>/dev/null || echo "")
            if [[ -n "$group" ]]; then
                groups_found+=("$group")
            fi
        fi
    done
    
    # If no directories exist, prompt user for group
    if [[ ${#existing_dirs[@]} -eq 0 ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            # In dry-run, show what would happen but don't prompt
            echo "" >&2
            echo "📁 No existing /usr/local subdirectories found." >&2
            echo "   The following directories will be created:" >&2
            echo "   - $prefix/bin" >&2
            echo "   - $prefix/lib" >&2
            echo "   - $prefix/etc" >&2
            echo "   - $prefix/log" >&2
            echo "" >&2
            dry_run_log "Would prompt for group name (skipped in dry-run mode)"
            # Return a placeholder for dry-run
            DIRECTORY_GROUP_RESULT="wheel"  # Default group for dry-run
            echo "wheel"  # Also output for backwards compatibility
            return 0
        else
            # Use stderr for prompts so they don't interfere with return value
            echo "" >&2
            echo "📁 No existing /usr/local subdirectories found." >&2
            echo "   The following directories will be created:" >&2
            echo "   - $prefix/bin" >&2
            echo "   - $prefix/lib" >&2
            echo "   - $prefix/etc" >&2
            echo "   - $prefix/log" >&2
            echo "" >&2
            
            while true; do
                read -p "Enter the group name for these directories (e.g., devgroup, admin, wheel): " group_name
                if [[ -n "$group_name" ]]; then
                    # Verify group exists
                    if dscl . -read /Groups/"$group_name" >/dev/null 2>&1; then
                        DIRECTORY_GROUP_RESULT="$group_name"
                        echo "$group_name"
                        return 0
                    else
                        error "Group '$group_name' does not exist. Please enter a valid group name."
                        echo "You can list available groups with: dscl . -list /Groups" >&2
                    fi
                else
                    warning "Group name cannot be empty. Please try again."
                fi
            done
        fi
    fi
    
    # Check for group consistency
    if [[ ${#groups_found[@]} -gt 0 ]]; then
        # Get unique groups
        local unique_groups=($(printf '%s\n' "${groups_found[@]}" | sort -u))
        
        if [[ ${#unique_groups[@]} -gt 1 ]]; then
            # Build error message
            local error_msg="Multiple groups found in existing /usr/local subdirectories:"
            for dir in "${existing_dirs[@]}"; do
                local dir_group=$(stat -f "%Sg" "$dir" 2>/dev/null || echo "unknown")
                error_msg="$error_msg"$'\n'"   $dir: group '$dir_group'"
            done
            error_msg="$error_msg"$'\n'$'\n'"All directories must use the same group. Please fix the group ownership"
            error_msg="$error_msg"$'\n'"of the existing directories before running setup again."
            error_msg="$error_msg"$'\n'$'\n'"You can fix this by running:"
            error_msg="$error_msg"$'\n'"  sudo chgrp -R <groupname> $prefix/bin $prefix/lib $prefix/etc $prefix/log"
            
            # Display error
            error "Multiple groups found in existing /usr/local subdirectories:"
            for dir in "${existing_dirs[@]}"; do
                local dir_group=$(stat -f "%Sg" "$dir" 2>/dev/null || echo "unknown")
                echo "   $dir: group '$dir_group'"
            done
            echo ""
            error "All directories must use the same group. Please fix the group ownership"
            error "of the existing directories before running setup again."
            echo ""
            echo "You can fix this by running:"
            echo "  sudo chgrp -R <groupname> $prefix/bin $prefix/lib $prefix/etc $prefix/log"
            
            # In dry-run mode, store error and continue; otherwise exit
            if [[ "$DRY_RUN" == true ]]; then
                # Only add error once (function may be called multiple times)
                local error_already_added=false
                for existing_error in "${PERMISSION_ERRORS[@]}"; do
                    if [[ "$existing_error" == "$error_msg" ]]; then
                        error_already_added=true
                        break
                    fi
                done
                if [[ "$error_already_added" == false ]]; then
                    PERMISSION_ERRORS+=("$error_msg")
                fi
                DIRECTORY_GROUP_RESULT="wheel"  # Set placeholder for dry-run
                echo "wheel"  # Also output for backwards compatibility
                return 0
            else
                exit 1
            fi
        else
            # All directories use the same group
            DIRECTORY_GROUP_RESULT="${unique_groups[0]}"
            echo "Found existing directories with consistent group: ${unique_groups[0]}" >&2
            echo "${unique_groups[0]}"
            return 0
        fi
    else
        # Directories exist but couldn't determine group (shouldn't happen, but handle gracefully)
        echo "Could not determine group from existing directories" >&2
        echo "" >&2
        read -p "Enter the group name to use for new directories: " group_name
        if [[ -n "$group_name" ]]; then
            DIRECTORY_GROUP_RESULT="$group_name"
            echo "$group_name"
            return 0
        else
            echo "Group name is required" >&2
            exit 1
        fi
    fi
}

# Helper function to set directory ownership and permissions
# Uses the provided group and matches permissions from reference directories
set_directory_permissions() {
    local target_dir="$1"
    local target_group="$2"
    local description="${3:-directory}"
    
    if [[ ! -d "$target_dir" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            # In dry-run, just log what would be done even if directory doesn't exist yet
            dry_run_log "Would set ownership and permissions for $target_dir (directory would be created first)"
            return 0
        else
            return 1
        fi
    fi
    
    # Find a reference directory to match permissions (but use provided group)
    local reference_dir=""
    local parent_dir=$(dirname "$target_dir")
    
    # Check sibling directories first, then parent
    for dir in "$parent_dir/bin" "$parent_dir/lib" "$parent_dir/etc" "$parent_dir/log" "$parent_dir"; do
        if [[ -d "$dir" && "$dir" != "$target_dir" ]]; then
            reference_dir="$dir"
            break
        fi
    done
    
    local ref_perms="755"
    local target_user="root"
    
    # For /usr/local subdirectories, always use root as owner
    # For other prefixes, use root as default but allow reference directory's owner
    if [[ "$target_dir" =~ ^/usr/local/ ]]; then
        target_user="root"
        # Still get permissions from reference directory if available
        if [[ -n "$reference_dir" ]]; then
            ref_perms=$(stat -f "%OLp" "$reference_dir" 2>/dev/null || echo "755")
        fi
    elif [[ -n "$reference_dir" ]]; then
        ref_perms=$(stat -f "%OLp" "$reference_dir" 2>/dev/null || echo "755")
        local ref_user=$(stat -f "%Su" "$reference_dir" 2>/dev/null || echo "root")
        target_user="$ref_user"
    fi
    
    # Set ownership (always root for /usr/local, group from parameter)
    log "Setting $description ownership: $target_user:$target_group"
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_log "Would run: chown $target_user:$target_group $target_dir"
    else
        if [[ ! -w "$(dirname "$target_dir")" ]]; then
            sudo chown "$target_user:$target_group" "$target_dir"
        else
            chown "$target_user:$target_group" "$target_dir"
        fi
    fi
    
    # Set permissions with setgid bit to match group ownership behavior
    log "Setting $description permissions with setgid bit: ${ref_perms}"
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_log "Would run: chmod ${ref_perms} $target_dir && chmod g+s $target_dir"
    else
        if [[ ! -w "$(dirname "$target_dir")" ]]; then
            sudo chmod "${ref_perms}" "$target_dir"
            sudo chmod g+s "$target_dir"  # Set setgid bit for group inheritance
        else
            chmod "${ref_perms}" "$target_dir"
            chmod g+s "$target_dir"  # Set setgid bit for group inheritance
        fi
    fi
}

# Function to create directories and virtual environment
create_venv() {
    log "Creating virtual environment at $VENV_DIR"
    
    # Create directories for user or system mode
    if [[ "$INSTALL_MODE" == "user" || "$INSTALL_MODE" == "system" ]]; then
        log "Creating installation directories..."
        
        # Determine the group to use for directories
        determine_directory_group "$INSTALL_PREFIX"
        local dir_group="$DIRECTORY_GROUP_RESULT"
        log "Using group '$dir_group' for /usr/local subdirectories"
        
        # Determine if we need sudo
        local need_sudo=false
        if [[ ! -w "$INSTALL_PREFIX" ]]; then
            need_sudo=true
            if ! sudo -n true 2>/dev/null; then
                log "You may be prompted for your password to create directories..."
            fi
        fi
        
        # First, ensure /usr/local/lib exists and has correct permissions
        # This must be done BEFORE creating subdirectories
        local lib_parent_dir="$INSTALL_PREFIX/lib"
        if [[ "$DRY_RUN" == true ]]; then
            if [[ -d "$lib_parent_dir" ]]; then
                log "Found existing directory: $lib_parent_dir"
                dry_run_log "Would set ownership and permissions for $lib_parent_dir"
            else
                dry_run_log "Would create directory: $lib_parent_dir"
                dry_run_log "Would set ownership and permissions for $lib_parent_dir"
            fi
        else
            # Ensure /usr/local/lib exists
            if [[ ! -d "$lib_parent_dir" ]]; then
                if [[ "$need_sudo" == true ]]; then
                    sudo mkdir -p "$lib_parent_dir"
                else
                    mkdir -p "$lib_parent_dir"
                fi
            fi
            # Set permissions for /usr/local/lib FIRST (before creating subdirectories)
            set_directory_permissions "$lib_parent_dir" "$dir_group" "lib parent directory"
        fi
        
        # Create /usr/local/bin, /usr/local/lib/network_loc_switcher, and /usr/local/etc directories
        local etc_dir="$INSTALL_PREFIX/etc"
        
        if [[ "$DRY_RUN" == true ]]; then
            # Check which directories already exist
            if [[ -d "$INSTALL_BIN_DIR" ]]; then
                log "Found existing directory: $INSTALL_BIN_DIR"
            else
                dry_run_log "Would create directory: $INSTALL_BIN_DIR"
            fi
            
            if [[ -d "$INSTALL_LIB_DIR" ]]; then
                log "Found existing directory: $INSTALL_LIB_DIR"
            else
                dry_run_log "Would create directory: $INSTALL_LIB_DIR"
            fi
            
            if [[ -d "$etc_dir" ]]; then
                log "Found existing directory: $etc_dir"
            else
                dry_run_log "Would create directory: $etc_dir"
            fi
        else
            # Create directories - /usr/local/lib should already have correct permissions
            if [[ "$need_sudo" == true ]]; then
                sudo mkdir -p "$INSTALL_BIN_DIR" "$INSTALL_LIB_DIR" "$etc_dir"
            else
                mkdir -p "$INSTALL_BIN_DIR" "$INSTALL_LIB_DIR" "$etc_dir"
            fi
            
            # Verify INSTALL_LIB_DIR was created successfully
            if [[ ! -d "$INSTALL_LIB_DIR" ]]; then
                error "Failed to create directory: $INSTALL_LIB_DIR"
                exit 1
            fi
        fi
        
        # Set ownership and permissions using the determined group
        set_directory_permissions "$INSTALL_BIN_DIR" "$dir_group" "bin directory"
        set_directory_permissions "$etc_dir" "$dir_group" "etc directory"
        set_directory_permissions "$INSTALL_LIB_DIR" "$dir_group" "lib directory"
    fi
    
    # Ensure the parent directory exists and is writable before creating venv
    local venv_parent_dir=$(dirname "$VENV_DIR")
    if [[ "$DRY_RUN" == true ]]; then
        if [[ ! -d "$venv_parent_dir" ]]; then
            dry_run_log "Would ensure parent directory exists: $venv_parent_dir"
        fi
    else
        # Verify parent directory exists
        if [[ ! -d "$venv_parent_dir" ]]; then
            error "Parent directory does not exist: $venv_parent_dir"
            error "This should have been created earlier. Please check the setup process."
            exit 1
        fi
        
        # For system mode, ensure we can write to the directory (may need sudo)
        if [[ "$INSTALL_MODE" == "system" && ! -w "$venv_parent_dir" ]]; then
            log "Parent directory requires sudo for venv creation"
        fi
    fi
    
    # Remove existing venv if it exists
    if [ -d "$VENV_DIR" ]; then
        warning "Removing existing virtual environment..."
        if [[ "$DRY_RUN" == true ]]; then
            dry_run_log "Would remove: $VENV_DIR"
        else
            # Determine if we need sudo to remove the venv
            # We need sudo if:
            # 1. We're in system mode (parent dir is owned by root)
            # 2. The parent directory is not writable (can't remove subdirectories)
            # 3. The venv directory itself is not writable
            local need_sudo_for_rm=false
            if [[ "$INSTALL_MODE" == "system" ]]; then
                need_sudo_for_rm=true
            elif [[ ! -w "$venv_parent_dir" ]]; then
                # Can't remove directory from parent if parent isn't writable
                need_sudo_for_rm=true
            elif [[ ! -w "$VENV_DIR" ]]; then
                # Can't remove directory if it's not writable
                need_sudo_for_rm=true
            fi
            
            if [[ "$need_sudo_for_rm" == true ]]; then
                log "Removing venv with sudo (required for system mode or unwritable parent directory)"
                if ! sudo rm -rf "$VENV_DIR" 2>/dev/null; then
                    # If sudo rm fails, try again with explicit error handling
                    error "Failed to remove venv directory. Attempting cleanup..."
                    sudo rm -rf "$VENV_DIR" || {
                        error "Could not remove $VENV_DIR"
                        error "You may need to manually remove it with: sudo rm -rf $VENV_DIR"
                        exit 1
                    }
                fi
            else
                rm -rf "$VENV_DIR"
            fi
        fi
    fi
    
    # Create new venv
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_log "Would create virtual environment: $VENV_DIR"
        if [[ "$INSTALL_MODE" == "system" && ! -w "$venv_parent_dir" ]]; then
            dry_run_log "Would run: sudo $PYTHON_VERSION -m venv $VENV_DIR"
        else
            dry_run_log "Would run: $PYTHON_VERSION -m venv $VENV_DIR"
        fi
    else
        # For system mode or if parent directory is not writable, use sudo
        if [[ ("$INSTALL_MODE" == "system" || ! -w "$venv_parent_dir") ]]; then
            sudo "$PYTHON_VERSION" -m venv "$VENV_DIR"
            # Set ownership of venv to current user so they can install packages
            sudo chown -R "$USER:$(id -gn)" "$VENV_DIR"
        else
            "$PYTHON_VERSION" -m venv "$VENV_DIR"
        fi
        success "Virtual environment created"
    fi
}

# Function to activate and upgrade pip
setup_venv() {
    log "Setting up virtual environment..."
    
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_log "Would activate virtual environment: $VENV_DIR"
        dry_run_log "Would upgrade pip, setuptools, and wheel"
    else
        # Activate venv
        source "$VENV_DIR/bin/activate"
        
        # Upgrade pip
        log "Upgrading pip..."
        pip install --upgrade pip setuptools wheel
        
        success "Virtual environment setup complete"
    fi
}

# Function to install dependencies
install_dependencies() {
    log "Installing dependencies..."
    
    # Check for macOS - this script only works on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        error "This network location switcher is macOS-specific and requires Darwin/macOS"
        error "Detected OS type: $OSTYPE"
        echo ""
        echo "The network location switcher uses macOS-specific frameworks:"
        echo "  - SystemConfiguration framework"
        echo "  - CoreFoundation framework"
        echo "  - networksetup command"
        echo "  - scutil command"
        echo ""
        echo "These are not available on other operating systems."
        echo "For cross-platform network management, consider using:"
        echo "  - NetworkManager (Linux)"
        echo "  - netsh (Windows)"
        echo "  - Custom solutions using psutil/netifaces"
        exit 1
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_log "Would activate virtual environment: $VENV_DIR"
        dry_run_log "Would install dependencies from: requirements-macos.txt"
        if [[ "$INSTALL_MODE" == "development" ]]; then
            dry_run_log "Would install development tools: pre-commit"
        fi
    else
        # Activate venv
        source "$VENV_DIR/bin/activate"
        
        # Install macOS-specific dependencies
        log "Installing macOS-specific dependencies..."
        pip install -r requirements-macos.txt
        success "macOS dependencies installed"
        
        # Install development dependencies (only in development mode)
        if [[ "$INSTALL_MODE" == "development" ]]; then
            log "Installing development tools..."
            pip install pre-commit
        fi
        
        success "All dependencies installed"
    fi
}

# Function to update config file with appropriate log path
update_config_log_path() {
    local config_file="$1"
    local log_path
    
    if [[ "$INSTALL_MODE" == "development" ]]; then
        log_path="$PROJECT_DIR/logs/NetworkLocationSwitcher/network_loc_switcher.log"
        log "Setting development log path: $log_path"
    elif [[ "$INSTALL_MODE" == "system" ]]; then
        log_path="/usr/local/log/NetworkLocationSwitcher/network_loc_switcher.log"
        log "Setting system log path: $log_path"
    else
        # User mode
        log_path="$HOME/Library/Logs/NetworkLocationSwitcher/network_loc_switcher.log"
        log "Setting user log path: $log_path"
    fi
    
    # Update the config file log_file path
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_log "Would update log_file path in $config_file to: $log_path"
    else
        if [ -f "$config_file" ]; then
            # Determine if we need sudo to write to the config file
            # Note: Even if the file is group-writable, sed -i needs to create a temp file
            # in the same directory, so we need write access to the directory, not just the file
            local need_sudo_for_config=false
            if [[ "$INSTALL_MODE" == "system" ]]; then
                # In system mode, config is in /usr/local/etc, owned by root:devgroup
                # Even if user is in devgroup, the directory may not be group-writable,
                # so sed -i cannot create temp files there without sudo
                need_sudo_for_config=true
            elif [[ ! -w "$config_file" ]]; then
                # File is not writable by current user
                need_sudo_for_config=true
            elif [[ ! -w "$(dirname "$config_file")" ]]; then
                # Directory is not writable, so sed -i cannot create temp files there
                need_sudo_for_config=true
            fi
            
            # Use sed to replace the log_file line, handling both cases with and without trailing comma
            if [[ "$need_sudo_for_config" == true ]]; then
                sudo sed -i '' "s|\"log_file\": \"[^\"]*\"|\"log_file\": \"$log_path\"|g" "$config_file"
            else
                sed -i '' "s|\"log_file\": \"[^\"]*\"|\"log_file\": \"$log_path\"|g" "$config_file"
            fi
            success "Updated log_file path to: $log_path"
        else
            warning "Config file not found: $config_file"
        fi
    fi
}

# Function to install script files
install_script_files() {
    log "Installing script files..."
    
    if [[ "$INSTALL_MODE" == "user" || "$INSTALL_MODE" == "system" ]]; then
        # Copy source files to library directory
        log "Installing script files to $INSTALL_LIB_DIR"
        
        # Determine config directory based on mode
        local config_dir
        if [[ "$INSTALL_MODE" == "system" ]]; then
            config_dir="$INSTALL_PREFIX/etc"
        else
            # User mode - config goes to /usr/local/etc/{username}
            config_dir="$INSTALL_PREFIX/etc/$USER"
        fi
        
        # Determine the group for setting config file permissions (for system/user modes)
        local config_group=""
        if [[ "$INSTALL_MODE" == "system" || "$INSTALL_MODE" == "user" ]]; then
            determine_directory_group "$INSTALL_PREFIX"
            config_group="$DIRECTORY_GROUP_RESULT"
        fi
        
        # For user mode, ensure the user-specific config directory exists with proper permissions
        if [[ "$INSTALL_MODE" == "user" ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                if [[ -d "$config_dir" ]]; then
                    log "Found existing directory: $config_dir"
                else
                    dry_run_log "Would create directory: $config_dir"
                    dry_run_log "Would set ownership and permissions for $config_dir"
                fi
            else
                # Ensure /usr/local/etc exists first
                local etc_parent="$INSTALL_PREFIX/etc"
                if [[ ! -d "$etc_parent" ]]; then
                    if [[ ! -w "$INSTALL_PREFIX" ]]; then
                        sudo mkdir -p "$etc_parent"
                    else
                        mkdir -p "$etc_parent"
                    fi
                fi
                
                # Create user-specific directory if it doesn't exist
                if [[ ! -d "$config_dir" ]]; then
                    log "Creating user config directory: $config_dir"
                    if [[ ! -w "$etc_parent" ]]; then
                        sudo mkdir -p "$config_dir"
                    else
                        mkdir -p "$config_dir"
                    fi
                fi
                
                # Set ownership and permissions for the user config directory
                set_directory_permissions "$config_dir" "$config_group" "user config directory"
            fi
        fi
        
        # Create wrapper script for production
        local wrapper_script="$INSTALL_BIN_DIR/$SCRIPT_NAME"
        
        if [[ "$DRY_RUN" == true ]]; then
            dry_run_log "Would copy: $PROJECT_DIR/network_loc_switcher/network_loc_switcher.py -> $INSTALL_LIB_DIR/"
            dry_run_log "Would copy: $PROJECT_DIR/requirements-macos.txt -> $INSTALL_LIB_DIR/"
            dry_run_log "Would copy: $PROJECT_DIR/network-location-config.default.json -> $INSTALL_LIB_DIR/"
            if [ -f "$config_dir/network-location-config.json" ]; then
                log "Found existing configuration file at $config_dir/network-location-config.json"
                dry_run_log "Would preserve existing config and update log path"
            elif [ -f "$PROJECT_DIR/network-location-config.json" ]; then
                dry_run_log "Would copy: $PROJECT_DIR/network-location-config.json -> $config_dir/"
            else
                dry_run_log "Would create: $config_dir/network-location-config.json (from template)"
            fi
            dry_run_log "Would create wrapper script: $wrapper_script"
            dry_run_log "Would update log_file path in config file"
        else
            # Use sudo if needed
            if [[ ! -w "$INSTALL_BIN_DIR" ]]; then
            # Copy Python script and config files to lib directory
            sudo cp "$PROJECT_DIR/network_loc_switcher/network_loc_switcher.py" "$INSTALL_LIB_DIR/"
            sudo cp "$PROJECT_DIR/requirements-macos.txt" "$INSTALL_LIB_DIR/"
            
            # Copy default template (always) to lib directory
            sudo cp "$PROJECT_DIR/network-location-config.default.json" "$INSTALL_LIB_DIR/"
            
            # Handle config file - preserve existing if present, otherwise create from template or project
            # For system mode, config goes to /usr/local/etc; for user mode, it goes to /usr/local/etc/{username}
            if [ -f "$config_dir/network-location-config.json" ]; then
                log "Preserving existing configuration file at $config_dir/network-location-config.json"
                # Just update log path in existing config
                update_config_log_path "$config_dir/network-location-config.json"
            elif [ -f "$PROJECT_DIR/network-location-config.json" ]; then
                sudo cp "$PROJECT_DIR/network-location-config.json" "$config_dir/"
                log "Copied configuration from project directory to $config_dir"
                # Make config file group-writable
                sudo chmod g+w "$config_dir/network-location-config.json"
                # Update log path in copied config
                update_config_log_path "$config_dir/network-location-config.json"
            else
                log "Creating new configuration from template in $config_dir"
                sudo cp "$PROJECT_DIR/network-location-config.default.json" "$config_dir/network-location-config.json"
                # Make config file group-writable
                sudo chmod g+w "$config_dir/network-location-config.json"
                # Update log path in new config
                update_config_log_path "$config_dir/network-location-config.json"
            fi
            
            # Create wrapper script in bin directory
            sudo tee "$wrapper_script" > /dev/null << EOF
#!/bin/bash
# Production wrapper for network_loc_switcher
SCRIPT_DIR="$INSTALL_LIB_DIR"
VENV_DIR="$VENV_DIR"

# Activate virtual environment and run script
source "\$VENV_DIR/bin/activate"
exec "\$VENV_DIR/bin/python" "\$SCRIPT_DIR/network_loc_switcher.py" "\$@"
EOF
            
            sudo chmod +x "$wrapper_script"
            sudo chown "$USER:$(id -gn)" "$wrapper_script"
        else
            # Copy without sudo
            cp "$PROJECT_DIR/network_loc_switcher/network_loc_switcher.py" "$INSTALL_LIB_DIR/"
            cp "$PROJECT_DIR/requirements-macos.txt" "$INSTALL_LIB_DIR/"
            
            # Copy default template (always) to lib directory
            cp "$PROJECT_DIR/network-location-config.default.json" "$INSTALL_LIB_DIR/"
            
            # Handle config file - preserve existing if present, otherwise create from template or project
            # For system mode, config goes to /usr/local/etc; for user mode, it goes to /usr/local/etc/{username}
            if [ -f "$config_dir/network-location-config.json" ]; then
                log "Preserving existing configuration file at $config_dir/network-location-config.json"
                # Just update log path in existing config
                update_config_log_path "$config_dir/network-location-config.json"
            elif [ -f "$PROJECT_DIR/network-location-config.json" ]; then
                cp "$PROJECT_DIR/network-location-config.json" "$config_dir/"
                log "Copied configuration from project directory to $config_dir"
                # Make config file group-writable
                chmod g+w "$config_dir/network-location-config.json"
                # Update log path in copied config
                update_config_log_path "$config_dir/network-location-config.json"
            else
                log "Creating new configuration from template in $config_dir"
                cp "$PROJECT_DIR/network-location-config.default.json" "$config_dir/network-location-config.json"
                # Make config file group-writable
                chmod g+w "$config_dir/network-location-config.json"
                # Update log path in new config
                update_config_log_path "$config_dir/network-location-config.json"
            fi
            
            # Create wrapper script
            cat > "$wrapper_script" << EOF
#!/bin/bash
# Production wrapper for network_loc_switcher
SCRIPT_DIR="$INSTALL_LIB_DIR"
VENV_DIR="$VENV_DIR"

# Activate virtual environment and run script
source "\$VENV_DIR/bin/activate"
exec "\$VENV_DIR/bin/python" "\$SCRIPT_DIR/network_loc_switcher.py" "\$@"
EOF
            
            chmod +x "$wrapper_script"
        fi
        
        success "Script installed to $wrapper_script"
        fi  # End of DRY_RUN else block
    else
        # Development mode - files stay in project directory
        log "Development mode - updating configuration for local logs"
        
        if [[ "$DRY_RUN" == true ]]; then
            if [ -f "$PROJECT_DIR/network-location-config.json" ]; then
                dry_run_log "Would update log_file path in: $PROJECT_DIR/network-location-config.json"
            else
                dry_run_log "Would create: $PROJECT_DIR/network-location-config.json (from template)"
                dry_run_log "Would update log_file path in config file"
            fi
        else
            # Create or update config file for development
            if [ -f "$PROJECT_DIR/network-location-config.json" ]; then
                log "Updating existing user configuration for development"
                update_config_log_path "$PROJECT_DIR/network-location-config.json"
            else
                log "Creating user configuration from template for development"
                cp "$PROJECT_DIR/network-location-config.default.json" "$PROJECT_DIR/network-location-config.json"
                update_config_log_path "$PROJECT_DIR/network-location-config.json"
            fi
        fi
        
        success "Development mode - files remain in $PROJECT_DIR"
    fi
}

# Function to setup pre-commit hooks (development mode only)
setup_precommit() {
    log "Setting up development pre-commit hooks..."
    
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_log "Would activate virtual environment: $VENV_DIR"
        if [ ! -f ".pre-commit-config.yaml" ]; then
            dry_run_log "Would create: .pre-commit-config.yaml"
        fi
        dry_run_log "Would install pre-commit hooks"
    else
        source "$VENV_DIR/bin/activate"
        
        # Create pre-commit config if it doesn't exist
        if [ ! -f ".pre-commit-config.yaml" ]; then
            cat > .pre-commit-config.yaml << 'EOF'
repos:
  - repo: https://github.com/psf/black
    rev: 24.10.0
    hooks:
      - id: black
        language_version: python3
        
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.8.4
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format
              
  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.11.2
    hooks:
      - id: mypy
        args: [--ignore-missing-imports, --no-strict-optional]
EOF
        fi
        
        # Install pre-commit hooks
        pre-commit install
        success "Pre-commit hooks installed"
    fi
}

# Function to create activation script (development mode only)
create_activation_script() {
    log "Creating development activation script..."
    
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_log "Would create: activate.sh"
    else
        cat > activate.sh << EOF
#!/bin/bash
# Activation script for network_loc_switcher virtual environment

PROJECT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="\$PROJECT_DIR/.venv"

if [ ! -d "\$VENV_DIR" ]; then
    echo "❌ Virtual environment not found. Run ./install.sh first"
    exit 1
fi

echo "🐍 Activating virtual environment..."
source "\$VENV_DIR/bin/activate"

echo "✅ Virtual environment activated!"
echo "📍 Project: \$PROJECT_DIR"
echo "🐍 Python: \$(which python)"
echo "📦 Pip: \$(which pip)"

# Show installed packages
echo ""
echo "📋 Installed packages:"
pip list --format=columns

echo ""
echo "🚀 Usage:"
echo "  python network_loc_switcher.py    # Run the network switcher"
echo "  pytest                                 # Run tests" 
echo "  black .                                # Format code"
echo "  ruff check .                          # Lint code"
echo "  deactivate                            # Exit virtual environment"
EOF

        chmod +x activate.sh
        success "Activation script created: ./activate.sh"
    fi
}

# Function to create launchd plist for venv
create_launchd_plist() {
    log "Creating launchd plist files for virtual environment..."
    
    if [[ "$DRY_RUN" == true ]]; then
        local plist_name=""
        local plist_source=""
        local plist_dest=""
        
        if [[ "$INSTALL_MODE" == "development" ]]; then
            plist_name="network.location.switcher.development.plist"
            plist_source="$PROJECT_DIR/$plist_name"
            plist_dest="$HOME/Library/LaunchAgents/$plist_name"
            dry_run_log "Would create: $plist_source"
            dry_run_log "Would copy to: $plist_dest (cp $plist_name ~/Library/LaunchAgents/)"
        elif [[ "$INSTALL_MODE" == "system" ]]; then
            plist_name="network.location.switcher.system.plist"
            plist_source="$PROJECT_DIR/$plist_name"
            plist_dest="/Library/LaunchDaemons/$plist_name"
            dry_run_log "Would create: $plist_source"
            dry_run_log "Would copy to: $plist_dest (sudo cp $plist_name /Library/LaunchDaemons/)"
        else
            plist_name="network.location.switcher.user.plist"
            plist_source="$PROJECT_DIR/$plist_name"
            plist_dest="$HOME/Library/LaunchAgents/$plist_name"
            dry_run_log "Would create: $plist_source"
            dry_run_log "Would copy to: $plist_dest (cp $plist_name ~/Library/LaunchAgents/)"
        fi
    else
        if [[ "$INSTALL_MODE" == "development" ]]; then
            # Create development plist
            create_development_plist
        elif [[ "$INSTALL_MODE" == "system" ]]; then
            # Create system service plist
            create_production_system_plist
        else
            # User mode - create user service plist
            create_production_user_plist
        fi
    fi
}

# Function to create production system service plist
create_production_system_plist() {
    local plist_name="network.location.switcher.system.plist"
    local plist_source="$PROJECT_DIR/$plist_name"
    local plist_dest="/Library/LaunchDaemons/$plist_name"
    local log_dir="/usr/local/log/NetworkLocationSwitcher"
    local exec_path="$INSTALL_BIN_DIR/$SCRIPT_NAME"
    
    log "Creating system service plist: $plist_source"
    
    cat > "$plist_source" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.system.network_loc_switcher</string>
    
    <key>Program</key>
    <string>$exec_path</string>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
        <key>Crashed</key>
        <true/>
    </dict>
    
    <key>StandardOutPath</key>
    <string>$log_dir/network_loc_switcher-stdout.log</string>
    
    <key>StandardErrorPath</key>
    <string>$log_dir/network_loc_switcher-stderr.log</string>
    
    <key>WorkingDirectory</key>
    <string>$INSTALL_LIB_DIR</string>
    
    <!-- Use virtual environment's Python and PATH -->
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>$VENV_DIR/bin:/usr/local/bin:/usr/bin:/bin</string>
        <key>VIRTUAL_ENV</key>
        <string>$VENV_DIR</string>
        <key>PYTHONPATH</key>
        <string>$INSTALL_LIB_DIR</string>
    </dict>
    
    <!-- Resource limits -->
    <key>SoftResourceLimits</key>
    <dict>
        <key>NumberOfFiles</key>
        <integer>1024</integer>
    </dict>
    
    <!-- Throttle restart attempts -->
    <key>ThrottleInterval</key>
    <integer>10</integer>
</dict>
</plist>
EOF

    success "System service plist created: $plist_source"
    log "Plist destination: $plist_dest (copy with: sudo cp $plist_name $plist_dest)"
}

# Function to create production user service plist
create_production_user_plist() {
    local plist_name="network.location.switcher.user.plist"
    local plist_source="$PROJECT_DIR/$plist_name"
    local plist_dest="$HOME/Library/LaunchAgents/$plist_name"
    local log_dir="$HOME/Library/Logs/NetworkLocationSwitcher"
    local exec_path="$INSTALL_BIN_DIR/$SCRIPT_NAME"
    
    log "Creating user service plist: $plist_source"
    
    # Ensure user log directory exists
    mkdir -p "$log_dir"
    
    cat > "$plist_source" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.network_loc_switcher</string>
    
    <key>Program</key>
    <string>$exec_path</string>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
        <key>Crashed</key>
        <true/>
    </dict>
    
    <key>StandardOutPath</key>
    <string>$log_dir/network_loc_switcher-stdout.log</string>
    
    <key>StandardErrorPath</key>
    <string>$log_dir/network_loc_switcher-stderr.log</string>
    
    <key>WorkingDirectory</key>
    <string>$INSTALL_LIB_DIR</string>
    
    <!-- Use virtual environment's Python and PATH -->
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>$VENV_DIR/bin:/usr/local/bin:/usr/bin:/bin</string>
        <key>VIRTUAL_ENV</key>
        <string>$VENV_DIR</string>
        <key>PYTHONPATH</key>
        <string>$INSTALL_LIB_DIR</string>
    </dict>
    
    <!-- Resource limits -->
    <key>SoftResourceLimits</key>
    <dict>
        <key>NumberOfFiles</key>
        <integer>1024</integer>
    </dict>
    
    <!-- Throttle restart attempts -->
    <key>ThrottleInterval</key>
    <integer>10</integer>
</dict>
</plist>
EOF

    success "User service plist created: $plist_source"
    log "Plist destination: $plist_dest (copy with: cp $plist_name ~/Library/LaunchAgents/)"
}

# Function to create development plist
create_development_plist() {
    local plist_name="network.location.switcher.development.plist"
    local plist_source="$PROJECT_DIR/$plist_name"
    local plist_dest="$HOME/Library/LaunchAgents/$plist_name"
    local log_dir="$PROJECT_DIR/logs/NetworkLocationSwitcher"
    local exec_path="$VENV_DIR/bin/python"
    
    log "Creating development plist: $plist_source"
    
    # Create logs directory for development
    mkdir -p "$log_dir"
    
    cat > "$plist_source" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.network_loc_switcher.development</string>
    
    <key>Program</key>
    <string>$exec_path</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>$exec_path</string>
        <string>$PROJECT_DIR/network_loc_switcher/network_loc_switcher.py</string>
    </array>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
        <key>Crashed</key>
        <true/>
    </dict>
    
    <key>StandardOutPath</key>
    <string>$log_dir/network_loc_switcher-stdout.log</string>
    
    <key>StandardErrorPath</key>
    <string>$log_dir/network_loc_switcher-stderr.log</string>
    
    <key>WorkingDirectory</key>
    <string>$PROJECT_DIR</string>
    
    <!-- Use virtual environment's Python and PATH -->
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>$VENV_DIR/bin:/usr/local/bin:/usr/bin:/bin</string>
        <key>VIRTUAL_ENV</key>
        <string>$VENV_DIR</string>
        <key>PYTHONPATH</key>
        <string>$PROJECT_DIR:$PROJECT_DIR/network_loc_switcher</string>
    </dict>
    
    <!-- Resource limits -->
    <key>SoftResourceLimits</key>
    <dict>
        <key>NumberOfFiles</key>
        <integer>1024</integer>
    </dict>
    
    <!-- Throttle restart attempts -->
    <key>ThrottleInterval</key>
    <integer>10</integer>
</dict>
</plist>
EOF

    success "Development plist created: $plist_source"
    log "Plist destination: $plist_dest (copy with: cp $plist_name ~/Library/LaunchAgents/)"
}

# Function to create logs directory
create_logs_dir() {
    if [[ "$INSTALL_MODE" == "development" ]]; then
        log "Creating development logs directory..."
        if [[ "$DRY_RUN" == true ]]; then
            if [[ -d "$PROJECT_DIR/logs" ]]; then
                log "Found existing directory: $PROJECT_DIR/logs"
            else
                dry_run_log "Would create directory: $PROJECT_DIR/logs"
            fi
            if [[ ! -f "$PROJECT_DIR/logs/.gitkeep" ]]; then
                dry_run_log "Would create file: $PROJECT_DIR/logs/.gitkeep"
            fi
        else
            mkdir -p "$PROJECT_DIR/logs"
            touch "$PROJECT_DIR/logs/.gitkeep"
            success "Development logs directory created"
        fi
    elif [[ "$INSTALL_MODE" == "system" ]]; then
        log "Creating system logs directories..."
        
        # Create user logs directory (always safe to create)
        if [[ "$DRY_RUN" == true ]]; then
            if [[ -d "$HOME/Library/Logs" ]]; then
                log "Found existing directory: $HOME/Library/Logs"
            else
                dry_run_log "Would create directory: $HOME/Library/Logs"
            fi
            dry_run_log "Would create directory: $HOME/Library/Logs/NetworkLocationSwitcher"
        else
            mkdir -p "$HOME/Library/Logs"
            mkdir -p "$HOME/Library/Logs/NetworkLocationSwitcher"
            success "User logs directory created: $HOME/Library/Logs/NetworkLocationSwitcher"
        fi
        
        # Create system logs directory (/usr/local/log/NetworkLocationSwitcher) for system service
        local system_log_base="/usr/local/log"
        local system_log_dir="$system_log_base/NetworkLocationSwitcher"
        
        # Determine the group to use (will find existing directories or prompt if needed)
        determine_directory_group "/usr/local"
        local dir_group="$DIRECTORY_GROUP_RESULT"
        
        # Ensure base log directory exists first
        if [[ "$DRY_RUN" == true ]]; then
            if [[ -d "$system_log_base" ]]; then
                log "Found existing directory: $system_log_base"
            else
                dry_run_log "Would create directory: $system_log_base (requires sudo)"
            fi
            if [[ -d "$system_log_dir" ]]; then
                log "Found existing directory: $system_log_dir"
            else
                log "Creating system logs directory: $system_log_dir (requires root privileges)"
                dry_run_log "Would create directory: $system_log_dir (requires sudo)"
                dry_run_log "Would set ownership and permissions for $system_log_dir"
            fi
        else
            # Ensure base directory exists
            if [[ ! -d "$system_log_base" ]]; then
                if ! sudo -n true 2>/dev/null; then
                    log "You may be prompted for your password to create $system_log_base..."
                fi
                sudo mkdir -p "$system_log_base"
            fi
            
            if [[ ! -d "$system_log_dir" ]]; then
                log "Creating system logs directory: $system_log_dir (requires root privileges)"
                if ! sudo -n true 2>/dev/null; then
                    log "You may be prompted for your password to create $system_log_dir..."
                fi
                sudo mkdir -p "$system_log_dir"
                
                # Set ownership and permissions using the determined group
                set_directory_permissions "$system_log_dir" "$dir_group" "log directory"
                
                success "System logs directory created: $system_log_dir"
            else
                log "System logs directory already exists: $system_log_dir"
                
                # Check and display current ownership/permissions
                local current_owner=$(stat -f "%Su:%Sg" "$system_log_dir" 2>/dev/null || echo "unknown")
                local current_group=$(stat -f "%Sg" "$system_log_dir" 2>/dev/null || echo "unknown")
                local current_perms=$(stat -f "%OLp" "$system_log_dir" 2>/dev/null || echo "unknown")
                # Check for setgid bit: if octal perms start with 2, 3, 6, or 7, setgid is set
                local octal_perms=$(stat -f "%OLp" "$system_log_dir" 2>/dev/null || echo "0")
                local has_setgid="no"
                if [[ "$octal_perms" =~ ^[2367] ]]; then
                    has_setgid="yes"
                fi
                
                log "Current ownership: $current_owner, permissions: $current_perms, setgid: $has_setgid"
                
                # Check if group matches the determined group
                if [[ "$current_group" != "$dir_group" ]]; then
                    warning "System logs directory group '$current_group' does not match expected group '$dir_group'"
                    log "Consider updating the group to maintain consistency:"
                    log "  sudo chgrp $dir_group $system_log_dir"
                fi
                
                # Preserve existing ownership/permissions - don't overwrite them
                # Only check if it's writable by the current user (for testing)
                if [[ ! -w "$system_log_dir" ]]; then
                    warning "System logs directory exists but may not be writable by current user"
                    log "Note: Directory ownership and permissions are preserved as-is"
                    log "The system service (running as root) should be able to write to this directory"
                else
                    log "Directory is writable and permissions are preserved"
                fi
            fi
        fi
        
        echo "System service plist will be created:"
        echo "  - network.location.switcher.system.plist (for /Library/LaunchDaemons - logs to /usr/local/log/NetworkLocationSwitcher)"
        success "System logs configured"
    else
        # User mode
        log "Creating user logs directories..."
        
        # Create user logs directory (always safe to create)
        if [[ "$DRY_RUN" == true ]]; then
            if [[ -d "$HOME/Library/Logs" ]]; then
                log "Found existing directory: $HOME/Library/Logs"
            else
                dry_run_log "Would create directory: $HOME/Library/Logs"
            fi
            dry_run_log "Would create directory: $HOME/Library/Logs/NetworkLocationSwitcher"
        else
            mkdir -p "$HOME/Library/Logs"
            mkdir -p "$HOME/Library/Logs/NetworkLocationSwitcher"
            success "User logs directory created: $HOME/Library/Logs/NetworkLocationSwitcher"
        fi
        
        echo "User service plist will be created:"
        echo "  - network.location.switcher.user.plist (for ~/Library/LaunchAgents - logs to ~/Library/Logs/NetworkLocationSwitcher)"
        success "User logs configured"
    fi
}

# Function to show summary
show_summary() {
    # In dry-run mode, don't show success summary - show instructions instead
    if [[ "$DRY_RUN" == true ]]; then
        echo ""
        echo "🔍 Dry run complete - no changes were made"
        echo ""
        
        # Display permission errors if any were found
        if [[ ${#PERMISSION_ERRORS[@]} -gt 0 ]]; then
            echo ""
            error "⚠️  Permission errors detected:"
            echo ""
            for error_msg in "${PERMISSION_ERRORS[@]}"; do
                echo "$error_msg"
            done
            echo ""
            echo "Please fix these errors before running the installation."
            echo ""
        fi
        
        echo "To install with mode '$INSTALL_MODE', run (without "--dry-run"):"
        echo "   ./install.sh --mode $INSTALL_MODE"
        echo ""
        return 0
    fi
    
    echo ""
    echo "🎉 Virtual Environment Setup Complete!"
    echo ""
    echo "📁 Installation Mode: $INSTALL_MODE"
    echo "📁 Virtual Environment: $VENV_DIR"
    echo "🐍 Python: $($VENV_DIR/bin/python --version)"
    echo "📦 Pip: $($VENV_DIR/bin/pip --version)"
    
    if [[ "$INSTALL_MODE" == "system" ]]; then
        echo "🚀 System Installation:"
        echo "   Binary: $INSTALL_BIN_DIR/$SCRIPT_NAME"
        echo "   Library: $INSTALL_LIB_DIR"
        echo "   Config: $INSTALL_PREFIX/etc/network-location-config.json"
        echo "   Log path automatically configured for system service"
        echo "   Plist created: $PROJECT_DIR/network.location.switcher.system.plist"
        echo "   Plist destination: /Library/LaunchDaemons/network.location.switcher.system.plist"
        echo "   System plist logs: /usr/local/log/NetworkLocationSwitcher/network_loc_switcher-*.log"
    elif [[ "$INSTALL_MODE" == "user" ]]; then
        echo "🚀 User Installation:"
        echo "   Binary: $INSTALL_BIN_DIR/$SCRIPT_NAME"
        echo "   Library: $INSTALL_LIB_DIR"
        echo "   Config: $INSTALL_PREFIX/etc/$USER/network-location-config.json"
        echo "   Plist created: $PROJECT_DIR/network.location.switcher.user.plist"
        echo "   Plist destination: $HOME/Library/LaunchAgents/network.location.switcher.user.plist"
        echo "   User plist logs: $HOME/Library/Logs/NetworkLocationSwitcher/network_loc_switcher-*.log"
    else
        echo ""
        echo "🚀 Next Steps:"
        echo ""
        echo "1. Activate the environment:"
        echo "   source ./activate.sh"
        echo ""
        echo "2. Test the installation:"
        echo "   python network_loc_switcher.py"
        echo ""
        echo "3. Install as user service:"
        echo "   Plist created: $PROJECT_DIR/network.location.switcher.development.plist"
        echo "   Plist destination: $HOME/Library/LaunchAgents/network.location.switcher.development.plist"
        echo "   cp network.location.switcher.development.plist ~/Library/LaunchAgents/"
        echo "   launchctl bootstrap gui/\$(id -u) ~/Library/LaunchAgents/network.location.switcher.development.plist"
        echo "   Config: Log path automatically set to $PROJECT_DIR/logs/"
        echo ""
        echo "4. Development workflow:"
        echo "   source ./activate.sh    # Activate environment"
        echo "   black .                 # Format code"
        echo "   ruff check .           # Lint code"
        echo "   pytest                 # Run tests"
        echo "   deactivate             # Exit environment"
    fi
    echo ""
}

# Function to install and launch the service
install_and_launch_service() {
    # Skip in dry-run mode
    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi
    
    local plist_name
    local plist_source
    local plist_dest
    local launch_cmd
    local stop_cmd
    local remove_cmd
    local service_id
    local service_installed=false
    
    if [[ "$INSTALL_MODE" == "system" ]]; then
        plist_name="network.location.switcher.system.plist"
        plist_source="$PROJECT_DIR/$plist_name"
        plist_dest="/Library/LaunchDaemons/$plist_name"
        service_id="system/com.system.network_loc_switcher"
        launch_cmd="sudo launchctl bootstrap system $plist_dest"
        stop_cmd="sudo launchctl bootout $service_id"
        remove_cmd="sudo rm $plist_dest"
    else
        # User mode
        plist_name="network.location.switcher.user.plist"
        plist_source="$PROJECT_DIR/$plist_name"
        plist_dest="$HOME/Library/LaunchAgents/$plist_name"
        service_id="gui/$(id -u)/com.user.network_loc_switcher"
        launch_cmd="launchctl bootstrap gui/$(id -u) $plist_dest"
        stop_cmd="launchctl bootout $service_id"
        remove_cmd="rm $plist_dest"
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📦 Service Installation"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Would you like to install and launch the service now?"
    echo ""
    # Determine config file location
    local config_file
    if [[ "$INSTALL_MODE" == "system" ]]; then
        config_file="$INSTALL_PREFIX/etc/network-location-config.json"
    else
        config_file="$INSTALL_PREFIX/etc/$USER/network-location-config.json"
    fi
    echo "HINT: You may want to edit the network configuration file, $config_file, before launching the service."
    echo ""
    echo "This will:"
    echo "  1. Copy $plist_name to $plist_dest"
    echo "  2. Launch the service using launchctl"
    echo ""
    read -p "Install and launch service? (Yes/No): " install_choice
    
    if [[ "$install_choice" == "Yes" || "$install_choice" == "yes" || "$install_choice" == "Y" || "$install_choice" == "y" ]]; then
        echo ""
        log "Installing service..."
        
        # Copy plist file
        if [[ "$INSTALL_MODE" == "system" ]]; then
            if sudo cp "$plist_source" "$plist_dest"; then
                success "Copied $plist_name to $plist_dest"
            else
                error "Failed to copy plist file"
                return 1
            fi
        else
            if cp "$plist_source" "$plist_dest"; then
                success "Copied $plist_name to $plist_dest"
            else
                error "Failed to copy plist file"
                return 1
            fi
        fi
        
        # Launch service
        log "Launching service..."
        if [[ "$INSTALL_MODE" == "system" ]]; then
            if sudo launchctl bootstrap system "$plist_dest" 2>/dev/null; then
                success "Service launched successfully"
            else
                # Check if service is already loaded
                if sudo launchctl list | grep -q "com.system.network_loc_switcher"; then
                    warning "Service appears to already be running"
                    log "To restart, first stop it with: $stop_cmd"
                else
                    error "Failed to launch service"
                    return 1
                fi
            fi
        else
            if launchctl bootstrap "gui/$(id -u)" "$plist_dest" 2>/dev/null; then
                success "Service launched successfully"
            else
                # Check if service is already loaded
                if launchctl list | grep -q "com.user.network_loc_switcher"; then
                    warning "Service appears to already be running"
                    log "To restart, first stop it with: $stop_cmd"
                else
                    error "Failed to launch service"
                    return 1
                fi
            fi
        fi
        
        echo ""
        success "✅ Service installation complete!"
        service_installed=true
    else
        echo ""
        echo "📋 Manual Installation Steps:"
        echo ""
        echo "1. Copy the plist file:"
        if [[ "$INSTALL_MODE" == "system" ]]; then
            echo "   sudo cp $plist_source $plist_dest"
        else
            echo "   cp $plist_source $plist_dest"
        fi
        echo ""
        echo "2. Launch the service:"
        echo "   $launch_cmd"
        echo ""
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔧 Service Management"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "To start the service:"
    echo "   $launch_cmd"
    echo ""
    echo "To check service status:"
    if [[ "$INSTALL_MODE" == "system" ]]; then
        echo "   sudo launchctl list | grep network_loc_switcher"
    else
        echo "   launchctl list | grep network_loc_switcher"
    fi
    echo ""
    echo "To stop the service:"
    echo "   $stop_cmd"
    echo ""
    echo "To remove the service:"
    echo "   $stop_cmd  # Stop first"
    echo "   $remove_cmd"
    echo ""
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🚀 Next Steps"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "1. Test the installation:"
    echo "   $INSTALL_BIN_DIR/$SCRIPT_NAME --help"
    echo ""
    
    # Only show step 2 if service was not installed
    if [[ "$service_installed" == false ]]; then
        echo "2. Install as $INSTALL_MODE service:"
        if [[ "$INSTALL_MODE" == "system" ]]; then
            echo "   sudo cp $plist_name $plist_dest"
            echo "   sudo launchctl bootstrap system $plist_dest"
        else
            echo "   cp $plist_name $plist_dest"
            echo "   launchctl bootstrap gui/\$(id -u) $plist_dest"
        fi
        echo ""
        echo "3. Management:"
    else
        echo "2. Management:"
    fi
    
    if [[ "$INSTALL_MODE" == "system" ]]; then
        echo "   sudo launchctl list | grep network_loc_switcher  # Check status"
        echo "   sudo tail -f /usr/local/log/NetworkLocationSwitcher/network_loc_switcher*.log  # View logs"
    else
        echo "   launchctl list | grep network_loc_switcher       # Check status"
        echo "   tail -f ~/Library/Logs/NetworkLocationSwitcher/network_loc_switcher*.log  # View logs"
    fi
    echo ""
}

# Main execution
main() {
    # Parse command line arguments
    local mode_provided=false
    
    # Check if --mode was provided
    for arg in "$@"; do
        if [[ "$arg" == "--mode" ]]; then
            mode_provided=true
            break
        fi
    done
    
    parse_args "$@"
    
    # If mode wasn't provided and we're not in dry-run, prompt for mode
    if [[ "$mode_provided" == false && "$DRY_RUN" == false ]]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🐍 Network Location Switcher Installer"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Which installation mode would you like to use?"
        echo ""
        echo "  1) development  - Install in project directory (for development/testing)"
        echo "  2) user          - Install as user service (/usr/local, runs at login)"
        echo "  3) system        - Install as system service (/usr/local, runs at boot, requires sudo)"
        echo ""
        read -p "Enter mode (1/2/3 or development/user/system) [default: $DEFAULT_INSTALL_MODE]: " install_choice
        
        # Use default if empty, otherwise process input
        if [ -z "$install_choice" ]; then
            INSTALL_MODE="$DEFAULT_INSTALL_MODE"
            log "Using default mode: $DEFAULT_INSTALL_MODE"
        else
            # Map numeric input to mode names
            case "$install_choice" in
                1)
                    INSTALL_MODE="development"
                    ;;
                2)
                    INSTALL_MODE="user"
                    ;;
                3)
                    INSTALL_MODE="system"
                    ;;
                development|user|system)
                    INSTALL_MODE="$install_choice"
                    ;;
                *)
                    error "Invalid mode: $install_choice. Use '1', '2', '3', 'development', 'user', or 'system'"
                    exit 1
                    ;;
            esac
        fi
    fi
    
    echo ""
    echo "🐍 Python Virtual Environment Setup"
    echo "===================================="
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}🔍 DRY RUN MODE - No changes will be made${NC}"
        echo ""
    fi
    echo "📋 Mode: $INSTALL_MODE"
    if [[ "$INSTALL_MODE" == "user" || "$INSTALL_MODE" == "system" ]]; then
        echo "📋 Prefix: $INSTALL_PREFIX"
    fi
    echo ""
    
    # Setup installation paths
    setup_paths
    
    # Execute setup steps
    detect_python
    create_logs_dir
    create_venv
    if [[ "$DRY_RUN" == false ]]; then
        setup_venv
        install_dependencies
    else
        log "Skipping venv activation and dependency installation in dry-run mode"
    fi
    install_script_files
    
    # Only setup development tools in development mode
    if [[ "$INSTALL_MODE" == "development" ]]; then
        setup_precommit
        create_activation_script
    fi
    
    create_launchd_plist
    show_summary
    
    # For system and user modes, offer to install and launch the service
    if [[ "$INSTALL_MODE" == "system" || "$INSTALL_MODE" == "user" ]]; then
        install_and_launch_service
    fi
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
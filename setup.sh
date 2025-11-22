#!/bin/bash
set -e

# Virtual Environment Setup Script for Network Location Switcher
# Supports both development and production installation modes

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_VERSION="python3"

# Installation mode and paths
INSTALL_MODE="development"  # Default to development mode
INSTALL_PREFIX="/usr/local"
INSTALL_BIN_DIR=""
INSTALL_LIB_DIR=""
VENV_DIR=""
SCRIPT_NAME="network-location-switcher"

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

# Function to show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --mode MODE           Installation mode: 'development' or 'production' (default: development)"
    echo "  --prefix PATH         Installation prefix for production mode (default: /usr/local)"
    echo "  --bin-dir PATH        Binary directory (default: PREFIX/bin)"
    echo "  --lib-dir PATH        Library directory (default: PREFIX/lib/network-location-switcher)"
    echo "  --help, -h            Show this help message"
    echo ""
    echo "Installation Modes:"
    echo "  development           Install in current directory with .venv (for development)"
    echo "  production            Install to system directories (for deployment)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Development setup"
    echo "  $0 --mode production                 # Production setup to /usr/local"
    echo "  $0 --mode production --prefix /opt   # Production setup to /opt"
    echo ""
    exit 0
}

# Function to parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --mode)
                INSTALL_MODE="$2"
                if [[ "$INSTALL_MODE" != "development" && "$INSTALL_MODE" != "production" ]]; then
                    error "Invalid mode: $INSTALL_MODE. Use 'development' or 'production'"
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
    if [[ "$INSTALL_MODE" == "production" ]]; then
        # Production mode - install to system directories
        INSTALL_BIN_DIR="${INSTALL_BIN_DIR:-$INSTALL_PREFIX/bin}"
        INSTALL_LIB_DIR="${INSTALL_LIB_DIR:-$INSTALL_PREFIX/lib/$SCRIPT_NAME}"
        VENV_DIR="$INSTALL_LIB_DIR/.venv"
        
        log "Production installation paths:"
        log "  Prefix: $INSTALL_PREFIX"
        log "  Binary: $INSTALL_BIN_DIR/$SCRIPT_NAME"
        log "  Library: $INSTALL_LIB_DIR"
        log "  Virtual env: $VENV_DIR"
        
        # Check if we need sudo for installation
        if [[ ! -w "$INSTALL_PREFIX" ]]; then
            warning "Installation requires sudo privileges for $INSTALL_PREFIX"
            if ! sudo -n true 2>/dev/null; then
                log "You may be prompted for your password..."
            fi
        fi
    else
        # Development mode - use project directory
        VENV_DIR="$PROJECT_DIR/.venv"
        INSTALL_BIN_DIR="$PROJECT_DIR"
        INSTALL_LIB_DIR="$PROJECT_DIR"
        
        log "Development installation paths:"
        log "  Project: $PROJECT_DIR"
        log "  Virtual env: $VENV_DIR"
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

# Function to create directories and virtual environment
create_venv() {
    log "Creating virtual environment at $VENV_DIR"
    
    # Create directories for production mode
    if [[ "$INSTALL_MODE" == "production" ]]; then
        log "Creating production directories..."
        
        # Use sudo if needed for directory creation
        if [[ ! -w "$INSTALL_PREFIX" ]]; then
            sudo mkdir -p "$INSTALL_BIN_DIR" "$INSTALL_LIB_DIR"
            sudo chown "$USER:$(id -gn)" "$INSTALL_LIB_DIR"
        else
            mkdir -p "$INSTALL_BIN_DIR" "$INSTALL_LIB_DIR"
        fi
    fi
    
    # Remove existing venv if it exists
    if [ -d "$VENV_DIR" ]; then
        warning "Removing existing virtual environment..."
        if [[ "$INSTALL_MODE" == "production" && ! -w "$(dirname "$VENV_DIR")" ]]; then
            sudo rm -rf "$VENV_DIR"
        else
            rm -rf "$VENV_DIR"
        fi
    fi
    
    # Create new venv
    "$PYTHON_VERSION" -m venv "$VENV_DIR"
    success "Virtual environment created"
}

# Function to activate and upgrade pip
setup_venv() {
    log "Setting up virtual environment..."
    
    # Activate venv
    source "$VENV_DIR/bin/activate"
    
    # Upgrade pip
    log "Upgrading pip..."
    pip install --upgrade pip setuptools wheel
    
    success "Virtual environment setup complete"
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
}

# Function to update config file with appropriate log path
update_config_log_path() {
    local config_file="$1"
    local log_path
    
    if [[ "$INSTALL_MODE" == "development" ]]; then
        log_path="$PROJECT_DIR/logs/network-location-switcher.log"
        log "Setting development log path: $log_path"
    else
        # Production mode - ask user preference
        echo ""
        echo "📝 Configure log file location for production:"
        echo "1) System logs (/var/log/) - accessible to system service"
        echo "2) User logs (~/Library/Logs/) - accessible to user service"
        echo ""
        
        while true; do
            read -p "Choose log location [1-2]: " choice
            case $choice in
                1) 
                    log_path="/var/log/network-location-switcher.log"
                    log "Setting system log path: $log_path"
                    break
                    ;;
                2) 
                    log_path="$HOME/Library/Logs/network-location-switcher.log"
                    log "Setting user log path: $log_path"
                    break
                    ;;
                *) 
                    echo "Please choose 1 or 2"
                    ;;
            esac
        done
    fi
    
    # Update the config file log_file path
    if [ -f "$config_file" ]; then
        # Use sed to replace the log_file line, handling both cases with and without trailing comma
        sed -i '' "s|\"log_file\": \"[^\"]*\"|\"log_file\": \"$log_path\"|g" "$config_file"
        success "Updated log_file path to: $log_path"
    else
        warning "Config file not found: $config_file"
    fi
}

# Function to install script files
install_script_files() {
    log "Installing script files..."
    
    if [[ "$INSTALL_MODE" == "production" ]]; then
        # Copy source files to library directory
        log "Copying source files to $INSTALL_LIB_DIR"
        
        # Create wrapper script for production
        local wrapper_script="$INSTALL_BIN_DIR/$SCRIPT_NAME"
        
        # Use sudo if needed
        if [[ ! -w "$INSTALL_BIN_DIR" ]]; then
            # Copy Python script and config files to lib directory
            sudo cp "$PROJECT_DIR/network-location-switcher.py" "$INSTALL_LIB_DIR/"
            sudo cp "$PROJECT_DIR/requirements-macos.txt" "$INSTALL_LIB_DIR/"
            
            # Copy default template (always)
            sudo cp "$PROJECT_DIR/network-location-config.default.json" "$INSTALL_LIB_DIR/"
            
            # Copy user config if it exists, otherwise create from template
            if [ -f "$PROJECT_DIR/network-location-config.json" ]; then
                sudo cp "$PROJECT_DIR/network-location-config.json" "$INSTALL_LIB_DIR/"
                log "Copied existing user configuration"
                # Update log path in copied config
                update_config_log_path "$INSTALL_LIB_DIR/network-location-config.json"
            else
                log "Creating user configuration from template"
                sudo cp "$PROJECT_DIR/network-location-config.default.json" "$INSTALL_LIB_DIR/network-location-config.json"
                # Update log path in new config
                update_config_log_path "$INSTALL_LIB_DIR/network-location-config.json"
            fi
            
            # Create wrapper script in bin directory
            sudo tee "$wrapper_script" > /dev/null << EOF
#!/bin/bash
# Production wrapper for network-location-switcher
SCRIPT_DIR="$INSTALL_LIB_DIR"
VENV_DIR="$VENV_DIR"

# Activate virtual environment and run script
source "\$VENV_DIR/bin/activate"
exec "\$VENV_DIR/bin/python" "\$SCRIPT_DIR/network-location-switcher.py" "\$@"
EOF
            
            sudo chmod +x "$wrapper_script"
            sudo chown "$USER:$(id -gn)" "$wrapper_script"
        else
            # Copy without sudo
            cp "$PROJECT_DIR/network-location-switcher.py" "$INSTALL_LIB_DIR/"
            cp "$PROJECT_DIR/requirements-macos.txt" "$INSTALL_LIB_DIR/"
            
            # Copy default template (always)
            cp "$PROJECT_DIR/network-location-config.default.json" "$INSTALL_LIB_DIR/"
            
            # Copy user config if it exists, otherwise create from template
            if [ -f "$PROJECT_DIR/network-location-config.json" ]; then
                cp "$PROJECT_DIR/network-location-config.json" "$INSTALL_LIB_DIR/"
                log "Copied existing user configuration"
                # Update log path in copied config
                update_config_log_path "$INSTALL_LIB_DIR/network-location-config.json"
            else
                log "Creating user configuration from template"
                cp "$PROJECT_DIR/network-location-config.default.json" "$INSTALL_LIB_DIR/network-location-config.json"
                # Update log path in new config
                update_config_log_path "$INSTALL_LIB_DIR/network-location-config.json"
            fi
            
            # Create wrapper script
            cat > "$wrapper_script" << EOF
#!/bin/bash
# Production wrapper for network-location-switcher
SCRIPT_DIR="$INSTALL_LIB_DIR"
VENV_DIR="$VENV_DIR"

# Activate virtual environment and run script
source "\$VENV_DIR/bin/activate"
exec "\$VENV_DIR/bin/python" "\$SCRIPT_DIR/network-location-switcher.py" "\$@"
EOF
            
            chmod +x "$wrapper_script"
        fi
        
        success "Script installed to $wrapper_script"
    else
        # Development mode - files stay in project directory
        log "Development mode - updating configuration for local logs"
        
        # Create or update config file for development
        if [ -f "$PROJECT_DIR/network-location-config.json" ]; then
            log "Updating existing user configuration for development"
            update_config_log_path "$PROJECT_DIR/network-location-config.json"
        else
            log "Creating user configuration from template for development"
            cp "$PROJECT_DIR/network-location-config.default.json" "$PROJECT_DIR/network-location-config.json"
            update_config_log_path "$PROJECT_DIR/network-location-config.json"
        fi
        
        success "Development mode - files remain in $PROJECT_DIR"
    fi
}

# Function to setup pre-commit hooks (development mode only)
setup_precommit() {
    log "Setting up development pre-commit hooks..."
    
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
}

# Function to create activation script (development mode only)
create_activation_script() {
    log "Creating development activation script..."
    
    cat > activate.sh << EOF
#!/bin/bash
# Activation script for network-location-switcher virtual environment

PROJECT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="\$PROJECT_DIR/.venv"

if [ ! -d "\$VENV_DIR" ]; then
    echo "❌ Virtual environment not found. Run ./setup.sh first"
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
echo "  python network-location-switcher.py    # Run the network switcher"
echo "  pytest                                 # Run tests" 
echo "  black .                                # Format code"
echo "  ruff check .                          # Lint code"
echo "  deactivate                            # Exit virtual environment"
EOF

    chmod +x activate.sh
    success "Activation script created: ./activate.sh"
}

# Function to create launchd plist for venv
create_launchd_plist() {
    log "Creating launchd plist files for virtual environment..."
    
    if [[ "$INSTALL_MODE" == "production" ]]; then
        # Create both system and user service plists for production
        create_production_system_plist
        create_production_user_plist
    else
        # Create development plist
        create_development_plist
    fi
}

# Function to create production system service plist
create_production_system_plist() {
    local plist_name="network-location-switcher-system.plist"
    local log_dir="/var/log"
    local exec_path="$INSTALL_BIN_DIR/$SCRIPT_NAME"
    
    log "Creating system service plist: $plist_name"
    
    cat > "$plist_name" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.system.network-location-switcher</string>
    
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
    <string>$log_dir/network-location-switcher-stdout.log</string>
    
    <key>StandardErrorPath</key>
    <string>$log_dir/network-location-switcher-stderr.log</string>
    
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

    success "System service plist created: $plist_name"
}

# Function to create production user service plist
create_production_user_plist() {
    local plist_name="network-location-switcher-user.plist"
    local log_dir="$HOME/Library/Logs"
    local exec_path="$INSTALL_BIN_DIR/$SCRIPT_NAME"
    
    log "Creating user service plist: $plist_name"
    
    # Ensure user log directory exists
    mkdir -p "$log_dir"
    
    cat > "$plist_name" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.network-location-switcher</string>
    
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
    <string>$log_dir/network-location-switcher-stdout.log</string>
    
    <key>StandardErrorPath</key>
    <string>$log_dir/network-location-switcher-stderr.log</string>
    
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

    success "User service plist created: $plist_name"
}

# Function to create development plist
create_development_plist() {
    local plist_name="network-location-switcher-development.plist"
    local log_dir="$PROJECT_DIR/logs"
    local exec_path="$VENV_DIR/bin/python"
    
    log "Creating development plist: $plist_name"
    
    # Create logs directory for development
    mkdir -p "$log_dir"
    
    cat > "$plist_name" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.network-location-switcher.development</string>
    
    <key>Program</key>
    <string>$exec_path</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>$exec_path</string>
        <string>$INSTALL_LIB_DIR/network-location-switcher.py</string>
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
    <string>$log_dir/network-location-switcher-stdout.log</string>
    
    <key>StandardErrorPath</key>
    <string>$log_dir/network-location-switcher-stderr.log</string>
    
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
        <string>$PROJECT_DIR</string>
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

    success "Development plist created: $plist_name"
}

# Function to create logs directory
create_logs_dir() {
    if [[ "$INSTALL_MODE" == "development" ]]; then
        log "Creating development logs directory..."
        mkdir -p "$PROJECT_DIR/logs"
        touch "$PROJECT_DIR/logs/.gitkeep"
        success "Development logs directory created"
    else
        log "Creating production logs directories..."
        
        # Create user logs directory (always safe to create)
        mkdir -p "$HOME/Library/Logs"
        success "User logs directory created: $HOME/Library/Logs"
        
        # Note about system logs
        log "System logs will be written to /var/log/ (requires root privileges)"
        warning "Note: /var/log directory requires root privileges for writing."
        echo "Two plist files will be created:"
        echo "  - network-location-switcher-system.plist (for /Library/LaunchDaemons - logs to /var/log)"
        echo "  - network-location-switcher-user.plist (for ~/Library/LaunchAgents - logs to ~/Library/Logs)"
        success "Production logs configured"
    fi
}

# Function to show summary
show_summary() {
    echo ""
    echo "🎉 Virtual Environment Setup Complete!"
    echo ""
    echo "📁 Installation Mode: $INSTALL_MODE"
    echo "📁 Virtual Environment: $VENV_DIR"
    echo "🐍 Python: $($VENV_DIR/bin/python --version)"
    echo "📦 Pip: $($VENV_DIR/bin/pip --version)"
    
    if [[ "$INSTALL_MODE" == "production" ]]; then
        echo "🚀 Production Installation:"
        echo "   Binary: $INSTALL_BIN_DIR/$SCRIPT_NAME"
        echo "   Library: $INSTALL_LIB_DIR"
        echo "   Config: Log path automatically configured based on your choice"
        echo "   System plist logs: /var/log/network-location-switcher-*.log"
        echo "   User plist logs: $HOME/Library/Logs/network-location-switcher-*.log"
        echo ""
        echo "🚀 Next Steps:"
        echo ""
        echo "1. Test the installation:"
        echo "   $INSTALL_BIN_DIR/$SCRIPT_NAME --help"
        echo ""
        echo "2. Install as system service (runs as root, logs to /var/log):"
        echo "   sudo cp network-location-switcher-system.plist /Library/LaunchDaemons/"
        echo "   sudo launchctl bootstrap system /Library/LaunchDaemons/network-location-switcher-system.plist"
        echo ""
        echo "3. Or install as user service (runs as user, logs to ~/Library/Logs):"
        echo "   cp network-location-switcher-user.plist ~/Library/LaunchAgents/"
        echo "   launchctl bootstrap gui/\$(id -u) ~/Library/LaunchAgents/network-location-switcher-user.plist"
        echo ""
        echo "4. Management:"
        echo "   System service:"
        echo "     sudo launchctl list | grep network-location-switcher  # Check status"
        echo "     sudo tail -f /var/log/network-location-switcher-*.log  # View logs"
        echo "   User service:"
        echo "     launchctl list | grep network-location-switcher       # Check status"
        echo "     tail -f ~/Library/Logs/network-location-switcher-*.log  # View logs"
    else
        echo ""
        echo "🚀 Next Steps:"
        echo ""
        echo "1. Activate the environment:"
        echo "   source ./activate.sh"
        echo ""
        echo "2. Test the installation:"
        echo "   python network-location-switcher.py"
        echo ""
        echo "3. Install as user service:"
        echo "   cp network-location-switcher-development.plist ~/Library/LaunchAgents/"
        echo "   launchctl bootstrap gui/\$(id -u) ~/Library/LaunchAgents/network-location-switcher-development.plist"
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

# Main execution
main() {
    # Parse command line arguments
    parse_args "$@"
    
    echo ""
    echo "🐍 Python Virtual Environment Setup"
    echo "===================================="
    echo "📋 Mode: $INSTALL_MODE"
    if [[ "$INSTALL_MODE" == "production" ]]; then
        echo "📋 Prefix: $INSTALL_PREFIX"
    fi
    echo ""
    
    # Setup installation paths
    setup_paths
    
    # Execute setup steps
    detect_python
    create_logs_dir
    create_venv
    setup_venv
    install_dependencies
    install_script_files
    
    # Only setup development tools in development mode
    if [[ "$INSTALL_MODE" == "development" ]]; then
        setup_precommit
        create_activation_script
    fi
    
    create_launchd_plist
    show_summary
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
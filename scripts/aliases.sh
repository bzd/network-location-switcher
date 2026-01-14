# Aliases for common commands
#
# $ source ./scripts/aliases.sh
#

# CONSTANTS

LAUNCHCTL_PROCESS_USER="com.agilesv.networklocationswitcher.user"
LAUNCHCTL_PROCESS_SYSTEM="com.agilesv.networklocationswitcher.system"
LAUNCHCTL_PROCESS_DEVELOPMENT="com.agilesv.networklocationswitcher.development"

PLIST_FILENAME_USER="${LAUNCHCTL_PROCESS_USER}.plist"

PLIST_PATH_USER="${HOME}/Library/LaunchAgents/$PLIST_FILENAME_USER"

PLIST_FILENAME_SYSTEM="com.agilesv.networklocationswitcher.system.plist"
PLIST_PATH_SYSTEM="/Library/LaunchDaemons/$PLIST_FILENAME_SYSTEM"

PLIST_FILENAME_DEVELOPMENT="com.agilesv.networklocationswitcher.development.plist"

## Directories
APP_DIR="${HOME}/Library/Application Support/NetworkLocationSwitcher"
alias cdapp='if [ -d ${APP_DIR} ]; then cd ${APP_DIR}; else echo "NOT FOUND: ${APP_DIR}"; fi'
alias cdla='cd ${HOME}/Library/LaunchAgents'

## Configuration File

CFG_DIR="${HOME}/Library/Application Support/NetworkLocationSwitcher"

alias cdconf='if [ -d ${CFG_DIR} ]; then cd ${CFG_DIR}; else echo "NOT FOUND: ${CFG_DIR}"; fi'

CFG_FILE="${CFG_DIR}/network-location-switcher.json"
alias nlsconfls='if [ -f "$CFG_FILE" ]; then ls -l "$CFG_FILE"; else echo "NOT FOUND! ($CFG_FILE)"; fi'
alias nlscatconf='if [ -f "$CFG_FILE" ]; then cat "$CFG_FILE"; else echo "NOT FOUND! ($CFG_FILE)"; fi'

# LaunchCtl

alias nlslist='if ! (launchctl list | grep networklocationswitcher); then echo "NOT INSTALLED! ($PLIST_FILENAME_USER)"; fi'
alias nlsstart='launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.agilesv.networklocationswitcher.user.plist'
alias nlsstop='launchctl bootout gui/$(id -u)/com.agilesv.networklocationswitcher.user && echo "please wait a few seconds..." && sleep 3'

# Uninstall

alias nlsremove='launchctl bootout gui/\$(id -u)/network_location_switcher && rm ~/Library/LaunchAgents/network_location_switcher.plist'

# Information
alias nlsprint='launchctl print gui/$(id -u)/$PLIST_FILENAME'
alias nlsprogram='nlsprint | grep program'
alias nlsdir='nlsprint | grep "working directory"'
alias nlslogs='nlsprint | grep -E "std.* *path"'
alias nlsstate='nlsprint | grep state'


# LaunchAgent log monitoring
LOG_DIR="${HOME}/Library/Logs/NetworkLocationSwitcher/"
alias nlslog='tail -f $LOG_DIR/network_location_switcher.log'
alias nlsout='tail -f ${HOME}/Library/Logs/NetworkLocationSwitcher/network_location_switcher-stdout.log'
alias nlserr='tail -f ${HOME}/Library/Logs/NetworkLocationSwitcher/network_location_switcher-stderr.log'

# Development Mode
DEV_DIR="/usr/local/src/$USER/network-location-switcher"

alias cddev='if [ -d $DEV_DIR ]; then cd $DEV_DIR; else echo "NOT FOUND: $DEV_DIR"; fi'
alias nlsdevlog='tail -f $DEV_DIR/logs/network_location_switcher.log'
alias nlsdevout='tail -f $DEV_DIR/logs/network_location_switcher-stdout.log'
alias nlsdeverr='tail -f $DEV_DIR/logs/network_location_switcher-stderr.log'

alias nlsdevcp='cp $DEV_DIR/network_location_switcher/network_location_switcher.py $APP_DIR'

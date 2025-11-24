#!/usr/bin/env python3
"""
Network Location Switcher for macOS

Automatically switches network locations based on connected Wi-Fi networks
or Ethernet.
Configuration is loaded from an external JSON file for maximum flexibility.

Usage:
    network-location-switcher [config_file]
    network-location-switcher --help
    network-location-switcher --version
"""

# import re
import json
import os
import signal
import subprocess
import sys
import time
from typing import Any, Optional, Union
import CoreFoundation
import SystemConfiguration

# Prevent ruff from reordering the the CoreFoundation and SystemConfiguration imports
# ruff: noqa: I001

# Version constant
VERSION = "Network Location Switcher v2.0"


def log(msg: str) -> None:
    """Log message with timestamp to configured log file."""
    try:
        with open(LOG_FILE, "a") as f:
            f.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} {msg}\n")
    except OSError as e:
        # Fallback to stderr if log file can't be written
        print(f"{time.strftime('%Y-%m-%d %H:%M:%S')} {msg}", file=sys.stderr)
        print(f"Warning: Could not write to log file {LOG_FILE}: {e}", file=sys.stderr)


# ──────────────────────────────────────────────
# CONFIGURATION SECTION
# ──────────────────────────────────────────────


def show_help() -> None:
    """Display help message."""
    print(__doc__)
    print("Configuration file locations (searched in order):")
    print("  1. Command line argument: network-location-switcher config.json")
    print("  2. Script directory: ./network-location-config.json")
    print("  3. User home: ~/.network-location-config.json")
    print("  4. System-wide: /usr/local/etc/network-location-config.json")
    print("  5. System: /etc/network-location-config.json")
    print()
    print("If no config file is found, a default one will be created.")
    print("Edit the config file to match your network setup.")


def show_version() -> None:
    """Display version information."""
    print(VERSION)
    print("macOS network location automation with external configuration")


def parse_args() -> Optional[str]:
    """Parse command line arguments."""
    if len(sys.argv) > 1:
        arg = sys.argv[1]
        if arg in ("--help", "-h", "help"):
            show_help()
            sys.exit(0)
        elif arg in ("--version", "-v", "version"):
            show_version()
            sys.exit(0)
        elif arg.startswith("-"):
            print(f"Unknown option: {arg}")
            print("Use --help for usage information.")
            sys.exit(1)
        else:
            # Assume it's a config file path
            return arg
    return None


def load_config() -> dict[str, Any]:
    """Load configuration from external JSON file."""
    # Parse command line arguments
    config_file_arg = parse_args()

    # Configuration file paths to try (in order of preference)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    username = os.environ.get("USER", os.environ.get("USERNAME", ""))
    config_paths = [
        # 1. Command line argument
        config_file_arg,
        # 2. Same directory as script
        os.path.join(script_dir, "network-location-config.json"),
        # 3. User's home directory
        os.path.expanduser("~/.network-location-config.json"),
        # 4. User-specific system configuration (for user mode installations)
        f"/usr/local/etc/{username}/network-location-config.json" if username else None,
        # 5. System-wide configuration
        "/usr/local/etc/network-location-config.json",
        "/etc/network-location-config.json",
    ]

    # Filter out None values and ensure type safety
    config_paths_filtered: list[str] = []
    for path in config_paths:
        if path is not None:
            config_paths_filtered.append(path)

    for config_path in config_paths_filtered:
        if os.path.isfile(config_path):
            try:
                with open(config_path) as f:
                    config: dict[str, Any] = json.load(f)
                    print(
                        f"{time.strftime('%Y-%m-%d %H:%M:%S')} "
                        f"Loaded configuration from: {config_path}"
                    )
                    return config
            except (OSError, json.JSONDecodeError) as e:
                print(f"Error reading config file {config_path}: {e}")
                continue

    # No config file found, create one from template
    return create_default_config(script_dir)


def create_default_config(script_dir: str) -> dict[str, Any]:
    """Create a new configuration file from the default template."""
    default_config_path = os.path.join(script_dir, "network-location-config.json")
    template_path = os.path.join(script_dir, "network-location-config.default.json")

    # Try to use the template file first
    if os.path.isfile(template_path):
        try:
            with open(template_path) as f:
                template_config = json.load(f)

            # Clean the template (remove comment fields starting with _)
            clean_config = {}
            for key, value in template_config.items():
                if not key.startswith("_"):
                    if isinstance(value, dict):
                        # Clean nested dictionaries too
                        clean_value = {
                            k: v for k, v in value.items() if not k.startswith("_")
                        }
                        clean_config[key] = clean_value
                    else:
                        clean_config[key] = value

            # Write the clean config
            with open(default_config_path, "w") as f:
                json.dump(clean_config, f, indent=2)

            log(f"Created configuration file from template: " f"{default_config_path}")
            log("Template file used: network-location-config.default.json")
            log("Please edit the new config file to match your network setup!")
            return clean_config

        except (OSError, json.JSONDecodeError) as e:
            log(f"Error using template file {template_path}: {e}")
            # Fall through to hardcoded defaults

    # Fallback: create minimal config without template
    fallback_config = {
        "ssid_location_map": {
            "YourWiFiNetwork": "Home",
            "OfficeWiFi": "Work",
            "MobileHotspot": "Mobile",
        },
        "default_wifi_location": "Automatic",
        "ethernet_location": "Wired",
        "log_file": "/usr/local/log/network-location-switcher.log",
    }

    try:
        with open(default_config_path, "w") as f:
            json.dump(fallback_config, f, indent=2)
        log(f"Created basic configuration file: {default_config_path}")
        log("Please edit this file to match your network setup!")
        return fallback_config
    except OSError as e:
        log(f"Error creating config file: {e}")
        # Return hardcoded defaults as last resort
        return {
            "ssid_location_map": {},
            "default_wifi_location": "Automatic",
            "ethernet_location": "Wired",
            "log_file": "/usr/local/log/network-location-switcher.log",
        }


def validate_config(config: dict[str, Any]) -> dict[str, Any]:
    """Validate configuration and fix common issues."""
    # Ensure required keys exist with defaults
    defaults = {
        "ssid_location_map": {},
        "default_wifi_location": "Automatic",
        "ethernet_location": "Wired",
        "log_file": "/usr/local/log/network-location-switcher.log",
    }

    for key, default_value in defaults.items():
        if key not in config:
            log(
                f"Warning: Missing config key '{key}', "
                f"using default: {default_value}"
            )
            config[key] = default_value

    # Validate ssid_location_map is a dictionary
    if not isinstance(config["ssid_location_map"], dict):
        log("Error: 'ssid_location_map' must be an object/dictionary")
        config["ssid_location_map"] = {}

    # Validate log file directory exists or can be created
    log_file = config["log_file"]
    log_dir = os.path.dirname(log_file)
    if log_dir and not os.path.exists(log_dir):
        try:
            os.makedirs(log_dir, mode=0o755, exist_ok=True)
            log(f"Created log directory: {log_dir}")
        except OSError as e:
            log(f"Warning: Cannot create log directory {log_dir}: {e}")
            # Fall back to script directory
            script_dir = os.path.dirname(os.path.abspath(__file__))
            config["log_file"] = os.path.join(
                script_dir, "network-location-switcher.log"
            )
            log(f"Using fallback log file: {config['log_file']}")

    return config


# Load and validate configuration
CONFIG = validate_config(load_config())
SSID_LOCATION_MAP = CONFIG["ssid_location_map"]
DEFAULT_WIFI_LOCATION = CONFIG["default_wifi_location"]
ETHERNET_LOCATION = CONFIG["ethernet_location"]
LOG_FILE = CONFIG["log_file"]


# Log startup information
def log_startup_info() -> None:
    """Log configuration information at startup."""
    log("=" * 50)
    log(VERSION + " Starting")
    log(f"Configuration loaded with {len(SSID_LOCATION_MAP)} SSID mappings:")
    for ssid, location in SSID_LOCATION_MAP.items():
        log(f"  '{ssid}' → '{location}'")
    log(f"Default Wi-Fi location: {DEFAULT_WIFI_LOCATION}")
    log(f"Ethernet location: {ETHERNET_LOCATION}")
    log(f"Log file: {LOG_FILE}")
    log("=" * 50)


# ──────────────────────────────────────────────


def run_command(cmd: Union[str, list[str]]) -> str:
    try:
        if isinstance(cmd, list):
            # For list commands, don't use shell=True
            return subprocess.check_output(cmd, text=True).strip()
        else:
            # For string commands, use shell=True
            return subprocess.check_output(cmd, shell=True, text=True).strip()
    except subprocess.CalledProcessError:
        return ""


def get_wifi_interface() -> Optional[str]:
    """
    Returns the Wi-Fi interface name (e.g., en0, en1)
    Uses networksetup to find the Wi-Fi hardware port device name.
    """
    # Get list of all hardware ports
    ports_output = run_command("/usr/sbin/networksetup -listallhardwareports")
    if not ports_output:
        log("Could not get hardware ports list.")
        return None

    # Parse hardware ports to find Wi-Fi device
    lines = ports_output.splitlines()
    wifi_device = None

    for i, line in enumerate(lines):
        if line.startswith("Hardware Port: Wi-Fi"):  # noqa: SIM102
            # Look for the Device line that follows
            if i + 1 < len(lines) and lines[i + 1].startswith("Device:"):
                wifi_device = lines[i + 1].replace("Device:", "").strip()
                break
    if wifi_device:
        return wifi_device
    else:
        log("Could not detect Wi-Fi interface.")
        return None


def get_current_ssid() -> Optional[str]:
    """
    Returns the currently connected Wi-Fi SSID.
    Uses preferred wireless networks list method, modern and reliable.
    """
    wifi_iface = get_wifi_interface()
    if not wifi_iface:
        return None

    # Get preferred networks list
    cmd = ["/usr/sbin/networksetup", "-listpreferredwirelessnetworks", wifi_iface]
    output = run_command(cmd)
    if not output:
        return None

    # Extract SSID from second line. By convention, the first line is a header
    # and the second line is the current SSID if connected.
    ssid = None
    lines = output.splitlines()
    if len(lines) >= 2:
        ssid = lines[1].strip().lstrip("\t")

    # cmd = (
    #     f'networksetup -listpreferredwirelessnetworks "{iface}" '
    #     '| awk \'NR==2 && sub("\\t","") { print; exit }\''
    # )
    # ssid = run_command(cmd)

    return ssid


def ethernet_active() -> bool:
    """
    Detects if any wired Ethernet interface is active by checking all
    hardware ports. Returns True if any non-WiFi interface is active.
    """
    wifi_iface = get_wifi_interface()

    # Get list of all hardware ports
    ports_output = run_command("/usr/sbin/networksetup -listallhardwareports")
    if not ports_output:
        return False

    # Parse hardware ports to find device names
    lines = ports_output.splitlines()
    ethernet_ports = []

    for _i, line in enumerate(lines):
        if line.startswith("Device:"):
            device = line.replace("Device:", "").strip()
            # Skip WiFi interface and loopback
            if device != wifi_iface and device != "lo0" and device.startswith("en"):
                ethernet_ports.append(device)

    # Check if any ethernet port is active
    for port in ethernet_ports:
        if_output = run_command(f"/sbin/ifconfig {port}")
        if "status: active" in if_output and "inet " in if_output:
            log(f"Found active Ethernet interface: {port}")
            return True

    return False


def wifi_active() -> bool:
    """
    Detects if Wi-Fi is active and connected.
    """
    iface = get_wifi_interface()
    if not iface:
        return False

    output = run_command(f"/sbin/ifconfig {iface} | grep 'status: active'")

    return "status: active" in output


def get_current_location() -> Optional[str]:
    """Return the active network location (the one marked with '*')."""
    try:
        output = subprocess.check_output(["/usr/sbin/scselect"], text=True)
        for line in output.splitlines():
            if line.strip().startswith("*"):
                # Active location found will have the format:
                # * LocationID (LocationName)
                # Return just the LocationName part
                location = line.strip().lstrip("*").strip()
                return location[location.find("(") + 1 : location.find(")")]
    except Exception:
        pass
    return None


def switch_location(target: str) -> None:
    """Switch to the specified network location if not already active."""
    current = get_current_location()
    log(f"Current location: {current}, target: {target}")
    if current != target:
        try:
            subprocess.run(
                ["/usr/sbin/networksetup", "-switchtolocation", target], check=True
            )  # throw exception error if fails
            log(f"Switched network location → {target}")
        except Exception as e:
            log(f"Failed to switch to location '{target}': {e}")
    else:
        log(f"Already on location: {target}")


def network_changed(store: Any, changed_keys: Any, info: Any) -> None:
    """
    Callback triggered instantly when a network configuration event occurs.
    """
    ssid = get_current_ssid()
    wifi = wifi_active()
    wired = ethernet_active()

    if wired:
        target = ETHERNET_LOCATION
        log(f"Detected Ethernet connection active. Target={target}")
    elif wifi and ssid:
        target = SSID_LOCATION_MAP.get(ssid, DEFAULT_WIFI_LOCATION)
        log(f"Detected Wi-Fi SSID={ssid}, target={target}")
    else:
        target = DEFAULT_WIFI_LOCATION
        log(
            "No active Wi-Fi or Ethernet detected. " f"Using default location: {target}"
        )

    switch_location(target)


# ──────────────────────────────────────────────
# Main setup
# ──────────────────────────────────────────────

# This line creates a dynamic store object using Apple's System
# Configuration framework, which is the foundation for monitoring
# network changes on macOS systems.
# The SCDynamicStoreCreate function establishes a connection to the
# system's dynamic configuration database - think of it as subscribing
# to a live feed of system configuration changes. The first parameter
# is None, which means the store will use the default allocator for
# memory management. The second parameter "network_watcher" is a
# descriptive name for this store session, which helps identify it in
# system logs and debugging tools.
# The third parameter network_changed is the most critical - it's a
# callback function that will be automatically invoked whenever the
# system detects network configuration changes. This is where your
# custom logic for handling network state transitions would be
# implemented. The final None parameter represents the context info
# that would be passed to the callback function, but since it's not
# needed here, it's set to None.
# Key gotcha: The dynamic store object returned by this function needs
# to be properly scheduled with a run loop to actually receive
# notifications. Simply creating the store won't trigger any callbacks
# - you'll need additional setup code to make the monitoring active.
# Also, this is macOS-specific code using the SystemConfiguration
# framework, so it won't work on other operating systems.
store = SystemConfiguration.SCDynamicStoreCreate(
    None,  # use the default allocator for memory management
    "network_watcher",  # descriptive name for this store session
    network_changed,  # callback function for network changes
    None,  # context info for the callback function (not used here)
)

# This line configures what specific network events will trigger
# your callback function by setting up notification keys for the
# dynamic store you created earlier.
# The SCDynamicStoreSetNotificationKeys function tells the system
# configuration framework exactly which changes you want to monitor.
# The first parameter store is the dynamic store object you created
# previously. The second parameter is None, which means you're not
# specifying any exact key patterns to watch - instead, you're
# relying on the third parameter for pattern matching.
# The third parameter ["State:/Network/Global/IPv4"] is a list of
# key patterns that define which system configuration changes should
# trigger your callback. In this case, you're monitoring
# State:/Network/Global/IPv4, which is a special key in macOS's
# configuration database that gets updated whenever the global IPv4
# network state changes. This includes events like connecting to
# Wi-Fi, plugging in an Ethernet cable, switching networks, or
# losing network connectivity entirely.
# Important detail: This particular key pattern is ideal for a
# network location switcher because it fires on all the major network
# transitions you care about. When a device connects to a new network
# or changes its primary network interface, the global IPv4 state gets
# updated, which triggers your network_changed callback function. This
# is more reliable than trying to monitor individual interface states,
# since it captures the overall network connectivity picture that
# affects which network location should be active.
# The beauty of this approach is that you don't need to guess which
# specific network interfaces might change - you're monitoring the
# system's high-level view of network connectivity, which
# automatically covers Wi-Fi, Ethernet, and other network interfaces.
SystemConfiguration.SCDynamicStoreSetNotificationKeys(
    store,  # dynamic store object created earlier
    None,  # no specific key patterns to watch
    ["State:/Network/Global/IPv4"],  # monitor global IPv4 network state changes
)

# This line creates a run loop source that bridges your dynamic store with
# macOS's event processing system, making the network monitoring actually
# functional.
# The SCDynamicStoreCreateRunLoopSource function converts your dynamic store
# into a format that can be integrated with a run loop - think of it as
# creating an adapter that allows your network monitoring to plug into the
# system's event-driven architecture. The first parameter is None, indicating
# the default memory allocator should be used. The second parameter store is
# your previously created dynamic store object that contains the callback
# function and notification keys. The final parameter 0 represents the
# priority order of this source within the run loop (0 being the default
# priority).
# Critical concept: This step is essential because simply creating a dynamic
# store and setting notification keys doesn't actually start the
# monitoring - it just sets up the configuration. The run loop source is what
# makes the system actively listen for those network changes and invoke your
# callback function. Without this, your network_changed function would never
# be called, regardless of how many network events occur.
# Key gotcha: The run loop source created here still needs to be added to an
# actual run loop and that run loop needs to be running for the monitoring to
# work. This line just creates the source object - you'll need additional code
# to schedule it with a run loop (typically the current thread's default run
# loop) and then start the run loop to begin receiving network change
# notifications.
loop = SystemConfiguration.SCDynamicStoreCreateRunLoopSource(None, store, 0)

# ──────────────────────────────────────────────

# Set up signal handling to gracefully stop the run loop if needed


def signal_handler(signum: int, frame: Any) -> None:
    log("Received termination signal, shutting down...")
    # Remove the run loop source
    CoreFoundation.CFRunLoopRemoveSource(
        CoreFoundation.CFRunLoopGetCurrent(), loop, CoreFoundation.kCFRunLoopDefaultMode
    )
    # Stop the run loop
    CoreFoundation.CFRunLoopStop(CoreFoundation.CFRunLoopGetCurrent())
    sys.exit(0)


# Set up signal handlers before starting the run loop
signal.signal(signal.SIGINT, signal_handler)  # Ctrl+C
signal.signal(signal.SIGTERM, signal_handler)  # Termination signal

# This line connects your network monitoring run loop source to the current
# thread's run loop, which is the final step needed to activate your network
# change detection system.
# The CFRunLoopAddSource function takes three parameters that work together to
# integrate your monitoring into macOS's event system. The first parameter
# CFRunLoopGetCurrent() gets a reference to the run loop associated with the
# current thread - this is typically the main thread's run loop where your
# application is executing. The second parameter loop is the run loop source
# you created in the previous step, which contains your network monitoring
# configuration. The third parameter kCFRunLoopDefaultMode specifies which run
# loop mode this source should be active in - the default mode means it will
# process events during normal program execution.
# Critical understanding: This is where everything comes together. Up until
# this point, you've created a dynamic store, configured what network changes
# to watch for, and created a run loop source - but none of that actually
# does anything yet. This function call is what schedules your network
# monitoring to be processed by the system's event loop, making it live and
# responsive.
# Important detail: Once this line executes and a run loop starts running
# (typically with CFRunLoopRun()), your network_changed callback function will
# be automatically invoked whenever the system detects changes to the global
# IPv4 network state. This creates a reactive system where network transitions
# immediately trigger your location switching logic without any polling or
# manual checking required.
CoreFoundation.CFRunLoopAddSource(
    CoreFoundation.CFRunLoopGetCurrent(), loop, CoreFoundation.kCFRunLoopDefaultMode
)

# Log startup information and initial status
log_startup_info()

# Perform initial network check
network_changed(None, None, None)

log("Network watcher started (Wi-Fi + Ethernet aware).")

# This line starts the run loop and puts your program into an active listening
#  state, where it will continuously monitor for the network changes you've
# configured.
# The CFRunLoopRun() function is what actually begins the event processing
# cycle. Think of it as starting the engine of your network monitoring
# system - all the previous setup (creating the dynamic store, setting
# notification keys, creating the run loop source, and adding it to the run
# loop) was just configuration. This function call is what makes everything
# come alive and start responding to network events.
# Critical behavior: This is a blocking call, meaning your program will pause
# at this line and enter an infinite loop where it waits for and processes
# events. When network changes occur that match your notification patterns
# (like changes to the global IPv4 state), the run loop will automatically
# invoke your network_changed callback function. The program will continue
# running indefinitely until something explicitly stops the run loop or the
# process is terminated.
# Important gotcha: Since this is a blocking call, any code you place after
# this line won't execute until the run loop stops running. This is typically
# the desired behavior for a network monitoring daemon that should run
# continuously in the background, but if you need your program to do other
# work, you'd need to either run the run loop on a separate thread or use a
# different approach like CFRunLoopRunInMode() with a timeout to periodically
# break out of the loop.
CoreFoundation.CFRunLoopRun()

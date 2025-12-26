#!/usr/bin/env python3
"""
Network Location Switcher for macOS

Automatically switches network locations based on connected Wi-Fi networks
or Ethernet.
Configuration is loaded from an external JSON file for maximum flexibility.

Usage:
    network_loc_switcher [config_file]
    network_loc_switcher --help
    network_loc_switcher --version
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
    print("Options:")
    print("  --help, -h              Show this help message")
    print("  --version, -v           Show version information")
    print("  -c, --configuration_file FILE")
    print("                          Use a specific configuration file")
    print()
    print("Test modes (for debugging and verification):")
    print("  --test, -t [TYPE]       Run tests without starting the daemon")
    print("                          Types: notification, network, location, all")
    print(
        "  --test-notification     Test sending a notification to Notification Center"
    )
    print("  --test-network          Test network detection (Wi-Fi SSID, Ethernet)")
    print("  --test-location         Test location detection and switching")
    print()
    print("Configuration mode (use with --test to test specific installation):")
    print("  --mode, -m MODE         Use config from a specific installation mode")
    print("                          Modes: system, user, dev, auto")
    print(
        "                          system: /usr/local/etc/network-location-config.json"
    )
    print(
        "                          user:   /usr/local/etc/$USER/network-location-config.json"
    )
    print(
        "                          dev:    ./network-location-config.json (script dir)"
    )
    print("                          auto:   Search all locations (default)")
    print()
    print("Examples:")
    print("  network_loc_switcher --test notification")
    print("  network_loc_switcher --test --mode system")
    print("  network_loc_switcher --test --mode system notification")
    print("  network_loc_switcher -t -m user network")
    print("  network_loc_switcher -c /path/to/config.json")
    print("  network_loc_switcher -c /path/to/config.json --test")
    print()
    print("Configuration file locations (searched in order when mode=auto):")
    print("  1. Explicit: -c /path/to/config.json")
    print("  2. Script directory: ./network-location-config.json")
    print("  3. User home: ~/.network-location-config.json")
    print("  4. User-specific: /usr/local/etc/$USER/network-location-config.json")
    print("  5. System-wide: /usr/local/etc/network-location-config.json")
    print("  6. System: /etc/network-location-config.json")
    print()
    print("If no config file is found, a default one will be created.")
    print("Edit the config file to match your network setup.")


def show_version() -> None:
    """Display version information."""
    print(VERSION)
    print("macOS network location automation with external configuration")


class TestMode:
    """Enum-like class for test modes."""

    NONE = "none"
    NOTIFICATION = "notification"
    NETWORK = "network"
    LOCATION = "location"
    ALL = "all"


class ConfigMode:
    """Enum-like class for config file modes."""

    AUTO = "auto"  # Use default search order
    SYSTEM = "system"  # Use /usr/local/etc/network-location-config.json
    USER = "user"  # Use /usr/local/etc/{username}/network-location-config.json
    DEV = "dev"  # Use script directory config


# Global to track if we're in test mode (set during arg parsing)
_test_mode: str = TestMode.NONE
_config_mode: str = ConfigMode.AUTO


def parse_args() -> Optional[str]:
    """Parse command line arguments.

    Supports formats:
        script.py -c config_file
        script.py --configuration_file config_file
        script.py --test [type]
        script.py --test --mode system [type]
        script.py --mode user --test notification
    """
    global _test_mode, _config_mode

    config_file: Optional[str] = None
    i = 1

    while i < len(sys.argv):
        arg = sys.argv[i]

        if arg in ("--help", "-h", "help"):
            show_help()
            sys.exit(0)
        elif arg in ("--version", "-v", "version"):
            show_version()
            sys.exit(0)
        elif arg in ("--configuration_file", "--config", "-c"):
            # Explicit config file path
            if i + 1 < len(sys.argv):
                config_file = sys.argv[i + 1]
                i += 1  # Skip the config file argument
            else:
                print(f"{arg} requires a file path argument")
                sys.exit(1)
        elif arg in ("--mode", "-m"):
            # Config mode selection
            if i + 1 < len(sys.argv):
                mode = sys.argv[i + 1].lower()
                if mode in ("system", "sys", "s"):
                    _config_mode = ConfigMode.SYSTEM
                elif mode in ("user", "usr", "u"):
                    _config_mode = ConfigMode.USER
                elif mode in ("dev", "development", "d"):
                    _config_mode = ConfigMode.DEV
                elif mode in ("auto", "a"):
                    _config_mode = ConfigMode.AUTO
                else:
                    print(f"Unknown mode: {mode}")
                    print("Available modes: system, user, dev, auto")
                    sys.exit(1)
                i += 1  # Skip the mode argument
            else:
                print("--mode requires an argument: system, user, dev, or auto")
                sys.exit(1)
        elif arg in ("--test", "-t"):
            # Test mode - check for sub-command (skip if next arg is a flag)
            if i + 1 < len(sys.argv) and not sys.argv[i + 1].startswith("-"):
                test_type = sys.argv[i + 1].lower()
                if test_type in ("notification", "notify", "n"):
                    _test_mode = TestMode.NOTIFICATION
                    i += 1  # Skip the test type argument
                elif test_type in ("network", "net"):
                    _test_mode = TestMode.NETWORK
                    i += 1  # Skip the test type argument
                elif test_type in ("location", "loc"):
                    _test_mode = TestMode.LOCATION
                    i += 1  # Skip the test type argument
                elif test_type in ("all", "a"):
                    _test_mode = TestMode.ALL
                    i += 1  # Skip the test type argument
                else:
                    # Not a known test type, might be next flag - default to all
                    _test_mode = TestMode.ALL
            else:
                # Default to all tests
                _test_mode = TestMode.ALL
        elif arg == "--test-notification":
            _test_mode = TestMode.NOTIFICATION
        elif arg == "--test-network":
            _test_mode = TestMode.NETWORK
        elif arg == "--test-location":
            _test_mode = TestMode.LOCATION
        elif arg.startswith("-"):
            print(f"Unknown option: {arg}")
            print("Use --help for usage information.")
            sys.exit(1)
        else:
            print(f"Unexpected argument: {arg}")
            print("Use -c or --configuration_file to specify a config file.")
            print("Use --help for usage information.")
            sys.exit(1)

        i += 1

    return config_file


def get_config_mode() -> str:
    """Return the current config mode."""
    return _config_mode


def get_test_mode() -> str:
    """Return the current test mode."""
    return _test_mode


def get_config_path_for_mode(mode: str) -> Optional[str]:
    """Get the config file path for a specific mode."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    username = os.environ.get("USER", os.environ.get("USERNAME", ""))

    if mode == ConfigMode.SYSTEM:
        return "/usr/local/etc/network-location-config.json"
    elif mode == ConfigMode.USER:
        if username:
            return f"/usr/local/etc/{username}/network-location-config.json"
        print("Error: Cannot determine username for user mode config")
        return None
    elif mode == ConfigMode.DEV:
        return os.path.join(script_dir, "network-location-config.json")
    # AUTO mode uses search order
    return None


def load_config() -> dict[str, Any]:
    """Load configuration from external JSON file."""
    # Parse command line arguments
    config_file_arg = parse_args()
    config_mode = get_config_mode()

    # Configuration file paths to try (in order of preference)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    username = os.environ.get("USER", os.environ.get("USERNAME", ""))

    # If a specific mode was requested, use that config path
    if config_mode != ConfigMode.AUTO:
        mode_config_path = get_config_path_for_mode(config_mode)
        if mode_config_path:
            if os.path.isfile(mode_config_path):
                try:
                    with open(mode_config_path) as f:
                        config: dict[str, Any] = json.load(f)
                        print(
                            f"{time.strftime('%Y-%m-%d %H:%M:%S')} "
                            f"Loaded configuration from: {mode_config_path} "
                            f"(mode: {config_mode})"
                        )
                        return config
                except (OSError, json.JSONDecodeError) as e:
                    print(f"Error reading config file {mode_config_path}: {e}")
                    sys.exit(1)
            else:
                print(
                    f"Error: Config file not found for mode '{config_mode}': {mode_config_path}"
                )
                sys.exit(1)

    # Standard search order
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
                    config = json.load(f)
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
        "log_file": "/usr/local/log/network_loc_switcher.log",
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
            "log_file": "/usr/local/log/network_loc_switcher.log",
        }


def validate_config(config: dict[str, Any]) -> dict[str, Any]:
    """Validate configuration and fix common issues."""
    # Ensure required keys exist with defaults
    defaults = {
        "ssid_location_map": {},
        "default_wifi_location": "Automatic",
        "ethernet_location": "Wired",
        "log_file": "/usr/local/log/network_loc_switcher.log",
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
            config["log_file"] = os.path.join(script_dir, "network_loc_switcher.log")
            log(f"Using fallback log file: {config['log_file']}")

    return config


# Load and validate configuration
CONFIG = validate_config(load_config())
SSID_LOCATION_MAP = CONFIG["ssid_location_map"]
DEFAULT_WIFI_LOCATION = CONFIG["default_wifi_location"]
ETHERNET_LOCATION = CONFIG["ethernet_location"]
LOG_FILE = CONFIG["log_file"]

# Check if we're in test mode (must be done after config is loaded
# but before we define functions that need the config)
_current_test_mode = get_test_mode()


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


def get_notifytool_path() -> Optional[str]:
    """
    Find the NotifyTool binary path.
    Checks common installation locations.
    """
    # Common paths to check for NotifyTool
    paths_to_check = [
        # User's Application Support bundle (created by NotifyTool on first run)
        os.path.expanduser(
            "~/Library/Application Support/NotifyTool.app/Contents/MacOS/notifytool"
        ),
        # Local bin directory
        "/usr/local/bin/notifytool",
        # Same directory as this script
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "notifytool"),
    ]

    for path in paths_to_check:
        if os.path.isfile(path) and os.access(path, os.X_OK):
            return path
    return None


def send_notification_notifytool(
    title: str, message: str, subtitle: Optional[str] = None
) -> bool:
    """
    Send a notification using NotifyTool (native UserNotifications framework).
    Returns True if successful, False otherwise.
    """
    notifytool_path = get_notifytool_path()
    if not notifytool_path:
        return False

    try:
        cmd = [notifytool_path, "--title", title, "--body", message]
        if subtitle:
            cmd += ["--subtitle", subtitle]

        # Check if running as root (system service mode)
        is_root = os.geteuid() == 0

        if is_root:
            # Running as system service - need to send notification to console user
            console_user_output = run_command("/usr/bin/stat -f '%Su' /dev/console")
            if console_user_output:
                console_user = console_user_output.strip()
                user_id_output = run_command(f"/usr/bin/id -u {console_user}")
                if user_id_output:
                    user_id = user_id_output.strip()
                    # Use launchctl asuser to run notifytool as the console user
                    subprocess.run(
                        ["/bin/launchctl", "asuser", user_id] + cmd,
                        check=False,
                        capture_output=True,
                    )
                    return True

        # Regular notification (user mode or fallback)
        result = subprocess.run(cmd, check=False, capture_output=True)
        return result.returncode == 0

    except Exception as e:
        log(f"NotifyTool failed: {e}")
        return False


def send_notification_osascript(title: str, message: str) -> bool:
    """
    Send a notification using osascript (AppleScript).
    Fallback method when NotifyTool is not available.
    Returns True if successful, False otherwise.
    """
    try:
        # Escape special characters for AppleScript
        title_escaped = title.replace('"', '\\"').replace("\\", "\\\\")
        message_escaped = message.replace('"', '\\"').replace("\\", "\\\\")

        script = (
            f'display notification "{message_escaped}" '
            f'with title "{title_escaped}" '
            f'sound name "Glass"'
        )

        # Check if running as root (system service mode)
        is_root = os.geteuid() == 0

        if is_root:
            # Running as system service - need to send notification to console user
            console_user_output = run_command("/usr/bin/stat -f '%Su' /dev/console")
            if console_user_output:
                console_user = console_user_output.strip()
                user_id_output = run_command(f"/usr/bin/id -u {console_user}")
                if user_id_output:
                    user_id = user_id_output.strip()
                    subprocess.run(
                        [
                            "/bin/launchctl",
                            "asuser",
                            user_id,
                            "/usr/bin/osascript",
                            "-e",
                            script,
                        ],
                        check=False,
                        capture_output=True,
                    )
                return True

        # Regular notification (user mode or fallback)
        subprocess.run(
            ["/usr/bin/osascript", "-e", script],
            check=False,
            capture_output=True,
        )
        return True

    except Exception as e:
        log(f"osascript notification failed: {e}")
        return False


def send_notification(title: str, message: str, subtitle: Optional[str] = None) -> None:
    """
    Send a macOS notification using the best available method.

    Tries NotifyTool first (native UserNotifications framework) for better
    integration with Notification Center, Focus mode, and system settings.
    Falls back to osascript if NotifyTool is not available.

    Works for both user and system service modes:
    - User mode: Runs as current user
    - System mode: Detects console user and sends notification to their session

    Args:
        title: The notification title
        message: The notification body text
        subtitle: Optional subtitle (only supported by NotifyTool)
    """
    # Try NotifyTool first (preferred method)
    if send_notification_notifytool(title, message, subtitle):
        return

    # Fall back to osascript
    if not send_notification_osascript(title, message):
        log(f"Could not send notification: {title} - {message}")


def run_test_notification() -> bool:
    """
    Test sending a notification to Notification Center.
    Returns True if successful.
    """
    print("\n" + "=" * 60)
    print("NOTIFICATION TEST")
    print("=" * 60)

    # Check for NotifyTool
    notifytool_path = get_notifytool_path()
    if notifytool_path:
        print(f"✓ NotifyTool found: {notifytool_path}")
    else:
        print("✗ NotifyTool not found (will use osascript fallback)")
        print("  Install NotifyTool for better Notification Center integration")

    print("\nSending test notification...")

    # Send a test notification
    send_notification(
        title="Network Location Switcher",
        message="Test notification successful!",
        subtitle="This is a test",
    )

    print("✓ Notification sent!")
    print("\nCheck your Notification Center to verify the notification appeared.")
    print("=" * 60)
    return True


def run_test_network() -> bool:
    """
    Test network detection functionality.
    Returns True if successful.
    """
    print("\n" + "=" * 60)
    print("NETWORK DETECTION TEST")
    print("=" * 60)

    # Test Wi-Fi interface detection
    print("\n[Wi-Fi Interface]")
    wifi_iface = get_wifi_interface()
    if wifi_iface:
        print(f"  ✓ Wi-Fi interface: {wifi_iface}")
    else:
        print("  ✗ No Wi-Fi interface found")

    # Test Wi-Fi status
    print("\n[Wi-Fi Status]")
    wifi_is_active = wifi_active()
    print(f"  Active: {'✓ Yes' if wifi_is_active else '✗ No'}")

    # Test current SSID
    print("\n[Current SSID]")
    ssid = get_current_ssid()
    if ssid:
        print(f"  ✓ Connected to: {ssid}")
        # Check if SSID is in config
        if ssid in SSID_LOCATION_MAP:
            print(f"  ✓ Mapped to location: {SSID_LOCATION_MAP[ssid]}")
        else:
            print(f"  ⚠ Not in config (will use default: {DEFAULT_WIFI_LOCATION})")
    else:
        print("  ✗ Not connected to any Wi-Fi network")

    # Test Ethernet detection
    print("\n[Ethernet Status]")
    ethernet_is_active = ethernet_active()
    print(f"  Active: {'✓ Yes' if ethernet_is_active else '✗ No'}")

    # Summary
    print("\n[Connection Priority]")
    if ethernet_is_active:
        print(f"  → Would use Ethernet location: {ETHERNET_LOCATION}")
    elif wifi_is_active and ssid:
        target = SSID_LOCATION_MAP.get(ssid, DEFAULT_WIFI_LOCATION)
        print(f"  → Would use Wi-Fi location: {target}")
    else:
        print(f"  → Would use default location: {DEFAULT_WIFI_LOCATION}")

    print("=" * 60)
    return True


def run_test_location() -> bool:
    """
    Test location detection and display available locations.
    Returns True if successful.
    """
    print("\n" + "=" * 60)
    print("NETWORK LOCATION TEST")
    print("=" * 60)

    # Get current location
    print("\n[Current Location]")
    current = get_current_location()
    if current:
        print(f"  ✓ Active location: {current}")
    else:
        print("  ✗ Could not determine current location")

    # List all available locations
    print("\n[Available Locations]")
    try:
        output = subprocess.check_output(["/usr/sbin/scselect"], text=True)
        for line in output.splitlines():
            line = line.strip()
            if line.startswith("*"):
                # Active location
                print(f"  → {line} (active)")
            elif line and not line.startswith("Defined"):
                print(f"    {line}")
    except Exception as e:
        print(f"  ✗ Could not list locations: {e}")

    # Show configured mappings
    print("\n[Configured SSID Mappings]")
    if SSID_LOCATION_MAP:
        for ssid, location in SSID_LOCATION_MAP.items():
            print(f"  '{ssid}' → '{location}'")
    else:
        print("  (no SSID mappings configured)")

    print("\n[Default Locations]")
    print(f"  Default Wi-Fi: {DEFAULT_WIFI_LOCATION}")
    print(f"  Ethernet: {ETHERNET_LOCATION}")

    print("=" * 60)
    return True


def run_test_config() -> bool:
    """
    Display which configuration file is being used.
    Returns True always (informational only).
    """
    print("\n" + "=" * 60)
    print("CONFIGURATION")
    print("=" * 60)

    config_mode = get_config_mode()
    script_dir = os.path.dirname(os.path.abspath(__file__))
    username = os.environ.get("USER", os.environ.get("USERNAME", ""))

    # Show mode if explicitly set
    if config_mode != ConfigMode.AUTO:
        mode_path = get_config_path_for_mode(config_mode)
        print(f"\n[Config Mode: {config_mode}]")
        print(f"  ✓ Using: {mode_path}")
    else:
        # Show which config file was loaded from search order
        config_paths = [
            (
                "Script directory (dev)",
                os.path.join(script_dir, "network-location-config.json"),
            ),
            ("User home", os.path.expanduser("~/.network-location-config.json")),
            (
                "User-specific (user)",
                (
                    f"/usr/local/etc/{username}/network-location-config.json"
                    if username
                    else None
                ),
            ),
            ("System-wide (system)", "/usr/local/etc/network-location-config.json"),
            ("System", "/etc/network-location-config.json"),
        ]

        print("\n[Config Mode: auto]")
        print("[Config File Search Order]")
        loaded_path = None
        for label, path in config_paths:
            if path is None:
                continue
            exists = os.path.isfile(path)
            if exists and loaded_path is None:
                loaded_path = path
                print(f"  ✓ {label}: {path}")
                print("    └── THIS CONFIG IS BEING USED")
            elif exists:
                print(f"  ⚠ {label}: {path}")
                print("    └── exists but not used (lower priority)")
            else:
                print(f"  ✗ {label}: {path}")

        if not loaded_path:
            print("\n  ⚠ No config file found - using defaults")

    # Show config summary
    print("\n[Loaded Configuration]")
    print(f"  SSID mappings: {len(SSID_LOCATION_MAP)}")
    for ssid, location in SSID_LOCATION_MAP.items():
        print(f"    '{ssid}' → '{location}'")
    print(f"  Default Wi-Fi location: {DEFAULT_WIFI_LOCATION}")
    print(f"  Ethernet location: {ETHERNET_LOCATION}")
    print(f"  Log file: {LOG_FILE}")

    # Show tip if not using a specific mode
    if config_mode == ConfigMode.AUTO:
        print("\n[TIP] To test with a specific config, use --mode:")
        print("  --mode system  (installed system service config)")
        print("  --mode user    (installed user service config)")
        print("  --mode dev     (development/script directory config)")

    print("=" * 60)
    return True


def run_tests(test_mode: str) -> None:
    """Run the specified tests and exit."""
    print(f"\n{VERSION}")
    print("Running in test mode...")

    success = True

    # Always show config info first
    success = run_test_config() and success

    if test_mode in (TestMode.ALL, TestMode.NETWORK):
        success = run_test_network() and success

    if test_mode in (TestMode.ALL, TestMode.LOCATION):
        success = run_test_location() and success

    if test_mode in (TestMode.ALL, TestMode.NOTIFICATION):
        success = run_test_notification() and success

    print("\n" + "=" * 60)
    if success:
        print("All tests completed successfully!")
    else:
        print("Some tests failed.")
    print("=" * 60 + "\n")

    sys.exit(0 if success else 1)


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
            # Send notification for successful switch
            send_notification(
                "Network Location Switched", f"Switched to '{target}' network location"
            )
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

# Check for test mode before starting daemon
if _current_test_mode != TestMode.NONE:
    run_tests(_current_test_mode)
    # run_tests calls sys.exit(), so we won't reach here

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

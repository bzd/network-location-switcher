#!/usr/bin/env python3
"""
Configuration test script for network_loc_switcher

This script validates your configuration file and tests network detection
without actually switching network locations.
"""

import json
import os
import subprocess
import sys
from typing import Any, Optional, cast


def load_and_validate_config(
    config_path: Optional[str] = None,
) -> tuple[Optional[dict[str, Any]], Optional[str]]:
    """Load and validate configuration file."""

    # Find config file
    if config_path:
        config_paths = [config_path]
        template_path = None
        main_config_path = None
    else:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        config_paths = [
            os.path.join(script_dir, "network-location-config.json"),
            os.path.expanduser("~/.network-location-config.json"),
            "/usr/local/etc/network-location-config.json",
            "/etc/network-location-config.json",
        ]

        # Check if we should create a config from template
        template_path = os.path.join(script_dir, "network-location-config.default.json")
        main_config_path = os.path.join(script_dir, "network-location-config.json")

    config: Optional[dict[str, Any]] = None
    config_file_used: Optional[str] = None

    for path in config_paths:
        if os.path.isfile(path):
            try:
                with open(path) as f:
                    config = json.load(f)
                    config_file_used = path
                    break
            except (OSError, json.JSONDecodeError) as e:
                print(f"❌ Error reading {path}: {e}")
                continue

    if not config:
        # Check if we can create one from template
        if (
            template_path
            and os.path.isfile(template_path)
            and main_config_path
            and not os.path.isfile(main_config_path)
        ):
            print(
                f"📋 No configuration found, " f"but template exists: {template_path}"
            )
            response = input(
                "Would you like to create a configuration file "
                "from the template? (y/N): "
            )
            if response.lower() in ["y", "yes"]:
                try:
                    create_config_from_template(template_path, main_config_path)
                    print(f"✅ Created configuration file: {main_config_path}")
                    print(
                        "⚠️  Please edit this file to match your network "
                        "setup before testing!"
                    )
                    return None, None  # Don't test the template values
                except Exception as e:
                    print(f"❌ Error creating config from template: {e}")

        print("❌ No valid configuration file found!")
        print("Expected locations:")
        for path in config_paths:
            print(f"  - {path}")
        if template_path and os.path.isfile(template_path):
            print(f"\n💡 Template available: {template_path}")
            print("   You can create a config file from this template.")
        return None, None

    print(f"✅ Configuration loaded from: {config_file_used}")

    # Validate structure
    required_keys = [
        "ssid_location_map",
        "default_wifi_location",
        "ethernet_location",
        "log_file",
    ]
    missing_keys: list[str] = []

    for key in required_keys:
        if key not in config:
            missing_keys.append(key)

    if missing_keys:
        print(
            f"❌ Missing required configuration keys: {
                ', '.join(missing_keys)}"
        )
        return None, None

    # Validate types
    if not isinstance(config["ssid_location_map"], dict):
        print("❌ 'ssid_location_map' must be an object/dictionary")
        return None, None

    print("✅ Configuration structure is valid")
    return config, config_file_used


def create_config_from_template(template_path: str, output_path: str) -> None:
    """Create a clean config file from template."""
    with open(template_path) as f:
        template_config = json.load(f)

    # Remove template comments (keys starting with _)
    clean_config: dict[str, Any] = {}
    for key, value in template_config.items():
        if not key.startswith("_"):
            if isinstance(value, dict):
                value_dict = cast(dict[str, Any], value)
                clean_value: dict[str, Any] = {
                    k: v for k, v in value_dict.items() if not k.startswith("_")
                }
                clean_config[key] = clean_value
            else:
                clean_config[key] = value

    with open(output_path, "w") as f:
        json.dump(clean_config, f, indent=2)


def test_network_locations(config: dict[str, Any]) -> bool:
    """Test that all configured network locations exist."""
    print("\n🔍 Testing network locations...")

    try:
        # Get list of available network locations
        output = subprocess.check_output(
            ["/usr/sbin/networksetup", "-listlocations"], text=True
        )
        available_locations = [line.strip() for line in output.strip().split("\n")]

        print(
            f"📋 Available network locations: {
                ', '.join(available_locations)}"
        )

        # Check locations used in config
        all_locations: set[str] = set()
        all_locations.add(config["default_wifi_location"])
        all_locations.add(config["ethernet_location"])
        all_locations.update(config["ssid_location_map"].values())

        missing_locations: list[str] = []
        for location in all_locations:
            if location not in available_locations:
                missing_locations.append(location)

        if missing_locations:
            print(
                f"❌ Missing network locations: {
                    ', '.join(missing_locations)}"
            )
            print(
                "Create them with: /usr/sbin/networksetup -createlocation "
                "'<name>' populate"
            )
            return False
        else:
            print("✅ All network locations exist")
            return True

    except subprocess.CalledProcessError as e:
        print(f"❌ Error checking network locations: {e}")
        return False


def test_current_network() -> Optional[str]:
    """Test current network detection."""
    print("\n📡 Testing current network detection...")

    try:
        # Current network location
        output = subprocess.check_output(["/usr/sbin/scselect"], text=True)
        current_location = None
        for line in output.splitlines():
            if line.strip().startswith("*"):
                current_location = line.strip().lstrip("*").strip()
                break

        print(f"📍 Current network location: {current_location or 'Unknown'}")

        # Ethernet status
        # ethernet_output = subprocess.check_output(
        #     "ifconfig | grep -A2 'flags' | grep 'status: active'",
        #     shell=True, text=True
        # )
        # ethernet_active = (
        #     "en" in ethernet_output and "status: active" in ethernet_output
        # )

        ethernet_active = (
            subprocess.check_output(
                "/sbin/route get default | grep interface | grep en",
                shell=True,
                text=True,
            )
            != ""
        )

        print(f"🔌 Ethernet active: {ethernet_active}")

        # Wi-Fi interface
        # Wi-Fi interface detection with fallback
        primary_cmd = (
            "/usr/sbin/scutil <<< list | /usr/bin/awk -F/ "
            "'/Setup:.*AirPort$/{i=$(NF-1);exit} "
            "END {if(i) {print i} else {exit 1}}'"
        )
        fallback_cmd = (
            "/usr/sbin/scutil <<< list | /usr/bin/awk -F/ "
            "'/en[0-9]+\\/AirPort$/ {print $(NF-1);exit}'"
        )
        wifi_cmd = f"{primary_cmd} || {fallback_cmd}"
        wifi_iface = subprocess.check_output(wifi_cmd, shell=True, text=True).strip()
        print(f"📶 Wi-Fi interface: {wifi_iface or 'Not found'}")

        if wifi_iface:
            # Wi-Fi status
            wifi_status_output = subprocess.check_output(
                f"/sbin/ifconfig {wifi_iface} | grep 'status: active'",
                shell=True,
                text=True,
            )
            wifi_active = "status: active" in wifi_status_output
            print(f"📶 Wi-Fi active: {wifi_active}")

            # Current SSID
            if wifi_active:
                try:
                    # Get preferred networks list
                    cmd = [
                        "/usr/sbin/networksetup",
                        "-listpreferredwirelessnetworks",
                        wifi_iface,
                    ]
                    output = subprocess.check_output(cmd, text=True).strip()

                    # Extract SSID from second line
                    lines = output.splitlines()
                    if len(lines) >= 2:
                        ssid = lines[1].strip().lstrip("\t")
                        print(f"📶 Current SSID: {ssid or 'Unknown'}")
                        return ssid
                    else:
                        print("📶 Current SSID: No networks found")
                        return None
                except subprocess.CalledProcessError:
                    print("📶 Current SSID: Unable to detect")

        return None

    except subprocess.CalledProcessError as e:
        print(f"❌ Error detecting network: {e}")
        return None


def test_ssid_mapping(config: dict[str, Any], current_ssid: Optional[str]) -> None:
    """Test SSID to location mapping."""
    print("\n🗺️  Testing SSID mapping...")

    ssid_map = config["ssid_location_map"]

    if not ssid_map:
        print("⚠️  No SSID mappings configured")
        return

    print("📋 Configured SSID mappings:")
    for ssid, location in ssid_map.items():
        print(f"  '{ssid}' → '{location}'")

    if current_ssid:
        if current_ssid in ssid_map:
            target_location = ssid_map[current_ssid]
            print(
                f"✅ Current SSID '{current_ssid}' maps to "
                f"location '{target_location}'"
            )
        else:
            default_location = config["default_wifi_location"]
            print(
                f"ℹ️  Current SSID '{current_ssid}' not in map, "
                f"would use default: '{default_location}'"
            )
    else:
        print("ℹ️  No current SSID to test mapping")


def test_log_file(config: dict[str, Any]) -> bool:
    """Test log file accessibility."""
    print("\n📝 Testing log file...")

    log_file = config["log_file"]
    log_dir = os.path.dirname(log_file)

    print(f"📄 Log file: {log_file}")

    # Check if directory exists
    if log_dir and not os.path.exists(log_dir):
        print(f"⚠️  Log directory does not exist: {log_dir}")
        try:
            os.makedirs(log_dir, mode=0o755, exist_ok=True)
            print(f"✅ Created log directory: {log_dir}")
        except OSError as e:
            print(f"❌ Cannot create log directory: {e}")
            return False

    # Test write access
    try:
        with open(log_file, "a") as f:
            f.write(
                f"# Test write at {
                    __import__('time').strftime('%Y-%m-%d %H:%M:%S')}\n"
            )
        print("✅ Log file is writable")
        return True
    except OSError as e:
        print(f"❌ Cannot write to log file: {e}")
        return False


def main() -> None:
    """Main test function."""
    print("🧪 Network Location Switcher Configuration Test")
    print("=" * 50)

    # Parse arguments
    config_path = None
    if len(sys.argv) > 1:
        if sys.argv[1] in ("--help", "-h"):
            print(__doc__)
            print("Usage:")
            print("  python test.py [config_file.json]")
            sys.exit(0)
        else:
            config_path = sys.argv[1]

    # Load and validate config
    config, config_file = load_and_validate_config(config_path)
    if not config:
        sys.exit(1)

    print("\n📋 Configuration summary:")
    print(f"  SSID mappings: {len(config['ssid_location_map'])}")
    print(f"  Default Wi-Fi location: {config['default_wifi_location']}")
    print(f"  Ethernet location: {config['ethernet_location']}")
    print(f"  Log file: {config['log_file']}")

    # Run tests
    tests = [
        ("Network Locations", lambda: test_network_locations(config)),
        ("Log File", lambda: test_log_file(config)),
    ]

    current_ssid = test_current_network()
    test_ssid_mapping(config, current_ssid)

    # Run remaining tests
    passed = 0
    total = len(tests)

    for _test_name, test_func in tests:
        if test_func():
            passed += 1

    # Summary
    print("\n" + "=" * 50)
    print(f"🎯 Test Results: {passed}/{total} tests passed")

    if passed == total:
        print("🎉 Configuration is ready for use!")
        print("\nTo start the network switcher:")
        print(f"  python network_loc_switcher.py {config_file}")
    else:
        print("💥 Please fix the issues above before using " "the network switcher")
        sys.exit(1)


if __name__ == "__main__":
    main()

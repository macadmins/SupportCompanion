#!/usr/bin/python3

# This script is used to gather data about the system and write it to a JSON file that will be read by the Support Companion app.
# The script gathers data about the current WiFi network, battery status, USB devices, and displays.
# The data is written to a JSON file in the /Library/Application Support/SupportCompanion directory.

import subprocess
import json

# Initialize an empty list to store support companion data
sc_data = []


# Function to run a subprocess command and return its output
def run_subprocess(command):
    try:
        result = subprocess.run(
            command, shell=True, capture_output=True, text=True, check=True
        )
        return result.stdout
    except subprocess.CalledProcessError as e:
        return ""


# Function to get the name of the current WiFi network
def get_wifi_name():
    command = "sudo wdutil info | grep 'SSID' | head -n 1 | awk -F ': ' '{print $2}'"
    return run_subprocess(command).strip()


# Function to get the current battery status
def get_battery():
    command = "pmset -g batt | egrep '([0-9]+\\%).*' -o --colour=auto | cut -f1 -d';'"
    return run_subprocess(command).strip()


# Function to parse USB device data
def parse_usb_device(device):
    return {
        "name": device.get("_name", ""),
        "ProductID": device.get("product_id", ""),
        "VendorID": device.get("vendor_id", ""),
        "Manufacturer": device.get("manufacturer", ""),
        "Serial Number": device.get("serial_num", ""),
        "Speed": device.get("speed", ""),
        "LocationID": device.get("location_id", ""),
    }


# Function to get a list of USB devices
def usb_devices():
    command = "system_profiler SPUSBDataType -json -detaillevel full"
    usb_data = run_subprocess(command)

    devices = []
    try:
        usb_data = json.loads(usb_data)
    except json.JSONDecodeError as e:
        return devices

    def _handle_sub_device_recursive(device):
        if "_items" in device:
            for sub_device in device["_items"]:
                _handle_sub_device_recursive(sub_device)
        else:
            devices.append(parse_usb_device(device))

    for device in usb_data.get("SPUSBDataType", []):
        for usb_device in device.get("_items", []):
            if "_items" in usb_device:
                _handle_sub_device_recursive(usb_device)
            devices.append(parse_usb_device(usb_device))

    return devices


# Function to get a list of displays
def displays():
    command = "system_profiler SPDisplaysDataType -detaillevel full -json"
    display_data = run_subprocess(command)

    displays = []
    try:
        display_data = json.loads(display_data)
    except json.JSONDecodeError as e:
        return displays

    if display_data.get("SPDisplaysDataType", []) == []:
        return displays
    for display in display_data.get("SPDisplaysDataType", [])[0].get(
        "spdisplays_ndrvs", []
    ):
        display_info = {
            "name": display.get("_name", ""),
            "Resolution": display.get("_spdisplays_resolution", ""),
            "Serial Number": display.get("_spdisplays_display-serial-number", ""),
            "Main Display": (
                "Yes"
                if display.get("spdisplays_main", "") == "spdisplays_yes"
                else "No"
            ),
            "Mirror": display.get("spdisplays_mirror", "").split("_")[-1],
            "Rotation": (
                "Supported"
                if display.get("spdisplays_rotation", "") == "spdisplays_supported"
                else display.get("spdisplays_rotation", "")
            ),
        }
        displays.append(display_info)

    return displays


# Main function to gather all data and write it to a JSON file
def main():
    wifi = get_wifi_name()
    battery = get_battery()
    usb = usb_devices()
    displays_info = displays()

    for display in displays_info:
        data = {
            "icon": "display",
            "Header": display["name"] or "Display",
            "data": display.pop("name") and display,
        }
        sc_data.append(data)

    for device in usb:
        data = {
            "icon": "cable.connector.horizontal",
            "Header": device["name"] or "USB Device",
            "data": {
                "Product": device.get("ProductID", ""),
                "Vendor": device.get("VendorID", ""),
                "Manufacturer": device.get("Manufacturer", ""),
                "Serial Number": device.get("Serial Number", ""),
                "Location": device.get("LocationID", ""),
            },
        }
        sc_data.append(data)

    data = {
        "icon": "briefcase.fill",
        "Header": "AwesomeCorp Info",
        "data": {"Wifi": wifi, "Battery": battery},
    }

    sc_data.append(data)

    with open(
        "/Library/Application Support/SupportCompanion/awesomecorp.json", "w"
    ) as f:
        json_data = json.dumps(sc_data, indent=4)
        f.write(json_data)


if __name__ == "__main__":
    main()

#!/bin/zsh

# Script requires root so check for root access
if [ $(id -u) -ne 0 ]; then
    echo "Please run this script as root or using sudo"
    exit 1
fi
# Use Apple Recommended Method to detect the user signed in to the desktop
current_user=$(echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }')
console_user_uid=$(echo "show State:/Users/ConsoleUser" | scutil | awk '/kCGSSessionUserIDKey/ {print $NF; exit}' )
# Kill the process
echo "Killing the process..."
pkill -f SupportCompanion
# Unload launchctl job
echo "Unloading helepr launchctl job..."
launchctl unload -w /Library/LaunchDaemons/com.github.macadmins.SupportCompanion.helper.plist
# Remove launchctl job
echo "Removing helper launchctl job..."
rm -f /Library/LaunchDaemons/com.github.macadmins.SupportCompanion.helper.plist
# Remove launch agent
if [ -f "/Library/LaunchAgents/com.github.macadmins.SupportCompanion.agent.plist" ]; then
    echo "Unloading launch agent..."
    /bin/launchctl asuser "${console_user_uid}" /bin/launchctl unload -w /Library/LaunchAgents/com.github.macadmins.SupportCompanion.agent.plist
    echo "Removing launch agent..."
    rm /Library/LaunchAgents/com.github.macadmins.SupportCompanion.agent.plist
fi
# Remove the app
echo "Removing the app..."
rm -rf /Applications/SupportCompanion.app
# Remove app data
echo "Removing helper..."
rm -rf "/Library/PrivilegedHelperTools/com.github.macadmins.SupportCompanion.helper"
# Forget the package
echo "Forgetting the package..."
pkgutil --forget com.github.macadmins.SupportCompanion > /dev/null 2>&1
pkgutil --forget com.github.macadmins.SupportCompanion.LaunchAgent > /dev/null 2>&1
pkgutil --forget com.github.macadmins.SupportCompanion.suite > /dev/null 2>&1

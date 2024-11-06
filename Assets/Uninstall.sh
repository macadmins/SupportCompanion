#!/bin/sh
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
echo "Unloading launchctl job..."
launchctl unload -w /Library/LaunchDaemons/com.almenscorner.supportcompanion.plist
# Remove launchctl job
echo "Removing launchctl job..."
rm /Library/LaunchDaemons/com.almenscorner.supportcompanion.plist
# Remove launch agent
if [ -f "/Library/LaunchAgents/com.almenscorner.supportcompanion.agent.plist" ]; then
    echo "Unloading launch agent..."
    /bin/launchctl asuser "${console_user_uid}" /bin/launchctl unload -w /Library/LaunchAgents/com.almenscorner.supportcompanion.agent.plist
    echo "Removing launch agent..."
    rm /Library/LaunchAgents/com.almenscorner.supportcompanion.agent.plist
fi
# Remove the app
echo "Removing the app..."
rm -rf /Applications/Utilities/SupportCompanion.app
# Remove app data
echo "Removing app data..."
rm -rf "/Users/$current_user/Library/Application Support/SupportCompanion"
rm -rf "/Library/Application Support/SupportCompanion"
# Forget the package
echo "Forgetting the package..."
pkgutil --forget com.almenscorner.supportcompanion > /dev/null 2>&1
pkgutil --forget com.almenscorner.supportcompanion.LaunchAgent > /dev/null 2>&1
pkgutil --forget com.almenscorner.supportcompanion.suite > /dev/null 2>&1

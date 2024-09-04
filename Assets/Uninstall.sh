current_user=$(ls -l /dev/console | awk '{print $3}')
console_user_uid=$(/usr/bin/id -u "$current_user")
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
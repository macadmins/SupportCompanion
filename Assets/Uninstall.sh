current_user=$(ls -l /dev/console | awk '{print $3}')
# Kill the process
echo "Killing the process..."
pkill -f SupportCompanion
# Unload launchctl job
echo "Unloading launchctl job..."
launchctl unload /Library/LaunchDaemons/com.almenscorner.supportcompanion.plist
# Remove launchctl job
echo "Removing launchctl job..."
rm /Library/LaunchDaemons/com.almenscorner.supportcompanion.plist
# Remove the app
echo "Removing the app..."
rm -rf /Applications/Utilities/SupportCompanion.app
# Remove the scripts
echo "Removing the scripts..."
rm -rf /usr/local/supportcompanion
# Remove app data
echo "Removing app data..."
rm -rf "/Users/$current_user/Library/Application Support/SupportCompanion"
# Forget the package
echo "Forgetting the package..."
pkgutil --forget com.almenscorner.supportcompanion
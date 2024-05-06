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
# Forget the package
echo "Forgetting the package..."
pkgutil --forget com.almenscorner.supportcompanion
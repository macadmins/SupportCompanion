#!/bin/zsh
PROJECT_PATH="."
BUILD_PATH="./Build"
BUILD_LA_PATH="./LaunchAgent"
APP_SUPPORT_PATH="${BUILD_PATH}/payload/Library/Application Support/SupportCompanion"
PUBLISH_OUTPUT_DIRECTORY="${PROJECT_PATH}/bin/Release/net8.0-macos/SupportCompanion.app"
PUBLISH_OUTPUT_APP="${PROJECT_PATH}/bin/Release/net8.0-macos/SupportCompanion.app"
ICON_FILE="${PROJECT_PATH}/Assets/appicon.icns"
SUKIUI_LICENSE_FILE="${PROJECT_PATH}/SUKIUI_LICENSE"
AVALONIA_LICENSE_FILE="${PROJECT_PATH}/LICENSE"
UNINSTALL_SCRIPT="${PROJECT_PATH}/Assets/Uninstall.sh"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "${PROJECT_PATH}/Info.plist")
CURRENT_SC_MAIN_BUILD_VERSION=$VERSION
NEWSUBBUILD=$((80620 + $(git rev-parse HEAD~0 | xargs -I{} git rev-list --count {})))

# automate the build version bump
AUTOMATED_SC_BUILD="$CURRENT_SC_MAIN_BUILD_VERSION.$NEWSUBBUILD"

echo "$AUTOMATED_SC_BUILD" > "./build_info.txt"
echo "$CURRENT_SC_MAIN_BUILD_VERSION" > "./build_info_main.txt"

# is dotnet installed?
dotnet="$(dotnet --version)"

if [ -z "$dotnet" ]
then
  echo "dotnet is not installed"
  exit 1
fi

if [ -d "$PUBLISH_OUTPUT_DIRECTORY" ]
then
  rm -rf "$PUBLISH_OUTPUT_DIRECTORY"
fi

if [ -d "$APP_SUPPORT_PATH/scripts" ]
then
  rm -rf "$APP_SUPPORT_PATH/scripts"
fi

if [ -d "$BUILD_PATH/payload/Applications/Utilities/SupportCompanion.app/" ]
then
  rm -rf "$BUILD_PATH/payload/Applications/Utilities/SupportCompanion.app/"
fi

dotnet publish --configuration Release -p:UseAppHost=true

# Create the Applications directory and utilities directory
mkdir -p "${BUILD_PATH}/payload/Applications/Utilities"

# Create resources directory
mkdir -p "$PUBLISH_OUTPUT_DIRECTORY/Contents/Resources"

rm -f "$PUBLISH_OUTPUT_DIRECTORY/Contents/Resources/suki_photo.ico"
cp "$ICON_FILE" "$PUBLISH_OUTPUT_DIRECTORY/Contents/Resources/"
cp "$UNINSTALL_SCRIPT" "$PUBLISH_OUTPUT_DIRECTORY/Contents/Resources/"
cp "$SUKIUI_LICENSE_FILE" "$PUBLISH_OUTPUT_DIRECTORY/Contents/Resources/"
cp "$AVALONIA_LICENSE_FILE" "$PUBLISH_OUTPUT_DIRECTORY/Contents/Resources/"
chmod +x "$PUBLISH_OUTPUT_DIRECTORY/Contents/Resources/Uninstall.sh"
cp -a "${PROJECT_PATH}/Assets/scripts" "${BUILD_PATH}/payload/Library/Application Support/SupportCompanion/"

# set the plist version to AUTOMATED_SC_BUILD
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $AUTOMATED_SC_BUILD" "${PUBLISH_OUTPUT_APP}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $AUTOMATED_SC_BUILD" "${PUBLISH_OUTPUT_APP}/Contents/Info.plist"

# mv each script file to remove the extension
SCRIPT_FILES="$(ls "${APP_SUPPORT_PATH}/scripts/")"
for SCRIPT_FILE in $SCRIPT_FILES
do
    FILE_WITHOUT_EXT=$(basename "$SCRIPT_FILE" .py)
    mv "$APP_SUPPORT_PATH/scripts/$SCRIPT_FILE" "$APP_SUPPORT_PATH/scripts/$FILE_WITHOUT_EXT"
    chmod +x "$APP_SUPPORT_PATH/scripts/$FILE_WITHOUT_EXT"
done

cp -a "$PUBLISH_OUTPUT_APP" "${BUILD_PATH}/payload/Applications/Utilities/"

# Create the json file for munkipkg Support Companion pkg
/bin/cat << SIGNED_JSONFILE > "$BUILD_PATH/build-info.json"
{
  "ownership": "recommended",
  "suppress_bundle_relocation": true,
  "identifier": "com.almenscorner.supportcompanion",
  "postinstall_action": "none",
  "distribution_style": true,
  "version": "$AUTOMATED_SC_BUILD",
  "name": "SupportCompanion-$AUTOMATED_SC_BUILD.pkg",
  "install_location": "/"
}
SIGNED_JSONFILE

# Create the signed pkg
munkipkg "$BUILD_PATH"

# Create the json file for munkipkg Support Companion LA
LAUNCHAGENT_VERSION="1.0.1"
/bin/cat << SIGNED_JSONFILE > "$BUILD_LA_PATH/build-info.json"
{
  "ownership": "recommended",
  "suppress_bundle_relocation": true,
  "identifier": "com.almenscorner.supportcompanion.LaunchAgent",
  "postinstall_action": "none",
  "distribution_style": true,
  "version": "$LAUNCHAGENT_VERSION",
  "name": "SupportCompanion_LaunchAgent-$LAUNCHAGENT_VERSION.pkg",
  "install_location": "/Library/LaunchAgents"
}
SIGNED_JSONFILE

# Create the signed pkg
munkipkg "$BUILD_LA_PATH"

# Move LA build to the main build
mv "$BUILD_LA_PATH/build/SupportCompanion_LaunchAgent-$LAUNCHAGENT_VERSION.pkg" "$BUILD_PATH/build/SupportCompanion_LaunchAgent-$LAUNCHAGENT_VERSION.pkg"

# Create the json file for munkipkg Support Companion suite
mkdir "$BUILD_PATH/payload/Library/LaunchAgents"
cp "$BUILD_LA_PATH/payload/com.almenscorner.supportcompanion.agent.plist" "$BUILD_PATH/payload/Library/LaunchAgents/com.almenscorner.supportcompanion.agent.plist"

/bin/cat << SIGNED_JSONFILE > "$BUILD_PATH/build-info.json"
{
  "ownership": "recommended",
  "suppress_bundle_relocation": true,
  "identifier": "com.almenscorner.supportcompanion.suite",
  "postinstall_action": "none",
  "distribution_style": true,
  "version": "$AUTOMATED_SC_BUILD",
  "name": "SupportCompanion_Suite-$AUTOMATED_SC_BUILD.pkg",
  "install_location": "/"
}
SIGNED_JSONFILE

munkipkg "$BUILD_PATH"

rm -rf "$BUILD_PATH/payload/Library/LaunchAgents"
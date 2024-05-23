#!/bin/bash
PROJECT_PATH="./"
BUILD_PATH="./Build"
APP_SUPPORT_PATH="${BUILD_PATH}/payload/Library/Application Support/SupportCompanion"
PUBLISH_OUTPUT_DIRECTORY="${PROJECT_PATH}/bin/Release/net8.0-macos/SupportCompanion.app/"
PUBLISH_OUTPUT_APP="${PROJECT_PATH}/bin/Release/net8.0-macos/SupportCompanion.app"
ICON_FILE="${PROJECT_PATH}/Assets/appicon.icns"
SUKIUI_LICENSE_FILE="${PROJECT_PATH}/SUKIUI_LICENSE"
UNINSTALL_SCRIPT="${PROJECT_PATH}/Assets/Uninstall.sh"

# is munkipkg installed?
munkipkg="$(munkipkg --version)"

if [ -z "$munkipkg" ]
then
  echo "munkipkg is not installed"
  exit 1
fi

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

if [ -d "$BUILD_PATH/payload/Applications/Utilities/SupportCompanion.app/" ]
then
  rm -rf "$BUILD_PATH/payload/Applications/Utilities/SupportCompanion.app/"
fi

dotnet publish --configuration Release -p:UseAppHost=true

rm -f "$PUBLISH_OUTPUT_DIRECTORY/Contents/Resources/suki_photo.ico"
cp "$ICON_FILE" "$PUBLISH_OUTPUT_DIRECTORY/Contents/Resources/"
cp "$UNINSTALL_SCRIPT" "$PUBLISH_OUTPUT_DIRECTORY/Contents/Resources/"
cp "$SUKIUI_LICENSE_FILE" "$PUBLISH_OUTPUT_DIRECTORY/Contents/Resources/"
chmod +x "$PUBLISH_OUTPUT_DIRECTORY/Contents/Resources/Uninstall.sh"
cp -a "${PROJECT_PATH}/Assets/scripts" "${BUILD_PATH}/payload/Library/Application Support/SupportCompanion/"

# mv each script file to remove the extension
SCRIPT_FILES="$(ls "${APP_SUPPORT_PATH}/scripts/")"
for SCRIPT_FILE in $SCRIPT_FILES
do
    FILE_WITHOUT_EXT=$(basename "$SCRIPT_FILE" .py)
    mv "$APP_SUPPORT_PATH/scripts/$SCRIPT_FILE" "$APP_SUPPORT_PATH/scripts/$FILE_WITHOUT_EXT"
    chmod +x "$APP_SUPPORT_PATH/scripts/$FILE_WITHOUT_EXT"
done

cp -a "$PUBLISH_OUTPUT_APP" "${BUILD_PATH}/payload/Applications/Utilities/"

munkipkg ./Build
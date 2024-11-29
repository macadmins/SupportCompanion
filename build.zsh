#!/bin/zsh

#  build.zsh
#  SupportCompanion
#
#  Created by Tobias Almén on 2024-11-26.
#

check_exit_code() {
    if [ "$1" != "0" ]; then
        echo "$2: $1" 1>&2
        exit 1
    fi
}


create_pkg() {

    local identifier="$1"
    local version="$2"
    local input_path="$3"
    local output_path="$4"
    local install_location="$5"
    
    pkgbuild --root "${input_path}/payload" \
        --scripts "${input_path}/scripts" \
        --install-location "${install_location}" \
        --identifier "${identifier}" \
        --version "${version}" \
        --sign "${SIGNING_IDENTITY}" \
        "${output_path}" >/dev/null 2>&1
        
    check_exit_code "$?" "Error creating pkg"
}

generate_dist_file() {
    local bundle_identifier="$1"
    local build_version="$2"
    local output_file="$3"
    local pkg_type="$4"
    local pkg_ref_path="SupportCompanion${pkg_type}-${build_version}.pkg"

    cat <<EOF > "$output_file"
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
  <title>${APP_NAME}</title>
  <options customize="never" require-scripts="false" hostArchitectures="x86_64,arm64"/>
  <volume-check>
    <allowed-os-versions>
        <os-version min="14"/>
    </allowed-os-versions>
  </volume-check>
  <choices-outline>
    <line choice="${bundle_identifier}"/>
  </choices-outline>
  <choice id="${bundle_identifier}" title="${APP_NAME}">
    <pkg-ref id="${bundle_identifier}"/>
  </choice>
  <pkg-ref id="${bundle_identifier}" version="${build_version}" onConclusion="none">
    ${pkg_ref_path}
  </pkg-ref>
</installer-gui-script>
EOF
}

run_product_build_sign() {
    
    local package_path="$1"
    local package="$2"
    
    productbuild --distribution "$DIST_FILE" \
        --package-path "${package_path}" \
        "${package}_dist.pkg"
        
    check_exit_code "$?" "Error running productbuild"

    # Sign package
    productsign --sign "${SIGNING_IDENTITY}" \
        "${package}_dist.pkg" \
        "${package}.pkg"
        
    check_exit_code "$?" "Error running productsign"
}

notarize_and_staple() {
    local pkg_path="$1"
    $XCODE_NOTARY_PATH submit "$pkg_path" --keychain-profile "${KEYCHAIN_PROFILE}" --wait
    check_exit_code "$?" "Error notarizing pkg"
    $XCODE_STAPLER_PATH staple "$pkg_path"
    check_exit_code "$?" "Error stapling pkg"
}

# Exit on error
set -e

CONFIGURATION="$1"
APP_NAME="SupportCompanion"
BUNDLE_IDENTIFIER="com.github.macadmins.SupportCompanion"
LA_BUNDLE_IDENTIFIER="com.github.macadmins.SupportCompanion.LaunchAgent"
LA_NAME="com.github.macadmins.SupportCompanion.agent.plist"
SUITE_BUNDLE_IDENTIFIER="com.github.macadmins.SupportCompanion.suite"
if [ "$CONFIGURATION" = "Debug" ]; then
    SIGNING_IDENTITY="Developer ID Installer: ANDERS TOBIAS ALMÉN (H92SB6Z7S4)"
    SIGNING_IDENTITY_APP="Developer ID Application: ANDERS TOBIAS ALMÉN (H92SB6Z7S4)"
    KEYCHAIN_PROFILE="AC-creds"
    XCODE_PATH="/Applications/Xcode.app"
elif [ "$CONFIGURATION" = "Release" ]; then
    SIGNING_IDENTITY_APP="Developer ID Application: Mac Admins Open Source (T4SK8ZXCXG)"
    SIGNING_IDENTITY="Developer ID Installer: Mac Admins Open Source (T4SK8ZXCXG)"
    KEYCHAIN_PROFILE="supportcompanion"
    XCODE_PATH="/Applications/Xcode_16.app"
else
    echo "No configuration set, exiting..."
    exit 1
fi
XCODE_NOTARY_PATH="$XCODE_PATH/Contents/Developer/usr/bin/notarytool"
XCODE_STAPLER_PATH="$XCODE_PATH/Contents/Developer/usr/bin/stapler"
XCODE_BUILD_PATH="$XCODE_PATH/Contents/Developer/usr/bin/xcodebuild"
TOOLSDIR=$(dirname $0)
BUILDSDIR="$TOOLSDIR/build"
PKGBUILDDIR="$BUILDSDIR/pkgbuild"
OUTPUTSDIR="$TOOLSDIR/outputs"
RELEASEDIR="$TOOLSDIR/release"
PKG_PATH="$TOOLSDIR/SupportCompanion/pkgbuild"
LA_PATH="$TOOLSDIR/SupportCompanion/LaunchAgent"
SCRIPTS="$PKG_PATH/scripts"
LA_SCRIPTS="$LA_PATH/scripts"
DIST_FILE="$BUILDSDIR/Distribution.xml"
CURRENT_SC_MAIN_BUILD_VERSION=$(/usr/libexec/PlistBuddy -c Print:CFBundleVersion $TOOLSDIR/SupportCompanion/Info.plist)
NEWSUBBUILD=$((80620 + $(git rev-parse HEAD~0 | xargs -I{} git rev-list --count {})))

# automate the build version bump
AUTOMATED_SC_BUILD="$CURRENT_SC_MAIN_BUILD_VERSION.$NEWSUBBUILD"

# Ensure Xcode is set to run-time
sudo xcode-select -s "$XCODE_PATH"

# Resolve package dependencies
$XCODE_BUILD_PATH -resolvePackageDependencies

# Setup notary item
$XCODE_NOTARY_PATH store-credentials --apple-id "opensource@macadmins.io" --team-id "T4SK8ZXCXG" --password "$2" supportcompanion

# Create release folder
if [ -e $RELEASEDIR ]; then
/bin/rm -rf $RELEASEDIR
fi
/bin/mkdir -p "$RELEASEDIR"

# Create build folder
if [ -e $BUILDSDIR ]; then
/bin/rm -rf $BUILDSDIR
fi
/bin/mkdir -p "$BUILDSDIR"

# build Support Companion
echo "=========== Building SupportCompanion $CONFIGURATION ==========="

echo "$AUTOMATED_SC_BUILD" > "$BUILDSDIR/build_info.txt"
echo "$CURRENT_SC_MAIN_BUILD_VERSION" > "$BUILDSDIR/build_info_main.txt"

$XCODE_BUILD_PATH clean archive -scheme SupportCompanion -project "$TOOLSDIR/SupportCompanion.xcodeproj" \
-configuration $CONFIGURATION \
CODE_SIGN_IDENTITY="$SIGNING_IDENTITY_APP" \
OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime --deep" \
-archivePath "$BUILDSDIR/SupportCompanion"

check_exit_code "$?" "Error running xcodebuild"

cp -r $PKG_PATH "$BUILDSDIR/pkgbuild"

# move the app to the payload folder
echo "Moving SupportCompanion.app to payload folder"
if [ -d "$PKGBUILDDIR/payload/Applications/SupportCompanion.app" ]; then
rm -r "$PKGBUILDDIR/payload/Applications/SupportCompanion.app"
fi

mkdir "$PKGBUILDDIR/payload/Applications"
cp -R "${BUILDSDIR}/SupportCompanion.xcarchive/Products/Applications/SupportCompanion.app" "$PKGBUILDDIR/payload/Applications/SupportCompanion.app"

# set the plist version to AUTOMATED_SC_BUILD
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $AUTOMATED_SC_BUILD" "$PKGBUILDDIR/payload/Applications/SupportCompanion.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $AUTOMATED_SC_BUILD" "$PKGBUILDDIR/payload/Applications/SupportCompanion.app/Contents/Info.plist"

codesign --force --options runtime --deep --timestamp --sign $SIGNING_IDENTITY_APP "$PKGBUILDDIR/payload/Applications/SupportCompanion.app"

# Build and export pkg
create_pkg $BUNDLE_IDENTIFIER $AUTOMATED_SC_BUILD $PKGBUILDDIR "${BUILDSDIR}/SupportCompanion-${AUTOMATED_SC_BUILD}.pkg" "/"
    
generate_dist_file $BUNDLE_IDENTIFIER $AUTOMATED_SC_BUILD $DIST_FILE

run_product_build_sign $BUILDSDIR "${BUILDSDIR}/${APP_NAME}-${AUTOMATED_SC_BUILD}"

notarize_and_staple "${BUILDSDIR}/${APP_NAME}-${AUTOMATED_SC_BUILD}.pkg"

cp "${BUILDSDIR}/${APP_NAME}-${AUTOMATED_SC_BUILD}.pkg" "${RELEASEDIR}/${APP_NAME}-${AUTOMATED_SC_BUILD}.pkg"

echo "Build complete: ${RELEASEDIR}/${APP_NAME}-${AUTOMATED_SC_BUILD}.pkg"

rm -f $DIST_FILE
rm -r $PKGBUILDDIR

echo "=========== Building LaunchAgent ==========="
cp -r $LA_PATH "$BUILDSDIR/pkgbuild"

LA_VERSION="1.0.0"

create_pkg $LA_BUNDLE_IDENTIFIER $LA_VERSION $PKGBUILDDIR "${BUILDSDIR}/${APP_NAME}_LaunchAgent-${LA_VERSION}.pkg" "/Library/LaunchAgents"
    
generate_dist_file $LA_BUNDLE_IDENTIFIER $LA_VERSION $DIST_FILE "_LaunchAgent"

run_product_build_sign $BUILDSDIR "${BUILDSDIR}/${APP_NAME}_LaunchAgent-${LA_VERSION}"

notarize_and_staple "${BUILDSDIR}/${APP_NAME}_LaunchAgent-${LA_VERSION}.pkg"

cp "${BUILDSDIR}/${APP_NAME}_LaunchAgent-${LA_VERSION}.pkg" "${RELEASEDIR}/${APP_NAME}_LaunchAgent-${LA_VERSION}.pkg"

echo "Build complete: ${RELEASEDIR}/${APP_NAME}_LaunchAgent-${LA_VERSION}.pkg"

rm -f $DIST_FILE
rm -r $PKGBUILDDIR

echo "=========== Building suite ==========="
cp -r $PKG_PATH "$BUILDSDIR/pkgbuild"

echo "Moving SupportCompanion.app to payload folder"
if [ -d "$PKGBUILDDIR/payload/Applications/SupportCompanion.app" ]; then
rm -r "$PKGBUILDDIR/payload/Applications/SupportCompanion.app"
fi

mkdir "$PKGBUILDDIR/payload/Applications"
cp -R "${BUILDSDIR}/SupportCompanion.xcarchive/Products/Applications/SupportCompanion.app" "$PKGBUILDDIR/payload/Applications/SupportCompanion.app"

# set the plist version to AUTOMATED_SC_BUILD
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $AUTOMATED_SC_BUILD" "$PKGBUILDDIR/payload/Applications/SupportCompanion.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $AUTOMATED_SC_BUILD" "$PKGBUILDDIR/payload/Applications/SupportCompanion.app/Contents/Info.plist"

codesign --force --options runtime --deep --timestamp --sign $SIGNING_IDENTITY_APP "$PKGBUILDDIR/payload/Applications/SupportCompanion.app"
cp -r $PKG_PATH "$BUILDSDIR/pkgbuild"

mkdir "$PKGBUILDDIR/payload/Library/LaunchAgents"
cp "$LA_PATH/payload/$LA_NAME" "$PKGBUILDDIR/payload/Library/LaunchAgents/$LA_NAME"

check_exit_code "$?" "Error copying launch agent"

create_pkg $BUNDLE_IDENTIFIER $AUTOMATED_SC_BUILD $PKGBUILDDIR "${BUILDSDIR}/SupportCompanion_suite-${AUTOMATED_SC_BUILD}.pkg" "/"
    
generate_dist_file $BUNDLE_IDENTIFIER $AUTOMATED_SC_BUILD $DIST_FILE "_suite"

run_product_build_sign $BUILDSDIR "${BUILDSDIR}/${APP_NAME}_Suite-${AUTOMATED_SC_BUILD}"

notarize_and_staple "${BUILDSDIR}/${APP_NAME}_Suite-${AUTOMATED_SC_BUILD}.pkg"

cp "${BUILDSDIR}/${APP_NAME}_suite-${AUTOMATED_SC_BUILD}.pkg" "${RELEASEDIR}/${APP_NAME}_suite-${AUTOMATED_SC_BUILD}.pkg"

echo "Build complete: ${RELEASEDIR}/${APP_NAME}_Suite-${AUTOMATED_SC_BUILD}.pkg"

rm -f $DIST_FILE

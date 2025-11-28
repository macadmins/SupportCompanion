#!/bin/zsh

#  helper_install.zsh
#  SupportCompanion
#
#  Created by Tobias Almén on 2024-11-26.
#

privileged_helper_tool="/Library/PrivilegedHelperTools/com.github.macadmins.SupportCompanion.helper"
install_location="/Applications/SupportCompanion.app"
launch_daemon="com.github.macadmins.SupportCompanion.helper"

# Create "/Library/PrivilegedHelperTools/" if not present
if [[ ! -d "/Library/PrivilegedHelperTools/" ]]; then
  mkdir "/Library/PrivilegedHelperTools/"
fi

# Copy the PrivilegedHelperTool
cp "${install_location}/Contents/Library/LaunchDaemons/${launch_daemon}" "/Library/PrivilegedHelperTools/"
# Set permissions
chown root:wheel "${privileged_helper_tool}"
chmod 544 "${privileged_helper_tool}"

chown root:wheel "/Library/LaunchDaemons/${launch_daemon}.plist"
chmod 644 "/Library/LaunchDaemons/${launch_daemon}.plist"

# Unload the LaunchDaemon
if launchctl print "system/${launch_daemon}" &> /dev/null ; then
  launchctl unload "/Library/LaunchDaemons/${launch_daemon}.plist"
fi

# Load the LaunchDaemon
if ! launchctl print "system/${launch_daemon}" &> /dev/null ; then
  launchctl load -w "/Library/LaunchDaemons/${launch_daemon}.plist"
fi

exit 0

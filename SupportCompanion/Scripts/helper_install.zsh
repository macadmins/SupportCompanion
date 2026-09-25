#!/bin/zsh

#  helper_install.zsh
#  SupportCompanion
#
#  Created by Tobias Almén on 2024-11-26.
#

privileged_helper_tool="/Library/PrivilegedHelperTools/com.github.macadmins.SupportCompanion.helper"
install_location="/Applications/SupportCompanion.app"
launch_daemon="com.github.macadmins.SupportCompanion.helper"

# An organisation can deploy the helper declaratively instead, with
# com.apple.configuration.services.background-tasks, which puts both the executable and its launchd
# job in a managed directory the OS re-asserts. Installing our own copy as well would leave two
# daemons claiming the same Mach service, so this skips the whole helper install.
#
# Read only from a DEVICE-scoped configuration profile, which is the single source the app and the
# helper trust for anything privileged. A user-scoped profile is no good here either: it lands under
# a per-user directory that an installer script has no reliable way to resolve.
#
# /Library/Preferences is deliberately not consulted, for the reason HelperPreferences gives: only
# root can write it, and that is the problem. Setting this key removes the helper and its launchd
# job, so honouring it from a root-writable file would let one root moment disable the component
# that demotes elevated users, and every later package install would keep it disabled.
skip_helper_install=false
managed_domain="/Library/Managed Preferences/com.github.macadmins.SupportCompanion"
if [[ -f "${managed_domain}.plist" ]]; then
  value=$(/usr/bin/defaults read "$managed_domain" SkipHelperInstall 2>/dev/null)
  [[ "$value" == "1" ]] && skip_helper_install=true
fi

# Say when the key is being ignored because of where it lives, rather than silently installing the
# helper anyway and leaving two daemons claiming the same Mach service.
if [[ "$skip_helper_install" == "false" ]] \
  && [[ -f "/Library/Preferences/com.github.macadmins.SupportCompanion.plist" ]] \
  && [[ -n "$(/usr/bin/defaults read /Library/Preferences/com.github.macadmins.SupportCompanion SkipHelperInstall 2>/dev/null)" ]]
then
  echo "Ignoring SkipHelperInstall in /Library/Preferences: it is only read from a device-scoped configuration profile. Deliver it through your MDM."
fi

if [[ "$skip_helper_install" == "true" ]]; then
  echo "SkipHelperInstall is set; leaving the helper to the declarative configuration."
  # The package payload writes this plist before any script runs, so it has to be removed rather
  # than skipped, or it will compete with the declaratively deployed job.
  /bin/rm -f "/Library/LaunchDaemons/${launch_daemon}.plist"
  /bin/rm -f "${privileged_helper_tool}"
  exit 0
fi

# Create "/Library/PrivilegedHelperTools/" if not present
if [[ ! -d "/Library/PrivilegedHelperTools/" ]]; then
  mkdir -p "/Library/PrivilegedHelperTools/"
fi

# Stop the running helper before replacing it.
#
# The app and the helper speak a versioned XPC interface, and the helper refuses clients older than
# it supports. A new app left talking to an old helper is therefore broken rather than merely stale:
# every privileged operation fails. Unloading first means the load at the end starts the executable
# written below, and not whatever was already running.
if launchctl print "system/${launch_daemon}" &> /dev/null ; then
  launchctl bootout "system/${launch_daemon}" &> /dev/null \
    || launchctl unload "/Library/LaunchDaemons/${launch_daemon}.plist" &> /dev/null
fi

# Remove before copying: unlink always succeeds, while writing over a file another process still
# holds open is not guaranteed to on every filesystem.
/bin/rm -f "${privileged_helper_tool}"

if ! cp "${install_location}/Contents/Library/LaunchDaemons/${launch_daemon}" "${privileged_helper_tool}" ; then
  echo "Failed to copy the privileged helper into ${privileged_helper_tool}" >&2
  exit 1
fi

# Set permissions
chown root:wheel "${privileged_helper_tool}"
chmod 544 "${privileged_helper_tool}"

chown root:wheel "/Library/LaunchDaemons/${launch_daemon}.plist"
chmod 644 "/Library/LaunchDaemons/${launch_daemon}.plist"

# Load unconditionally rather than only when it looks unloaded. Skipping this because the job still
# appears registered is how an install quietly finishes with the previous helper still running.
launchctl load -w "/Library/LaunchDaemons/${launch_daemon}.plist" &> /dev/null

if ! launchctl print "system/${launch_daemon}" &> /dev/null ; then
  echo "The privileged helper did not load after installation" >&2
  exit 1
fi

exit 0

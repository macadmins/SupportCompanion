#!/bin/zsh
#
# Build the two assets needed to deploy the privileged helper with
# com.apple.configuration.services.background-tasks.
#
# Usage: ./make_ddm_assets.zsh <path to SupportCompanion.app> [TaskType] [output dir]
#
# Produces, in the output directory:
#   helper.zip                 the executable asset (ExecutableAssetReference)
#   <label>.plist              the launchd job (LaunchdConfigurations → FileAssetReference)
#   declarations.json          the three declarations, with hashes and sizes filled in
#
# Settings, including EnforceAdminAllowlist and PermanentAdmins, come from the ordinary
# configuration profile, not from here.
#
# Host helper.zip and the plist over https, put their URLs into declarations.json, and load the
# declarations into your MDM.

set -e

APP="${1:?Usage: make_ddm_assets.zsh <path to SupportCompanion.app> [TaskType] [output dir]}"
TASK_TYPE="${2:-com.github.macadmins.SupportCompanion}"
OUT="${3:-./ddm-assets}"

LABEL="com.github.macadmins.SupportCompanion.helper"
HELPER_SRC="${APP}/Contents/Library/LaunchDaemons/${LABEL}"

# The background-tasks configuration extracts the zip into this directory, so the launchd job has to
# point at the executable inside it rather than at /Library/PrivilegedHelperTools.
MANAGED_DIR="/var/db/ManagedConfigurationFiles/BackgroundTaskServices/Services/${TASK_TYPE}"

if [[ ! -f "$HELPER_SRC" ]]; then
  print -u2 "Helper executable not found at $HELPER_SRC"
  exit 1
fi

/bin/rm -rf "$OUT"
/bin/mkdir -p "$OUT/staging"

/bin/cp "$HELPER_SRC" "$OUT/staging/${LABEL}"
/bin/chmod 544 "$OUT/staging/${LABEL}"


# Keep the signature intact: the helper must still validate, and -X keeps the zip free of the
# resource-fork and finder-info entries that would otherwise be added.
( cd "$OUT/staging" && /usr/bin/zip -qrX "../helper.zip" "${LABEL}" )
/bin/rm -rf "$OUT/staging"

/bin/cat > "$OUT/${LABEL}.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${MANAGED_DIR}/${LABEL}</string>
    </array>
    <key>MachServices</key>
    <dict>
        <key>${LABEL}</key>
        <true/>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>Disabled</key>
    <false/>
    <!-- Deliberately no KeepAlive. The device kills and restarts the task itself when the
         configuration updates, and launchd relaunching it in the middle of that has been seen to
         fail the re-registration with "Operation already in progress". MachServices still gives
         on-demand launch, and RunAtLoad covers boot. The packaged LaunchDaemon keeps KeepAlive,
         because there nothing else would restart the helper. -->
</dict>
</plist>
PLIST

/usr/bin/plutil -lint "$OUT/${LABEL}.plist" > /dev/null

hash_of() { /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}' }
size_of() { /usr/bin/stat -f%z "$1" }

ZIP_HASH=$(hash_of "$OUT/helper.zip")
ZIP_SIZE=$(size_of "$OUT/helper.zip")
PLIST_HASH=$(hash_of "$OUT/${LABEL}.plist")
PLIST_SIZE=$(size_of "$OUT/${LABEL}.plist")

/bin/cat > "$OUT/declarations.json" <<JSON
{
  "_comment": "Replace every REPLACE_WITH_HTTPS_URL before loading these into your MDM.",
  "assets": [
    {
      "Type": "com.apple.asset.data",
      "Identifier": "${TASK_TYPE}.helper.executable",
      "ServerToken": "1",
      "Payload": {
        "Reference": {
          "DataURL": "REPLACE_WITH_HTTPS_URL/helper.zip",
          "ContentType": "application/zip",
          "Size": ${ZIP_SIZE},
          "Hash-SHA-256": "${ZIP_HASH}"
        }
      }
    },
    {
      "Type": "com.apple.asset.data",
      "Identifier": "${TASK_TYPE}.helper.launchd",
      "ServerToken": "1",
      "Payload": {
        "Reference": {
          "DataURL": "REPLACE_WITH_HTTPS_URL/${LABEL}.plist",
          "ContentType": "application/xml",
          "Size": ${PLIST_SIZE},
          "Hash-SHA-256": "${PLIST_HASH}"
        }
      }
    }
  ],
  "configurations": [
    {
      "Type": "com.apple.configuration.services.background-tasks",
      "Identifier": "${TASK_TYPE}.helper",
      "ServerToken": "1",
      "Payload": {
        "TaskType": "${TASK_TYPE}",
        "TaskDescription": "Support Companion privileged helper",
        "ExecutableAssetReference": "${TASK_TYPE}.helper.executable",
        "LaunchdConfigurations": [
          {
            "FileAssetReference": "${TASK_TYPE}.helper.launchd",
            "Context": "daemon"
          }
        ]
      }
    }
  ]
}
JSON

print "Wrote:"
print "  $OUT/helper.zip              sha256 $ZIP_HASH  (${ZIP_SIZE} bytes)"
print "  $OUT/${LABEL}.plist          sha256 $PLIST_HASH  (${PLIST_SIZE} bytes)"
print "  $OUT/declarations.json"
print ""
print ""
print "The job will run: ${MANAGED_DIR}/${LABEL}"
print "Set SkipHelperInstall=true in a DEVICE-scoped profile before installing the package."

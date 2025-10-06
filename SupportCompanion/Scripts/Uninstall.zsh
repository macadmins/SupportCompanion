#!/bin/zsh

set -u  # error on unset vars

# --- helpers ---------------------------------------------------------------
log() { print -- "[uninstall] $*" }
warn() { print -- "[warn] $*" >&2 }
err() { print -- "[error] $*" >&2 }

# run a command, ignore if it fails; print message
_try() {
  local desc="$1"; shift
  if "$@"; then
    log "$desc: ok"
  else
    warn "$desc: skipped/failed"
  fi
}

# delete a file/dir if it exists
_rm_if_exists() {
  local path="$1"
  if [ -e "$path" ] || [ -L "$path" ]; then
    /bin/rm -rf -- "$path" && log "removed: $path" || warn "failed to remove: $path"
  else
    log "not present: $path"
  fi
}

# get console user + uid
get_console_user() {
  /usr/sbin/scutil <<< "show State:/Users/ConsoleUser" \
    | /usr/bin/awk '/Name :/ && $3 != "loginwindow" { print $3 }'
}
get_console_uid() {
  /usr/sbin/scutil <<< "show State:/Users/ConsoleUser" \
    | /usr/bin/awk '/kCGSSessionUserIDKey/ {print $NF; exit}'
}

# --- preflight -------------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
  err "Please run this script as root or using sudo"
  exit 1
fi

APP_ID="com.github.macadmins.SupportCompanion"
HELPER_ID="com.github.macadmins.SupportCompanion.helper"
AGENT_ID="com.github.macadmins.SupportCompanion.agent"

APP_PATH="/Applications/SupportCompanion.app"
HELPER_PATH="/Library/PrivilegedHelperTools/${HELPER_ID}"
DAEMON_PLIST="/Library/LaunchDaemons/${HELPER_ID}.plist"
AGENT_PLIST="/Library/LaunchAgents/${AGENT_ID}.plist"

CONSOLE_USER=$(get_console_user || true)
CONSOLE_UID=$(get_console_uid || true)

log "Console user: ${CONSOLE_USER:-unknown} (uid ${CONSOLE_UID:-n/a})"

# --- stop processes --------------------------------------------------------
log "Stopping application and helper if running"
_try "kill app" pkill -f SupportCompanion

# --- defaults cleanup (non-fatal) -----------------------------------------
if [ -n "${CONSOLE_USER:-}" ]; then
  # Only attempt if domain exists to avoid noisy errors
  if sudo -u "$CONSOLE_USER" /usr/bin/defaults domains | /usr/bin/grep -q -- "$APP_ID"; then
    _try "delete user defaults" sudo -u "$CONSOLE_USER" /usr/bin/defaults delete "$APP_ID"
  else
    log "user defaults domain not present: $APP_ID"
  fi
else
  warn "No console user detected; skipping user defaults removal"
fi

# --- launchd: daemon (helper) ---------------------------------------------
if [ -f "$DAEMON_PLIST" ]; then
  log "Unloading helper launch daemon"
  _try "launchctl unload daemon" /bin/launchctl unload -w "$DAEMON_PLIST"
else
  log "daemon plist not present: $DAEMON_PLIST"
fi

# Remove daemon plist regardless of unload outcome
_rm_if_exists "$DAEMON_PLIST"

# --- launchd: agent (per-user) --------------------------------------------
if [ -f "$AGENT_PLIST" ]; then
  if [ -n "${CONSOLE_UID:-}" ]; then
    log "Unloading launch agent for uid $CONSOLE_UID"
    _try "launchctl unload agent" /bin/launchctl asuser "$CONSOLE_UID" /bin/launchctl unload -w "$AGENT_PLIST"
  else
    warn "No console uid; unloading agent in current context"
    _try "launchctl unload agent (fallback)" /bin/launchctl unload -w "$AGENT_PLIST"
  fi
else
  log "agent plist not present: $AGENT_PLIST"
fi

# Remove agent plist
_rm_if_exists "$AGENT_PLIST"

# --- remove bits -----------------------------------------------------------
log "Removing installed components"
_rm_if_exists "$APP_PATH"
_rm_if_exists "$HELPER_PATH"

# --- pkg receipts -------------------------------------------
forget_if_present() {
  local package="$1"
  if /usr/sbin/pkgutil --pkgs | /usr/bin/grep -qx -- "$package"; then
    _try "forget $package" /usr/sbin/pkgutil --forget "$package"
  else
    log "receipt not present: $package"
  fi
}

forget_if_present "${APP_ID}"
forget_if_present "${APP_ID}.LaunchAgent"
forget_if_present "${APP_ID}.suite"

log "Uninstall completed"
exit 0

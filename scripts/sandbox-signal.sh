#!/usr/bin/env bash
# sandbox-signal.sh — Send a signal to the running sandbox agent.
#
# Usage:
#   scripts/sandbox-signal.sh compact   # compress context
#   scripts/sandbox-signal.sh clear     # clear context + re-prompt
#
# Can be run from the HOST or from INSIDE THE SANDBOX — the tmp/ directory
# is bind-mounted into the sandbox, so both sides share the same signal file.
# The managed-sandbox.sh watcher (runs on host) picks this up and injects
# the corresponding command via tmux send-keys.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SIGNAL_FILE="$PROJECT_DIR/tmp/sandbox-signal"

usage() {
  echo "Usage: $0 <compact|clear|exit|restart>"
  exit 1
}

[ $# -eq 1 ] || usage

case "$1" in
  compact|clear|exit|restart)
    mkdir -p "$PROJECT_DIR/tmp"
    echo "$1" > "$SIGNAL_FILE"
    echo "Signal '$1' sent -> $SIGNAL_FILE"
    ;;
  *)
    usage
    ;;
esac

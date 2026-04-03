#!/usr/bin/env bash
# sandbox.sh — Runs the Claude sandbox with:
#   1. OOM-kill restart with debug logging
#   2. Signal file watcher: agent/user can request /compact or /clear
#
# Usage:
#   scripts/sandbox.sh                    # default prompt
#   scripts/sandbox.sh -- "Custom prompt" # custom prompt
#
# Signal (from host or inside sandbox):
#   scripts/sandbox-signal.sh compact
#   scripts/sandbox-signal.sh clear
#
# Runs autopush.sh in the background automatically.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SIGNAL_FILE="$PROJECT_DIR/tmp/sandbox-signal"
LOG_FILE="$PROJECT_DIR/tmp/managed-sandbox.log"
POLL_INTERVAL=3
MAX_RETRIES=10
RESTART_COOLDOWN=5

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log() {
  local msg
  msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo "$msg"
  echo "$msg" >> "$LOG_FILE"
}

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
mkdir -p "$PROJECT_DIR/tmp"
: > "$LOG_FILE"
rm -f "$SIGNAL_FILE"

log "managed-sandbox starting"
log "  project: $PROJECT_DIR"
log "  signal:  $SIGNAL_FILE"
log "  log:     $LOG_FILE"

# ---------------------------------------------------------------------------
# Autopush (background)
# ---------------------------------------------------------------------------
AUTOPUSH_PID=""

start_autopush() {
  if [ -f "$SCRIPT_DIR/autopush.sh" ]; then
    # autopush uses `read -t` which needs stdin; give it /dev/null
    "$SCRIPT_DIR/autopush.sh" < /dev/null >> "$LOG_FILE" 2>&1 &
    AUTOPUSH_PID=$!
    log "autopush started (pid $AUTOPUSH_PID)"
  fi
}

stop_autopush() {
  if [ -n "$AUTOPUSH_PID" ] && kill -0 "$AUTOPUSH_PID" 2>/dev/null; then
    kill "$AUTOPUSH_PID" 2>/dev/null || true
    wait "$AUTOPUSH_PID" 2>/dev/null || true
    log "autopush stopped"
  fi
}

# ---------------------------------------------------------------------------
# Signal watcher — runs in background, injects into the tmux pane
# ---------------------------------------------------------------------------
WATCHER_PID=""
SANDBOX_PANE=""

find_sandbox_pane() {
  # Find the pane running this script (which is also where docker sandbox runs)
  # In iTerm2+tmux integration, the active pane is where we are
  SANDBOX_PANE="$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)"

  if [ -z "$SANDBOX_PANE" ]; then
    log "WARNING: not running in tmux, signal watcher disabled"
    return 1
  fi
  log "tmux pane: $SANDBOX_PANE"
  return 0
}

signal_watcher() {
  local pane="$1"
  while true; do
    if [ -f "$SIGNAL_FILE" ]; then
      local cmd
      cmd="$(cat "$SIGNAL_FILE" 2>/dev/null | tr -d '[:space:]')"
      rm -f "$SIGNAL_FILE"

      case "$cmd" in
        compact)
          log "SIGNAL: compact"
          tmux send-keys -t "$pane" '/compact' Enter
          ;;
        clear)
          log "SIGNAL: clear → /clear + re-prompt"
          tmux send-keys -t "$pane" '/clear' Enter
          sleep 3
          tmux send-keys -t "$pane" 'Stelle sicher, dass die loops aus @LOOPS.md korrekt scheduled sind' Enter
          ;;
        exit)
          log "SIGNAL: exit → /exit"
          tmux send-keys -t "$pane" '/exit' Enter
          ;;
        restart)
          log "SIGNAL: restart → /exit + re-create signal for main loop"
          echo "restart" > "$SIGNAL_FILE"
          tmux send-keys -t "$pane" '/exit' Enter
          ;;
        *)
          log "SIGNAL: unknown '$cmd'"
          ;;
      esac
    fi
    sleep "$POLL_INTERVAL"
  done
}

start_watcher() {
  if find_sandbox_pane; then
    signal_watcher "$SANDBOX_PANE" &
    WATCHER_PID=$!
    log "signal watcher started (pid $WATCHER_PID)"
  fi
}

stop_watcher() {
  if [ -n "$WATCHER_PID" ] && kill -0 "$WATCHER_PID" 2>/dev/null; then
    kill "$WATCHER_PID" 2>/dev/null || true
    wait "$WATCHER_PID" 2>/dev/null || true
    log "signal watcher stopped"
  fi
}

# ---------------------------------------------------------------------------
# Cleanup on exit
# ---------------------------------------------------------------------------
cleanup() {
  log "shutting down..."
  stop_watcher
  stop_autopush
  rm -f "$SIGNAL_FILE"
  log "bye"
}
trap cleanup EXIT INT TERM

# ---------------------------------------------------------------------------
# Main loop — run sandbox with OOM restart
# ---------------------------------------------------------------------------
start_autopush
start_watcher

attempt=0

while true; do
  attempt=$((attempt + 1))
  log "--- sandbox run #$attempt ---"

  # Capture start time for uptime logging
  run_start="$(date +%s)"

  # Run sandbox (foreground — user interacts here)
  set +e
  if [ $# -gt 0 ]; then
    docker sandbox run claude "$@"
  else
    docker sandbox run claude -- "Starte alle Loops aus @LOOPS.md"
  fi
  exit_code=$?
  set -e

  run_end="$(date +%s)"
  run_duration=$(( run_end - run_start ))
  run_minutes=$(( run_duration / 60 ))
  run_seconds=$(( run_duration % 60 ))

  log "sandbox exited: code=$exit_code, uptime=${run_minutes}m${run_seconds}s"

  # Normal exit — unless restart was requested
  if [ $exit_code -eq 0 ]; then
    if [ -f "$SIGNAL_FILE" ] && grep -q "restart" "$SIGNAL_FILE" 2>/dev/null; then
      rm -f "$SIGNAL_FILE"
      log "restart requested, re-launching..."
      attempt=0
      sleep "$RESTART_COOLDOWN"
      continue
    fi
    log "clean exit, done"
    exit 0
  fi

  # OOM-kill: 137 = SIGKILL, 139 = SIGSEGV
  # Docker sandbox may wrap OOM-kills as exit 1, so also restart exit 1
  # when uptime was long (>60s) — short-lived exit 1 = startup error.
  MIN_UPTIME_FOR_RESTART=60
  is_oom=false
  is_long_running_crash=false

  if [ $exit_code -eq 137 ] || [ $exit_code -eq 139 ]; then
    is_oom=true
  elif [ $exit_code -eq 1 ] && [ $run_duration -ge $MIN_UPTIME_FOR_RESTART ]; then
    is_long_running_crash=true
  fi

  if $is_oom || $is_long_running_crash; then
    if $is_oom; then
      log "OOM-KILL detected (exit $exit_code)"
    else
      log "long-running crash detected (exit $exit_code, uptime ${run_minutes}m${run_seconds}s) — likely OOM wrapped by docker"
    fi
    log "  system memory at crash:"
    # Log memory info for debugging
    if command -v vm_stat &>/dev/null; then
      vm_stat | head -5 >> "$LOG_FILE" 2>/dev/null
    elif command -v free &>/dev/null; then
      free -h >> "$LOG_FILE" 2>/dev/null
    fi
    # Log docker memory
    docker stats --no-stream --format "  docker: {{.Name}} {{.MemUsage}}" >> "$LOG_FILE" 2>/dev/null || true

    if [ $attempt -ge $MAX_RETRIES ]; then
      log "GIVING UP after $attempt attempts"
      exit $exit_code
    fi

    log "restarting in ${RESTART_COOLDOWN}s... (attempt $((attempt))/$MAX_RETRIES)"
    sleep "$RESTART_COOLDOWN"
    continue
  fi

  # Other non-zero exit: don't retry
  log "non-OOM failure (exit $exit_code), not restarting"
  exit $exit_code
done

#!/usr/bin/env bash
# Manage a headless Godot editor running as a background process.
set -eu

PID_FILE=.godot/headless.pid
LOG_FILE=.godot/headless.log

start() {
    mkdir -p .godot
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "Headless Godot already running (PID $(cat "$PID_FILE"))"
        return 0
    fi
    nohup "$GODOT_BIN" --headless --editor --path . > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    echo "Started headless Godot (PID $!), log: $LOG_FILE"
}

stop() {
    [ -f "$PID_FILE" ] || { echo "No background Godot recorded."; return 0; }
    pid=$(cat "$PID_FILE")
    # Git Bash PIDs differ from Windows PIDs, so fall back to taskkill.
    kill "$pid" 2>/dev/null || taskkill //F //PID "$pid" >/dev/null 2>&1 || true
    rm -f "$PID_FILE"
    echo "Stopped headless Godot (PID $pid)"
}

case "${1:-}" in
    start) start ;;
    stop) stop ;;
    log) tail -f "$LOG_FILE" ;;
    *) echo "Usage: $0 {start|stop|log}" >&2; exit 1 ;;
esac

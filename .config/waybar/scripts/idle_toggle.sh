#!/usr/bin/env bash
set -euo pipefail

IDLE_CMD=(swayidle -w \
    timeout 300 "gtklock -s" \
    before-sleep "gtklock -s")

command -v swayidle >/dev/null 2>&1 || { echo "swayidle not found" >&2; exit 1; }
command -v gtklock >/dev/null 2>&1 || { echo "gtklock not found" >&2; exit 1; }

is_running() {
    pgrep -x swayidle >/dev/null 2>&1
}

start_idle() {
    if ! is_running; then
        setsid -f "${IDLE_CMD[@]}" >/dev/null 2>&1
    fi
}

stop_idle() {
    if is_running; then
        pkill -x swayidle
    fi
}

print_status() {
    if is_running; then
        printf '{"text":"󰒲","tooltip":"Idle timers active","class":"active"}'
    else
        printf '{"text":"󰅶","tooltip":"Keep Awake enabled","class":"inhibited"}'
    fi
}

case "${1:-status}" in
    status)
        print_status
        ;;
    toggle)
        if is_running; then
            stop_idle
        else
            start_idle
        fi
        sleep 0.1
        print_status
        ;;
    enable)
        start_idle
        ;;
    disable)
        stop_idle
        ;;
    *)
        echo "Usage: $0 [status|toggle|enable|disable]" >&2
        exit 1
        ;;
 esac

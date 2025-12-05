#!/usr/bin/env bash
set -euo pipefail

LOCK_CMD="gtklock -s"
if ! command -v gtklock >/dev/null 2>&1; then
    if command -v loginctl >/dev/null 2>&1; then
        LOCK_CMD="loginctl lock-session"
    else
        echo "gtklock not found and no loginctl fallback available" >&2
        exit 1
    fi
fi

LOCK_TIMEOUT=300
DPMS_TIMEOUT=420

IDLE_CMD=(swayidle -w \
    timeout "$LOCK_TIMEOUT" "$LOCK_CMD" \
    timeout "$DPMS_TIMEOUT" "niri msg action power-off-monitors" \
    resume "niri msg action power-on-monitors" \
    before-sleep "$LOCK_CMD")
IDLE_UNIT="niri-swayidle"

command -v swayidle >/dev/null 2>&1 || { echo "swayidle not found" >&2; exit 1; }

has_user_systemd() {
    command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1
}

is_running() {
    if has_user_systemd; then
        systemctl --user is-active --quiet "$IDLE_UNIT"
    else
        pgrep -x swayidle >/dev/null 2>&1
    fi
}

start_idle() {
    if is_running; then
        return
    fi

    if has_user_systemd; then
        local env_args=()
        [[ -n ${WAYLAND_DISPLAY:-} ]] && env_args+=(--setenv=WAYLAND_DISPLAY="$WAYLAND_DISPLAY")
        [[ -n ${XDG_RUNTIME_DIR:-} ]] && env_args+=(--setenv=XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR")
        [[ -n ${DBUS_SESSION_BUS_ADDRESS:-} ]] && env_args+=(--setenv=DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS")
        env_args+=(--setenv=PATH="$PATH")

        systemd-run --user --quiet --unit "$IDLE_UNIT" --description "Niri swayidle locker" \
          "${env_args[@]}" "${IDLE_CMD[@]}" >/dev/null 2>&1 || \
          setsid -f "${IDLE_CMD[@]}" >/dev/null 2>&1
    else
        setsid -f "${IDLE_CMD[@]}" >/dev/null 2>&1
    fi
}

stop_idle() {
    if ! is_running; then
        return
    fi
    if has_user_systemd; then
        systemctl --user stop "$IDLE_UNIT" >/dev/null 2>&1 || true
    fi
    pkill -x swayidle >/dev/null 2>&1 || true
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

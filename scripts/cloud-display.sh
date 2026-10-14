#!/bin/sh
set -eu

# The onboarding snapshot retains this locally installed, verified Xvfb.
xvfb_root=/workspace/.runtime/xvfb
export DISPLAY=:99
export XAUTHORITY="$xvfb_root/Xauthority"
if xdpyinfo >/dev/null 2>&1; then
    exit 0
fi
if [ ! -x "$xvfb_root/root/usr/bin/Xvfb" ] || [ ! -f "$XAUTHORITY" ]; then
    printf 'Display virtual ausente; use um display local ou prepare Xvfb.\n' >&2
    exit 1
fi
# Cloud tasks can have a different IPC namespace from the retained display.
# Ordinary X11 transport also supports window resizing in that environment.
"$xvfb_root/root/usr/bin/Xvfb" :99 -screen 0 1440x960x24 -auth "$XAUTHORITY" -nolisten tcp -extension MIT-SHM >"$xvfb_root/xvfb.log" 2>&1 &
display_pid=$!
for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if xdpyinfo >/dev/null 2>&1; then
        printf '%s\n' "$display_pid" >"$xvfb_root/pid"
        exit 0
    fi
    sleep 0.2
done
kill "$display_pid" 2>/dev/null || true
printf 'Xvfb não iniciou; consulte %s/xvfb.log\n' "$xvfb_root" >&2
exit 1

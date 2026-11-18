#!/usr/bin/env bash
set -e

MODE="${1:-mt4}"

export DISPLAY=:99
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# Clean up any stale X lock files on container restart
rm -f /tmp/.X99-lock /tmp/.X11-unix/X99

# Start virtual X server and VNC server in the background
Xvfb :99 -screen 0 1280x800x24 &
sleep 2
x11vnc -display :99 -forever -nopw -listen 0.0.0.0 -rfbport 5900 &

case "$MODE" in
  mt4)
    MT4_EXE=$(find "$WINEPREFIX/drive_c" -iname "terminal.exe" 2>/dev/null | head -n 1)
    if [ -z "$MT4_EXE" ]; then
      echo "Error: MetaTrader 4 (terminal.exe) not found in $WINEPREFIX/drive_c"
      exit 1
    fi
    echo "Starting MetaTrader 4: $MT4_EXE"
    exec wine "$MT4_EXE" /portable
    ;;
  mt5)
    MT5_EXE=$(find "$WINEPREFIX/drive_c" -iname "terminal64.exe" 2>/dev/null | head -n 1)
    if [ -z "$MT5_EXE" ]; then
      echo "Error: MetaTrader 5 (terminal64.exe) not found in $WINEPREFIX/drive_c"
      exit 1
    fi
    echo "Starting MetaTrader 5: $MT5_EXE"
    exec wine "$MT5_EXE" /portable
    ;;
  *)
    echo "Error: Invalid argument '$MODE'. Usage: docker run <image> [mt4|mt5]"
    exit 1
    ;;
esac

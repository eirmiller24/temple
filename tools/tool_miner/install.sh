#!/usr/bin/env bash
# Install (or remove) the tool miner: the Claude Code hook + /mine-tools
# command (via setup_claude.py) and the nightly systemd *user* timer.
#
#   tools/tool_miner/install.sh                    # nightly at 03:30
#   tools/tool_miner/install.sh --at 22:15
#   tools/tool_miner/install.sh --container NAME   # toolbox that has `claude`
#   tools/tool_miner/install.sh --host             # run on the host, no toolbox
#   tools/tool_miner/install.sh --uninstall
#
# Works from the host or from inside the toolbox. By default the service runs
# the miner inside the toolbox where `claude` is installed (a login shell, so
# ~/.local/bin is on PATH). Run it now:  systemctl --user start tool-miner.service
# Logs:                                 journalctl --user -u tool-miner -e
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
AT="03:30"
CONTAINER=""
MODE="auto"
UNINSTALL=0

while [ $# -gt 0 ]; do
    case "$1" in
        --at) AT="$2"; shift 2 ;;
        --container) CONTAINER="$2"; MODE="toolbox"; shift 2 ;;
        --host) MODE="host"; shift ;;
        --uninstall) UNINSTALL=1; shift ;;
        -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done
if ! [[ "$AT" =~ ^[0-2][0-9]:[0-5][0-9]$ ]]; then
    echo "--at wants HH:MM, got '$AT'" >&2; exit 2
fi

UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
IN_CONTAINER=0
if [ -f /run/.containerenv ]; then
    IN_CONTAINER=1
    SYSTEMCTL=(flatpak-spawn --host systemctl --user)
else
    SYSTEMCTL=(systemctl --user)
fi

if [ "$UNINSTALL" = 1 ]; then
    "${SYSTEMCTL[@]}" disable --now tool-miner.timer 2>/dev/null || true
    rm -f "$UNIT_DIR/tool-miner.service" "$UNIT_DIR/tool-miner.timer"
    "${SYSTEMCTL[@]}" daemon-reload
    python3 "$HERE/setup_claude.py" --remove
    echo "Removed the tool-miner timer. (.tool_miner/ is untouched.)"
    exit 0
fi

# The SessionEnd hook and /mine-tools command (settings.json is merged, not replaced).
python3 "$HERE/setup_claude.py"

MINE="$REPO/tools/tool_miner/mine.py"
if [ "$MODE" = "auto" ]; then
    if [ "$IN_CONTAINER" = 1 ]; then
        MODE="toolbox"
        CONTAINER=$(sed -n 's/^name="\(.*\)"$/\1/p' /run/.containerenv)
    elif command -v claude >/dev/null 2>&1; then
        MODE="host"
    else
        MODE="toolbox"
        mapfile -t BOXES < <(podman ps -a --filter label=com.github.containers.toolbox=true \
                                 --format '{{.Names}}' 2>/dev/null || true)
        if [ "${#BOXES[@]}" = 1 ]; then
            CONTAINER="${BOXES[0]}"
        elif [ "${#BOXES[@]}" -gt 1 ]; then
            echo "Several toolboxes (${BOXES[*]}); pick the one with claude: --container NAME" >&2
            exit 2
        fi
    fi
fi

if [ "$MODE" = "host" ]; then
    EXEC="/usr/bin/env python3 \"$MINE\" run"
    WHERE="on the host"
else
    BOX=""
    [ -n "$CONTAINER" ] && BOX="-c $CONTAINER"
    EXEC="/usr/bin/toolbox run $BOX /bin/bash -lc 'exec python3 \"$MINE\" run'"
    WHERE="in toolbox ${CONTAINER:-<default>}"
fi

mkdir -p "$UNIT_DIR"
sed -e "s#@REPO@#$REPO#g" -e "s#@EXEC@#$EXEC#g" \
    "$HERE/systemd/tool-miner.service.in" > "$UNIT_DIR/tool-miner.service"
sed -e "s#@AT@#$AT#g" "$HERE/systemd/tool-miner.timer.in" > "$UNIT_DIR/tool-miner.timer"
"${SYSTEMCTL[@]}" daemon-reload
"${SYSTEMCTL[@]}" enable --now tool-miner.timer

echo "Installed: nightly at $AT, $WHERE."
echo "  run it now:  systemctl --user start tool-miner.service"
echo "  logs:        journalctl --user -u tool-miner -e"
echo "  next run:    systemctl --user list-timers tool-miner.timer"

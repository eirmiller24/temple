#!/usr/bin/env bash
# Headless test runner. Tests are SCENES (tests/test_*.tscn) because a
# script run with `-s` is compiled before the autoloads exist and cannot
# name Data/GameState/etc. Each scene's root script runs in _ready and
# quits with 0/1; this script also greps for engine SCRIPT ERROR lines,
# which a test cannot see from the inside.
#
#   tests/run_all.sh            # everything
#   tests/run_all.sh boot ui    # a subset, by stem (test_<name>.tscn)
set -uo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"

# --- Git LFS gate -----------------------------------------------------------
# Binary assets live in LFS on a loopback-only rudolfs server (.lfsconfig).
# Where that server is unreachable (CI, another machine) every png/ogg/wav
# is a ~130-byte pointer file, so the asset-decoding tests would fail for
# reasons that have nothing to do with the code. Detect that by content.
LFS_DEPENDENT_TESTS="test_assets test_skins"
LFS_MAGIC="version https://git-lfs.github.com/spec/v1"
assets_are_pointers() {
    local f
    for f in assets/tilesets/SSW_SET3_MainLevBuild.png assets/sfx/sword_clash.wav; do
        [ -f "$f" ] || return 0
        case "$(head -c 44 "$f" 2>/dev/null | tr -d '\0')" in "$LFS_MAGIC"*) return 0 ;; esac
    done
    return 1
}
skip_list=""
if assets_are_pointers; then
    skip_list="$LFS_DEPENDENT_TESTS"
    echo "############################################################"
    echo "# LFS objects are NOT materialised -- assets are pointers."
    echo "# SKIPPING:$(printf ' %s' $skip_list)"
    echo "# On a dev machine this means a broken checkout: run 'git lfs checkout',"
    echo "# delete .godot/ and re-run."
    echo "############################################################"
fi
should_skip() {
    local name s
    name="$(basename "$1" .tscn)"
    for s in $skip_list; do [ "$name" = "$s" ] && return 0; done
    return 1
}
# ----------------------------------------------------------------------------

echo "== import (builds the .godot cache)"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

echo "== room registry"
if ! "$GODOT" --headless --path . -s res://tools/build_room_registry.gd 2>&1 | grep -v "^$" | grep -v "WARNING: .*leaked" ; then
    echo "FAILED: room registry"
    exit 1
fi
if ! git diff --quiet -- data/rooms.json 2>/dev/null; then
    echo "note: data/rooms.json changed -- commit it with the room scenes"
fi

tests=()
if [ "$#" -gt 0 ]; then
    for n in "$@"; do tests+=("tests/test_${n#test_}.tscn"); done
else
    for t in tests/test_*.tscn; do tests+=("$t"); done
fi

fail=0
for t in "${tests[@]}"; do
    if should_skip "$t"; then
        echo "== $t -- SKIPPED (no LFS objects)"
        continue
    fi
    echo "== $t"
    log="$(mktemp)"
    "$GODOT" --headless --path . "res://$t" >"$log" 2>&1
    code=$?
    if grep -q "SCRIPT ERROR" "$log"; then
        echo "   engine script errors:"
        grep -A3 "SCRIPT ERROR" "$log" | head -40
        code=1
    fi
    grep -E "CHECK FAILED|failures" "$log" | sed 's/^/   /'
    if [ "$code" -ne 0 ]; then
        echo "FAILED: $t (exit $code)"
        fail=1
    fi
    rm -f "$log"
done
exit $fail

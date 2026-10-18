#!/usr/bin/env python3
"""Wire the tool miner into Claude Code for this repo (idempotent).

  - adds the SessionEnd hook (enqueue.py) to .claude/settings.json, keeping
    everything else in that file as it is;
  - installs the /mine-tools command into .claude/commands/.

    python3 tools/tool_miner/setup_claude.py            # install / update
    python3 tools/tool_miner/setup_claude.py --remove   # take both out again

install.sh runs this for you.
"""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
SETTINGS = REPO / ".claude" / "settings.json"
COMMAND_SRC = HERE / "claude" / "mine-tools.md"
COMMAND_DST = REPO / ".claude" / "commands" / "mine-tools.md"
MARK = "tools/tool_miner/enqueue.py"
HOOK = {"type": "command", "command": f'python3 "$CLAUDE_PROJECT_DIR/{MARK}"', "timeout": 10}


def ours(group: dict) -> bool:
    return any(MARK in h.get("command", "") for h in group.get("hooks", []))


def main() -> int:
    remove = "--remove" in sys.argv[1:]
    settings = json.loads(SETTINGS.read_text()) if SETTINGS.exists() else {}
    groups = settings.setdefault("hooks", {}).setdefault("SessionEnd", [])
    had = any(ours(g) for g in groups)
    if remove:
        settings["hooks"]["SessionEnd"] = [g for g in groups if not ours(g)]
        if not settings["hooks"]["SessionEnd"]:
            del settings["hooks"]["SessionEnd"]
        if not settings["hooks"]:
            del settings["hooks"]
    elif not had:
        groups.append({"hooks": [HOOK]})
    if remove or not had:
        SETTINGS.parent.mkdir(exist_ok=True)
        SETTINGS.write_text(json.dumps(settings, indent=2) + "\n")
    print(("removed" if had else "no") + " SessionEnd hook" if remove
          else ("SessionEnd hook already present" if had else "added SessionEnd hook") + f" in {SETTINGS.relative_to(REPO)}")

    if remove:
        if COMMAND_DST.exists():
            COMMAND_DST.unlink()
            print(f"removed {COMMAND_DST.relative_to(REPO)}")
        return 0
    COMMAND_DST.parent.mkdir(parents=True, exist_ok=True)
    src = COMMAND_SRC.read_text()
    if not COMMAND_DST.exists() or COMMAND_DST.read_text() != src:
        COMMAND_DST.write_text(src)
        print(f"installed /mine-tools → {COMMAND_DST.relative_to(REPO)}")
    else:
        print("/mine-tools already up to date")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Claude Code SessionEnd hook: queue the finished session for the tool miner.

Wired in .claude/settings.json. Reads the hook's JSON from stdin and appends
one line to .tool_miner/queue.jsonl. Never blocks or fails the session: any
error is swallowed. Does nothing while the miner itself is running
(TOOL_MINER_ACTIVE=1), so the miner never mines its own calls.
"""
import json
import os
import sys
import time
from pathlib import Path


def main() -> None:
    if os.environ.get("TOOL_MINER_ACTIVE"):
        return
    try:
        hook = json.load(sys.stdin)
    except Exception:
        return
    path = hook.get("transcript_path")
    if not path:
        return
    repo = Path(os.environ.get("CLAUDE_PROJECT_DIR") or Path(__file__).resolve().parents[2])
    state = repo / ".tool_miner"
    state.mkdir(exist_ok=True)
    (state / ".gdignore").touch(exist_ok=True)
    entry = {
        "session_id": hook.get("session_id"),
        "transcript_path": path,
        "cwd": hook.get("cwd"),
        "reason": hook.get("reason"),
        "queued_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    }
    with open(state / "queue.jsonl", "a", encoding="utf-8") as fh:
        fh.write(json.dumps(entry) + "\n")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
    sys.exit(0)

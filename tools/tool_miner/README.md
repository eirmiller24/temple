# Tool miner

Reads this repo's Claude Code sessions and proposes tools, commands, hooks,
doc fixes and CLAUDE.md rules that would have saved time. It proposes only
tooling and process, never game content. Nothing gets built until you accept
a proposal.

```
SessionEnd hook ──► .tool_miner/queue.jsonl ─┐
~/.claude/projects/<this repo>/*.jsonl ──────┴─► digest.py ─► claude -p (read-only,
                                                  prompt.md + schema.json) ─► ledger.json
                                                                           └► PROPOSALS.md
```

1. **Collect.** A `SessionEnd` hook in `.claude/settings.json` runs
   `enqueue.py` to queue each finished session. `setup_claude.py` adds the
   hook (merging it into the settings file you already have) and installs
   `claude/mine-tools.md` as the `/mine-tools` command; `install.sh` runs it
   for you. Sessions that never ended
   cleanly (terminal closed, crash) are picked up anyway once they've been
   idle for `idle_minutes`.
2. **Digest.** `digest.py` keeps what you said, one line per tool call
   (full Bash commands), failures, interruptions and rejected calls, plus a
   slice of each reply. It drops tool outputs, which shrinks a transcript
   about 100–200×. A resumed session only has its new lines digested.
3. **Mine.** Each batch of digests goes to `claude -p` along with the current
   ledger. The run uses Read/Grep/Glob only, no project settings, no MCP and
   no session persistence, so the miner's own runs never become transcripts.
   Every observation has to quote a digest verbatim, and quotes that don't
   match are thrown out.
4. **Surface.** An idea starts as *watching*. It becomes *proposed* once it
   shows up in `surface_after_sessions` different sessions (default 2;
   doc-drift needs only 1). You then accept, reject or close it. Rejected
   ideas never come back. Once a week the run also merges duplicate ideas
   and marks ones that turn out to exist already.

## Running it

| how | what |
|---|---|
| `python3 tools/tool_miner/mine.py run` | Mine now (works from the host or the toolbox; it finds `claude` either way). |
| `… run --dry-run` | Build the prompts into `.tool_miner/runs/` without calling Claude. Try this first: it shows how much a backfill will send. |
| `… run --session 3f2a [--full]` | (Re)mine particular sessions. |
| `/mine-tools` in Claude Code | Runs it, reads you the proposals, and records your decisions. |
| `systemctl --user start tool-miner.service` | Runs exactly what the timer runs. |
| `… status` · `list [--all]` · `show TM-003` | See where things stand. |
| `… accept TM-003 [--launch]` | Writes `.tool_miner/briefs/TM-003.md`. With `--launch` it starts Claude on it. |
| `… reject TM-003 "reason"` · `done TM-003` · `reopen TM-003` | Decide. |
| `… consolidate [--dry-run]` | Merge duplicates now. |
| `… digest 3f2a` | Print one session's digest. |

## Setup and the timer

```bash
bash tools/tool_miner/install.sh          # hook + /mine-tools + nightly 03:30 timer, inside the toolbox that has claude
python3 tools/tool_miner/setup_claude.py  # hook + /mine-tools only, no timer
bash tools/tool_miner/install.sh --at 22:15    # other time
bash tools/tool_miner/install.sh --uninstall   # timer, hook and command all removed
journalctl --user -u tool-miner -e         # logs
```

`Persistent=true` means a run missed while the machine was asleep happens
at the next wake. The service runs `toolbox run … bash -lc 'python3 mine.py run'`
so that a toolbox install of `claude` in `~/.local/bin` is found. When new
proposals surface you get a desktop notification.

## Settings

`config.json` holds the model, batch size, surfacing threshold, idle time,
the per-call budget cap (`max_budget_usd_per_call`) and the digest limits.
Two env overrides: `TOOL_MINER_CLAUDE` (e.g. `toolbox run -c fedora-toolbox-43 claude`)
and `TOOL_MINER_MODEL`.

All state lives in `.tool_miner/` (gitignored; it has a `.gdignore`). Delete
`state.json` to re-mine everything, or `ledger.json` to forget every idea.

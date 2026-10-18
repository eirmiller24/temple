You maintain the tool-miner ledger for **The Temple of Rhys** (a Godot 4.7
game repo; you are in its root with read-only tools: Read, Grep, Glob).
The ledger collects tool and process ideas mined from Claude Code sessions.
Over time it picks up duplicates, and some ideas get built without the
ledger being told. Tidy it.

1. **Merges.** Find entries that are the same idea worded differently. For
   each group, keep the entry that is best evidenced (or oldest if tied) and
   absorb the rest. You may give the kept entry a better title/summary that
   covers the merged scope; leave them "" to keep the current ones. Never
   merge an entry into a `rejected` one or a `rejected` one into anything —
   the author's decisions stay separate. Don't merge ideas that merely
   share a topic: they must be the same tool or the same change.
2. **Already exists.** For `watching` and `proposed` entries, check the repo
   for something that already does it. Start with CLAUDE.md's command list
   and architecture map (the quickest index of what exists), then tools/,
   addons/room_tools/, .claude/, tests/ and docs/. Report only clear
   matches, with the path.

Return empty lists if there is nothing to do. Today is {{TODAY}}.

## Ledger

{{LEDGER}}

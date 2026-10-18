---
description: Run the tool miner now and go through its proposals
argument-hint: "[mine.py run options, e.g. --include-active or --dry-run]"
allowed-tools: Bash(python3 tools/tool_miner/mine.py:*), Read
---
Run `python3 tools/tool_miner/mine.py run $ARGUMENTS` with a long timeout
(10 minutes); it calls Claude on the new session digests, so it can take a
few minutes. Then read `.tool_miner/PROPOSALS.md`.

Give me a short rundown I can listen to: for each entry under **Proposed**,
its id, one line on what it is, and how strong the evidence looks. Mention
anything under **Miner notes**. Then wait for my decision on each one, and
carry it out with `python3 tools/tool_miner/mine.py accept|reject|done <id> [reason]`.

Accepting only writes a brief to `.tool_miner/briefs/`. Don't start building a
proposal in this session unless I explicitly say to build it now.

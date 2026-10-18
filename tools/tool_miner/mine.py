#!/usr/bin/env python3
"""Tool miner: read this repo's Claude Code sessions and propose tools.

Sessions are found in ~/.claude/projects/ (the ones whose working directory
is this repo), cut down to digests (digest.py), and handed to `claude -p`
with read-only tools and prompt.md. What it finds goes into a ledger; an idea
surfaces as a proposal once it has evidence from enough different sessions.
Nothing gets built until you accept it.

Everything lives in .tool_miner/ at the repo root (gitignored):
  PROPOSALS.md   what to read      ledger.json   every idea + evidence
  state.json     what's been mined queue.jsonl   sessions queued by the hook
  briefs/        accepted briefs   runs.jsonl    one line per run (cost etc.)

Commands (run from the toolbox or the host; it finds `claude` either way):
  mine.py run                  mine queued + idle unmined sessions (what the timer runs)
  mine.py run --dry-run        build the prompts into .tool_miner/runs/, call nothing
  mine.py run --session 3f2a   (re)mine specific sessions; add --full to start from line 1
  mine.py status               queue, unmined sessions, last runs
  mine.py list [--all]         proposals (and with --all, everything on file)
  mine.py show TM-003
  mine.py accept TM-003 [--launch]   write a build brief; --launch starts Claude on it
  mine.py reject TM-003 "reason"     never surface it again
  mine.py done TM-003 [note]         it's built
  mine.py reopen TM-003
  mine.py consolidate          merge duplicates, spot ideas that already exist
  mine.py digest 3f2a          print one session's digest
"""
from __future__ import annotations

import argparse
import fcntl
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = Path(os.environ.get("TOOL_MINER_REPO") or HERE.parents[1])
STATE = Path(os.environ.get("TOOL_MINER_STATE_DIR") or REPO / ".tool_miner")
sys.path.insert(0, str(HERE))
import digest as dg  # noqa: E402

ACTIVE = ("watching", "proposed", "accepted")
NESTED_ENV = {"CLAUDECODE", "CLAUDE_CODE_ENTRYPOINT", "CLAUDE_CODE_SESSION_ID",
              "CLAUDE_CODE_CHILD_SESSION", "CLAUDE_PID", "CLAUDE_CODE_SSE_PORT", "CLAUDE_PROJECT_DIR"}
ID_RE = re.compile(r"^TM-\d+$")


class MinerError(Exception):
    pass


class Busy(MinerError):
    """Another run holds the lock. Not a failure: the timer shouldn't go red over it."""


# ---------------------------------------------------------------- config / io

def load_config() -> dict:
    cfg = json.loads((HERE / "config.json").read_text())
    if os.environ.get("TOOL_MINER_MODEL"):
        cfg["model"] = os.environ["TOOL_MINER_MODEL"]
    return cfg


def now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def today() -> str:
    return datetime.now().strftime("%Y-%m-%d")


def read_json(path: Path, default):
    try:
        return json.loads(path.read_text())
    except FileNotFoundError:
        return default


def write_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    tmp.replace(path)


def ensure_state() -> None:
    STATE.mkdir(parents=True, exist_ok=True)
    (STATE / ".gdignore").touch(exist_ok=True)


def load_ledger() -> dict:
    return read_json(STATE / "ledger.json", {"version": 1, "next_id": 1, "proposals": {}})


def load_state() -> dict:
    return read_json(STATE / "state.json", {"transcripts": {}, "last_consolidated": None, "notes": []})


class Lock:
    """Non-blocking run lock so the timer and a manual run don't collide."""

    def __enter__(self):
        ensure_state()
        self.fh = open(STATE / "lock", "w")
        try:
            fcntl.flock(self.fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise Busy("another tool-miner run is in progress; skipping")
        return self

    def __exit__(self, *exc):
        fcntl.flock(self.fh, fcntl.LOCK_UN)
        self.fh.close()


# ---------------------------------------------------------------- claude

def claude_base(cfg: dict, for_miner: bool = True) -> list[str]:
    """How to start `claude`: env override, config, PATH, or through toolbox."""
    marker = ["env", "TOOL_MINER_ACTIVE=1"] if for_miner else []
    if os.environ.get("TOOL_MINER_CLAUDE"):
        return marker + shlex.split(os.environ["TOOL_MINER_CLAUDE"])
    if cfg.get("claude_cmd"):
        cmd = cfg["claude_cmd"]
        return marker + (shlex.split(cmd) if isinstance(cmd, str) else list(cmd))
    if shutil.which("claude"):
        return marker + ["claude"]
    if shutil.which("toolbox"):
        box = ["-c", cfg["toolbox_container"]] if cfg.get("toolbox_container") else []
        # toolbox run doesn't forward the environment, so the marker goes inside.
        return ["toolbox", "run", *box, *marker, "claude"]
    raise MinerError("can't find `claude` (not on PATH, no toolbox). Set TOOL_MINER_CLAUDE.")


def call_claude(cfg: dict, prompt: str, schema_file: str, model: str) -> tuple[dict, float]:
    schema = json.dumps(json.loads((HERE / schema_file).read_text()), separators=(",", ":"))
    cmd = claude_base(cfg) + [
        "-p",
        "--output-format", "json",
        "--json-schema", schema,
        "--tools", "Read,Grep,Glob",   # read-only: it can look, never touch
        "--no-session-persistence",     # its own runs never become transcripts to mine
        "--strict-mcp-config",          # no godot-ai etc.
        "--setting-sources", "user",    # skip project settings: no hooks, no Bash allow-rule
        "--model", model,
        "--max-budget-usd", str(cfg["max_budget_usd_per_call"]),
    ]
    # When this runs from inside a Claude Code session (the /mine-tools command),
    # don't let the child think it is part of that session.
    env = {k: v for k, v in os.environ.items() if k not in NESTED_ENV}
    env["TOOL_MINER_ACTIVE"] = "1"
    try:
        proc = subprocess.run(cmd, input=prompt, capture_output=True, text=True, cwd=REPO,
                              env=env, timeout=cfg["claude_timeout_s"])
    except subprocess.TimeoutExpired:
        raise MinerError(f"claude timed out after {cfg['claude_timeout_s']}s")
    except FileNotFoundError as e:
        raise MinerError(f"couldn't start claude: {e}")
    result = None
    for line in reversed(proc.stdout.strip().splitlines()):
        try:
            d = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(d, dict) and d.get("type") == "result":
            result = d
            break
    if result is None:
        tail = (proc.stderr or proc.stdout).strip()[-800:]
        raise MinerError(f"claude exited {proc.returncode} without a result:\n{tail}")
    cost = float(result.get("total_cost_usd") or 0)
    out = result.get("structured_output")
    if result.get("is_error") or not isinstance(out, dict):
        raise MinerError(f"claude returned no structured output ({result.get('subtype')}): "
                         f"{str(result.get('result'))[:500]}")
    return out, cost


# ---------------------------------------------------------------- transcripts

def projects_dir() -> Path:
    if os.environ.get("TOOL_MINER_PROJECTS_DIR"):
        return Path(os.environ["TOOL_MINER_PROJECTS_DIR"])
    base = os.environ.get("CLAUDE_CONFIG_DIR") or Path.home() / ".claude"
    return Path(base) / "projects"


def repo_roots() -> list[str]:
    """The repo's path as Claude Code may have recorded it (/home vs /var/home on Atomic)."""
    roots = {str(REPO), os.path.realpath(REPO)}
    for r in list(roots):
        if r.startswith("/var/home/"):
            roots.add(r[len("/var"):])
        elif r.startswith("/home/"):
            roots.add("/var" + r)
    return sorted(roots)


def _encode(p: str) -> str:
    return re.sub(r"[^a-zA-Z0-9]", "-", p)


def _first_cwd(path: Path) -> str | None:
    with open(path, encoding="utf-8", errors="replace") as fh:
        for i, line in enumerate(fh):
            if i > 200:
                break
            m = re.search(r'"cwd":\s*"([^"]+)"', line)
            if m:
                return m.group(1)
    return None


def find_transcripts() -> list[Path]:
    pd = projects_dir()
    if not pd.is_dir():
        return []
    roots = repo_roots()
    encs = {_encode(r) for r in roots}
    found = []
    for d in pd.iterdir():
        if not d.is_dir():
            continue
        exact = d.name in encs
        if not exact and not any(d.name.startswith(e + "-") for e in encs):
            continue
        for f in d.glob("*.jsonl"):
            if not exact:  # a subdirectory of the repo, or a sibling like temple-old?
                cwd = _first_cwd(f) or ""
                if not any(cwd == r or cwd.startswith(r + "/") for r in roots):
                    continue
            found.append(f)
    return found


def count_lines(path: Path) -> int:
    with open(path, "rb") as fh:
        return sum(1 for _ in fh)


def read_queue() -> list[dict]:
    q = []
    try:
        for line in (STATE / "queue.jsonl").read_text().splitlines():
            try:
                q.append(json.loads(line))
            except json.JSONDecodeError:
                pass
    except FileNotFoundError:
        pass
    return q


def write_queue(entries: list[dict]) -> None:
    ensure_state()
    path = STATE / "queue.jsonl"
    tmp = path.with_suffix(".tmp")
    tmp.write_text("".join(json.dumps(e) + "\n" for e in entries))
    tmp.replace(path)


def find_session(prefix: str) -> Path:
    hits = [p for p in find_transcripts() if p.stem.startswith(prefix)]
    if not hits:
        raise MinerError(f"no transcript for this repo starts with {prefix!r}")
    if len(hits) > 1:
        raise MinerError(f"{prefix!r} is ambiguous: " + ", ".join(p.stem[:12] for p in hits))
    return hits[0]


# ---------------------------------------------------------------- ledger logic

def _norm(s: str) -> str:
    s = s.replace("⏎", " ").replace("`", "").replace("“", '"').replace("”", '"')
    s = s.replace("’", "'")
    return re.sub(r"\s+", " ", s).strip().strip('"').strip().lower()


def quote_in(quote: str, text: str) -> bool:
    q, t = _norm(quote), _norm(text)
    if not q:
        return False
    if q in t:
        return True
    parts = [p.strip() for p in re.split(r"…|\.\.\.", q) if len(p.strip()) >= 15]
    return bool(parts) and all(p in t for p in parts)


def threshold(cfg: dict, kind: str) -> int:
    return int(cfg["surface_after_sessions_by_kind"].get(kind, cfg["surface_after_sessions"]))


def history(entry: dict, event: str, note: str = "") -> None:
    entry.setdefault("history", []).append({"at": now_iso(), "event": event, **({"note": note} if note else {})})


def maybe_surface(cfg: dict, entry: dict) -> bool:
    if entry["status"] == "watching" and len(entry["sessions"]) >= threshold(cfg, entry["kind"]):
        entry["status"] = "proposed"
        entry["surfaced_at"] = now_iso()
        history(entry, "proposed", f"{len(entry['sessions'])} sessions")
        return True
    return False


def resolve(ledger: dict, pid: str) -> dict | None:
    seen = set()
    e = ledger["proposals"].get(pid)
    while e and e.get("status") == "merged" and e.get("merged_into") and pid not in seen:
        seen.add(pid)
        pid = e["merged_into"]
        e = ledger["proposals"].get(pid)
    return e


def apply_observations(cfg: dict, ledger: dict, out: dict, batch: list[dict]) -> dict:
    """Merge one batch's observations into the ledger. Returns a report."""
    by_prefix = {d["session_id"][:8]: d for d in batch}
    report = {"new": [], "updated": [], "surfaced": [], "discarded": []}
    for obs in out.get("observations", []):
        evidence = []
        for ev in obs.get("evidence", []):
            sid = (ev.get("session") or "").strip()[:8]
            d = by_prefix.get(sid)
            if not d or not quote_in(ev.get("quote", ""), d["text"]):
                continue
            evidence.append({
                "session": d["session_id"],
                "date": (d.get("last") or "")[:10],
                "quote": ev["quote"].strip()[:400],
                "note": ev.get("note", "").strip(),
            })
        if not evidence:
            report["discarded"].append(obs.get("title", "?"))
            continue
        match = (obs.get("match") or "").strip().upper()
        entry = resolve(ledger, match) if ID_RE.match(match) else None
        if entry is None:
            pid = f"TM-{ledger['next_id']:03d}"
            ledger["next_id"] += 1
            entry = {
                "id": pid, "title": obs["title"].strip(), "kind": obs["kind"],
                "signals": [], "summary": obs["summary"].strip(), "rationale": obs["rationale"].strip(),
                "size": obs["size"], "status": "watching", "first_seen": now_iso(),
                "sessions": [], "evidence": [],
            }
            ledger["proposals"][pid] = entry
            history(entry, "created")
            report["new"].append(pid)
        else:
            report["updated"].append(entry["id"])
            if entry["status"] == "rejected":
                entry["seen_after_reject"] = entry.get("seen_after_reject", 0) + 1
        if obs.get("signal") and obs["signal"] not in entry["signals"]:
            entry["signals"].append(obs["signal"])
        have = {(e["session"], _norm(e["quote"])) for e in entry["evidence"]}
        for ev in evidence:
            if (ev["session"], _norm(ev["quote"])) not in have:
                entry["evidence"].append(ev)
            if ev["session"] not in entry["sessions"]:
                entry["sessions"].append(ev["session"])
        entry["evidence"] = entry["evidence"][-12:]
        entry["last_seen"] = now_iso()
        if maybe_surface(cfg, entry):
            report["surfaced"].append(entry["id"])
    return report


def ledger_for_prompt(ledger: dict, full: bool = False) -> str:
    rows = []
    for e in sorted(ledger["proposals"].values(), key=lambda e: e["id"]):
        if e["status"] == "merged":
            continue
        status = e["status"]
        if status in ("rejected", "done", "exists") and e.get("status_note"):
            status += f': "{e["status_note"]}"'
        n = len(e["sessions"])
        summary = e["summary"] if full else dg._clip(e["summary"], 220)
        rows.append(f"- {e['id']} [{status}; {n} session{'s' if n != 1 else ''}] ({e['kind']}) "
                    f"{e['title']} — {summary}")
        if full:
            for ev in e["evidence"][-3:]:
                rows.append(f"    · {ev['session'][:8]}: \"{dg._clip(ev['quote'], 160)}\"")
    return "\n".join(rows) if rows else "(empty — nothing on file yet)"


# ---------------------------------------------------------------- rendering

def _entry_md(e: dict, cfg: dict) -> list[str]:
    n = len(e["sessions"])
    signals = ", ".join(e.get("signals", []))
    out = [f"### {e['id']} · {e['title']}",
           f"*{e['kind']} · size {e['size']} · {n} session{'s' if n != 1 else ''} · {signals}*", "",
           e["summary"], "", f"**Why:** {e['rationale']}", ""]
    for ev in e["evidence"][-5:]:
        out.append(f"- `{ev['session'][:8]}` {ev['date']} — \"{dg._clip(ev['quote'], 220)}\" — {ev['note']}")
    out += ["", f"`mine.py accept {e['id']}` · `mine.py reject {e['id']} \"why\"`", ""]
    return out


def render(cfg: dict, ledger: dict, state: dict) -> Path:
    ps = list(ledger["proposals"].values())
    by = lambda s: sorted((e for e in ps if e["status"] == s), key=lambda e: (-len(e["sessions"]), e["id"]))
    mined = len(state["transcripts"])
    runs = read_runs(1)
    last = runs[-1]["at"] if runs else "never"
    lines = ["# Tool miner proposals", "",
             f"_Updated {now_iso()} · {mined} sessions mined · last run {last}_", "",
             "Act with `python3 tools/tool_miner/mine.py accept|reject|done TM-xxx` "
             "(`accept --launch` starts Claude on the brief). Nothing is built until you accept it.", ""]
    proposed = by("proposed")
    lines += [f"## Proposed ({len(proposed)})", ""]
    if not proposed:
        lines += ["_Nothing has enough evidence yet._", ""]
    for e in proposed:
        lines += _entry_md(e, cfg)
    accepted = by("accepted")
    if accepted:
        lines += [f"## Accepted, not done yet ({len(accepted)})", ""]
        lines += [f"- **{e['id']}** {e['title']} — brief: `.tool_miner/briefs/{e['id']}.md`" for e in accepted]
        lines.append("")
    watching = by("watching")
    lines += [f"## Watching ({len(watching)})", "",
              f"_Seen, not yet in {cfg['surface_after_sessions']} sessions._", ""]
    for e in watching:
        lines.append(f"- {e['id']} ({e['kind']}, {len(e['sessions'])}/{threshold(cfg, e['kind'])}) "
                     f"{e['title']} — {dg._clip(e['summary'], 160)}")
    lines.append("")
    closed = by("done") + by("exists") + by("rejected")
    if closed:
        lines += ["## Closed", ""]
        for e in closed:
            note = f" — {e['status_note']}" if e.get("status_note") else ""
            again = f" (seen {e['seen_after_reject']}× since)" if e.get("seen_after_reject") else ""
            lines.append(f"- {e['id']} [{e['status']}] {e['title']}{note}{again}")
        lines.append("")
    notes = state.get("notes", [])[-5:]
    if notes:
        lines += ["## Miner notes", ""]
        lines += [f"- {n['date']}: {n['text']}" for n in reversed(notes)]
        lines.append("")
    path = STATE / "PROPOSALS.md"
    path.write_text("\n".join(lines))
    return path


def notify(cfg: dict, title: str, body: str) -> None:
    if not cfg.get("notify"):
        return
    for cmd in (["notify-send"], ["flatpak-spawn", "--host", "notify-send"]):
        if shutil.which(cmd[0]):
            try:
                subprocess.run(cmd + ["-a", "Tool miner", title, body], timeout=10,
                               capture_output=True)
                return
            except Exception:
                continue


def read_runs(n: int) -> list[dict]:
    try:
        lines = (STATE / "runs.jsonl").read_text().splitlines()[-n:]
    except FileNotFoundError:
        return []
    return [json.loads(l) for l in lines if l.strip()]


def log_run(rec: dict) -> None:
    with open(STATE / "runs.jsonl", "a") as fh:
        fh.write(json.dumps(rec) + "\n")


# ---------------------------------------------------------------- commands

def collect(cfg: dict, state: dict, args) -> list[tuple[Path, int, str]]:
    """Return [(transcript, from_line, why)] to mine, oldest first."""
    queued_paths = [Path(q["transcript_path"]) for q in read_queue() if q.get("transcript_path")]
    queued = {p.stem for p in queued_paths}
    if args.session:
        paths = [find_session(s) for s in args.session]
    else:
        by_id: dict[str, Path] = {p.stem: p for p in queued_paths if p.exists()}
        if not args.queue_only:
            for p in find_transcripts():
                by_id.setdefault(p.stem, p)
        paths = list(by_id.values())
    todo = []
    idle = cfg["idle_minutes"] * 60
    for p in sorted(paths, key=lambda p: p.stat().st_mtime):
        done = 0 if (args.session and args.full) else state["transcripts"].get(p.stem, {}).get("lines", 0)
        total = count_lines(p)
        if total <= done:
            continue
        in_queue = p.stem in queued
        if not (in_queue or args.session or args.include_active) and time.time() - p.stat().st_mtime < idle:
            continue  # probably still in use; next run will get it
        todo.append((p, done, "queued" if in_queue else ("asked" if args.session else "swept")))
    if args.limit:
        todo = todo[: args.limit]
    return todo


def batches(digests: list[dict], max_chars: int) -> list[list[dict]]:
    out, cur, size = [], [], 0
    for d in digests:
        if cur and size + len(d["text"]) > max_chars:
            out.append(cur)
            cur, size = [], 0
        cur.append(d)
        size += len(d["text"])
    if cur:
        out.append(cur)
    return out


def fill(template: str, **kw) -> str:
    for k, v in kw.items():
        template = template.replace("{{" + k + "}}", v)
    return template


def cmd_run(cfg: dict, args) -> int:
    with Lock():
        ensure_state()
        ledger, state = load_ledger(), load_state()
        todo = collect(cfg, state, args)
        model = args.model or cfg["model"]
        if not todo:
            print("Nothing new to mine.")
        else:
            why = {}
            for _, _, w in todo:
                why[w] = why.get(w, 0) + 1
            print(f"Mining {len(todo)} session(s) (" + ", ".join(f"{n} {w}" for w, n in why.items()) + ")")
        digests, trivial = [], []
        for p, start, _ in todo:
            d = dg.digest(p, start, repo_roots(), cfg["digest"])
            d["path"] = str(p)
            (digests if d["user_turns"] >= cfg["min_user_turns"] else trivial).append(d)
        if trivial:
            print(f"  skipping {len(trivial)} session(s) with no real conversation")
        groups = batches(digests, cfg["batch_max_chars"])
        template = (HERE / "prompt.md").read_text()
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        surfaced, total_cost, failed = [], 0.0, None

        def mark(ds):
            for d in ds:
                state["transcripts"][Path(d["path"]).stem] = {
                    "lines": d["lines"], "mined_at": now_iso(), "title": d.get("title")}

        if not args.dry_run:
            mark(trivial)
        for i, group in enumerate(groups, 1):
            prompt = fill(template, TODAY=today(), THRESHOLD=str(cfg["surface_after_sessions"]),
                          LEDGER=ledger_for_prompt(ledger),
                          DIGESTS="\n\n---\n\n".join(d["text"] for d in group))
            label = f"  batch {i}/{len(groups)}: {len(group)} session(s), {len(prompt) // 1000}k chars"
            if args.dry_run:
                path = STATE / "runs" / f"dry-{stamp}" / f"batch-{i}.md"
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(prompt)
                print(f"{label} → {path.relative_to(REPO) if path.is_relative_to(REPO) else path}")
                continue
            print(f"{label} → claude ({model}) …", flush=True)
            t0 = time.time()
            try:
                out, cost = call_claude(cfg, prompt, "schema.json", model)
            except MinerError as e:
                failed = str(e)
                print(f"  ✗ {e}", file=sys.stderr)
                break
            total_cost += cost
            rep = apply_observations(cfg, ledger, out, group)
            surfaced += rep["surfaced"]
            if out.get("notes", "").strip():
                state.setdefault("notes", []).append({"date": today(), "text": out["notes"].strip()})
                state["notes"] = state["notes"][-20:]
            mark(group)
            write_json(STATE / "ledger.json", ledger)
            write_json(STATE / "state.json", state)
            print(f"    {time.time() - t0:.0f}s, ${cost:.2f}: {len(rep['new'])} new, "
                  f"{len(rep['updated'])} more evidence, {len(rep['surfaced'])} surfaced"
                  + (f", {len(rep['discarded'])} discarded (no verifiable quote)" if rep["discarded"] else ""))
            for pid in rep["new"]:
                print(f"    + {pid} {ledger['proposals'][pid]['title']}")
            for pid in rep["surfaced"]:
                print(f"    ★ {pid} is now a proposal: {ledger['proposals'][pid]['title']}")
            log_run({"at": now_iso(), "sessions": [d["session_id"] for d in group], "model": model,
                     "cost_usd": round(cost, 4), **rep})

        if args.dry_run:
            print("Dry run: nothing called, nothing recorded.")
            return 0

        # Keep only queue entries that still have unmined activity. (A hook that
        # appends during this rewrite can lose its line; the idle sweep still
        # finds that session next time.)
        keep = []
        for q in read_queue():
            p = Path(q.get("transcript_path", ""))
            rec = state["transcripts"].get(p.stem)
            if p.exists() and not (rec and count_lines(p) <= rec["lines"]):
                keep.append(q)
        write_queue(keep)
        write_json(STATE / "state.json", state)

        if not failed and not args.no_consolidate:
            due = args.consolidate
            last = state.get("last_consolidated")
            active = sum(1 for e in ledger["proposals"].values() if e["status"] in ACTIVE)
            if not due and active >= 4:
                due = not last or (time.time() - datetime.fromisoformat(last).timestamp()
                                   >= cfg["consolidate_every_days"] * 86400)
            if due:
                try:
                    total_cost += consolidate(cfg, ledger, state, surfaced)
                except MinerError as e:
                    print(f"  ✗ consolidation failed: {e}", file=sys.stderr)

        path = render(cfg, ledger, state)
        if todo or args.consolidate:
            print(f"Total ${total_cost:.2f}. Proposals: {path.relative_to(REPO) if path.is_relative_to(REPO) else path}")
        if surfaced:
            ids = ", ".join(sorted(set(surfaced)))
            notify(cfg, f"{len(set(surfaced))} new tool idea(s)", f"{ids} — see .tool_miner/PROPOSALS.md")
        return 1 if failed else 0


def consolidate(cfg: dict, ledger: dict, state: dict, surfaced: list[str], dry_run: bool = False) -> float:
    prompt = fill((HERE / "consolidate.md").read_text(), TODAY=today(),
                  LEDGER=ledger_for_prompt(ledger, full=True))
    if dry_run:
        path = STATE / "runs" / f"consolidate-{datetime.now():%Y%m%d-%H%M%S}.md"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(prompt)
        print(f"Dry run: prompt written to {path}")
        return 0.0
    print(f"  consolidating ledger ({cfg['consolidate_model']}) …", flush=True)
    out, cost = call_claude(cfg, prompt, "consolidate_schema.json", cfg["consolidate_model"])
    P = ledger["proposals"]
    for m in out.get("merges", []):
        keep = P.get(m.get("keep", ""))
        if not keep or keep["status"] in ("rejected", "merged"):
            continue
        for aid in m.get("absorb", []):
            a = P.get(aid)
            if not a or aid == keep["id"] or a["status"] in ("rejected", "merged"):
                continue
            for ev in a["evidence"]:
                if ev not in keep["evidence"]:
                    keep["evidence"].append(ev)
            keep["evidence"] = keep["evidence"][-12:]
            keep["sessions"] = list(dict.fromkeys(keep["sessions"] + a["sessions"]))
            keep["signals"] = list(dict.fromkeys(keep.get("signals", []) + a.get("signals", [])))
            if a["status"] == "accepted" and keep["status"] in ("watching", "proposed"):
                keep["status"] = "accepted"
            a["status"], a["merged_into"] = "merged", keep["id"]
            history(a, "merged", f"into {keep['id']}: {m.get('reason', '')}")
            history(keep, "absorbed", f"{aid}: {m.get('reason', '')}")
            print(f"    merged {aid} → {keep['id']}")
        if m.get("title"):
            keep["title"] = m["title"]
        if m.get("summary"):
            keep["summary"] = m["summary"]
        if maybe_surface(cfg, keep):
            surfaced.append(keep["id"])
    for x in out.get("already_exist", []):
        e = P.get(x.get("id", ""))
        if e and e["status"] in ("watching", "proposed"):
            e["status"], e["status_note"] = "exists", f"{x.get('where', '')} — {x.get('reason', '')}"
            history(e, "exists", e["status_note"])
            print(f"    {e['id']} already exists: {x.get('where')}")
    state["last_consolidated"] = now_iso()
    write_json(STATE / "ledger.json", ledger)
    write_json(STATE / "state.json", state)
    log_run({"at": now_iso(), "consolidate": True, "cost_usd": round(cost, 4),
             "merges": len(out.get("merges", [])), "exists": len(out.get("already_exist", []))})
    return cost


def cmd_consolidate(cfg, args) -> int:
    with Lock():
        ledger, state = load_ledger(), load_state()
        surfaced: list[str] = []
        consolidate(cfg, ledger, state, surfaced, dry_run=args.dry_run)
        if not args.dry_run:
            render(cfg, ledger, state)
            print("Done." + (f" Surfaced: {', '.join(surfaced)}" if surfaced else ""))
    return 0


def get_entry(ledger: dict, pid: str) -> dict:
    pid = pid.upper()
    if re.fullmatch(r"\d+", pid):
        pid = f"TM-{int(pid):03d}"
    e = resolve(ledger, pid)
    if not e:
        raise MinerError(f"no such proposal: {pid}")
    return e


def set_status(cfg, pid: str, status: str, note: str = "") -> dict:
    with Lock():
        ledger, state = load_ledger(), load_state()
        e = get_entry(ledger, pid)
        e["status"] = status
        if note:
            e["status_note"] = note
        elif status in ("watching", "proposed", "accepted"):
            e.pop("status_note", None)
        history(e, status, note)
        write_json(STATE / "ledger.json", ledger)
        render(cfg, ledger, state)
        return e


def brief_text(e: dict) -> str:
    ev = "\n".join(f"- session `{x['session'][:8]}` ({x['date']}): \"{x['quote']}\" — {x['note']}"
                   for x in e["evidence"])
    return f"""# Build {e['id']}: {e['title']}

This is a tool-miner proposal that I've accepted. Build exactly this.

**What:** {e['summary']}

**Why:** {e['rationale']}

**Form:** {e['kind']} · estimated size {e['size']}

**Evidence from earlier sessions:**
{ev}

Ground rules: read CLAUDE.md first. Agents draft, they never design: build what's
described, and where this brief is silent pick the simplest placeholder and report
every placeholder you filled. If this brief contradicts CLAUDE.md, the docs or the
code, flag it instead of picking one. Tunables go in data/*.json; never edit
addons/godot_ai/. Add any new command to CLAUDE.md's command list.

When it's built and works, run: python3 tools/tool_miner/mine.py done {e['id']}
"""


def cmd_accept(cfg, args) -> int:
    e = set_status(cfg, args.id, "accepted")
    path = STATE / "briefs" / f"{e['id']}.md"
    path.parent.mkdir(parents=True, exist_ok=True)
    text = brief_text(e)
    path.write_text(text)
    rel = path.relative_to(REPO) if path.is_relative_to(REPO) else path
    print(f"Accepted {e['id']}. Brief: {rel}")
    if args.launch:
        base = claude_base(cfg, for_miner=False)
        os.chdir(REPO)
        os.execvp(base[0], base + [text])
    print(f'Edit it if you like, then: claude "$(cat {rel})"   (or rerun with --launch)')
    return 0


def cmd_show(cfg, args) -> int:
    e = get_entry(load_ledger(), args.id)
    print("\n".join(_entry_md(e, cfg)))
    print(f"status: {e['status']}" + (f" — {e['status_note']}" if e.get("status_note") else ""))
    for h in e.get("history", []):
        print(f"  {h['at']}  {h['event']}" + (f"  {h['note']}" if h.get("note") else ""))
    return 0


def cmd_list(cfg, args) -> int:
    ledger = load_ledger()
    rows = sorted(ledger["proposals"].values(), key=lambda e: (["proposed", "accepted", "watching", "done", "exists", "rejected", "merged"].index(e["status"]), e["id"]))
    shown = 0
    for e in rows:
        if not args.all and e["status"] not in ("proposed", "accepted"):
            continue
        shown += 1
        print(f"{e['id']}  {e['status']:<9} {e['kind']:<15} {len(e['sessions']):>2} sess  {e['title']}")
    if not shown:
        print("No proposals yet." + ("" if args.all else " (--all shows ideas still being watched)"))
    return 0


def cmd_status(cfg, args) -> int:
    state = load_state()
    queue = read_queue()
    unmined = 0
    for p in find_transcripts():
        if count_lines(p) > state["transcripts"].get(p.stem, {}).get("lines", 0):
            unmined += 1
    ledger = load_ledger()
    counts: dict[str, int] = {}
    for e in ledger["proposals"].values():
        counts[e["status"]] = counts.get(e["status"], 0) + 1
    print(f"repo:        {REPO}")
    print(f"transcripts: {projects_dir()}  ({len(find_transcripts())} for this repo, {unmined} with unmined activity)")
    print(f"queue:       {len(queue)} session(s) queued by the hook")
    print("ledger:      " + (", ".join(f"{n} {s}" for s, n in sorted(counts.items())) or "empty"))
    print(f"claude:      {' '.join(claude_base(cfg, for_miner=False))}  (model {cfg['model']})")
    runs = read_runs(5)
    if runs:
        print("last runs:")
        for r in runs:
            what = "consolidate" if r.get("consolidate") else f"{len(r.get('sessions', []))} sessions"
            print(f"  {r['at']}  {what}  ${r.get('cost_usd', 0):.2f}")
    return 0


def cmd_digest(cfg, args) -> int:
    p = find_session(args.session)
    sys.stdout.write(dg.digest(p, 0, repo_roots(), cfg["digest"])["text"])
    return 0


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(prog="mine.py", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("run", help="mine new session activity")
    r.add_argument("--session", action="append", metavar="ID", help="only this session (id prefix); repeatable")
    r.add_argument("--full", action="store_true", help="with --session: re-mine from the start")
    r.add_argument("--queue-only", action="store_true", help="only sessions the hook queued")
    r.add_argument("--include-active", action="store_true", help="don't wait for sessions to go idle")
    r.add_argument("--limit", type=int, help="at most N sessions (oldest first)")
    r.add_argument("--dry-run", action="store_true", help="write prompts, call nothing, record nothing")
    r.add_argument("--model", help="override the model for this run")
    r.add_argument("--consolidate", action="store_true", help="also consolidate the ledger now")
    r.add_argument("--no-consolidate", action="store_true", help="skip the periodic consolidation")
    c = sub.add_parser("consolidate", help="merge duplicate ideas, spot ones that already exist")
    c.add_argument("--dry-run", action="store_true")
    l = sub.add_parser("list", help="list proposals")
    l.add_argument("--all", action="store_true")
    s = sub.add_parser("show")
    s.add_argument("id")
    a = sub.add_parser("accept", help="accept and write a build brief")
    a.add_argument("id")
    a.add_argument("--launch", action="store_true", help="start Claude Code on the brief")
    rj = sub.add_parser("reject")
    rj.add_argument("id")
    rj.add_argument("reason", nargs="*")
    dn = sub.add_parser("done")
    dn.add_argument("id")
    dn.add_argument("note", nargs="*")
    ro = sub.add_parser("reopen")
    ro.add_argument("id")
    sub.add_parser("status")
    d = sub.add_parser("digest", help="print one session's digest")
    d.add_argument("session")
    args = ap.parse_args(argv)
    cfg = load_config()
    try:
        if args.cmd == "run":
            return cmd_run(cfg, args)
        if args.cmd == "consolidate":
            return cmd_consolidate(cfg, args)
        if args.cmd == "list":
            return cmd_list(cfg, args)
        if args.cmd == "show":
            return cmd_show(cfg, args)
        if args.cmd == "accept":
            return cmd_accept(cfg, args)
        if args.cmd == "reject":
            e = set_status(cfg, args.id, "rejected", " ".join(args.reason))
            print(f"Rejected {e['id']}; it won't surface again.")
            return 0
        if args.cmd == "done":
            e = set_status(cfg, args.id, "done", " ".join(args.note))
            print(f"Marked {e['id']} done.")
            return 0
        if args.cmd == "reopen":
            e = get_entry(load_ledger(), args.id)
            target = "proposed" if len(e["sessions"]) >= threshold(cfg, e["kind"]) else "watching"
            e = set_status(cfg, args.id, target)
            print(f"{e['id']} is {target} again.")
            return 0
        if args.cmd == "status":
            return cmd_status(cfg, args)
        if args.cmd == "digest":
            return cmd_digest(cfg, args)
    except Busy as e:
        print(f"tool-miner: {e}")
        return 0
    except MinerError as e:
        print(f"tool-miner: {e}", file=sys.stderr)
        return 1
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

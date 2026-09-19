#!/usr/bin/env python3
"""Convert Cursor composer conversations into pi JSONL sessions.

Source: ~/Library/Application Support/Cursor/User/globalStorage/state.vscdb
        - table cursorDiskKV:  composerData:<id>  and  bubbleId:<id>:<bid>
        - table composerHeaders: composerId, workspaceId, isSubagent, isArchived
Output: pi session JSONL files laid out as
        <out>/--<cwd with / as - -->--/<ISO-with-dashes>_<uuid>.jsonl

Only messages are emitted: user text, assistant text, assistant thinking.
Tool calls/results are intentionally dropped.
"""

import argparse
import glob
import hashlib
import json
import os
import re
import sqlite3
import sys
import urllib.parse
from datetime import datetime, timezone

CURSOR_USER = os.path.expanduser("~/Library/Application Support/Cursor/User")
STATE_DB = os.path.join(CURSOR_USER, "globalStorage/state.vscdb")
SEARCH_DB = os.path.join(CURSOR_USER, "globalStorage/conversation-search.db")
UNKNOWN_CWD = os.path.expanduser("~/cursor-import/unknown")

ZERO_COST = {"input": 0.0, "output": 0.0, "cacheRead": 0.0, "cacheWrite": 0.0, "total": 0.0}


def ms_to_iso(ms):
    dt = datetime.fromtimestamp(ms / 1000.0, timezone.utc)
    return dt.strftime("%Y-%m-%dT%H:%M:%S.") + f"{int(ms) % 1000:03d}Z"


def parse_iso(s):
    if not s:
        return None
    try:
        return int(datetime.strptime(s, "%Y-%m-%dT%H:%M:%S.%fZ")
                   .replace(tzinfo=timezone.utc).timestamp() * 1000)
    except ValueError:
        return None


def entry_id(seed):
    return hashlib.sha1(seed.encode("utf-8")).hexdigest()[:8]


def load_workspaces():
    ws = {}
    for wj in glob.glob(os.path.join(CURSOR_USER, "workspaceStorage/*/workspace.json")):
        h = os.path.basename(os.path.dirname(wj))
        try:
            with open(wj) as fh:
                d = json.load(fh)
            ws[h] = d.get("folder") or d.get("workspace")
        except Exception:
            pass
    return ws


def folder_from_uri(uri):
    """(path, origin) for a workspace folder URI, else (None, None)."""
    if not uri:
        return None, None
    if uri.startswith("file://"):
        return urllib.parse.unquote(uri[len("file://"):]), "local"
    if uri.startswith("vscode-remote://"):
        rest = uri[len("vscode-remote://"):]
        host, _, path = rest.partition("/")
        host = urllib.parse.unquote(host)
        path = "/" + path if path else "/"
        origin = host
        m = re.match(r"^ssh-remote\+(.+)$", host)
        if m:
            tail = m.group(1)
            try:
                origin = json.loads(bytes.fromhex(tail)).get("hostName", tail)
            except Exception:
                origin = tail
        return path, origin
    return None, None


def resolve_cwd(path, origin, depth=0):
    """Normalize a Cursor workspace folder URI path into a real directory.

    Multi-root workspaces point at a `.code-workspace` file (or a Cursor-managed
    workspace.json); pi requires cwd to be an existing directory, so unwrap those.
    """
    if not path or depth > 4:
        return path
    if path.endswith(".code-workspace"):
        # <root>/.vscode/<name>.code-workspace -> <root>
        return os.path.dirname(os.path.dirname(path))
    if path.endswith("/workspace.json"):
        try:
            with open(path) as fh:
                d = json.load(fh)
            for f in (d.get("folders") or []):
                p, o = folder_from_uri(f.get("uri") or f.get("path") or "")
                if p:
                    return resolve_cwd(p, o, depth + 1)
        except Exception:
            pass
        return None
    return path


def load_titles():
    titles = {}
    if not os.path.exists(SEARCH_DB):
        return titles
    try:
        con = sqlite3.connect(f"file:{SEARCH_DB}?mode=ro", uri=True)
        for cid, title in con.execute("SELECT id, title FROM conversations"):
            if title:
                titles[cid] = title.strip()
        con.close()
    except Exception:
        pass
    return titles


def usage_from(tok):
    tok = tok or {}
    inp = int(tok.get("inputTokens") or 0)
    out = int(tok.get("outputTokens") or 0)
    return {
        "input": inp,
        "output": out,
        "cacheRead": 0,
        "cacheWrite": 0,
        "totalTokens": inp + out,
        "cost": dict(ZERO_COST),
    }


def convert_composer(con, cid, model_name, created_ms, title, cwd, origin):
    row = con.execute("SELECT value FROM cursorDiskKV WHERE key=?", (f"composerData:{cid}",)).fetchone()
    if not row:
        return None
    try:
        cd = json.loads(row[0])
    except Exception:
        return None

    headers = cd.get("fullConversationHeadersOnly")
    if not headers:
        headers = [{"bubbleId": b, "type": 1} for b in (cd.get("conversation") or [])]

    # fetch all bubbles for this composer in one indexed scan
    bubbles = {}
    for key, value in con.execute(
            "SELECT key, value FROM cursorDiskKV WHERE key GLOB ?", (f"bubbleId:{cid}:*",)):
        bid = key.rsplit(":", 1)[1]
        try:
            bubbles[bid] = json.loads(value)
        except Exception:
            pass

    model_name = (model_name or (cd.get("modelConfig") or {}).get("modelName") or "cursor-unknown")
    title = title or (cd.get("name") or "").strip() or f"Cursor {cid[:8]}"
    created_ms = created_ms or cd.get("createdAt") or 0
    iso0 = ms_to_iso(created_ms)

    entries = []
    parent = [None]

    def add(entry_type, ts_ms, **fields):
        e = {"type": entry_type, "id": entry_id(f"{cid}:{entry_type}:{len(entries)}"),
             "parentId": parent[0], "timestamp": ms_to_iso(ts_ms or created_ms)}
        e.update(fields)
        entries.append(e)
        parent[0] = e["id"]

    add("session_info", created_ms, name=title)
    add("model_change", created_ms, provider="cursor", modelId=model_name)

    pending = []      # accumulating assistant blocks
    pending_ms = [None]
    pending_tok = [None]
    n_user = n_asst = 0

    def flush():
        nonlocal n_asst
        if not pending:
            pending.clear()
            return
        msg = {
            "role": "assistant",
            "content": list(pending),
            "api": "cursor",
            "provider": "cursor",
            "model": model_name,
            "usage": usage_from(pending_tok[0]),
            "stopReason": "stop",
            "timestamp": pending_ms[0] or created_ms,
        }
        add("message", pending_ms[0], message=msg)
        n_asst += 1
        pending.clear()

    for h in headers:
        bid = h.get("bubbleId")
        if not bid:
            continue
        obj = bubbles.get(bid)
        if not obj:
            continue
        btype = obj.get("type")
        ts = parse_iso(obj.get("createdAt")) or created_ms
        if btype == 1:
            flush()
            text = obj.get("text") or ""
            if not text.strip():
                continue
            msg = {"role": "user", "content": [{"type": "text", "text": text}], "timestamp": ts}
            add("message", ts, message=msg)
            n_user += 1
        elif btype == 2:
            thinking = obj.get("thinking")
            if isinstance(thinking, dict):
                thinking = thinking.get("text")
            text = obj.get("text")
            if not isinstance(text, str):
                text = "" if text is None else str(text)
            if not isinstance(thinking, str):
                thinking = ""
            has_t = bool(text.strip())
            has_k = bool(thinking.strip())
            if not has_t and not has_k:
                flush()          # tool-only bubble: end the assistant turn
                continue
            if not pending:
                pending_ms[0] = ts
                pending_tok[0] = obj.get("tokenCount")
            if has_k:
                pending.append({"type": "thinking", "thinking": thinking})
            if has_t:
                pending.append({"type": "text", "text": text})
    flush()

    if n_user == 0 and n_asst == 0:
        return None

    header = {"type": "session", "version": 3, "id": cid, "timestamp": iso0, "cwd": cwd}
    lines = [json.dumps(header, ensure_ascii=False)]
    lines += [json.dumps(e, ensure_ascii=False) for e in entries]

    cwd_dir = "--" + cwd.strip("/").replace("/", "-") + "--"
    fname = iso0.replace(":", "-").replace(".", "-") + f"_{cid}.jsonl"
    rel = os.path.join(cwd_dir, fname)
    return rel, lines, {"composerId": cid, "title": title, "cwd": cwd, "origin": origin,
                        "model": model_name, "userMsgs": n_user, "assistantMsgs": n_asst,
                        "path": rel}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.expanduser("~/cursor-import/sessions"))
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    workspaces = load_workspaces()
    titles = load_titles()
    con = sqlite3.connect(f"file:{STATE_DB}?mode=ro", uri=True)

    rows = con.execute(
        "SELECT composerId, workspaceId, createdAt FROM composerHeaders "
        "WHERE isSubagent=0 AND isArchived=0 ORDER BY recency DESC").fetchall()
    if args.limit:
        rows = rows[:args.limit]

    manifest = []
    written = skipped = 0
    by_origin = {}
    for cid, wid, created in rows:
        path, origin = folder_from_uri(workspaces.get(wid))
        if path:
            path = resolve_cwd(path, origin)
        if not path:
            cwd, origin = UNKNOWN_CWD, "unknown"
        else:
            cwd = path
        res = convert_composer(con, cid, None, created, titles.get(cid), cwd, origin)
        if not res:
            skipped += 1
            continue
        rel, lines, meta = res
        manifest.append(meta)
        by_origin[origin] = by_origin.get(origin, 0) + 1
        if not args.dry_run:
            dest = os.path.join(args.out, rel)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            with open(dest, "w", encoding="utf-8") as fh:
                fh.write("\n".join(lines) + "\n")
        written += 1

    con.close()
    if not args.dry_run:
        with open(os.path.join(args.out, "manifest.jsonl"), "w", encoding="utf-8") as fh:
            for m in manifest:
                fh.write(json.dumps(m, ensure_ascii=False) + "\n")

    print(f"written: {written}  skipped(empty): {skipped}  out: {args.out}")
    for k, v in sorted(by_origin.items(), key=lambda kv: -kv[1]):
        print(f"  {v:4}  {k}")


if __name__ == "__main__":
    main()

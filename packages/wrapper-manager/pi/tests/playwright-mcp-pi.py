"""Check the managed Playwright MCP end to end through Pi's MCP adapter.

  python3 tests/playwright-mcp-pi.py <pi wrapper binary>

Uses a throwaway config/HOME/project, a local web page and the real `mcp`
proxy tool, with no model calls. It checks that:
  - the wrapper merges the playwright server into Pi's mcp.json, switched off by
    default, resets managed keys, and keeps the user's servers, settings and
    their own `disabled` choice;
  - while disabled, agents cannot use it and no browser or server starts;
  - `/mcp enable playwright` + reload turns it on for that project, and an agent
    can then drive a page (connect, navigate, snapshot, click, console, screenshot);
  - screenshots land in the state directory, not in the project;
  - `/mcp disable` + reload turns it off again and stops the browser;
  - no browser process survives Pi exiting.
"""
import json
import os
import queue
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

wrapper = Path(sys.argv[1]).resolve()
PAGE = b"""<!doctype html><title>MCP via Pi</title><h1>Counter demo</h1>
<p id="c">Count: 0</p>
<button onclick="n++;document.getElementById('c').textContent='Count: '+n">Increment</button>
<script>var n=0;console.error('pi adapter console error');</script>"""


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        self.wfile.write(PAGE)

    def log_message(self, *_):
        pass


httpd = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
threading.Thread(target=httpd.serve_forever, daemon=True).start()
url = f"http://127.0.0.1:{httpd.server_port}/"


def descendants(pid):
    out = subprocess.run(["ps", "-axo", "pid=,ppid=,args="], capture_output=True, text=True).stdout
    rows = [(int(a), int(b), c) for a, b, c in (l.strip().split(None, 2) for l in out.splitlines() if l.strip())]
    found, frontier = {}, {pid}
    while frontier:
        nxt = {p: c for p, pp, c in rows if pp in frontier and p not in found}
        found.update(nxt)
        frontier = set(nxt)
    return found


with tempfile.TemporaryDirectory(prefix="pi-playwright-") as scratch:
    scratch = Path(scratch)
    home, config, project, state = (scratch / n for n in ("home", "config", "project", "state"))
    for d in (home, config, project, state):
        d.mkdir()
    env = {**os.environ, "HOME": str(home), "PI_CODING_AGENT_DIR": str(config), "XDG_STATE_HOME": str(state)}

    # 1. Config merge: user entries survive, managed keys are reset, off by default.
    (config / "mcp.json").write_text(json.dumps({
        "mcpServers": {
            "mine": {"command": "true"},
            "playwright": {"command": "/stale/path", "idleTimeout": 999, "directTools": False},
        },
        "settings": {"toolPrefix": "short"},
    }))
    subprocess.run([str(wrapper), "--version"], env=env, check=True, capture_output=True)
    merged = json.loads((config / "mcp.json").read_text())
    pw = merged["mcpServers"]["playwright"]
    assert pw["command"].endswith("/bin/playwright-mcp") and os.access(pw["command"], os.X_OK), pw
    assert (pw["lifecycle"], pw["idleTimeout"]) == ("lazy", 10), f"managed keys not reset: {pw}"
    assert pw["disabled"] is True, f"not off by default: {pw}"
    assert pw["directTools"] is False, "user-set key on the managed server was lost"
    assert merged["mcpServers"]["mine"] == {"command": "true"} and merged["settings"] == {"toolPrefix": "short"}
    before = (config / "mcp.json").stat().st_mtime_ns
    subprocess.run([str(wrapper), "--version"], env=env, check=True, capture_output=True)
    assert (config / "mcp.json").stat().st_mtime_ns == before, "second launch rewrote an up-to-date mcp.json"
    assert oct((config / "mcp.json").stat().st_mode & 0o777) == "0o600"
    # A user who turns it on globally keeps it on across launches.
    other = scratch / "config-enabled"
    other.mkdir()
    (other / "mcp.json").write_text(json.dumps({"mcpServers": {"playwright": {"disabled": False}}}))
    subprocess.run([str(wrapper), "--version"], env={**env, "PI_CODING_AGENT_DIR": str(other)}, check=True, capture_output=True)
    kept = json.loads((other / "mcp.json").read_text())["mcpServers"]["playwright"]
    assert kept["disabled"] is False and kept["command"].endswith("/bin/playwright-mcp"), kept
    print("PASS: merged and off by default; user servers/settings/keys and their own `disabled` kept; idempotent; mode 600")

    # 2. Drive the page through the real adapter.
    adapter = next(p for p in json.loads((config / "settings.json").read_text())["packages"] if "pi-mcp-adapter" in p)
    (scratch / "fixture.ts").write_text(f'''
import adapter from {json.dumps(adapter + "/index.ts")};
export default function(pi) {{
  const tools = new Map();
  const wrapped = new Proxy(pi, {{ get(t, k) {{ if (k === "registerTool") return (d) => {{ tools.set(d.name, d); t.registerTool(d); }}; return Reflect.get(t, k); }} }});
  adapter(wrapped);
  pi.registerCommand("probe", {{ handler: async (args, ctx) => {{
    try {{
      const r = await tools.get("mcp").execute("x", JSON.parse(args), undefined, undefined, ctx);
      ctx.ui.notify("RESULT " + JSON.stringify(r.content.map(c => c.type === "text" ? {{type: "text", text: c.text}} : {{type: c.type, bytes: (c.data || "").length}})), "info");
    }} catch (e) {{ ctx.ui.notify("ERROR " + (e && e.message || e), "info"); }}
  }}}});
  pi.registerCommand("reload-fixture", {{ handler: async (_args, ctx) => {{ await ctx.reload(); }} }});
}}
''')
    proc = subprocess.Popen(
        [str(wrapper), "--mode", "rpc", "--no-session", "--no-extensions", "--no-skills", "--no-context-files", "-e", str(scratch / "fixture.ts")],
        cwd=project, env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    events = queue.Queue()
    threading.Thread(target=lambda: [events.put(l) for l in proc.stdout], daemon=True).start()
    counter = [0]

    def command(message, timeout=90):
        """Run a slash command; return the notifications it produced."""
        counter[0] += 1
        ident = f"c{counter[0]}"
        proc.stdin.write(json.dumps({"type": "prompt", "message": message, "id": ident}) + "\n")
        proc.stdin.flush()
        notes, deadline = [], time.time() + timeout
        while time.time() < deadline:
            try:
                e = json.loads(events.get(timeout=1))
            except Exception:
                continue
            if e.get("method") == "notify":
                notes.append(e.get("message", ""))
            if e.get("id") == ident:
                return notes
        raise AssertionError(f"{message}: no response; notifications: {notes}")

    def probe_raw(**params):
        notes = command("/probe " + json.dumps(params))
        return next((n for n in notes if n.startswith(("RESULT ", "ERROR "))), None)

    def probe(**params):
        result = probe_raw(**params)
        assert result and result.startswith("RESULT "), f"{params}: {(result or 'no result')[:400]}"
        blocks = json.loads(result[7:])
        return "\n".join(b["text"] for b in blocks if b["type"] == "text"), [b for b in blocks if b["type"] != "text"]

    def browsers():
        return [c for c in descendants(proc.pid).values() if re.search(r"chrom|playwright", c, re.I)]

    try:
        # Off by default: not usable, nothing starts.
        for params in ({"server": "playwright"}, {"tool": "playwright_browser_navigate", "args": {"url": url}}):
            result = probe_raw(**params) or ""
            assert "playwright_browser_navigate - " not in result and "Counter demo" not in result, f"usable while disabled: {result[:300]}"
        print("      while disabled, the mcp tool says:", " ".join((probe_raw(server="playwright") or "").split())[:160])
        assert not browsers(), "a browser or MCP server started while disabled"
        print("PASS: disabled by default; agents cannot use it and nothing is started")

        # Turn it on for this project with /mcp, then reload.
        notes = command("/mcp enable playwright")
        assert any("Enabled" in n for n in notes), notes
        override = json.loads((project / ".pi" / "mcp.json").read_text())
        assert override == {"mcpServers": {"playwright": {"disabled": False}}}, override
        command("/reload-fixture")
        print("PASS: /mcp enable playwright wrote a per-project override:", json.dumps(override))

        # A cold tool cache is filled in the background after startup, so the first
        # listing can say "not connected". Observe how an agent would experience it.
        listing, started = "", time.time()
        for _ in range(10):
            listing, _ = probe(server="playwright")
            if "playwright_browser_navigate" in listing:
                print(f"INFO: tool listing available {time.time() - started:.0f}s after reload, no explicit connect needed")
                break
            print("INFO: first listing said:", " ".join(listing.split())[:140])
            time.sleep(2)
        else:
            probe(connect="playwright")
            listing, _ = probe(server="playwright")
            print("INFO: listing needed an explicit mcp({ connect: \"playwright\" })")
        assert "playwright_browser_navigate" in listing, listing[:500]
        print("tool listing sample:", " ".join(listing.split())[:200])
        # Through the adapter's proxy, tools carry the server name as a prefix.
        text, _ = probe(tool="playwright_browser_navigate", args={"url": url})
        assert "Counter demo" in text or "MCP via Pi" in text, text[:400]
        snap, _ = probe(tool="playwright_browser_snapshot", args={})
        ref = re.search(r'button "Increment"[^\n]*\[ref=(e\d+)\]', snap)
        assert ref and "Count: 0" in snap, snap[:500]
        probe(tool="playwright_browser_click", args={"element": "Increment button", "target": ref.group(1)})
        snap, _ = probe(tool="playwright_browser_snapshot", args={})
        assert "Count: 1" in snap, snap[:500]
        console, _ = probe(tool="playwright_browser_console_messages", args={"level": "error"})
        assert "pi adapter console error" in console, console
        shot, images = probe(tool="playwright_browser_take_screenshot", args={"type": "png"})
        assert images and images[0]["bytes"] > 1000, f"no inline screenshot: {shot[:300]} {images}"
        print("PASS: after enabling, connect, navigate, snapshot, click by ref, console, inline screenshot via the mcp tool")

        pngs = list(state.rglob("*.png"))
        assert pngs, f"no screenshot under {state}"
        stray = [str(q.relative_to(project)) for q in project.rglob("*") if q.is_file() and not str(q).startswith(str(project / ".pi"))]
        assert not stray, f"files written into the project: {stray}"
        print(f"PASS: screenshot saved under the state dir ({pngs[0].relative_to(state)}); the only project file is .pi/mcp.json")

        running = browsers()
        assert running and any("--headless" in c for c in running), "expected a headless browser under Pi"
        browser_pids = list(descendants(proc.pid))

        # Turn it off again: reload stops the server and its browser.
        notes = command("/mcp disable playwright")
        assert any("Disabled" in n for n in notes), notes
        command("/reload-fixture")
        time.sleep(3)
        assert not browsers(), f"browser still running after disabling: {browsers()}"
        result = probe_raw(tool="playwright_browser_navigate", args={"url": url}) or ""
        assert "Counter demo" not in result, "still usable after /mcp disable"
        print("PASS: /mcp disable + reload turns it off and stops the browser")
    finally:
        proc.terminate()
        try:
            proc.wait(15)
        except subprocess.TimeoutExpired:
            proc.kill()
        httpd.shutdown()

    time.sleep(3)
    alive = [p for p in browser_pids if os.path.exists(f"/proc/{p}") or subprocess.run(["kill", "-0", str(p)], capture_output=True).returncode == 0]
    assert not alive, f"processes survived: {alive}"
    print("PASS: no MCP server or browser processes left after Pi exits")

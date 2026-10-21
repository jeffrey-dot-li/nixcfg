"""Drive a playwright-mcp binary over stdio against a local page.

  python3 tests/playwright-mcp.py <playwright-mcp binary> [extra server args...]

No model calls, no network access beyond 127.0.0.1. Checks that an agent can
iterate on a page without manual screenshots: navigate, read the accessibility
snapshot, click via snapshot refs, read console messages and failed requests,
and take a screenshot. Also checks that the browser runs headless and that no
browser processes survive the server.
"""
import base64
import json
import os
import re
import signal
import subprocess
import sys
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

binary, extra = sys.argv[1], [a for a in sys.argv[2:] if a != "--expect-clean-cwd"]
expect_clean_cwd = "--expect-clean-cwd" in sys.argv[2:]

PAGE = b"""<!doctype html><title>Playwright MCP test</title>
<h1>Counter demo</h1>
<p id="count">Count: 0</p>
<button onclick="n++;document.getElementById('count').textContent='Count: '+n;console.log('clicked '+n)">Increment</button>
<script>
  var n = 0;
  console.log('page loaded');
  console.error('deliberate console error');
  fetch('/missing.json').catch(function () {});
</script>"""


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith("/index"):
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            self.wfile.write(PAGE)
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, *_):
        pass


httpd = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
threading.Thread(target=httpd.serve_forever, daemon=True).start()
url = f"http://127.0.0.1:{httpd.server_port}/index.html"


def descendants(pid):
    out = subprocess.run(["ps", "-axo", "pid=,ppid=,args="], capture_output=True, text=True).stdout
    rows = [(int(a), int(b), c) for a, b, c in (l.strip().split(None, 2) for l in out.splitlines() if l.strip())]
    found, frontier = [], {pid}
    while frontier:
        nxt = {p for p, pp, _ in rows if pp in frontier and p not in {f[0] for f in found}}
        found += [r for r in rows if r[0] in nxt]
        frontier = nxt
    return found


with tempfile.TemporaryDirectory(prefix="playwright-mcp-test-") as scratch:
    work = os.path.join(scratch, "project")
    state = os.path.join(scratch, "state")
    os.makedirs(work)
    env = {**os.environ, "XDG_STATE_HOME": state}
    proc = subprocess.Popen([binary, *extra], cwd=work, env=env, stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    next_id = [0]

    def rpc(method, params=None, notify=False, timeout=60):
        msg = {"jsonrpc": "2.0", "method": method}
        if params is not None:
            msg["params"] = params
        if not notify:
            next_id[0] += 1
            msg["id"] = next_id[0]
        proc.stdin.write(json.dumps(msg) + "\n")
        proc.stdin.flush()
        if notify:
            return None
        result = {}

        def read():
            while True:
                line = proc.stdout.readline()
                if not line:
                    result["eof"] = True
                    return
                data = json.loads(line)
                if data.get("id") == msg["id"]:
                    result["r"] = data
                    return

        t = threading.Thread(target=read, daemon=True)
        t.start()
        t.join(timeout)
        assert "r" in result, f"{method}: no response ({'eof' if result.get('eof') else 'timeout'}); stderr: {proc.stderr.read() if proc.poll() is not None else ''}"
        assert "error" not in result["r"], f"{method}: {result['r']['error']}"
        return result["r"]["result"]

    def call(name, **args):
        res = rpc("tools/call", {"name": name, "arguments": args})
        assert not res.get("isError"), f"{name} failed: {res['content']}"
        text = "\n".join(c["text"] for c in res["content"] if c["type"] == "text")
        return text, [c for c in res["content"] if c["type"] == "image"]

    try:
        info = rpc("initialize", {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "test", "version": "0"}})
        rpc("notifications/initialized", notify=True)
        tools = {t["name"] for t in rpc("tools/list")["tools"]}
        needed = {"browser_navigate", "browser_snapshot", "browser_click", "browser_take_screenshot",
                  "browser_console_messages", "browser_network_requests", "browser_evaluate", "browser_close"}
        assert needed <= tools, f"missing tools: {sorted(needed - tools)}"
        print(f"server {info['serverInfo']['name']} {info['serverInfo'].get('version')}; {len(tools)} tools")

        text, _ = call("browser_navigate", url=url)
        assert "Counter demo" in text or "Playwright MCP test" in text, text[:400]
        snap, _ = call("browser_snapshot")
        assert "Counter demo" in snap and "Count: 0" in snap, snap[:600]
        ref = re.search(r'button "Increment"[^\n]*\[ref=(e\d+)\]', snap)
        assert ref, f"no button ref in snapshot:\n{snap[:800]}"
        call("browser_click", element="Increment button", target=ref.group(1))
        snap2, _ = call("browser_snapshot")
        assert "Count: 1" in snap2, snap2[:600]
        print("PASS: navigate, accessibility snapshot, click by ref, state change observed")

        console, _ = call("browser_console_messages", level="info")
        assert "deliberate console error" in console, console
        net, _ = call("browser_network_requests", static=False)
        assert "missing.json" in net and "404" in net, net
        print("PASS: console messages and failed network request visible to the agent")

        shot_text, images = call("browser_take_screenshot", type="png")
        assert images, f"no inline image in response: {shot_text[:300]}"
        data = base64.b64decode(images[0]["data"])
        assert data[:8] == b"\x89PNG\r\n\x1a\n", "screenshot is not a PNG"
        link = re.search(r"\]\(([^)]+\.png)\)", shot_text)
        assert link, f"no screenshot path in response: {shot_text[:300]}"
        shot_path = os.path.normpath(os.path.join(work, link.group(1)))
        assert os.path.exists(shot_path), f"reported screenshot file missing: {shot_path}"
        where = "state dir" if shot_path.startswith(state) else "project dir" if shot_path.startswith(work) else "elsewhere"
        print(f"PASS: screenshot returned inline ({len(data)} bytes) and saved in the {where}: {link.group(1)}")
        if expect_clean_cwd:
            assert where == "state dir", f"screenshot not in the state dir: {shot_path}"
            stray = [str(q.relative_to(work)) for q in Path(work).rglob("*")]
            assert not stray, f"files written into the project directory: {stray}"
            print("PASS: nothing written into the project directory")
        procs = descendants(proc.pid)
        browser = [a for _, _, a in procs if re.search(r"chrom|headless_shell", a, re.I)]
        assert browser, "no browser process found under the server"
        headless = any("--headless" in a for a in browser)
        print(f"browser processes under server: {len(procs)}; headless flag present: {headless}")
        if "--headless" in extra or expect_clean_cwd or os.environ.get("PLAYWRIGHT_MCP_HEADLESS") in ("1", "true"):
            assert headless, "expected a headless browser"
        browser_pids = [p for p, _, _ in procs]
    finally:
        proc.send_signal(signal.SIGTERM)
        try:
            proc.wait(10)
        except subprocess.TimeoutExpired:
            proc.kill()

    time.sleep(3)
    alive = []
    for pid in browser_pids:
        try:
            os.kill(pid, 0)
            alive.append(pid)
        except ProcessLookupError:
            pass
    assert not alive, f"browser processes survived server shutdown: {alive}"
    print("PASS: no browser processes left after the server exits")
    httpd.shutdown()

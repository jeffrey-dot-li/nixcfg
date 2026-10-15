"""python3 tests/task-inherit-path.py <patched-bg-package> <pi-binary>
Starts real bg tasks under fish, bash and zsh login shells and checks that
Pi's PATH order (a marker dir with a quote and space in a neighbour) and its
working directory are inherited. No model calls."""
import json, os, queue, shutil, subprocess, sys, tempfile, threading, time
from pathlib import Path

package, binary = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
FIXTURE = '''
import backgroundTasks from %s;
export default function(pi) {
  const tools = new Map();
  const wrapped = new Proxy(pi, { get(t, k) { if (k === "registerTool") return (d) => { tools.set(d.name, d); t.registerTool(d); }; return Reflect.get(t, k); } });
  backgroundTasks(wrapped);
  pi.registerCommand("probe", { handler: async (args, ctx) => {
    const r = await tools.get("task_start").execute("x", { command: args, name: "probe" }, undefined, undefined, ctx);
    ctx.ui.notify("LOG " + r.details.logPath, "info");
  }});
}
'''
with tempfile.TemporaryDirectory(prefix="bg-inherit-path-") as t:
    t = Path(t)
    for d in ("proj", "config", "state", "marker-bin"):
        (t / d).mkdir()
    (t / "fixture.ts").write_text(FIXTURE % json.dumps(str(package / "dist/index.js")))
    marker = str(t / "marker-bin")
    awkward = str(t / "it's a dir")
    results = []
    for shell in filter(None, [shutil.which("fish"), "/bin/bash", "/bin/zsh"]):
        env = {**os.environ, "PI_CODING_AGENT_DIR": str(t / "config"), "PI_BACKGROUND_TASK_STATE_DIR": str(t / "state"),
               "SHELL": shell, "PATH": f"{marker}:{awkward}:{os.environ['PATH']}"}
        p = subprocess.Popen([str(binary), "--mode", "rpc", "--no-session", "--no-extensions", "--no-skills", "--no-context-files", "-e", str(t / "fixture.ts")],
                             cwd=t / "proj", env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        q = queue.Queue(); threading.Thread(target=lambda: [q.put(l) for l in p.stdout], daemon=True).start()
        p.stdin.write(json.dumps({"type": "prompt", "message": '/probe pwd; echo "PATH-IS:$PATH"', "id": "1"}) + "\n"); p.stdin.flush()
        log, deadline = None, time.time() + 15
        while log is None and time.time() < deadline:
            try: e = json.loads(q.get(timeout=1))
            except Exception: continue
            if e.get("method") == "notify" and e["message"].startswith("LOG "): log = e["message"][4:]
        assert log, f"{shell}: task did not start"
        time.sleep(3); p.terminate()
        out = Path(log).read_text()
        line = next(l for l in out.splitlines() if "PATH-IS:" in l)
        # fish joins its PATH list with spaces when echoed; normalise to colons.
        got = line.split("PATH-IS:", 1)[1].replace(" ", ":") if "fish" in shell else line.split("PATH-IS:", 1)[1]
        assert got.startswith(f"{marker}:"), f"{shell}: Pi PATH not first: {got[:120]}"
        assert os.path.realpath(t / "proj") in [os.path.realpath(l) for l in out.splitlines()], f"{shell}: cwd not inherited"
        results.append(os.path.basename(shell))
    print("PASS: Pi PATH order and cwd inherited under", ", ".join(results))

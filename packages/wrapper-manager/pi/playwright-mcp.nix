# Playwright MCP for Pi agents, built from nixpkgs.
#
# Differences from the plain nixpkgs package:
#   - Chromium only (no Firefox/WebKit), keeping the closure much smaller.
#   - Headless by default, so it works on VMs without a display and does not
#     steal focus on macOS. Set PLAYWRIGHT_MCP_HEADLESS=0 to watch the browser.
#   - Screenshots and other output files go to the user's state directory
#     instead of `.playwright-mcp/` in whatever project the agent is working
#     in, with old files evicted once the directory passes ~256 MiB.
# Every default below is overridable from the environment Pi was launched in.
{
  lib,
  runCommand,
  makeWrapper,
  playwright-mcp,
  playwright-driver,
  playwright-test,
}: let
  # Full Chromium only: no Firefox, WebKit or separate headless shell.
  chromiumOnly = playwright-driver.browsers-chromium;
  # playwright-mcp only links node_modules out of playwright-test, but that
  # package's bin/playwright wrapper references the full browser set, which
  # would pull Firefox and WebKit back into the closure. Copy just the modules.
  nodeModules = runCommand "playwright-node-modules-${playwright-test.version}" {} ''
    mkdir -p $out/lib
    cp -r ${playwright-test}/lib/node_modules $out/lib/node_modules
  '';
  base = playwright-mcp.override {
    playwright-driver = playwright-driver // {browsers = chromiumOnly;};
    playwright-test = nodeModules;
  };
in
  runCommand "playwright-mcp-pi-${playwright-mcp.version}" {
    nativeBuildInputs = [makeWrapper];
    meta = {
      description = "Playwright MCP with headless Chromium and out-of-tree output";
      mainProgram = "playwright-mcp";
      inherit (playwright-mcp.meta) platforms license;
    };
  } ''
    makeWrapper ${lib.getExe base} $out/bin/playwright-mcp \
      --set-default PLAYWRIGHT_MCP_HEADLESS 1 \
      --set-default PLAYWRIGHT_MCP_OUTPUT_MAX_SIZE 268435456 \
      --run 'export PLAYWRIGHT_MCP_OUTPUT_DIR="''${PLAYWRIGHT_MCP_OUTPUT_DIR:-''${XDG_STATE_HOME:-$HOME/.local/state}/pi/playwright-mcp}"'
  ''

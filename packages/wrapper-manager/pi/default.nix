{pkgs, ...}: let
  inherit (pkgs) lib;
  version = "1.5.0";

  mkPiPackage = {
    pname,
    version,
    owner,
    repo,
    rev,
    hash,
    npmDepsHash,
    patches ? [],
  }:
    pkgs.buildNpmPackage {
      inherit pname version npmDepsHash patches;

      src = pkgs.fetchFromGitHub {
        inherit owner repo rev hash;
      };

      dontNpmBuild = true;
      # Pi supplies its own peer packages. Keeping development and peer
      # dependencies would duplicate Pi's SDK and considerably enlarge these
      # runtime-only package closures.
      postPatch = ''
        ${pkgs.jq}/bin/jq \
          'del(.devDependencies, .peerDependencies, .peerDependenciesMeta)' \
          package.json > package.json.tmp
        mv package.json.tmp package.json

        ${pkgs.jq}/bin/jq '
          .packages[""] |= del(.devDependencies, .peerDependencies, .peerDependenciesMeta)
          | .packages |= with_entries(select(
              .key == "" or (.value.link != true and .value.integrity != null)
            ))
        ' package-lock.json > package-lock.json.tmp
        mv package-lock.json.tmp package-lock.json
      '';
      npmFlags = [
        "--ignore-scripts"
        "--omit=dev"
        "--omit=peer"
      ];

      installPhase = ''
        runHook preInstall
        mkdir -p $out
        cp -R . $out/
        runHook postInstall
      '';
    };

  mkRpivPackage = {
    pname,
    workspace,
    version,
    rev,
    hash,
    npmDepsHash,
    patches ? [],
  }:
    pkgs.buildNpmPackage {
      inherit pname version npmDepsHash;

      src = pkgs.fetchFromGitHub {
        owner = "juicesharp";
        repo = "rpiv-mono";
        inherit rev hash;
      };

      dontNpmBuild = true;
      postPatch = ''
        ${lib.concatMapStringsSep "\n" (p: "patch -d packages/${workspace} -p1 < ${p}") patches}

        ${pkgs.jq}/bin/jq \
          'del(.devDependencies, .peerDependencies, .peerDependenciesMeta)' \
          packages/${workspace}/package.json > package.json.tmp
        mv package.json.tmp packages/${workspace}/package.json

        ${pkgs.jq}/bin/jq \
          '{name, version, private: true, workspaces: ["packages/${workspace}", "packages/rpiv-config"]}' \
          package.json > package.json.tmp
        mv package.json.tmp package.json

        ${pkgs.jq}/bin/jq --arg workspace '${workspace}' '
          .packages[""] = {
            "name": "rpiv-mono",
            "version": "0.0.0",
            "workspaces": ["packages/" + $workspace, "packages/rpiv-config"]
          }
          | .packages["packages/" + $workspace]
              |= del(.devDependencies, .peerDependencies, .peerDependenciesMeta)
          | [
              "",
              "packages/" + $workspace,
              "packages/rpiv-config",
              "node_modules/@juicesharp/" + $workspace,
              "node_modules/@juicesharp/rpiv-config",
              "node_modules/typebox"
            ] as $keep
          | .packages |= with_entries(select(.key as $key | $keep | index($key)))
        ' package-lock.json > package-lock.json.tmp
        mv package-lock.json.tmp package-lock.json
      '';
      npmFlags = [
        "--ignore-scripts"
        "--omit=dev"
        "--omit=peer"
      ];

      installPhase = ''
        runHook preInstall
        mkdir -p $out/node_modules/@juicesharp
        cp -R packages/${workspace}/. $out/
        # rpiv >= 2.15 declares typebox as a peer: Pi maps `typebox` imports to
        # its own copy, so only older releases bundle it.
        if [ -e node_modules/typebox ]; then cp -RL node_modules/typebox $out/node_modules/; fi
        cp -RL node_modules/@juicesharp/rpiv-config $out/node_modules/@juicesharp/
        runHook postInstall
      '';
    };

  piBackgroundTask =
    pkgs.runCommand "pi-background-task-0.1.1" {
      nativeBuildInputs = [pkgs.gnutar pkgs.gzip pkgs.patch];
    } ''
      mkdir -p source "$out"
      tar -xzf ${pkgs.fetchurl {
        url = "https://registry.npmjs.org/pi-background-task/-/pi-background-task-0.1.1.tgz";
        hash = "sha256-bilQUdku/nsReCn9d9ykeU/wFj3fLJZohDwR1JRmIZM=";
      }} -C source --strip-components=1
      cp -R source/. "$out/"
      chmod -R u+w "$out"
      patch -d "$out" -p1 < ${./patches/pi-background-task-ux.patch}
      patch -d "$out" -p1 < ${./patches/pi-background-task-reminders.patch}
      patch -d "$out" -p1 < ${./patches/pi-background-task-inherit-path.patch}
      cp ${./background-task/reminders.js} "$out/dist/reminders.js"
      substituteInPlace "$out/dist/tmux.js" \
        --replace-fail '"@node@"' '"${pkgs.nodejs}/bin/node"'
    '';

  managedResourcePackage = pkgs.runCommand "pi-managed-resources-1.0.12" {} ''
    mkdir -p "$out"
    cp -R ${./agents} "$out/agents"
    cp -R ${./extensions} "$out/extensions"
    cp ${./AGENTS.md} "$out/AGENTS.md"
    cat > "$out/package.json" <<'JSON'
    {
      "name": "pi-managed-resources",
      "version": "1.0.12",
      "pi": {
        "extensions": [
          "./extensions/load-universal-agents.ts",
          "./extensions/guard-invalid-slash.ts",
          "./extensions/load-local-agents.ts",
          "./extensions/expand-bash-command.ts",
          "./extensions/queue-input-follow-up.ts",
          "./extensions/static-working-indicator.ts",
          "./extensions/session-info-status.ts",
          "./extensions/undo-last-message.ts",
          "./extensions/clipboard-tools.ts"
        ],
        "subagents": {
          "agents": ["./agents"]
        }
      }
    }
    JSON
  '';

  piPackages = [
    managedResourcePackage
    piBackgroundTask
    (mkPiPackage {
      pname = "pi-subagents";
      version = "0.84.0";
      owner = "nicobailon";
      repo = "pi-subagents";
      rev = "0398b9e8d6f03dc6054dbf13dfe851c7a20bff3a";
      hash = "sha256-yJHclk8TqJX0OGDteZYAbcW9qGDY9a8BSVy0kxcRpEU=";
      npmDepsHash = "sha256-PaqVPgvezGFlx6gjwN85W73/FJSjdntyCEHI6ztpTsQ=";
    })
    (mkPiPackage {
      pname = "pi-web-access";
      version = "0.46.0";
      owner = "nicobailon";
      repo = "pi-web-access";
      rev = "4af1a7f7757d450ba0afefe2d98737384dc9a9b4";
      hash = "sha256-i/C22ovZYwUu3a7gzBeFVaMqvhIB+N/Z63wOCPdhwLs=";
      npmDepsHash = "sha256-aUiVi6IISo9DTfhtK/3+GVErsMhjFH1+9sMqSDaydUU=";
    })
    (mkPiPackage {
      pname = "pi-mcp-adapter";
      version = "7.0.1";
      patches = [./patches/pi-mcp-google-duration.patch];
      owner = "nicobailon";
      repo = "pi-mcp-adapter";
      rev = "0beff98460567cd228ae08d99db5f169a1ad3034";
      hash = "sha256-OyHd9Se7HDjbu8K668Q8/Z+sq83apfqHoKn72N8PBqg=";
      npmDepsHash = "sha256-4H3POKrLKvKP/06Wrw5PGb6JuzePpBm1f5LvvY7a3hE=";
    })
    (mkPiPackage {
      pname = "pi-cc-extensions";
      version = "1.0.14";
      owner = "minuque";
      repo = "pi-cc-extensions";
      rev = "562d687829a0048081efd71d7433dcda73d7f085";
      patches = [./patches/pi-cc-extensions-compact-footer.patch];
      hash = "sha256-NPpKC+xTXFdwWxt1kddjtEqjrgAxd9K/s9H1NhZsojU=";
      npmDepsHash = "sha256-kWkBAnEMQ3YJLps7FunEmZbR7MmTqGQKrWT4rc8mXF0=";
    })
    (mkRpivPackage {
      pname = "rpiv-ask-user-question";
      workspace = "rpiv-ask-user-question";
      version = "2.15.0";
      rev = "ce6d3530410812ca504ec294995581a52170f9e1";
      hash = "sha256-L+c/p6yhTDznxszJ8kkAxxGEWfizf5rFbXmiIGClWKg=";
      npmDepsHash = "sha256-Lr0OmixTQ6C/09MwipnWeGdX6f45oKaXRrwgE8V8nRs=";
    })
    (mkRpivPackage {
      pname = "rpiv-todo";
      workspace = "rpiv-todo";
      version = "2.15.0";
      rev = "ce6d3530410812ca504ec294995581a52170f9e1";
      hash = "sha256-L+c/p6yhTDznxszJ8kkAxxGEWfizf5rFbXmiIGClWKg=";
      npmDepsHash = "sha256-y+HhU6F59RCSHi3an9/+2AEt37bGGDeTIVtdAG5yAoI=";
      patches = [./patches/rpiv-todo-reset.patch];
    })
  ];

  managedPackages = builtins.toJSON (map toString piPackages);
  managedSubagents = builtins.toJSON {
    agentOverrides = {
      monitor = {
        model = "agent-control-plane/gpt-6-luna";
        thinking = "low";
      };
      scout = {
        model = "agent-control-plane/gpt-6-luna";
        thinking = "high";
      };
      delegate = {
        model = "cohere-oss-v2/deepseek-v4-1-flash";
        thinking = "high";
      };
      worker = {
        model = "agent-control-plane/gpt-6.1-sol";
        thinking = "medium";
      };
      reviewer = {
        model = "agent-control-plane/gpt-6.1-sol";
        thinking = "medium";
      };
      researcher = {
        model = "agent-control-plane/gpt-6.1-sol";
        thinking = "medium";
      };
      evidence-auditor = {
        model = "agent-control-plane/gpt-6.1-sol";
        thinking = "medium";
      };
      oracle = {
        model = "agent-gateway-dev/us.openai.gpt-6-astra";
        thinking = "off";
      };
    };
  };
  # Headless Chromium for agents to drive web pages themselves (navigate,
  # accessibility snapshots, clicks, console/network, screenshots).
  playwrightMcp = pkgs.callPackage ./playwright-mcp.nix {};
  hasPlaywrightMcp = lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.playwright-mcp;
  # Merged into pi-mcp-adapter's <Pi agent dir>/mcp-adapter.json (not the shared
  # ~/.config/mcp/mcp.json) so the store path can change on every update without
  # touching other tools' config.
  managedMcpServers = builtins.toJSON {
    mcpServers = lib.optionalAttrs hasPlaywrightMcp {
      playwright = {
        command = lib.getExe playwrightMcp;
        lifecycle = "lazy";
        # Closes the browser after ten idle minutes so it cannot linger.
        idleTimeout = 10;
      };
    };
  };
  # Defaults applied only when the key is absent, so a user's own choice wins.
  # Playwright stays off until enabled: `/mcp-adapter enable playwright` (per
  # project, then `/reload`) or `"disabled": false` in
  # <Pi agent dir>/mcp-adapter.json (everywhere).
  managedMcpDefaults = builtins.toJSON {
    mcpServers = lib.optionalAttrs hasPlaywrightMcp {
      playwright.disabled = true;
    };
    # Footer chip "MCP <connected>/<enabled>" instead of
    # "🔌 MCP: 1 server enabled (1 disabled)".
    settings.mcpFooterStatus = "compact";
  };
  # pi-cc-extensions draws the footer (it replaces pi-footer's). Laid out for
  # half-width VS Code panes: two lines, most important chips first because
  # lines truncate from the right. The compact footer patch shows the model
  # name instead of provider/id, the context percentage without a bar, and the
  # git branch without stats, and drops the session name from the cwd chip
  # (session-info shows it). Nerd icons are off: VS Code's terminal font has
  # no Nerd Font glyphs. Plugin chips are setStatus keys: pi-background-task,
  # mcp (pi-mcp-adapter), session-info (managed extension); unlisted ones are
  # appended to line 2.
  managedCcFooter = builtins.toJSON {
    enableCustomFooter = true;
    footerNerdIcons = false;
    footerTokenRate = false;
    footerSessionTokens = false;
    footerHiddenKeys = ["rate" "tokens"];
    footerLine1Keys = ["model" "context" "cache" "cost" "pi-usage"];
    footerLine2Keys = ["cwd" "git" "pi-background-task" "mcp" "session-info"];
    footerLine3Keys = [];
  };
  managedKeybindings = builtins.toJSON {
    "tui.altScreen.previousPrompt" = "ctrl+shift+up";
    "tui.altScreen.nextPrompt" = "ctrl+shift+down";
    "app.message.followUp" = "alt+enter";
    # Ctrl+X belongs to the managed clipboard-tools extension (cut the prompt,
    # else copy the last response); Pi reserves app.message.copy's key from
    # extensions, so the built-in copy (/tree message, sign-in URL) moves here.
    "app.message.copy" = "ctrl+shift+x";
    # Same for the scoped-model picker's "clear all", so Ctrl+Shift+X is
    # consistently "Pi's built-in Ctrl+X" and startup shows no conflict warning.
    "app.models.clearAll" = "ctrl+shift+x";
    "tui.input.newLine" = [
      "ctrl+enter"
      "shift+enter"
      "ctrl+j"
    ];
    "tui.input.submit" = "enter";
    "app.message.dequeue" = [
      "ctrl+q"
      "alt+up"
    ];
  };
  loadMcpOAuthKey = pkgs.writeText "load-pi-mcp-oauth-key.sh" ''
    pi_mcp_oauth_key_file="''${XDG_CONFIG_HOME:-$HOME/.config}/pi-mcp-adapter/oauth-file-key"
    if [ -z "''${PI_MCP_ADAPTER_OAUTH_FILE_KEY-}" ] && [ -r "$pi_mcp_oauth_key_file" ]; then
      PI_MCP_ADAPTER_OAUTH_FILE_KEY=$(tr -d '[:space:]' < "$pi_mcp_oauth_key_file")
      export PI_MCP_ADAPTER_OAUTH_FILE_KEY
    fi
    unset pi_mcp_oauth_key_file
  '';
  # configurePackages also adds -builtin:mcp to `extensions`: pi-mcp-adapter
  # replaces Pi's built-in MCP (both read the same mcp.json and register /mcp).
  # The adapter turns the built-in off itself only when installed with
  # `pi install`, which never happens for Nix-managed packages.
  configurePackages = pkgs.writeShellScript "configure-pi-packages" ''
    config_dir="''${PI_CODING_AGENT_DIR:-"$HOME/.pi/agent"}"
    settings="$config_dir/settings.json"
    mkdir -p "$config_dir"

    tmp=$(mktemp "$config_dir/.settings.json.XXXXXX")
    trap 'rm -f "$tmp" "$tmp.input"' EXIT

    if [ -f "$settings" ]; then
      input="$settings"
    else
      printf '{}\n' > "$tmp.input"
      input="$tmp.input"
    fi

    ${pkgs.jq}/bin/jq \
      --argjson managed '${managedPackages}' \
      --argjson managedSubagents '${managedSubagents}' '
      def source:
        if type == "string" then .
        elif type == "object" then (.source // "")
        else ""
        end;
      def managed_by_nix:
        source as $source
        | ($source == "npm:pi-bg")
          or ($source | startswith("npm:pi-bg@"))
          or ($source == "git:github.com/Bukutsu/pi-bg")
          or ($source | startswith("git:github.com/Bukutsu/pi-bg@"))
          or ($source == "npm:pi-background-task")
          or ($source | startswith("npm:pi-background-task@"))
          or ($source == "git:github.com/ZKiteLM/pi-background-task")
          or ($source | startswith("git:github.com/ZKiteLM/pi-background-task@"))
          or ($source == "npm:@smoose/pi-footer")
          or ($source | startswith("npm:@smoose/pi-footer@"))
          or ($source == "git:github.com/smoosex/pi-footer")
          or ($source | startswith("git:github.com/smoosex/pi-footer@"))
          or ($source == "npm:pi-subagents")
          or ($source | startswith("npm:pi-subagents@"))
          or ($source == "npm:pi-web-access")
          or ($source | startswith("npm:pi-web-access@"))
          or ($source == "npm:pi-mcp-adapter")
          or ($source | startswith("npm:pi-mcp-adapter@"))
          or ($source == "npm:pi-cc-extensions")
          or ($source | startswith("npm:pi-cc-extensions@"))
          or ($source == "npm:@juicesharp/rpiv-ask-user-question")
          or ($source | startswith("npm:@juicesharp/rpiv-ask-user-question@"))
          or ($source == "npm:@juicesharp/rpiv-todo")
          or ($source | startswith("npm:@juicesharp/rpiv-todo@"))
          or ($source | test("^/nix/store/[a-z0-9]+-(pi-(bg|background-task|footer|subagents|managed-(agents|resources)|web-access|mcp-adapter|cc-extensions)|rpiv-(ask-user-question|todo))-[0-9]"));

      .packages = (
        ((.packages // [])
          | if type == "array" then . else [] end
          | map(select(managed_by_nix | not)))
        + $managed
      )
      # Disable builtin:mcp; see the note above configurePackages.
      | .extensions = (
          ((.extensions // [])
            | if type == "array" then . else [] end
            | map(select(. != "builtin:mcp" and . != "+builtin:mcp" and . != "-builtin:mcp")))
          + ["-builtin:mcp"]
        )
      # pi-footer was removed (pi-cc-extensions draws the footer); drop its config.
      | del(.footer)
      | .subagents = (
          ((.subagents // {}) | if type == "object" then . else {} end)
          * $managedSubagents
          | .agentOverrides.scout = (
              (.agentOverrides.scout // {})
              | del(.model, .thinking)
              | .disabled = true
            )
        )
    ' "$input" > "$tmp"

    rm -f "$tmp.input"
    chmod 600 "$tmp"
    if [ -f "$settings" ] && cmp -s "$tmp" "$settings"; then
      rm -f "$tmp"
    else
      mv "$tmp" "$settings"
    fi
    trap - EXIT

    keybindings="$config_dir/keybindings.json"
    keybindings_tmp=$(mktemp "$config_dir/.keybindings.json.XXXXXX")
    trap 'rm -f "$keybindings_tmp" "$keybindings_tmp.input"' EXIT

    if [ -f "$keybindings" ]; then
      keybindings_input="$keybindings"
    else
      printf '{}\n' > "$keybindings_tmp.input"
      keybindings_input="$keybindings_tmp.input"
    fi

    ${pkgs.jq}/bin/jq --argjson managed '${managedKeybindings}' \
      '. * $managed' "$keybindings_input" > "$keybindings_tmp"

    rm -f "$keybindings_tmp.input"
    chmod 600 "$keybindings_tmp"
    if [ -f "$keybindings" ] && cmp -s "$keybindings_tmp" "$keybindings"; then
      rm -f "$keybindings_tmp"
    else
      mv "$keybindings_tmp" "$keybindings"
    fi
    trap - EXIT

    # pi-cc-extensions >= 1.0 reads pi-cc-extensions.json; it migrates a legacy
    # claude-code-style.json once and then ignores it, so manage the new file
    # (taking the legacy one as input the first time) and drop the legacy copy.
    # excludeRenderers gains "bash"; the footer keys in managedCcFooter are reset
    # on every launch (see the note above managedCcFooter). Everything else,
    # including choices saved from its config panel, is kept.
    ccext="$config_dir/pi-cc-extensions.json"
    ccstyle="$config_dir/claude-code-style.json"
    ccext_tmp=$(mktemp "$config_dir/.pi-cc-extensions.json.XXXXXX")
    trap 'rm -f "$ccext_tmp"' EXIT

    if [ -f "$ccext" ]; then
      ccext_input=$(cat "$ccext")
    elif [ -f "$ccstyle" ]; then
      ccext_input=$(cat "$ccstyle")
    else
      ccext_input='{}'
    fi

    if ${pkgs.jq}/bin/jq -n --argjson input "$ccext_input" --argjson footer '${managedCcFooter}' '
      ($input | if type == "object" then . else {} end)
      | .excludeRenderers = (
          ((.excludeRenderers // [])
            | if type == "array" then . else [] end
            | map(select(type == "string")))
          + ["bash"]
          | unique
        )
      | . * $footer
    ' > "$ccext_tmp"; then
      chmod 600 "$ccext_tmp"
      if [ -f "$ccext" ] && cmp -s "$ccext_tmp" "$ccext"; then
        rm -f "$ccext_tmp"
      else
        mv "$ccext_tmp" "$ccext"
      fi
      rm -f "$ccstyle"
    else
      echo "pi: could not update $ccext; left unchanged" >&2
      rm -f "$ccext_tmp"
    fi
    trap - EXIT

    # Managed MCP servers live in pi-mcp-adapter's global file. Since Pi 0.99 the
    # adapter also reads Pi's own mcp.json, but only in Pi's schema (`enabled`,
    # no lifecycle/idleTimeout), so the adapter-only keys below would be dropped
    # there. Managed keys (command, lifecycle, idleTimeout) are reset on every
    # launch; `disabled` defaults to true only when absent. A managed server
    # left in mcp.json by an older wrapper is moved over, keeping the user's
    # own keys (such as disabled or directTools). Other servers and settings in
    # both files are untouched.
    mcp="$config_dir/mcp.json"
    adapter="$config_dir/mcp-adapter.json"
    mcp_tmp=$(mktemp "$config_dir/.mcp.json.XXXXXX")
    adapter_tmp=$(mktemp "$config_dir/.mcp-adapter.json.XXXXXX")
    trap 'rm -f "$mcp_tmp" "$adapter_tmp" "$mcp_tmp.both"' EXIT

    mcp_input=$([ -f "$mcp" ] && cat "$mcp" || echo '{}')
    adapter_input=$([ -f "$adapter" ] && cat "$adapter" || echo '{}')

    # Unparseable input or a jq error leaves both files exactly as they were.
    if ${pkgs.jq}/bin/jq -n \
      --argjson managed '${managedMcpServers}' \
      --argjson defaults '${managedMcpDefaults}' \
      --argjson mcp "$mcp_input" \
      --argjson adapter "$adapter_input" '
      def servers: (.mcpServers // {}) | if type == "object" then . else {} end;
      def obj: if type == "object" then . else {} end;
      ($mcp | servers) as $legacy
      | {
          adapter: ($adapter | obj | .mcpServers = (
            ($adapter | obj | servers) as $existing
            | reduce ($managed.mcpServers | to_entries[]) as $server ($existing;
                .[$server.key] = (
                  ($defaults.mcpServers[$server.key] // {})
                  * ($legacy[$server.key] // {} | obj | del(.command, .lifecycle, .idleTimeout))
                  * (.[$server.key] // {} | obj)
                  * $server.value
                ))
          )
          # Adapter settings defaults apply only to keys the user has not set.
          | .settings = (($defaults.settings // {}) * (.settings // {} | obj))),
          mcp: (
            if ($mcp | obj | has("mcpServers")) then
              $mcp | .mcpServers = ($legacy | with_entries(select(.key as $k | ($managed.mcpServers | has($k)) | not)))
            else $mcp end
          )
        }
    ' > "$mcp_tmp.both" &&
      ${pkgs.jq}/bin/jq '.adapter' "$mcp_tmp.both" > "$adapter_tmp" &&
      ${pkgs.jq}/bin/jq '.mcp' "$mcp_tmp.both" > "$mcp_tmp"; then
      updated=1
    else
      echo "pi: could not update $adapter / $mcp; left unchanged" >&2
      updated=0
    fi
    rm -f "$mcp_tmp.both"

    install_json() { # <tmp> <dest>: replace dest only when the content changed
      chmod 600 "$1"
      if [ -f "$2" ] && cmp -s "$1" "$2"; then
        rm -f "$1"
      else
        mv "$1" "$2"
      fi
    }
    if [ "$updated" = 1 ]; then
      install_json "$adapter_tmp" "$adapter"
      # Never create an mcp.json that did not exist.
      if [ -f "$mcp" ]; then install_json "$mcp_tmp" "$mcp"; fi
    fi
    rm -f "$mcp_tmp" "$adapter_tmp"
    trap - EXIT
  '';

  archive =
    {
      aarch64-darwin = {
        name = "pi-darwin-arm64.tar.gz";
        hash = "sha256-qb8NgtWNKn0zf0rkFxtfyev/5CUJUnqDE2TEtlrfLN8=";
      };
      x86_64-darwin = {
        name = "pi-darwin-x64.tar.gz";
        hash = "sha256-9BsmzZoXVKviWeBaQh+zOwCTZ3nLB4PIk6Y4nRvS7g0=";
      };
      aarch64-linux = {
        name = "pi-linux-arm64.tar.gz";
        hash = "sha256-XVcRtIYAdWRzaC6GNgsCaxGr91keXREutBHU2iwQDZo=";
      };
      x86_64-linux = {
        name = "pi-linux-x64.tar.gz";
        hash = "sha256-34cLoONEy3szWNjY8ZOXuLjSJahml4RzataKXCFp1Ts=";
      };
    }.${
      pkgs.stdenv.hostPlatform.system
    };

  pi-unwrapped = pkgs.stdenvNoCC.mkDerivation {
    pname = "pi-unwrapped";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/earendil-works/pi/releases/download/v${version}/${archive.name}";
      inherit (archive) hash;
    };

    sourceRoot = "pi";
    nativeBuildInputs = [pkgs.makeWrapper];
    dontConfigure = true;
    dontBuild = true;
    dontPatchELF = true;
    dontStrip = true;
    # The upstream Bun-based executable traps when launched inside Nix build
    # sandboxes on Darwin, and must retain its upstream loader on Linux. The
    # fixed-output archive hash verifies the payload; validate installation
    # structurally instead of executing it during the build.
    doInstallCheck = false;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/libexec $out/bin
      cp -R . $out/libexec/pi
      makeWrapper $out/libexec/pi/pi $out/bin/pi
      test -x $out/libexec/pi/pi
      test -x $out/bin/pi
      runHook postInstall
    '';

    meta = {
      description = "Minimal terminal coding harness";
      homepage = "https://github.com/earendil-works/pi";
      license = lib.licenses.mit;
      mainProgram = "pi";
      platforms = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  };
in {
  wrappers.pi = {
    basePackage = pi-unwrapped;
    wrapperType = "shell";
    wrapFlags =
      [
        "--prefix"
        "PATH"
        ":"
        (lib.makeBinPath [
          pkgs.tmux
          pkgs.nodejs
        ])
        "--set-default"
        "PI_BACKGROUND_TASK_NODE"
        "${pkgs.nodejs}/bin/node"
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        # Linux hosts here are SSH remotes (VMs). Also send copies to the terminal
        # with OSC 52 so they reach the laptop's clipboard even when Pi cannot
        # detect the remote session (the VS Code server's extension host, tmux).
        "--set-default"
        "PI_CLIPBOARD_OSC52"
        "1"
      ]
      ++ [
        # Export pi-mcp-adapter's OAuth file-store key; see loadMcpOAuthKey.
        "--run"
        ". ${loadMcpOAuthKey}"
        "--run"
        configurePackages
      ];
    env.PI_SKIP_VERSION_CHECK.value = "1";
  };
}

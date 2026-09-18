{pkgs, ...}: let
  inherit (pkgs) lib;
  version = "0.85.1";

  mkPiPackage = {
    pname,
    version,
    owner,
    repo,
    rev,
    hash,
    npmDepsHash,
  }:
    pkgs.buildNpmPackage {
      inherit pname version npmDepsHash;

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
        cp -RL node_modules/typebox $out/node_modules/
        cp -RL node_modules/@juicesharp/rpiv-config $out/node_modules/@juicesharp/
        runHook postInstall
      '';
    };

  managedResourcePackage = pkgs.runCommand "pi-managed-resources-1.0.0" {} ''
    mkdir -p "$out"
    cp -R ${./agents} "$out/agents"
    cp -R ${./extensions} "$out/extensions"
    cat > "$out/package.json" <<'JSON'
    {
      "name": "pi-managed-resources",
      "version": "1.0.0",
      "pi": {
        "extensions": ["./extensions/guard-invalid-slash.ts"],
        "subagents": {
          "agents": ["./agents"]
        }
      }
    }
    JSON
  '';

  piPackages = [
    managedResourcePackage
    (mkPiPackage {
      pname = "pi-subagents";
      version = "0.69.0";
      owner = "nicobailon";
      repo = "pi-subagents";
      rev = "f4918e80b531f1bf9f1d9e847b8f86c9016108f1";
      hash = "sha256-j6nEmECD1jDXBCgc65AJMa6QFtbRYq4TblGB7ghQ1Ms=";
      npmDepsHash = "sha256-IQgqScaxHR4ZVjv2G/uy0GN+nlGKrkprYFLKRPWTqEI=";
    })
    (mkPiPackage {
      pname = "pi-web-access";
      version = "0.29.0";
      owner = "nicobailon";
      repo = "pi-web-access";
      rev = "192ac1875e3b8f88c78953dbc314949ec9fcaa27";
      hash = "sha256-5YMwE44pyMmCapGt9kFLxT61Qg3OCzuJCIATRhMBv6M=";
      npmDepsHash = "sha256-NcJX+r/aaLSkBXq1N8mpZAzL0fCJC9pE4f+alHHxyAI=";
    })
    (mkPiPackage {
      pname = "pi-mcp-adapter";
      version = "2.34.0";
      owner = "nicobailon";
      repo = "pi-mcp-adapter";
      rev = "74c5233c63ad0096077df925fd6135c3bf6b8c6b";
      hash = "sha256-YpiJROIG0/U81wAoImjktbg/d5wGnc6o130IlOrTyEE=";
      npmDepsHash = "sha256-4TmYcom+la6ZQN9RuFWpq6hzByJEcKe4gRnCu27gU84=";
    })
    (mkPiPackage {
      pname = "pi-cc-extensions";
      version = "0.8.71";
      owner = "minuque";
      repo = "pi-cc-extensions";
      rev = "e43e0041b59f5d7f03be9b9d103a5f9e954e4c11";
      hash = "sha256-P2aoupVV8TBOSilqGplRukbdktpTJ09YC0sPkcvMKEM=";
      npmDepsHash = "sha256-lf7AcK6bTbKh3rjbdJSozfFBBK1fUo1omFB4Efhsvms=";
    })
    (mkRpivPackage {
      pname = "rpiv-ask-user-question";
      workspace = "rpiv-ask-user-question";
      version = "2.10.1";
      rev = "42a272eb3363f18e072d71deccdbc27452bb0c45";
      hash = "sha256-kgULSuw55OIqoF36kPyl69PCoDyajducrq3jeENnVKM=";
      npmDepsHash = "sha256-9PR2jnPqSfHI/wIiAC9aFGiBXL+yw/qPPtIg++eJmOQ=";
    })
    (mkRpivPackage {
      pname = "rpiv-todo";
      workspace = "rpiv-todo";
      version = "2.10.1";
      rev = "42a272eb3363f18e072d71deccdbc27452bb0c45";
      hash = "sha256-kgULSuw55OIqoF36kPyl69PCoDyajducrq3jeENnVKM=";
      npmDepsHash = "sha256-aIZ0vSkcfi5zUSt91nFTaNeJ0leehvTxxhzEHgZM9yg=";
    })
  ];

  managedPackages = builtins.toJSON (map toString piPackages);
  managedSubagents = builtins.toJSON {
    agentOverrides = {
      monitor = {
        model = "agent-control-plane/north-mini-code-1-0";
        thinking = "low";
      };
      scout = {
        model = "agent-control-plane/gpt-5.6-luna";
        thinking = "low";
      };
      delegate = {
        model = "agent-control-plane/gpt-5.6-luna";
        thinking = "medium";
      };
      worker = {
        model = "agent-control-plane/gpt-5.6-sol";
        thinking = "medium";
      };
      reviewer = {
        model = "agent-control-plane/gpt-5.6-sol";
        thinking = "medium";
      };
      researcher = {
        model = "agent-control-plane/gpt-5.6-sol";
        thinking = "medium";
      };
      evidence-auditor = {
        model = "agent-control-plane/gpt-5.6-sol";
        thinking = "medium";
      };
      oracle = {
        model = "agent-gateway-dev/us.openai.gpt-6-astra";
        thinking = "off";
      };
    };
  };
  managedKeybindings = builtins.toJSON {
    "app.message.followUp" = "enter";
    "tui.input.newLine" = [
      "ctrl+enter"
      "shift+enter"
      "ctrl+j"
    ];
    "tui.input.submit" = "alt+enter";
    "app.message.dequeue" = [
      "ctrl+q"
      "alt+up"
    ];
  };
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
        | ($source == "npm:pi-subagents")
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
          or ($source | test("^/nix/store/[a-z0-9]+-(pi-(subagents|managed-(agents|resources)|web-access|mcp-adapter|cc-extensions)|rpiv-(ask-user-question|todo))-[0-9]"));

      .packages = (
        ((.packages // [])
          | if type == "array" then . else [] end
          | map(select(managed_by_nix | not)))
        + $managed
      )
      | .subagents = (
          ((.subagents // {}) | if type == "object" then . else {} end)
          * $managedSubagents
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
  '';

  archive =
    {
      aarch64-darwin = {
        name = "pi-darwin-arm64.tar.gz";
        hash = "sha256-1fcOPAz3OY6sI5/QJh7gdNmLe6f2tD/jYX8FLtW3nQY=";
      };
      x86_64-darwin = {
        name = "pi-darwin-x64.tar.gz";
        hash = "sha256-rbkYuEViXxhNi+pAjVXqyvIaqHI4eTwPW087lze85is=";
      };
      aarch64-linux = {
        name = "pi-linux-arm64.tar.gz";
        hash = "sha256-BC0grohe5POxAoFfMoC5YsN3sun7RN5AN5CMxTDq5NQ=";
      };
      x86_64-linux = {
        name = "pi-linux-x64.tar.gz";
        hash = "sha256-SU5Jj0fXTSH0CzOG9qXpIaPUlTGhacq1W72soOof4lo=";
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
    # Bun's Linux executable must retain and use its upstream loader. Invoking
    # it through a Nix loader changes its runtime behavior.
    doInstallCheck = !pkgs.stdenv.hostPlatform.isLinux;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/libexec $out/bin
      cp -R . $out/libexec/pi
      makeWrapper $out/libexec/pi/pi $out/bin/pi
      runHook postInstall
    '';

    installCheckPhase = ''
      checkDir=$(mktemp -d)
      export HOME=$checkDir
      export TMPDIR=$checkDir
      $out/bin/pi --version
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
    wrapFlags = [
      "--run"
      configurePackages
    ];
    env.PI_SKIP_VERSION_CHECK.value = "1";
  };
}

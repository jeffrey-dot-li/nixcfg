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

  piPackages = [
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
  ];

  managedPackages = builtins.toJSON (map toString piPackages);
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

    ${pkgs.jq}/bin/jq --argjson managed '${managedPackages}' '
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
          or ($source | test("^/nix/store/[a-z0-9]+-pi-(subagents|web-access)-[0-9]"));

      .packages = (
        ((.packages // [])
          | if type == "array" then . else [] end
          | map(select(managed_by_nix | not)))
        + $managed
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

{
	pkgs,
	inputs,
	colors,
	...
} : let
	toml = pkgs.formats.toml {};
	starship-settings = import ./starship.nix;
	aliases = import ./aliases.nix { inherit pkgs; };
	fishconfig = import ./fish { inherit pkgs aliasesStr;};
	packages = import ./packages.nix { inherit pkgs; };
	aliasesStr =
    pkgs.lib.concatStringsSep "\n"
    (pkgs.lib.mapAttrsToList (k: v: "alias ${k}=\"${v}\"") aliases);

in
(inputs.wrapper-manager.lib.build {
	inherit pkgs;
	modules = [{
		wrappers = {
			nucleus = {
				basePackage = pkgs.fish;
				pathAdd = packages;
				env = {
					STARSHIP_CONFIG.value = toml.generate "starship.toml" starship-settings;
					FISH_CONFIG.value = "${fishconfig}";
				};
				flags = [
					"-C"
					"source ${fishconfig}"
				];
				renames = {
					"fish" = "nucleus";
				};
			};
		};
	
	# configs;
	}];
})
.overrideAttrs(_: {
	passthru = {
		shellPath = "/bin/nucleus";
	};
})


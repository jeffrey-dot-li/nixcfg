{pkgs, ...}: let
  inherit (pkgs.lib) getExe;
in rec {
  m = "mkdir -vp";

  g = "git";
  n = "nix";
  v = "nvim";

  # imagine using mp3
  ytopus = "yt-dlp -x --embed-metadata --audio-quality 0 --audio-format opus --embed-metadata --embed-thumbnail";

  cat = "${getExe pkgs.bat} --plain";

  kys = "shutdown now";

  gpl = "curl https://www.gnu.org/licenses/gpl-3.0.txt -o LICENSE";

  gcb = "git checkout";
  gp = "git pull";
  gu = "git push";
  gc = "git commit";
  ga = "git add";
  gs = "git status";
  gd = "git diff HEAD~ | bat --language=diff";
}

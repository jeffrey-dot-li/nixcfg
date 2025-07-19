{
  add_newline = false;
  command_timeout = 1000;
  scan_timeout = 10;
  directory = {
  };
  character = {
    error_symbol = "[✗](bold red)";
    success_symbol = "[V](bold green)";
    format = "$symbol [|](bold bright-black) ";
  };
  git_commit = {
    commit_hash_length = 7;
    disabled = false;
  };
  git_branch = {
    symbol = "🌿 ";
  };
  line_break.disabled = false;
  python.symbol = "[🐍](blue) ";
  hostname = {
    ssh_only = false;
    format = "[$hostname](bold blue) ";
    disabled = false;
  };
  gcloud = {
    disabled = true;
  };
  nix_shell = {
    format = "[$symbol]($style)";
  };
  kubernetes = {
    format = "[$symbol\($context\) ](bold blue)";
    disabled = false;
  };
}

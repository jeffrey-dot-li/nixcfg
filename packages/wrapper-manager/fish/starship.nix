{
  add_newline = false;
  command_timeout = 1000;
  scan_timeout = 10;
  directory = {
    truncation_length = 3;
    truncation_symbol = "…";
  };
  character = {
    use_symbol_for_status = true;
    error_symbol = "[✗](bold red)";
    vicmd_symbol = "[V](bold green)";
    format = "$symbol [|](bold bright-black) ";
  };
  git_commit = {commit_hash_length = 7;};
  line_break.disabled = false;
  python.symbol = "[🐍](blue) ";
  hostname = {
    ssh_only = false;
    format = "[$hostname](bold blue) ";
    disabled = false;
  };
  git_branch = {
    symbol = "🌿 ";
  };
  git_commit = {
    disabled = false;
  };
  gcloud = {
    disabled = true;
  };
  nix_shell = {
    format = "[$symbol]($style)";
  };
}

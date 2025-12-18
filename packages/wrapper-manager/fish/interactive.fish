set -gx fish_greeting

# Bindings
bind \cH backward-kill-path-component
bind \e\[3\;5~ kill-word


# EXA
alias ls="eza --icons"
alias la="eza --icons --all"
alias ll="eza --icons --long --header --group"
alias lla="eza --icons --all --long --header --group"
alias lal="eza --icons --all --long --header --group"
alias lt="eza --sort modified -1"

abbr -a -g e eza


# Bat
alias bat="bat --theme=base16 --style=changes,header --plain"

# Abbreviations
abbr -a -g p python
abbr -a -g n nvim
abbr -a -g pd pushd
abbr -a -g cdx cd \$XDG_RUNTIME_DIR
abbr -a -g k kubectl
abbr -a -g kx kubectl exec -it

function kctl
    if test "$argv[1]" = "stop"
        kubectl patch job $argv[2] -p '{"spec":{"activeDeadlineSeconds":1}}'
    else
        # Optional: handle other kctl commands or pass through to kubectl
        kubectl $argv
    end
end


function kcluster
    if test (count $argv) -eq 0
        kubectl config get-contexts
        return
    end

    if test "$argv[1]" = "-"
        if test -z "$KCLUSTER_PREV"
            echo "No previous context"
            return 1
        end
        kubectl config use-context "$KCLUSTER_PREV"
        return
    end

    set -g KCLUSTER_PREV (kubectl config current-context 2>/dev/null)
    kubectl config use-context "$argv[1]"
end

# Admin
abbr -a -g ss sudo systemctl
abbr -a -g us systemctl --user
abbr -a -g sf journalctl -xefu
abbr -a -g uf journalctl -xef --user-unit

# Image cat
abbr -a -g wat "wezterm imgcat --height 50%"

set self (builtin realpath (which fish))

# Git abbreviations
# https://gist.github.com/james2doyle/6e8a120e31dbaa806a2f91478507314c
abbr -a -g gd "git difftool"
abbr -a -g ga "git add"
abbr -a -g gs "git status"
abbr -a -g gm "git merge"
abbr -a -g gp "git push"
abbr -a -g gl "git logs" # Defined in git/gitconfig
abbr -a -g gr "cd (git-root)"
abbr -a -g gcm "git commit -m"

set -gx fish_color_normal grey
set -gx fish_color_command green
set -gx fish_color_keyword brblue
set -gx fish_color_quote yellow
set -gx fish_color_redirection bryellow
set -gx fish_color_end brred
set -gx fish_color_error -o red
set -gx fish_color_param cyan
# set -gx fish_color_comment brblack
# set -gx fish_color_selection --background=brblack
# # set -gx fish_color_selection cyan
# # set -gx fish_color_search_match cyan
# set -gx fish_color_search_match --background=brblack
# set -gx fish_color_operator green
# set -gx fish_color_escape brblue
# set -gx fish_color_autosuggestion brblack
# set -gx fish_pager_color_progress brblack
# set -gx fish_pager_color_prefix green
# set -gx fish_pager_color_completion lightgrey
# set -gx fish_pager_color_description brblack
set -gx fish_color_autosuggestion lightgrey

# Configure FZF keybinds
# https://github.com/PatrickF1/fzf.fish
# We only use this on linux because fzf-fish is broken on mac
if functions -q fzf_configure_bindings
    fzf_configure_bindings --directory=\cf
end
# Print newline after a command
function postexec_test --on-event fish_postexec
    echo
end

function __fish_command_not_found_handler --on-event fish_command_not_found
    echo -e >&2 "\e[31m$argv[1]: command not found\e[0m"
end


function duls
    # Usage: duls [target_directory]
    if test (count $argv) -eq 0
        du -h -d 1 | sort -hr
    else
        du -h -d 1 $argv[1] | sort -hr
    end    
end


# Check if NIX_LD_LIBRARY_PATH is set
if set -q NIX_LD_LIBRARY_PATH
    # Append to LD_LIBRARY_PATH (or set if not exists)
    if set -q LD_LIBRARY_PATH
        set -gx LD_LIBRARY_PATH $LD_LIBRARY_PATH:$NIX_LD_LIBRARY_PATH
    else
        set -gx LD_LIBRARY_PATH $NIX_LD_LIBRARY_PATH
    end
    
    # Append to LIBRARY_PATH (or set if not exists)
    if set -q LIBRARY_PATH
        set -gx LIBRARY_PATH $LIBRARY_PATH:$NIX_LD_LIBRARY_PATH
    else
        set -gx LIBRARY_PATH $NIX_LD_LIBRARY_PATH
    end
    
    echo_light "[LD_LIBRARY_PATH]" "Updated LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
    echo_light "[LD_LIBRARY_PATH]" "Updated LIBRARY_PATH: $LIBRARY_PATH"
end
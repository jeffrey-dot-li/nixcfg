
# Start SSH agent if not already running
# Sometimes mac is stupid and sets SSH_AUTH_SOCK to /private/tmp/com.apple.launchd.H7aAgQtped/Listeners I'm not sure why


function is_ssh_set --description "Check SSH agent for jeffrey.dot.li@gmail.com and warn if missing"
    if not set -q SSH_AUTH_SOCK
        return 1
    end

    if not test -S "$SSH_AUTH_SOCK"
        echo "warning: SSH_AUTH_SOCK is set but is not a valid socket" >&2
        return 1
    end

    if ssh-add -L 2>/dev/null | string match -q "*jeffrey.dot.li@gmail.com*"
        return 0
    end

    echo "warning: SSH agent reachable, but key for jeffrey.dot.li@gmail.com is not loaded" >&2
    return 1
end

function ssh_add_key --description "Add an SSH key to the agent if it exists"
    set -l key_path $argv[1]

    if test -z "$key_path"
        echo "usage: ssh_add_key <path-to-ssh-key>" >&2
        return 2
    end

    if test -f "$key_path"
        ssh-add "$key_path"
        if test $status -eq 0
            echo_light "[SSH Agent]" "Added "(basename "$key_path")" key to SSH agent"
            return 0
        else
            echo_light "[SSH Agent]" "Failed to add "(basename "$key_path")" key"
            return 1
        end
    else
        echo_light "[SSH Agent]" (basename "$key_path")" key not found"
        return 1
    end
end

if not is_ssh_set
    echo_light "[SSH Agent]" "Starting SSH agent"
    eval (ssh-agent -c)
    ssh_add_key ~/.ssh/id_ed25519
end

if not is_ssh_set
    echo "[SSH Agent] Error: Failed to start SSH agent properly"
else
    echo_light "[SSH Agent]" "SSH agent is running"
    ssh-add -l
end

# Check and add RSA key if it exists
# Only activate id_ed25519 not id_rsa.
# if test -f ~/.ssh/id_rsa
#     ssh-add ~/.ssh/id_rsa
#     echo_light "[SSH Key]" "Added RSA key to SSH agent"
# else
#     echo_light "[SSH Key]" "RSA key not found"
# end



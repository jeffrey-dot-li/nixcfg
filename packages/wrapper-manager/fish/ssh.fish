
# Start SSH agent if not already running
# Sometimes mac is stupid and sets SSH_AUTH_SOCK to /private/tmp/com.apple.launchd.H7aAgQtped/Listeners I'm not sure why
if not set -q SSH_AUTH_SOCK \
    or not string match -r '.*/agent\.[0-9]+$' -- $SSH_AUTH_SOCK
    echo_light "[SSH Agent]" "Starting SSH agent"
    eval (ssh-agent -c)
end

# Check and add RSA key if it exists
# Only activate id_ed25519 not id_rsa.
# if test -f ~/.ssh/id_rsa
#     ssh-add ~/.ssh/id_rsa
#     echo_light "[SSH Key]" "Added RSA key to SSH agent"
# else
#     echo_light "[SSH Key]" "RSA key not found"
# end

# Check and add Ed25519 key if it exists
if test -f ~/.ssh/id_ed25519
    ssh-add ~/.ssh/id_ed25519
    echo_light "[SSH Agent]" "Added id_ed25519 key to SSH agent"

else
    echo_light "[SSH Agent]" "id_ed25519 key not found"
end

ssh-add -l
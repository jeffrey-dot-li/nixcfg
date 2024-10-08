#!/bin/sh
darwin-rebuild switch --flake .\#applin
export SHELL=$(dscl . -read "/Users/$USER" UserShell | sed 's/UserShell: //')
exec $SHELL

#!/bin/bash

RCM_EXTENSION_VERSION=0.19.0-alpha.13

# Usage Functions.
usage() {
    cat << EOF
Usage: rcm plugin prompt

Alias of rcm plugin get-socket.

Make clear that socket will do the prompt.
EOF
}

# Prevent scripts from being executed directly.
[ -f "${RCM_LIB}/require.sh" ] && source "${RCM_LIB}/require.sh" || { usage >&2; exit 1; }

require rcm plugin get-socket

INDENT+="    " \
rcm plugin get-socket "$@" \
    --hide-title \
    ; [ ! $? -eq 0 ] && x

exit 0

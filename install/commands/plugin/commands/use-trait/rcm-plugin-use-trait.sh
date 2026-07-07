#!/bin/bash

RCM_EXTENSION_VERSION=0.19.0-alpha.12

# Usage Functions.
usage() {
    cat << EOF
Usage: rcm plugin use-trait

Alias of rcm plugin get-socket.

Make clear that socket will act as a trait.
EOF
}

# Prevent scripts from being executed directly.
[ -f "${RCM_LIB}/require.sh" ] && source "${RCM_LIB}/require.sh" || { usage >&2; exit 1; }


# ------------------------------------------------------------------------------

# Title.
title rcm plugin use-trait "$@"
____

# Dependency.
require rcm plugin get-socket

INDENT+="    " \
rcm plugin get-socket "$@" \
    --hide-title \
    ; [ ! $? -eq 0 ] && x

exit 0

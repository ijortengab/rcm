#!/bin/bash
[ -f "$0" ] || { echo "Cannot run as dot command."; kill -INT $$; }

RCM_EXTENSION_VERSION=0.19.0-alpha.13

# Usage Functions.
usage() {
    cat << EOF
Usage: rcm system list user regular
EOF
}

[ -f "${RCM_LIB}/require.sh" ] && source "${RCM_LIB}/require.sh" || { usage >&2; exit 1; }

_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --[^-]*) shift ;;
        *) _new_arguments+=("$1"); shift ;;
    esac
done
set -- "${_new_arguments[@]}"
unset _new_arguments

# Help and Version.
[ -n "$help" ] && { usage; exit 0; }
[ -n "$version" ] && { e $RCM_EXTENSION_VERSION; x; }

# ------------------------------------------------------------------------------

[ -f /etc/passwd ] || { error File not found; x; }

cut -d: -f1 /etc/passwd | while IFS= read -r line; do [ -d /home/$line ] && echo "${line}"; done

exit 0

# parse-options.sh \
# --without-end-options-double-dash \
# --compact \
# --clean \
# --no-hash-bang \
# --no-original-arguments \
# --no-error-invalid-options \
# --no-error-require-arguments << EOF | clip
# FLAG=(
# --version
# --help
# )
# VALUE=(
# )
# MULTIVALUE=(
# )
# FLAG_VALUE=(
# )
# CSV=(
# )
# EOF
# clear

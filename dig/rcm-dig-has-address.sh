#!/bin/bash

# Parse arguments. Generated by parse-options.sh
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --fast) fast=1; shift ;;
        --fqdn=*) fqdn="${1#*=}"; shift ;;
        --fqdn) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then fqdn="$2"; shift; fi; shift ;;
        --ip-address=*) ip_address="${1#*=}"; shift ;;
        --ip-address) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then ip_address="$2"; shift; fi; shift ;;
        --reverse) reverse=1; shift ;;
        --root-sure) root_sure=1; shift ;;
        --[^-]*) shift ;;
        *) _new_arguments+=("$1"); shift ;;
    esac
done
set -- "${_new_arguments[@]}"
unset _new_arguments

# Common Functions.
red() { echo -ne "\e[91m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
green() { echo -ne "\e[92m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
yellow() { echo -ne "\e[93m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
blue() { echo -ne "\e[94m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
magenta() { echo -ne "\e[95m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
error() { echo -n "$INDENT" >&2; red '#' "$@" >&2; echo >&2; }
success() { echo -n "$INDENT" >&2; green '#' "$@" >&2; echo >&2; }
chapter() { echo -n "$INDENT" >&2; yellow '#' "$@" >&2; echo >&2; }
title() { echo -n "$INDENT" >&2; blue '#' "$@" >&2; echo >&2; }
code() { echo -n "$INDENT" >&2; magenta "$@" >&2; echo >&2; }
x() { echo >&2; exit 1; }
e() { echo -n "$INDENT" >&2; echo -n "$@" >&2; }
_() { echo -n "$INDENT" >&2; echo -n "#" "$@" >&2; }
_,() { echo -n "$@" >&2; }
_.() { echo >&2; }
__() { echo -n "$INDENT" >&2; echo -n "#" '    ' >&2; [ -n "$1" ] && echo "$@" >&2 || echo -n  >&2; }
____() { echo >&2; [ -n "$delay" ] && sleep "$delay"; }

# Functions.
printVersion() {
    echo '0.16.6'
}
printHelp() {
    title RCM Dig Has Address
    _ 'Variation '; yellow Default; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-dig-has-address [options]

Options:
   --fqdn *
        Fully Qualified Domain Name to be checked.
   --ip-address *
        Set the IP Address. Used to verify A record in DNS.

Global Options:
   --fast
        No delay every subtask.
   --version
        Print version of this script.
   --help
        Show this help.
   --root-sure
        Bypass root checking.

Dependency:
   host
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Title.
title rcm-dig-has-address
____

if [ -z "$root_sure" ];then
    chapter Mengecek akses root.
    if [[ "$EUID" -ne 0 ]]; then
        error This script needs to be run with superuser privileges.; x
    else
        __ Privileges.
    fi
    ____
fi

# Dependency.
while IFS= read -r line; do
    [[ -z "$line" ]] || command -v `cut -d: -f1 <<< "${line}"` >/dev/null || { error Unable to proceed, command not found: '`'$line'`'.; x; }
done <<< `printHelp 2>/dev/null | sed -n '/^Dependency:/,$p' | sed -n '2,/^\s*$/p' | sed 's/^ *//g'`

# Require, validate, and populate value.
chapter Dump variable.
delay=.5; [ -n "$fast" ] && unset delay
if [ -z "$fqdn" ];then
    error "Argument --fqdn required."; x
fi
if [ -z "$ip_address" ];then
    error "Argument --ip-address required."; x
fi
code 'fqdn="'$fqdn'"'
code 'ip_address="'$ip_address'"'
tempfile=$(mktemp -p /dev/shm -t rcm-dig-has-address.XXXXXX)
____

chapter Mengecek IP Address FQDN '`'$fqdn'`'
code host -t A $fqdn
host -t A "$fqdn" | tee "$tempfile"
stdout=$(<"$tempfile")
found=
data="$ip_address"
data_escape=${data//\./\\.}
code grep -E --ignore-case "'"" has address ${data_escape}""'"
if grep -q -E --ignore-case ' has address '"$data_escape" <<< "$stdout";then
    found=1
fi
____

chapter Result
rm "$tempfile"
if [ -n "$found" ];then
    result='success'
    if [ -n "$reverse" ];then
        result='error'
    fi
    $result FQDN "$fqdn" has address "$ip_address".
else
    result='error'
    if [ -n "$reverse" ];then
        result='success'
    fi
    $result FQDN "$fqdn" has not address "$ip_address".
fi

[ "$result" == error ] && x
____

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
# --fast
# --version
# --help
# --root-sure
# --reverse
# )
# VALUE=(
# --fqdn
# --ip-address
# )
# FLAG_VALUE=(
# )
# CSV=(
# )
# EOF
# clear

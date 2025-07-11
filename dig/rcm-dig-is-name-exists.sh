#!/bin/bash

# Parse arguments. Generated by parse-options.sh
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --domain=*) domain="${1#*=}"; shift ;;
        --domain) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then domain="$2"; shift; fi; shift ;;
        --fast) fast=1; shift ;;
        --name-server=*) name_server="${1#*=}"; shift ;;
        --name-server) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then name_server="$2"; shift; fi; shift ;;
        --reverse) reverse=1; shift ;;
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
_() { echo -n "$INDENT" >&2; echo -n "#"' ' >&2; [ -n "$1" ] && echo -n "$@" >&2; }
_,() { echo -n "$@" >&2; }
_.() { echo >&2; }
__() { echo -n "$INDENT" >&2; echo -n "# ${RCM_INDENT}" >&2; [ -n "$1" ] && echo "$@" >&2; }
____() { echo >&2; [ -n "$RCM_DELAY" ] && sleep "$RCM_DELAY"; }

# Define variables and constants.
RCM_DELAY=${RCM_DELAY:=.5}; [ -n "$fast" ] && unset RCM_DELAY
RCM_INDENT='    '; [ "$(tput cols)" -le 80 ] && RCM_INDENT='  '

# Functions.
printVersion() {
    echo '0.17.3'
}
printHelp() {
    title RCM Dig Is Name Exists
    _ 'Variation '; yellow Default; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-dig-is-name-exists [options]

Options:
   --domain *
        Domain name to be checked.
   --name-server
        Set the Name server. Default value is - (dash). Available values: [1], [2], or other.
        [1]: 8.8.8.8
        [2]: 1.1.1.1

Global Options:
   --fast
        No delay every subtask.
   --version
        Print version of this script.
   --help
        Show this help.
   --reverse
        Reverse the result.

Dependency:
   dig
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Title.
title rcm-dig-is-name-exists
____

[ "$EUID" -ne 0 ] && { error This script needs to be run with superuser privileges.; x; }

# Dependency.
while IFS= read -r line; do
    [[ -z "$line" ]] || command -v `cut -d: -f1 <<< "${line}"` >/dev/null || { error Unable to proceed, command not found: '`'`cut -d: -f1 <<< "${line}"`'`'.; x; }
done <<< `printHelp 2>/dev/null | sed -n '/^Dependency:/,$p' | sed -n '2,/^\s*$/p' | sed 's/^ *//g'`

# Require, validate, and populate value.
chapter Dump variable.
if [ -z "$domain" ];then
    error "Argument --domain required."; x
fi
code 'domain="'$domain'"'
code 'name_server="'$name_server'"'
if [[ "$name_server" == - ]];then
    name_server=
fi
[ -n "$name_server" ] && add_name_server=' @'"$name_server" || add_name_server=''
[ -n "$name_server" ] && label_name_server=' in DNS '"$name_server" || label_name_server=''
tempfile=$(mktemp -p /dev/shm -t rcm-dig-is-name-exists.XXXXXX)
domain_dot="${domain}."
domain_dot_escape=${domain_dot//\./\\.}
____

chapter Mengecek Name Server domain '`'$domain'`'
code dig NS ${domain}${add_name_server}
dig NS $domain $add_name_server | tee "$tempfile"
stdout=$(<"$tempfile")
found=
if grep -q -E --ignore-case ^"$domain_dot_escape"'\s+''[0-9]+''\s+'IN'\s+'NS'\s+' <<< "$stdout";then
    code grep -E --ignore-case "'"^"$domain_dot_escape"'\s+''[0-9]+''\s+'IN'\s+'NS'\s+'"'"
    grep -E --ignore-case ^"$domain_dot_escape"'\s+''[0-9]+''\s+'IN'\s+'NS'\s+' <<< "$stdout"
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
    $result Name Server pada domain "$domain" FOUND${label_name_server}.
else
    result='error'
    if [ -n "$reverse" ];then
        result='success'
    fi
    $result Name Server pada domain "$domain" NOT FOUND${label_name_server}.
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
# --reverse
# )
# VALUE=(
# --domain
# --name-server
# )
# FLAG_VALUE=(
# )
# CSV=(
# )
# EOF
# clear

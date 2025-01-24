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

if [ -n "$1" ];then
    case "$1" in
        get-ipv4) command="$1"; shift ;;
    esac
fi

# Functions.
printVersion() {
    echo '0.16.21'
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
        Value available from command: rcm-dig-has-address(get-ipv4), or other.

Global Options:
   --fast
        No delay every subtask.
   --version
        Print version of this script.
   --help
        Show this help.

Dependency:
   host
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

command-get-ipv4() {
    _ip=`wget -T 3 -t 1 -4qO- "http://ip1.dynupdate.no-ip.com/"`
    if [ -n "$_ip" ];then
        echo "$_ip"
    else
        ip addr show | grep -o "inet [0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | grep -o "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*"
    fi
}

# Execute command.
if [[ -n "$command" && $(type -t "command-${command}") == function ]];then
    command-${command} "$@"
    exit 0
fi

# Title.
title rcm-dig-has-address
____

[ "$EUID" -ne 0 ] && { error This script needs to be run with superuser privileges.; x; }

# Dependency.
while IFS= read -r line; do
    [[ -z "$line" ]] || command -v `cut -d: -f1 <<< "${line}"` >/dev/null || { error Unable to proceed, command not found: '`'`cut -d: -f1 <<< "${line}"`'`'.; x; }
done <<< `printHelp 2>/dev/null | sed -n '/^Dependency:/,$p' | sed -n '2,/^\s*$/p' | sed 's/^ *//g'`

# Require, validate, and populate value.
chapter Dump variable.
if [ -z "$fqdn" ];then
    error "Argument --fqdn required."; x
fi
if [ -z "$ip_address" ];then
    error "Argument --ip-address required."; x
fi
fqdn_raw="$fqdn"
code 'fqdn_raw="'$fqdn_raw'"'
code 'fqdn="'$fqdn'"'
code 'ip_address="'$ip_address'"'
tempfile=$(mktemp -p /dev/shm -t rcm-dig-has-address.XXXXXX)
____

chapter Mengecek IP Address FQDN '`'$fqdn'`'
code host -t A $fqdn
host -t A "$fqdn" > "$tempfile"
while IFS= read line; do e "$line"; _.; done < "$tempfile"
stdout=$(<"$tempfile")
found=
code found="$found"
code fqdn="$fqdn"
while read line; do
    _ "$line"; _.
    __ Try
    data="${fqdn} is an alias for "
    data_escape=${data//\./\\.}
    __; magenta grep -E --ignore-case '"'"^${data_escape}"'"'; _.
    if grep -q -E --ignore-case "^${data_escape}" <<< "$line";then
        __ Alias ditemukan.
        __; magenta sed -E '"'"s|^${data_escape}(.*)\.$|\1|"'"'; _.
        __ Value of variable '`'\$fqdn'`' diperbarui.
        fqdn=$(echo "$line"| sed -E "s|^${data_escape}(.*)\.$|\1|")
        __; magenta fqdn="$fqdn"; _.
    else
        __ Try
        data="${fqdn} has address ${ip_address}"
        data_escape=${data//\./\\.}
        __; magenta grep -E --ignore-case "'""^${data_escape}""'"; _.
        if grep -q -E --ignore-case "^${data_escape}" <<< "$line";then
            found=1
            __; magenta found="$found"; _.
            __ Get Address
            data="${fqdn} has address "
            data_escape=${data//\./\\.}
            __; magenta sed -E '"'"s|^${data_escape}(.*)$|\1|"'"'; _.
            address=$(echo "$line"| sed -E "s|^${data_escape}(.*)$|\1|")
            __; magenta address="$address"; _.
            break
        else
            __ Try
            data="${fqdn} has address "
            data_escape=${data//\./\\.}
            __; magenta grep -E --ignore-case "'""^${data_escape}""'"; _.
            if grep -q -E --ignore-case "^${data_escape}" <<< "$line";then
                found=2
                __; magenta found="$found"; _.
                __ Get Address
                __; magenta sed -E '"'"s|^${data_escape}(.*)$|\1|"'"'; _.
                address=$(echo "$line"| sed -E "s|^${data_escape}(.*)$|\1|")
                __; magenta address="$address"; _.
                break
            fi
        fi
    fi
done <<< "$stdout"
____

chapter Result
rm "$tempfile"
if [ "$found" == 1 ];then
    result='success'
    if [ -n "$reverse" ];then
        result='error'
    fi
    $result FQDN "$fqdn_raw" has address "$ip_address".
else
    result='error'
    if [ -n "$reverse" ];then
        result='success'
    fi
    $result FQDN "$fqdn_raw" has not address "$ip_address".
    if [ "$found" == 2 ];then
        _ FQDN "$fqdn_raw" has address "$address".; _.
    fi
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
# --fqdn
# --ip-address
# )
# FLAG_VALUE=(
# )
# CSV=(
# )
# EOF
# clear

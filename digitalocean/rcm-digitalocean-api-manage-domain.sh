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
        --ip-address=*) ip_address="${1#*=}"; shift ;;
        --ip-address) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then ip_address="$2"; shift; fi; shift ;;
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
TOKEN=${TOKEN:=[HOME]/.digitalocean-token.txt}

# Command.
command="$1"; shift
if [ -n "$command" ];then
    case "$command" in
        add|delete) ;;
        *) echo -e "\e[91m""Command ${command} is unknown.""\e[39m"; exit 1
    esac
fi

# Functions.
printVersion() {
    echo '0.16.20'
}
printHelp() {
    title RCM DigitalOcean API
    _ 'Variation '; yellow Manage Domain; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << EOF
Usage: rcm-digitalocean-api-manage-domain [command] [options]

Available commands: add, delete.

Options:
   --domain
        Set the domain to add or delete.
   --ip-address
        Set the IP Address. Use with A record while registered.

Global Options:
   --fast
        No delay every subtask.
   --version
        Print version of this script.
   --help
        Show this help.

Environment Variables:
   TOKEN
        Default to $TOKEN

Dependency:
   php
   curl
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Title.
title rcm-digitalocean-api-manage-domain
____

[ "$EUID" -ne 0 ] && { error This script needs to be run with superuser privileges.; x; }

# Dependency.
while IFS= read -r line; do
    [[ -z "$line" ]] || command -v `cut -d: -f1 <<< "${line}"` >/dev/null || { error Unable to proceed, command not found: '`'`cut -d: -f1 <<< "${line}"`'`'.; x; }
done <<< `printHelp 2>/dev/null | sed -n '/^Dependency:/,$p' | sed -n '2,/^\s*$/p' | sed 's/^ *//g'`

# Functions.
fileMustExists() {
    # global used:
    # global modified:
    # function used: __, success, error, x
    if [ -f "$1" ];then
        __; green File '`'$(basename "$1")'`' ditemukan.; _.
    else
        __; red File '`'$(basename "$1")'`' tidak ditemukan.; x
    fi
}
isDomainExists() {
    local domain=$1 code
    local dumpfile=$2
    [ -z "$dumpfile" ] && dumpfile=$(mktemp -t digitalocean.XXXXXX)
    __; magenta "curl https://api.digitalocean.com/v2/domains/$domain"; _.
    code=$(curl -X GET \
        -H "Authorization: Bearer $digitalocean_token" \
        -o "$dumpfile" -s -w "%{http_code}\n" \
        "https://api.digitalocean.com/v2/domains/$domain")
    sleep .5 # Delay
    json=$(<"$dumpfile")
    json_pretty=$(php -r "echo json_encode(json_decode(fgets(STDIN)), JSON_PRETTY_PRINT).PHP_EOL;" <<< "$json")
    magenta "$json_pretty"; _.
    if [[ $code == 200 ]];then
        return 0
    elif [[ $code == 404 ]];then
        return 1
    fi
    error Unexpected result with response code: $code.; x
}
insertDomain() {
    if [[ ! "$command" == add ]];then
        return 1
    fi
    local domain="$1" ip="$2" reference code
    local dumpfile="$3"
    [ -z "$dumpfile" ] && dumpfile=$(mktemp -t digitalocean.XXXXXX)
    reference="$(php -r "echo json_encode([
        'name' => '$domain',
        'ip_address' => '$ip',
    ]);")"
    __; magenta "curl -X POST -d '$reference' https://api.digitalocean.com/v2/domains/"; _.
    code=$(curl -X POST \
        -H "Authorization: Bearer $digitalocean_token" \
        -H "Content-Type: application/json" \
        -o "$dumpfile" -s -w "%{http_code}\n" \
        -d "$reference" \
        "https://api.digitalocean.com/v2/domains")
    sleep .5 # Delay
    json=$(<"$dumpfile")
    json_pretty=$(php -r "echo json_encode(json_decode(fgets(STDIN)), JSON_PRETTY_PRINT).PHP_EOL;" <<< "$json")
    magenta "$json_pretty"; _.
    if [[ $code == 201 ]];then
        return 0
    fi
    error Unexpected result with response code: $code.; x
}

# Require, validate, and populate value.
chapter Dump variable.
code 'TOKEN="'$TOKEN'"'
find='[HOME]'
replace="$HOME"
TOKEN="${TOKEN/"$find"/"$replace"}"
code 'TOKEN="'$TOKEN'"'
if [ -z "$domain" ];then
    error "Argument --domain required."; x
fi
code 'domain="'$domain'"'
if [[ "$command" == delete ]];then
    error Command delete is not support yet.; x
fi
if [[ "$command" == add ]];then
    if [ -z "$ip_address" ];then
        error "Argument --ip-address required. "; x
    fi
    code 'ip_address="'$ip_address'"'
fi
____

chapter Mengecek Token
fileMustExists "$TOKEN"
digitalocean_token=$(<$TOKEN)
__; magenta 'digitalocean_token="'$digitalocean_token'"'; _.
____

chapter Query DNS Record for Domain '`'${domain}'`'
if isDomainExists $domain;then
    __ Domain '`'"$domain"'`' found in DNS Digital Ocean.
elif insertDomain $domain $ip_address;then
    __; green Domain '`'"$domain"'`' created in DNS Digital Ocean.; _.
fi
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
# )
# VALUE=(
# --domain
# --ip-address
# )
# FLAG_VALUE=(
# )
# CSV=(
# )
# EOF
# clear

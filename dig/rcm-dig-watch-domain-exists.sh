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
        --waiting-time=*) waiting_time="${1#*=}"; shift ;;
        --waiting-time) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then waiting_time="$2"; shift; fi; shift ;;
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
    echo '0.16.22'
}
printHelp() {
    title RCM Dig Watch
    _ 'Variation '; yellow Domain Exists; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-dig-watch-domain-exists [command] [options]

Options:
   --domain *
        Domain name to be checked.
   --waiting-time
        Time to waiting until next check. Default to 60.

Global Options:
   --fast
        No delay every subtask.
   --version
        Print version of this script.
   --help
        Show this help.

Dependency:
   rcm-dig-is-record-exists
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Title.
title rcm-dig-watch-domain-exists
____

[ "$EUID" -ne 0 ] && { error This script needs to be run with superuser privileges.; x; }

# Dependency.
while IFS= read -r line; do
    [[ -z "$line" ]] || command -v `cut -d: -f1 <<< "${line}"` >/dev/null || { error Unable to proceed, command not found: '`'`cut -d: -f1 <<< "${line}"`'`'.; x; }
done <<< `printHelp 2>/dev/null | sed -n '/^Dependency:/,$p' | sed -n '2,/^\s*$/p' | sed 's/^ *//g'`

# Functions.
# Global Used: add_name_server, tempfile.
sleepExtended() {
    local countdown=$1
    local width=$2
    if [ -z "$width" ];then
        width=80
    fi
    if [ "$countdown" -gt 0 ];then
        dikali10=$((countdown*10))
        _dikali10=$dikali10
        _dotLength=$(( ( width * _dikali10 ) / dikali10 ))
        printf "\r\033[K" >&2
        e; printf %"$_dotLength"s | tr " " "." >&2
        printf "\r"
        while [ "$_dikali10" -ge 0 ]; do
            dotLength=$(( ( width * _dikali10 ) / dikali10 ))
            if [[ ! "$dotLength" == "$_dotLength" ]];then
                _dotLength="$dotLength"
                printf "\r\033[K" >&2
                e; printf %"$dotLength"s | tr " " "." >&2
                printf "\r"
            fi
            _dikali10=$((_dikali10 - 1))
            sleep .1
        done
    fi
}

# Requirement, validate, and populate value.
chapter Dump variable.

if [ -z "$waiting_time" ];then
    waiting_time=60
fi
if [[ "$waiting_time" =~ [^0-9] ]];then
    waiting_time=60
fi
code 'waiting_time="'$waiting_time'"'
____

chapter Watching Begin
__ Make sure the DNS Record '(A or CNAME)' of '`'$domain'`' is exist.
finish=
_ Begin: $(date +%Y%m%d-%H%M%S); _.
Rcm_BEGIN=$SECONDS
____

until [ -n "$finish" ];do
    _finish=""

    INDENT+="    " \
    rcm-dig-is-record-exists $isfast --name-exists-sure \
        --without-color \
        --domain="$domain" \
        --type=a \
        --ip-address="*" \
        ; [ $? -eq 0 ] && _finish+="1"

    INDENT+="    " \
    rcm-dig-is-record-exists $isfast --name-exists-sure \
        --without-color \
        --domain="$domain" \
        --type=cname \
        --hostname="@" \
        --hostname-origin="*" \
        ; [ $? -eq 0 ] && _finish+="1"

    if [[ "$_finish" =~ 1 ]];then
        chapter Watching End
        success The required DNS Records already exist '(A or CNAME)'.
        _ End: $(date +%Y%m%d-%H%M%S); _.
        Rcm_END=$SECONDS
        duration=$(( Rcm_END - Rcm_BEGIN ))
        hours=$((duration / 3600)); minutes=$(( (duration % 3600) / 60 )); seconds=$(( (duration % 3600) % 60 ));
        runtime=`printf "%02d:%02d:%02d" $hours $minutes $seconds`
        _ Duration: $runtime; if [ $duration -gt 60 ];then _, " (${duration} seconds)"; fi; _, '.'; _.
        finish=1
        ____
    else
        error There are not exist DNS Record of '`'$domain'`' '(neither A nor CNAME)'.
        _ We are still waiting.; _.
        sleepExtended $waiting_time
    fi
done

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
# --waiting-time
# )
# FLAG_VALUE=(
# )
# CSV=(
# )
# EOF
# clear

#!/bin/bash

red() { echo -ne "\e[91m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
green() { echo -ne "\e[92m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
yellow() { echo -ne "\e[93m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
blue() { echo -ne "\e[94m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
magenta() { echo -ne "\e[95m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
purple() { echo -ne "\e[38;5;177m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
error() { echo -n "$INDENT" >&2; red '#' "$@" >&2; echo >&2; }
success() { echo -n "$INDENT" >&2; green '#' "$@" >&2; echo >&2; }
chapter() { echo -n "$INDENT" >&2; yellow '#' "$@" >&2; echo >&2; }
title() { echo -n "$INDENT" >&2; blue '#' "$@" >&2; echo >&2; }
code() {
    code-set() { [ "${1#*=}" == @ ] && { code-set-array "${1%%=*}"; } || { magenta "${1%%=*}"; _, =; yellow \"; purple "${1#*=}"; yellow \"; } }
    code-set-array() { local a="${1}[@]"; magenta "$1"; _, '=( '; _.;for i in "${!a}"; do echo -n "${INDENT}${RCM_INDENT}" >&2; yellow \"; purple "$i"; yellow \"; _.; done; e ')'; }
    echo -n "$INDENT" >&2; [[ $# -eq 1 && "$1" =~ ^[0-9a-zA-Z_]+= ]] && { code-set "$1"; } || magenta "$@" >&2; echo >&2;
}
x() { echo "$@" >&2; exit 1; }
e() { echo -n "$INDENT" >&2; echo -n "$@" >&2; }
_() { echo -n "$INDENT" >&2; echo -n "#"' ' >&2; [ -n "$1" ] && echo -n "$@" >&2; }
_,() { echo -n "$@" >&2; }
_.() { echo >&2; }
__() { echo -n "$INDENT" >&2; echo -n "# ${RCM_INDENT}" >&2; [ -n "$1" ] && echo "$@" >&2; }
___() { echo -n "$INDENT" >&2; echo -n "# ${RCM_INDENT}${RCM_INDENT}" >&2; [ -n "$1" ] && echo "$@" >&2 || echo -n  >&2; }
____() { echo >&2; [ -n "$RCM_DELAY" ] && sleep "$RCM_DELAY"; }
----() { echo -n "$RCM_INDENT"; }

require() {
    # global RCM_REQUIRE_LOADED
    if [ -z "$1" ];then
        return 1
    fi
    if [ "$1" == command ];then
        command -v "$2" >/dev/null || { error Unable to proceed, command not found: '`'"$2"'`'.; x; }
        return 0
    fi
    if [ "$1" == rcm ];then
        local prefix="$RCM_LIB"
        local command_file_sh="rcm"
        local command="rcm"
        shift
        while [[ $# -gt 0 ]]; do
            prefix+='/commands/'$1
            command_file_sh+="-${1}"
            command+=" ${1}"
            shift
        done
        command_file_sh+='.sh'
        OLDPATH="$PATH"
        PATH="$prefix":"$PATH"
        command -v "$command_file_sh" >/dev/null || { code $command; error "Unable to proceed, $command_file_sh command not found."; x; }
        PATH="$OLDPATH"
        return 0
    fi
    local path_source="$1"
    if [[ ! "${path_source:0:1}" == / ]];then
        path_source="${RCM_LIB}/${path_source}"
    fi
    # local filename=$(basename "$path_source")
    local filename="${path_source##*/}"

    if [ ! -f "$path_source" ];then
        code "${path_source}"
        _ 'File is not found: '; yellow "$filename"; _, .; red ' Process terminated.'; x
    fi

    if ! grep -q -F "<${path_source}>" <<< "$RCM_REQUIRE_LOADED";then
        # Create global variable.
        __FILE__="$path_source"
        # __DIR__=$(dirname "$path_source")
        __DIR__=${path_source%/*}
        . "$path_source"
        RCM_REQUIRE_LOADED+="<${path_source}>"$'\n'
    fi
}

include() {
    local path_source="$1"
    if [ -z "$path_source" ];then
        e Error 'include()' function: require argument:' '; magenta "<path_source>"; _, '. ';
        red 'Process terminated.'; x
    fi

    local filename="${path_source##*/}"
    if [ ! -f "$path_source" ];then
        e Require:' '; magenta "${path_source}"; _, '.'; _.
        red 'Process terminated.'; _, ' File is not found: '; yellow "$filename"; _, .; x
    fi
    INDENT+="$RCM_INDENT"; export INDENT="$INDENT"
    . "$path_source"
    INDENT="${INDENT::-${#RCM_INDENT}}"
}

#!/bin/bash

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
    local filename="$1"
    if [[ ! "${filename:0:1}" == / ]];then
        filename="${RCM_LIB}/${filename}"
    fi
    local basename=$(basename "$filename")
    local dirname=$(dirname "$filename")
    if [ ! -f "$filename" ];then
        code "${filename}"
        _ 'File is not found: '; yellow "$basename"; _, .; red ' Process terminated.'; x
    fi
    # Create global variable.
    __FILE__="$filename"
    __DIR__=$(dirname "$filename")
    . "$filename"
}

include() {
    local filename="$1"
    if [ -z "$filename" ];then
        e Error 'include()' function: require argument:' '; magenta "<filename>"; _, '. ';
        red 'Process terminated.'; x
    fi

    INDENT+="$RCM_INDENT"; export INDENT="$INDENT"
    if [ ! -f "$filename" ];then
        e Require:' '; magenta "${filename}"; _, '.'; _.
        red 'Process terminated.'; _, ' File is not found: '; yellow "$basename"; _, .; x
    fi
    . "$filename"
    INDENT="${INDENT::-${#RCM_INDENT}}"
}

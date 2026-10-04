#!/bin/bash

# Define variables and constants.
RCM_INDENT='    ';
RCM_USE_CACHED=
RCM_USE_LIST_FILES=
RCM_USE_NEXT_LIST_DIR=()
RCM_REQUIRE_LOADED=()

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
    code-set() { [ "$2" == '$' ] && { code-set-self "$1"; return; }; [ "$2" == @ ] && { code-set-array "$1" "${1}[@]"; return; }; [ "$2" == + ] && { code-set-heredoc "$1" "${!1}"; return; }; code-set-plain "$1" "$2"; }
    code-set-self() { magenta "$1"; _, =; yellow \"; purple "${!1}"; yellow \"; }
    code-set-array() { magenta "$1"; _, '=( '; _.;for i in "${!2}"; do echo -n "${INDENT}${RCM_INDENT}" >&2; yellow \"; purple "$i"; yellow \"; _.; done; e ')'; }
    code-set-heredoc() { magenta "$1"; _, '=$(cat << '"'EOF'"; _.; while read line; do purple "$line"; _.; done <<< "$2"; _, 'EOF'; _.; e ')'; }
    code-set-plain() { magenta "$1"; _, =; yellow \"; purple "$2"; yellow \"; }
    echo -n "$INDENT" >&2; [[ $# -eq 1 && "$1" =~ ^[0-9a-zA-Z_]+= ]] && { code-set "${1%%=*}" "${1#*=}"; } || magenta "$@" >&2; echo >&2;
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
    local each
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

    for each in "${RCM_REQUIRE_LOADED[@]}"; do
        if [[ "$each" == "$path_source" ]]; then
            return 0
        fi
    done

    RCM_REQUIRE_LOADED+=("$path_source")
    # Create global variable.
    __FILE__="$path_source"
    # __DIR__=$(dirname "$path_source")
    __DIR__=${path_source%/*}
    . "$path_source"
}

include() {
    local command="$1"; shift
    if [ -z "$command" ];then
        error "Argument <command> is required."; x
    fi
    path_source=$(INDENT+="$RCM_INDENT" $command "$@")
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

run() {
    local command="$1"; shift
    if [ -z "$command" ];then
        error "Argument <command> is required."; x
    fi
    INDENT+="$RCM_INDENT" $command "$@"
    return $?
}
use () {
    # global RCM_USE_NEXT_LIST_DIR
    # global RCM_USE_LIST_FILES
    # global RCM_USE_CACHED
    scandir() {
        # global stopper
        local each
        local dir="$1"
        local path line
        local nullglob_was_set=0
        # shopt -s nullglob
        # while IFS= read -r line; do
        shopt -q nullglob && nullglob_was_set=1
        shopt -s nullglob
        for each in "$dir"/*; do
            path="$each"
            line="${path##*/}"
            if [ -f "$path" ];then
                RCM_USE_LIST_FILES+="${path} ${line}"$'\n'
                if [[ "$path" == "${dir}/${command}.${extension}" ]];then
                    stopper=1
                fi
            else
                # Recursive.
                if [ -z "$stopper" ];then
                    scandir "$path"
                else
                    # Masukkan ke list direktori yang belum di scan.
                    RCM_USE_NEXT_LIST_DIR+=("$path")
                fi
            fi
        done
        # done <<< `ls "$dir"`
        # shopt -u nullglob
        [ "$nullglob_was_set" -eq 0 ] && shopt -u nullglob
    }
    local namespace="$1"
    local command="$2"
    local extension=sh
    local stopper
    local each list_dir found path

    if [ -z "$namespace" ];then
        error "Argument <namespace> is required."; x
    fi
    if [ -z "$command" ];then
        error "Argument <command> is required."; x
    fi
    local prefix="${RCM_LIB}/vendor/${namespace}/functions"

    # First, check cached.
    if grep -q -F "${command} " <<< "$RCM_USE_CACHED";then
        return
    fi

    # Mulai scan directory.
    if ! grep -q -F "${prefix}" <<< "$RCM_USE_LIST_FILES";then
        # Namespace baru, maka tambahkan append.
        RCM_USE_NEXT_LIST_DIR+=("${prefix}")
    fi
    list_dir=("${RCM_USE_NEXT_LIST_DIR[@]}")
    # Reset.
    RCM_USE_NEXT_LIST_DIR=()
    for each in "${list_dir[@]}";do
        if [ -z "$stopper" ];then
            scandir "$each"
        else
            # Masukkan ke list direktori yang belum di scan.
            RCM_USE_NEXT_LIST_DIR+=("$each")
        fi
    done

    found=$(grep -F " ${command}.${extension}" <<< "$RCM_USE_LIST_FILES" | head -n1)
    if [ -n "$found" ];then
        path=$(cut -d' ' -f1 <<< "$found")
        RCM_USE_CACHED+="${command} ${path}"$'\n'
        require "$path"
    fi
}

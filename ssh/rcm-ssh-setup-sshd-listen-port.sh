#!/bin/bash

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --config-file=*) config_file="${1#*=}"; shift ;;
        --config-file) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then config_file="$2"; shift; fi; shift ;;
        --disable=*) disable+=("${1#*=}"); shift ;;
        --disable) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then disable+=("$2"); shift; fi; shift ;;
        --enable=*) enable+=("${1#*=}"); shift ;;
        --enable) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then enable+=("$2"); shift; fi; shift ;;
        --fast) fast=1; shift ;;
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
    echo '0.16.12'
}
printHelp() {
    title RCM SSH Setup
    _ 'Variation '; yellow SSHD Listen Port; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-ssh-setup-sshd-listen-port [options]

Options:
   --config-file
        Set the config file of SSH Config file.
   --enable
        Set the port that will be enabled. Multivalue.
   --disable
        Set the port that will be disabled. Multivalue.

Global Options:
   --fast
        No delay every subtask.
   --version
        Print version of this script.
   --help
        Show this help.
   --root-sure
        Bypass root checking.

Environment Variables:
   SSH_DIRECTORY
        Default to /etc/ssh
   SSHD_CONFIG
        Default to $SSH_DIRECTORY/sshd_config
   SSHD_CONFIG_DIRECTORY
        Default to $SSHD_CONFIG.d
   RCM_CONF
        Default to rcm.conf

Dependency:
   sshd
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Title.
title rcm-ssh-setup-sshd-listen-port
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

# Require, validate, and populate value.
chapter Dump variable.
SSH_DIRECTORY=${SSH_DIRECTORY:=/etc/ssh}
code 'SSH_DIRECTORY="'$SSH_DIRECTORY'"'
SSHD_CONFIG=${SSHD_CONFIG:=$SSH_DIRECTORY/sshd_config}
code 'SSHD_CONFIG="'$SSHD_CONFIG'"'
SSHD_CONFIG_DIRECTORY=${SSHD_CONFIG_DIRECTORY:=$SSHD_CONFIG.d}
code 'SSHD_CONFIG_DIRECTORY="'$SSHD_CONFIG_DIRECTORY'"'
RCM_CONF=${RCM_CONF:=rcm.conf}
code 'RCM_CONF="'$RCM_CONF'"'
[ -z "$config_file" ] && config_file="$SSHD_CONFIG"
code 'config_file="'$config_file'"'
code 'enable="'"${enable[@]}"'"'
code 'disable="'"${disable[@]}"'"'

____

code 'listen_port="'$listen_port'"'
delay=.5; [ -n "$fast" ] && unset delay
____

chapter Memeriksa file SSH Daemon Config.
fileMustExists "$config_file"
____

string_added=
string_added_quote=
line_include_enable=
for each in "${enable[@]}";do
    chapter Enable Port $each.
    __ Mencari directive Port enable pada value $each.
    __; magenta grep -n -E \''^\s*Port\s+'\'$each \""$config_file"\"; _.
    if grep -q -E '^\s*Port\s+'$each "$config_file";then
        __ Directive Port enable pada value $each ditemukan.
    else
        __ Directive Port enable pada value $each tidak ditemukan.
        __ Mencari directive Port disable pada value $each.
        __; magenta grep -n -E \''^\s*#+[ #]+Port\s+'\'$each \""$config_file"\" ; _.
        if grep -q -E '^\s*#+[ #]+Port\s+'$each "$config_file";then
            __ Directive Port disable pada value $each ditemukan.
            __ Memulai enable.
            __; magenta sed -i -E \""s,^\s*#+[ #]+Port\s+$each,Port $each,"\" "$config_file" ; _.
            sed -i -E "s,^\s*#+[ #]+Port\s+$each,Port $each," "$config_file"
        else
            __ Directive Port disable pada value $each tidak ditemukan.
            __ Masuk antrian enable port pada file SSH Daemon Config.
            string_added+="Port $each"$'\n'
            string_added_quote+="Port $each"'\n'
        fi
    fi
    ____
done

if [ -n "$string_added" ];then
    chapter Antrian enable Port
    __ Memeriksa directive Port pada file SSH Daemon Config.
    __; magenta grep -n -E \''^\s*#*[ #]*Port\s+'\' \""$config_file"\"; _.
    number_1=$(grep -n -E '^\s*#*[ #]*Port\s+' "$config_file" | head -1 | cut -d: -f1)
    if [ -n "$number_1" ];then
        __ Menemukan directive Port '(enable/disable)' di baris ke $number_1.
    else
        __ Directive Port tidak ditemukan.
    fi
    ____

    __ Memeriksa SSH Daemon Config Directory.
    string=$SSHD_CONFIG_DIRECTORY'/*.conf'
    string_quoted=$(sed "s/\./\\\./g" <<< "$string")
    string_quoted=$(sed "s/\*/\\\*/g" <<< "$string_quoted")
    number_2=$(grep -n -E "^\s*Include\s+$string_quoted" "$config_file" | cut -d: -f1)
    if [ -n "$number_2" ];then
        __ Menemukan Include SSH Daemon Config Directory di baris ke $number_2.
        line_include_enable=1
        __; magenta Include "$string"; _.
    else
        __ Include SSH Daemon Config Directory tidak ditemukan.
    fi
    ____

    chapter Menambah directive Port.
    if [ -n "$number_1" ];then
        string_added_quote="${string_added_quote:0:(-2)}"
        code string_added='"'"$string_added_quote"'"'
        __ Menambahkan directive Port setelah baris ke $number_1.
        sed -i $number_1'a\'"$string_added_quote" "$config_file"
    elif [ -n "$line_include_enable" ];then
        mkdir -p "$SSHD_CONFIG_DIRECTORY"
        touch ${SSHD_CONFIG_DIRECTORY}/${RCM_CONF}
        string_added="${string_added:0:(-1)}"
        code string_added='"'"$string_added"'"'
        __ Menambahkan directive Port di file '`'${SSHD_CONFIG_DIRECTORY}/${RCM_CONF}'`' '(append)'.
        ifs="$IFS"
        while IFS= read line; do
            if ! grep -q '^'"$line"'$' "${SSHD_CONFIG_DIRECTORY}/${RCM_CONF}";then
                __; magenta 'echo "'$line'" >>' "${SSHD_CONFIG_DIRECTORY}/${RCM_CONF}"; _.
                echo "$line" >> "${SSHD_CONFIG_DIRECTORY}/${RCM_CONF}"
            fi
        done <<< "$string_added"
        IFS="$ifs"
    else
        string_added="${string_added:0:(-1)}"
        code string_added='"'"$string_added"'"'
        __ Menambahkan directive Port di akhir file '`'$config_file'`' '(append)'.
        echo "$string_added" >> "$config_file"
    fi
    ____
fi

arguments=
for each in "${disable[@]}";do
    chapter Disable Port $each.
    __ Mencari directive Port enable pada value $each.
    __; magenta grep -n -E \''^\s*Port\s+'\'$each \""$config_file"\"; _.
    if grep -q -E '^\s*Port\s+'$each "$config_file";then
        ifs="$IFS"
        while IFS= read line; do
            number_string=$(cut -d: -f1 <<< "$line")
            __ Directive Port enable pada value $each ditemukan pada baris ke $number_string.
            arguments+=' -e '"'${number_string}s,^,# ,'"
        done <<< `grep -n -E '^\s*Port\s+'$each "$config_file"`
        IFS="$ifs"
        __ Masuk antrian disable port pada file SSH Daemon Config.
    else
        __ Directive Port enable pada value $each tidak ditemukan.
    fi
    ____
done

if [ -n "$arguments" ];then
    chapter Menghapus directive Port.
    code sed"$arguments" -i "$config_file"
    echo sed $arguments -i "$config_file" | sh
fi

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
# )
# VALUE=(
# --config-file
# )
# MULTIVALUE=(
# --enable
# --disable
# )
# FLAG_VALUE=(
# )
# EOF
# clear

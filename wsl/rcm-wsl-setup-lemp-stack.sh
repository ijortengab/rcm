#!/bin/bash

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --fast) fast=1; shift ;;
        --php-version=*) php_version="${1#*=}"; shift ;;
        --php-version) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then php_version="$2"; shift; fi; shift ;;
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
e() { echo -n "$INDENT" >&2; echo "#" "$@" >&2; }
_() { echo -n "$INDENT" >&2; echo -n "#" "$@" >&2; }
_,() { echo -n "$@" >&2; }
_.() { echo >&2; }
__() { echo -n "$INDENT" >&2; echo -n "#" '    ' >&2; [ -n "$1" ] && echo "$@" >&2 || echo -n  >&2; }
____() { echo >&2; [ -n "$delay" ] && sleep "$delay"; }

# Functions.
printVersion() {
    echo '0.11.1'
}
printHelp() {
    title RCM WSL Setup
    _ 'Variation '; yellow LEMP Stack; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    unset count
    declare -i count
    count=0
    single_line=
    multi_line=
    while read line;do
        if [ -d /etc/php/$line/fpm ];then
            if [ $count -gt 0 ];then
                single_line+=", "
            fi
            count+=1
            single_line+="[${count}]"
            multi_line+=$'\n''        '"[${count}]: "${line}
        fi
    done <<< `ls /etc/php/`
    if [ -n "$single_line" ];then
        single_line=" Available values: ${single_line}, or other."
    fi
    if [ -n "$multi_line" ];then
        multi_line="$multi_line"
    fi

    cat << EOF
Usage: rcm-wsl-setup-lemp-stack [options]

Options:
   --php-version *
        Set the version of PHP FPM.${single_line}${multi_line}

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
   nginx
   php
   mariadb
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Dependency.
while IFS= read -r line; do
    [[ -z "$line" ]] || command -v "${line}" >/dev/null || { echo -e "\e[91m""Unable to proceed, "'`'"${line}"'`'" command not found." "\e[39m"; exit 1; }
done <<< `printHelp 2>/dev/null | sed -n '/^Dependency:/,$p' | sed -n '2,/^\s*$/p' | sed 's/^ *//g'`

# Functions.
isFileExists() {
    # global used:
    # global modified: found, notfound
    # function used: __
    found=
    notfound=
    if [ -f "$1" ];then
        __ File '`'$(basename "$1")'`' ditemukan.
        found=1
    else
        __ File '`'$(basename "$1")'`' tidak ditemukan.
        notfound=1
    fi
}
makeSureRunning() {
    local service="$1"
    chapter Memeriksa apakah daemon "$service" is running
    __ Memeriksa System V script '`'/etc/init.d/"$service"'`'
    isFileExists /etc/init.d/"$service"
    if [ -n "$notfound" ];then
        __; red File '`'/etc/init.d/"$service"'`' tidak ditemukan.; x
    fi
    if /etc/init.d/"$service" status 2>&1 >/dev/null; then
        __ Daemon "$service" running.
    else
        __ Daemon "$service" is not running.
        __ Trying to start.
        /etc/init.d/"$service" start
        if /etc/init.d/"$service" status 2>&1 >/dev/null; then
            __; green Daemon "$service" running.; _.
        else
            __; red Daemon "$service" is not running.; x
        fi
    fi
    ____
}

# Title.
title rcm-wsl-setup-lemp-stack
____

# Require, validate, and populate value.
chapter Dump variable.
code 'php_version="'$php_version'"'
delay=.5; [ -n "$fast" ] && unset delay
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

chapter Memerikasa apakah mesin ini merupakan WSL.
wsl=
if [ -f /proc/sys/kernel/osrelease ];then
    read osrelease </proc/sys/kernel/osrelease
    code osrelease=$osrelease
    # debian: osrelease=5.10.0-19-amd64
    # wsl2: 4.4.0-19041-Microsoft
    # wsl2: 4.19.128-microsoft-standard
    if [[ "$osrelease" =~ microsoft || "$osrelease" =~ Microsoft ]];then
        __ Mesin merupakan WSL.
        wsl=1
    else
        __ Mesin bukan merupakan WSL.
    fi
fi
____

if [ -n "$wsl" ];then
    makeSureRunning nginx
    makeSureRunning mariadb
    makeSureRunning "php${php_version}-fpm"
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
# --php-version
# )
# MULTIVALUE=(
# )
# FLAG_VALUE=(
# )
# EOF
# clear

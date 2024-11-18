#!/bin/bash

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --fast) fast=1; shift ;;
        --php-version=*) php_version="${1#*=}"; shift ;;
        --php-version) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then php_version="$2"; shift; fi; shift ;;
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
    title RCM PHP Setup
    _ 'Variation '; yellow Adjust CLI Version; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-php-setup-adjust-cli-version [options]

Options:
   --php-version
        Set the version of PHP.

Global Options.
   --fast
        No delay every subtask.
   --version
        Print version of this script.
   --help
        Show this help.
   --root-sure
        Bypass root checking.
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Title.
title rcm-php-setup-adjust-cli-version
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
code 'php_version="'$php_version'"'
____

update=
chapter Check PHP CLI version
current_value=$(update-alternatives --query php | grep -o -P 'Value: \K(.*)')
code 'current_value="'$current_value'"'
if [ -n "$php_version" ];then
    major=`echo "$php_version" | cut -d. -f1`
    minor=`echo "$php_version" | cut -d. -f2`
    expected_value=$(command -v php)"${major}.${minor}"
    code 'expected_value="'$expected_value'"'
    if [[ "$current_value" == "$expected_value" ]];then
        __ PHP CLI version tidak perlu diubah.
    else
        __ PHP CLI version perlu diubah.
        update=1
    fi
fi
____

if [ -n "$update" ];then
    chapter Set PHP CLI version
    found=
    success=
    while IFS= read line; do
        if [[ "$expected_value" == "$line" ]];then
            found=1
            break
        fi
    done <<< `update-alternatives --query php | grep -o -P 'Alternative: \K(.*)'`
    if [ -n "$found" ];then
        __ Alternative "$expected_value" dapat dijadikan sebagai link.
        __; magenta update-alternatives --set php "$line"; _.
        update-alternatives --quiet --set php "$line"
        _current_value=$(update-alternatives --query php | grep -o -P 'Value: \K(.*)')
        __; magenta '_current_value="'$_current_value'"'; _.
        if [[ "$_current_value" == "$current_value" ]];then
            __; red Gagal mengubah PHP CLI version menjadi "$expected_value"; x
        else
            __; green Berhasil mengubah PHP CLI version menjadi "$expected_value"; _.
            success==1
        fi
    else
        error Alternative "$expected_value" tidak dapat dijadikan sebagai link.;
        _ Periksa menggunakan command berikut:; _.
        code update-alternatives --query php
        x
    fi
    if [ -n "$success" ];then
        __; magenta php -v; _.
        php -v
    fi
    ____
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
# FLAG_VALUE=(
# )
# EOF
# clear

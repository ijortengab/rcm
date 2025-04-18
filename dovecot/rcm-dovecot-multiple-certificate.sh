#!/bin/bash

# Parse arguments. Generated by parse-options.sh
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --additional-config-file=*) additional_config_file="${1#*=}"; shift ;;
        --additional-config-file) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then additional_config_file="$2"; shift; fi; shift ;;
        --fast) fast=1; shift ;;
        --fqdn=*) fqdn="${1#*=}"; shift ;;
        --fqdn) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then fqdn="$2"; shift; fi; shift ;;
        --non-interactive) non_interactive=1; shift ;;
        --ssl-cert=*) ssl_cert="${1#*=}"; shift ;;
        --ssl-cert) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then ssl_cert="$2"; shift; fi; shift ;;
        --ssl-key=*) ssl_key="${1#*=}"; shift ;;
        --ssl-key) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then ssl_key="$2"; shift; fi; shift ;;
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
DOVECOT_CONFIG_DIR=${DOVECOT_CONFIG_DIR:=/etc/dovecot}
DOVECOT_CONFIG_FILE_MAIN=${DOVECOT_CONFIG_FILE_MAIN:=${DOVECOT_CONFIG_DIR}/dovecot.conf}

# Functions.
printVersion() {
    echo '0.16.23'
}
printHelp() {
    title RCM Dovecot Multiple Certificate
    _ 'Variation '; yellow ISPConfig; _, . ; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << EOF
Usage: rcm-dovecot-multiple-certificate [options]

Options:
   --domain *
        Add domain.

Global Options:
   --fast
        No delay every subtask.
   --version
        Print version of this script.
   --help
        Show this help.

Environment Variables:
   DOVECOT_CONFIG_DIR
        Default to $DOVECOT_CONFIG_DIR
   DOVECOT_CONFIG_FILE_MAIN
        Default to $DOVECOT_CONFIG_FILE_MAIN

Dependency:
   systemctl
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Title.
title rcm-dovecot-multiple-certificate
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
findString() {
    # global debug
    # global find_quoted
    # $find_quoted agar bisa di gunakan oleh sed.
    local find="$1" string path="$2" tempfile="$3" deletetempfile
    if [ -z "$tempfile" ];then
        tempfile=$(mktemp -p /dev/shm)
        deletetempfile=1
    fi
    _; _, Memeriksa baris dengan kalimat: '`'$find'`'.;_.
    find_quoted="$find"
    find_quoted=$(sed -E "s/\s+/\\\s\+/g" <<< "$find_quoted")
    find_quoted=$(sed "s/\./\\\./g" <<< "$find_quoted")
    find_quoted=$(sed "s/\*/\\\*/g" <<< "$find_quoted")
    find_quoted=$(sed "s/;$/\\\s\*;/g" <<< "$find_quoted")
    if [[ ! "${find_quoted:0:1}" == '^' ]];then
        find_quoted="^\s*${find_quoted}"
    fi
    _; magenta grep -E '"'"${find_quoted}"'"' '"'"\$path"'"'; _.
    if grep -E "${find_quoted}" "$path" > "$tempfile";then
        string="$(< "$tempfile")"
        while read -r line; do e "$line"; _.; done <<< "$string"
        __ Baris ditemukan.
        [ -n "$deletetempfile" ] && rm "$tempfile"
        return 0
    else
        __ Baris tidak ditemukan.
        [ -n "$deletetempfile" ] && rm "$tempfile"
        return 1
    fi
}

# Require, validate, and populate value.
chapter Dump variable.
code 'DOVECOT_CONFIG_DIR="'$DOVECOT_CONFIG_DIR'"'
code 'DOVECOT_CONFIG_FILE_MAIN="'$DOVECOT_CONFIG_FILE_MAIN'"'
if [ -z "$additional_config_file" ];then
    error "Argument --additional-config-file required."; x
fi
code 'additional_config_file="'$additional_config_file'"'
if [ -z "$fqdn" ];then
    error "Argument --fqdn required."; x
fi
code 'fqdn="'$fqdn'"'
if [ -z "$ssl_cert" ];then
    error "Argument --ssl-cert required."; x
fi
code 'ssl_cert="'$ssl_cert'"'
if [ -z "$ssl_key" ];then
    error "Argument --ssl-key required."; x
fi
code 'ssl_key="'$ssl_key'"'
[ -f "$ssl_cert" ] || fileMustExists "$ssl_cert"
[ -f "$ssl_key" ] || fileMustExists "$ssl_key"
[ -f "$DOVECOT_CONFIG_FILE_MAIN" ] || fileMustExists "$DOVECOT_CONFIG_FILE_MAIN"
____

target="$DOVECOT_CONFIG_FILE_MAIN"
filename=$(basename "$target")
source="$additional_config_file"
target_parent=$(dirname "$target")
source_relative=$(realpath -s --relative-to="$target_parent" "$source")
chapter Memastikan string include tersedia pada file config '`'$filename'`'.
string="!include_try ${source_relative}"
code string="'"$string"'"
path="$DOVECOT_CONFIG_FILE_MAIN"
code 'path="'$path'"'
code grep -F '"'\$string'"' '"'\$path'"'
if grep -q -F "$string" "$path";then
	__ String ditemukan.
else
	error String tidak ditemukan.; x
fi
____

path="$additional_config_file"
filename=$(basename "$path")
chapter Mengecek file '`'$filename'`'.
code path='"'$path'"'
isFileExists "$path"
____

restart=
if [ -n "$found" ];then
    chapter Mengecek FQDN '`'$fqdn'`'.
	if ! findString "local_name ${fqdn} " "$path";then
		notfound=1
	fi
	____
fi
if [ -n "$notfound" ];then
	chapter Menambah FQDN '`'$fqdn'`' ke file '`'$filename'`'.
	cat << EOF >> "$path"
local_name $fqdn {
    ssl_cert = <$ssl_cert
    ssl_key = <$ssl_key
}
EOF
    # Saat ini tidak support untuk verifikasi variable ssl_cert dan ssl_key.
    # @todo, support verifikais seperti postfix.
	__ Melakukan verifikasi.
	if ! findString "local_name ${fqdn} " "$path";then
		__; red Gagal menambahkan; x
	fi
	__; green Berhasil ditambahkan; _.
	restart=1
	____
fi

if [ -n "$restart" ];then
	chapter Restart Dovecot.
	code systemctl restart dovecot
	systemctl restart dovecot
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
# --non-interactive
# )
# VALUE=(
# --fqdn
# --ssl-cert
# --ssl-key
# --additional-config-file
# )
# MULTIVALUE=(
# )
# FLAG_VALUE=(
# )
# CSV=(
# )
# EOF
# clear

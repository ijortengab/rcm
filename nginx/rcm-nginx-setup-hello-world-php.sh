#!/bin/bash

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --domain=*) domain="${1#*=}"; shift ;;
        --domain) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then domain="$2"; shift; fi; shift ;;
        --fast) fast=1; shift ;;
        --php-version=*) php_version="${1#*=}"; shift ;;
        --php-version) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then php_version="$2"; shift; fi; shift ;;
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
    echo '0.16.23'
}
printHelp() {
    title RCM Nginx Setup
    _ 'Variation '; yellow Hello World PHP-FPM; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-nginx-setup-hello-world-php [options]

Options:
   --domain *
        Set the domain name.
   --php-version
        Set the version of PHP FPM.

Global Options:
   --fast
        No delay every subtask.
   --version
        Print version of this script.
   --help
        Show this help.

Dependency:
   curl
   rcm-nginx-setup-php
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Title.
title rcm-nginx-setup-hello-world-php
____

[ "$EUID" -ne 0 ] && { error This script needs to be run with superuser privileges.; x; }

# Dependency.
while IFS= read -r line; do
    [[ -z "$line" ]] || command -v `cut -d: -f1 <<< "${line}"` >/dev/null || { error Unable to proceed, command not found: '`'`cut -d: -f1 <<< "${line}"`'`'.; x; }
done <<< `printHelp 2>/dev/null | sed -n '/^Dependency:/,$p' | sed -n '2,/^\s*$/p' | sed 's/^ *//g'`

# Functions.
backupFile() {
    local mode="$1"
    local oldpath="$2" i newpath
    local target_dir="$3"
    i=1
    dirname=$(dirname "$oldpath")
    basename=$(basename "$oldpath")
    if [ -n "$target_dir" ];then
        case "$target_dir" in
            parent) dirname=$(dirname "$dirname") ;;
            *) dirname="$target_dir"
        esac
    fi
    [ -d "$dirname" ] || { echo 'Directory is not exists.' >&2; return 1; }
    newpath="${dirname}/${basename}.${i}"
    if [ -f "$newpath" ]; then
        let i++
        newpath="${dirname}/${basename}.${i}"
        while [ -f "$newpath" ] ; do
            let i++
            newpath="${dirname}/${basename}.${i}"
        done
    fi
    case $mode in
        move)
            mv "$oldpath" "$newpath" ;;
        copy)
            local user=$(stat -c "%U" "$oldpath")
            local group=$(stat -c "%G" "$oldpath")
            cp "$oldpath" "$newpath"
            chown ${user}:${group} "$newpath"
    esac
}
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
[ -n "$fast" ] && isfast=' --fast' || isfast=''
if [ -z "$domain" ];then
    error "Argument --domain required."; x
fi
code 'domain="'$domain'"'
____

chapter Prepare arguments.
root="/var/www/$domain/web"
code root="$root"
filename="$domain"
code filename="$filename"
server_name=("$domain")
code server_name="${server_name[@]}"
____

INDENT+="    " \
rcm-nginx-setup-php $isfast \
    --root="$root" \
    --filename="$filename" \
    --server-name="$server_name" \
    --php-version="$php_version" \
    ; [ ! $? -eq 0 ] && x

chapter Mempersiapkan web root directory.
__; magenta root='"'$root'"'; _.
notfound=
if [ -d "$root" ];then
    __ Direktori '`'$root'`' ditemukan.
else
    __ Direktori '`'$root'`' tidak ditemukan.
    notfound=1
fi
____

if [ -n "$notfound" ];then
    chapter Membuat directory.
    mkdir -p "$root"
    if [ -d "$root" ];then
        __; green Direktori '`'$root'`' ditemukan.; _.
    else
        __; red Direktori '`'$root'`' tidak ditemukan.; x
    fi
    ____
fi

chapter Mempersiapkan file '`'index.php'`'.
notfound=1
path="$root/index.php"
if [ -f "$path" ];then
    read contents < "$path"
    if [ "$contents" == "<?= 'Hello World' ?>" ];then
        notfound=
    fi
fi
if [ -n "$notfound" ];then
    if [ -f "$path" ];then
        __ Backup file "$path".
        backupFile move "$path"
    fi
    __ Membuat file '`'index.php'`'.
    echo "<?= 'Hello World' ?>" > "$path"
fi
fileMustExists "$path"
____

chapter Mengecek HTTP Response Code.
i=0
code=
if [ -z "$tempfile" ];then
    tempfile=$(mktemp -p /dev/shm -t rcm-nginx-setup-hello-world-php.XXXXXX)
fi
until [ $i -eq 10 ];do
    __; magenta curl -o /dev/null -s -w '"'%{http_code}\\n'"' '"'http://127.0.0.1'"' -H '"'Host: $domain'"'; _.
    curl -o /dev/null -s -w "%{http_code}\n" "http://127.0.0.1" -H "Host: ${domain}" > $tempfile
    while read line; do e "$line"; _.; done < $tempfile
    code=$(head -1 $tempfile)
    if [[ "$code" =~ ^[2,3] ]];then
        break
    else
        __ Retry.
        __; magenta sleep .5; _.
        sleep .5
    fi
    let i++
done
if [[ "$code" =~ ^[2,3] ]];then
    __ HTTP Response code '`'$code'`' '('Required')'.
else
    __; red Terjadi kesalahan. HTTP Response code '`'$code'`'.; x
fi
____

if [ -n "$tempfile" ];then
    rm "$tempfile"
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
# )
# VALUE=(
# --domain
# --php-version
# )
# MULTIVALUE=(
# )
# FLAG_VALUE=(
# )
# EOF
# clear

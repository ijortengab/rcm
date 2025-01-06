#!/bin/bash

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --fast) fast=1; shift ;;
        --filename=*) filename="${1#*=}"; shift ;;
        --filename) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then filename="$2"; shift; fi; shift ;;
        --root=*) root="${1#*=}"; shift ;;
        --root) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then root="$2"; shift; fi; shift ;;
        --server-name=*) server_name+=("${1#*=}"); shift ;;
        --server-name) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then server_name+=("$2"); shift; fi; shift ;;
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
__() { echo -n "$INDENT" >&2; echo -n "#" '    ' >&2; [ -n "$1" ] && echo "$@" >&2; }
____() { echo >&2; [ -n "$RCM_DELAY" ] && sleep "$RCM_DELAY"; }

# Define variables and constants.
RCM_DELAY=${RCM_DELAY:=.5}; [ -n "$fast" ] && unset RCM_DELAY

# Functions.
printVersion() {
    echo '0.16.14'
}
printHelp() {
    title RCM Nginx Setup
    _ 'Variation '; yellow Static; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-nginx-setup-static [options]

Options:
   --filename *
        Set the filename to created inside /etc/nginx/sites-available directory.
   --root *
        Set the value of root directive.
   --server-name *
        Set the value of server_name directive. Multivalue.

Global Options:
   --fast
        No delay every subtask.
   --version
        Print version of this script.
   --help
        Show this help.

Dependency:
   nginx
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Title.
title rcm-nginx-setup-static
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

# Require, validate, and populate value.
chapter Dump variable.
if [ -z "$filename" ];then
    error "Argument --filename required."; x
fi
code 'filename="'$filename'"'
if [ -z "$root" ];then
    error "Argument --root required."; x
fi
code 'root="'$root'"'
if [[ ${#server_name[@]} -eq 0 ]];then
    error "Argument --server-name required."; x
fi
code 'server_name=('"${server_name[@]}"')'
____

file_config="/etc/nginx/sites-available/$filename"
create_new=
chapter Memeriksa file konfigurasi $file_config.
if [ -f "$file_config" ];then
    __ File ditemukan.
    string="$root"
    string_quoted=$(sed "s/\./\\\./g" <<< "$string")
    if grep -q -E "^\s*root\s+.*$string_quoted.*;\s*$" "$file_config";then
        __ Directive root '`'$string'`' sudah terdapat pada file config.
    else
        __ Directive root '`'$string'`' belum terdapat pada file config.
        create_new=1
    fi
    for string in "${server_name[@]}" ;do
        string_quoted=$(sed "s/\./\\\./g" <<< "$string")
        if grep -q -E "^\s*server_name\s+.*$string_quoted.*;\s*$" "$file_config";then
            __ Directive server_name '`'$string'`' sudah terdapat pada file config.
        else
            __ Directive server_name '`'$string'`' belum terdapat pada file config.
            create_new=1
        fi
    done
else
    create_new=1
fi
____

if [ -n "$create_new" ];then
    chapter Membuat file konfigurasi $file_config.
    if [ -f "$file_config" ];then
        __ Backup file "$file_config".
        backupFile move "$file_config"
    fi
    __ Membuat file "$file_config".
    cat <<'EOF' > "$file_config"
server {
    listen 80;
    listen [::]:80;
    root __ROOT__;
    index index.html;
    server_name ;
    location / {
        try_files $uri $uri/ =404;
    }
}
EOF
    sed -i "s|__ROOT__|${root}|g" "$file_config"
    cd /etc/nginx/sites-enabled/
    ln -sf ../sites-available/$filename
    cd - >/dev/null
    for string in "${server_name[@]}" ;do
        sed -i -E "s/server_name([^;]+);/server_name\1 "${string}";/" "$file_config"
    done
    sed -i -E "s/server_name\s{2}/server_name /" "$file_config"
    __; _, Mengecek link di direktori sites-enabled:' ';
    if [ -L /etc/nginx/sites-enabled/$filename ];then
        _, Link sudah ada.; _.
    else
        _ Membuat link.' '
        cd /etc/nginx/sites-enabled/
        ln -sf ../sites-available/$filename
        cd - >/dev/null
        if [ -L /etc/nginx/sites-enabled/$filename ];then
            success Berhasil dibuat.
        else
            error Gagal dibuat.; x
        fi
    fi
    ____

    chapter Reload nginx configuration.
    __ Cleaning broken symbolic link.
    code find /etc/nginx/sites-enabled -xtype l -delete -print
    find /etc/nginx/sites-enabled -xtype l -delete -print
    if nginx -t 2> /dev/null;then
        code nginx -s reload
        nginx -s reload; sleep .5
    else
        error Terjadi kesalahan konfigurasi nginx. Gagal reload nginx.; x
    fi
    ____

    chapter Memeriksa ulang file konfigurasi.
    string="$root"
    string_quoted=$(sed "s/\./\\\./g" <<< "$string")
    if grep -q -E "^\s*root\s+.*$string_quoted.*;\s*$" "$file_config";then
        __; green Directive root "$string" sudah terdapat pada file config.; _.
        reload=1
    else
        __; red Directive root "$string" belum terdapat pada file config.; x
    fi
    for string in "${server_name[@]}" ;do
        string_quoted=$(sed "s/\./\\\./g" <<< "$string")
        if grep -q -E "^\s*server_name\s+.*$string_quoted.*;\s*$" "$file_config";then
            __; green Directive server_name "$string" sudah terdapat pada file config.; _.
        else
            __; red Directive server_name "$string" belum terdapat pada file config.; x
        fi
    done
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
# )
# VALUE=(
# --root
# --filename
# )
# MULTIVALUE=(
# --server-name
# )
# FLAG_VALUE=(
# )
# EOF
# clear

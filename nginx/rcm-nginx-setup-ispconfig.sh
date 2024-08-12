#!/bin/bash

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
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
e() { echo -n "$INDENT" >&2; echo "#" "$@" >&2; }
_() { echo -n "$INDENT" >&2; echo -n "#" "$@" >&2; }
_,() { echo -n "$@" >&2; }
_.() { echo >&2; }
__() { echo -n "$INDENT" >&2; echo -n "#" '    ' >&2; [ -n "$1" ] && echo "$@" >&2 || echo -n  >&2; }
____() { echo >&2; [ -n "$delay" ] && sleep "$delay"; }

# Functions.
printVersion() {
    echo '0.7.1'
}
printHelp() {
    title RCM Nginx Setup
    _ 'Variation '; yellow ISPConfig Default; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-nginx-setup-ispconfig [options]

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
   systemctl
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Dependency.
while IFS= read -r line; do
    [[ -z "$line" ]] || command -v "${line}" >/dev/null || { echo -e "\e[91m""Unable to proceed, ${line} command not found." "\e[39m"; exit 1; }
done <<< `printHelp 2>/dev/null | sed -n '/^Dependency:/,$p' | sed -n '2,/^$/p' | sed 's/^ *//g'`

# Functions.
backupFile() {
    local mode="$1"
    local oldpath="$2" i newpath
    i=1
    newpath="${oldpath}.${i}"
    if [ -f "$newpath" ]; then
        let i++
        newpath="${oldpath}.${i}"
        while [ -f "$newpath" ] ; do
            let i++
            newpath="${oldpath}.${i}"
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

# Title.
title rcm-nginx-setup-ispconfig
____

# Require, validate, and populate value.
chapter Dump variable.
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

chapter Mengecek UnitFileState service Apache2. # Menginstall PHP di Debian, biasanya auto install juga Apache2.
msg=$(systemctl show apache2.service --no-page | grep UnitFileState | grep -o -P "UnitFileState=\K(\S+)")
disable=
if [[ -z "$msg" ]];then
    __ UnitFileState service Apache2 not found.
elif [[ "$msg"  == 'enabled' ]];then
    __ UnitFileState service Apache2 enabled.
    disable=1
else
    __ UnitFileState service Apache2: $msg.
fi
____

if [ -n "$disable" ];then
    chapter Mematikan service Apache2.
    code systemctl disable --now apache2
    systemctl disable --now apache2
    msg=$(systemctl show apache2.service --no-page | grep UnitFileState | grep -o -P "UnitFileState=\K(\S+)")
    if [[ $msg == 'disabled' ]];then
        __; green Berhasil disabled.; _.
    else
        __; red Gagal disabled.; _.
        __ UnitFileState state: $msg.
        exit
    fi
    ____
fi

chapter Mengecek ActiveState service Nginx. # Kadang bentrok dengan Apache2.
msg=$(systemctl show nginx.service --no-page | grep ActiveState | grep -o -P "^ActiveState=\K(\S+)")
restart=
if [[ -z "$msg" ]];then
    __; red Service nginx tidak ditemukan.; x
elif [[ "$msg"  == 'active' ]];then
    __ Service nginx active.
else
    __ Service ActiveState nginx: $msg.
    restart=1
fi
____

if [ -n "$restart" ];then
    chapter Menjalankan service nginx.
    code systemctl enable --now nginx
    systemctl enable --now nginx
    msg=$(systemctl show nginx.service --no-page | grep ActiveState | grep -o -P "ActiveState=\K(\S+)")
    if [[ $msg == 'active' ]];then
        __; green Berhasil activated.; _.
    else
        __; red Gagal activated.; _.
        __ ActiveState state: $msg.
        exit
    fi
    ____
fi

chapter Membatasi akses ke localhost.
if [ -L /etc/nginx/sites-enabled/default ];then
    __ Menghapus symlink /etc/nginx/sites-enabled/default
    rm /etc/nginx/sites-enabled/default
fi
if [ -f /etc/nginx/sites-available/default ];then
    __ Backup file /etc/nginx/sites-available/default
    backupFile move /etc/nginx/sites-available/default
    cat <<'EOF' > /etc/nginx/sites-available/default
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root /var/www/html;
    index index.html;
    server_name _;
    location / {
        deny all;
    }
}
EOF
    cd /etc/nginx/sites-enabled/
    ln -sf ../sites-available/default
    __ Cleaning broken symbolic link.
    code find /etc/nginx/sites-enabled -xtype l -delete -print
    find /etc/nginx/sites-enabled -xtype l -delete -print
    if nginx -t 2> /dev/null;then
        code nginx -s reload
        nginx -s reload
        sleep .5
    else
        error Terjadi kesalahan konfigurasi nginx. Gagal reload nginx.; exit
    fi
    cd - >/dev/null
fi
    __; magenta curl http://127.0.0.1; _.
code=$(curl -L \
    -o /dev/null -s -w "%{http_code}\n" \
    http://127.0.0.1)
[ $code -eq 403 ] && {
    __ HTTP Response code '`'$code'`' '('Required')'.
} || {
    __; red Terjadi kesalahan. HTTP Response code '`'$code'`'.; x
}
____

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
# )
# MULTIVALUE=(
# )
# FLAG_VALUE=(
# )
# CSV=(
# )
# EOF
# clear

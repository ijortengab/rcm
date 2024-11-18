#!/bin/bash

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --fast) fast=1; shift ;;
        --master-certbot-certificate-name=*) master_certbot_certificate_name="${1#*=}"; shift ;;
        --master-certbot-certificate-name) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then master_certbot_certificate_name="$2"; shift; fi; shift ;;
        --master-filename=*) master_filename="${1#*=}"; shift ;;
        --master-filename) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then master_filename="$2"; shift; fi; shift ;;
        --master-include=*) master_include="${1#*=}"; shift ;;
        --master-include) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then master_include="$2"; shift; fi; shift ;;
        --master-include-2=*) master_include_2="${1#*=}"; shift ;;
        --master-include-2) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then master_include_2="$2"; shift; fi; shift ;;
        --master-root=*) master_root="${1#*=}"; shift ;;
        --master-root) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then master_root="$2"; shift; fi; shift ;;
        --master-url-host=*) master_url_host="${1#*=}"; shift ;;
        --master-url-host) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then master_url_host="$2"; shift; fi; shift ;;
        --master-url-port=*) master_url_port="${1#*=}"; shift ;;
        --master-url-port) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then master_url_port="$2"; shift; fi; shift ;;
        --master-url-scheme=*) master_url_scheme="${1#*=}"; shift ;;
        --master-url-scheme) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then master_url_scheme="$2"; shift; fi; shift ;;
        --root-sure) root_sure=1; shift ;;
        --slave-dirname=*) slave_dirname="${1#*=}"; shift ;;
        --slave-dirname) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then slave_dirname="$2"; shift; fi; shift ;;
        --slave-fastcgi-pass=*) slave_fastcgi_pass="${1#*=}"; shift ;;
        --slave-fastcgi-pass) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then slave_fastcgi_pass="$2"; shift; fi; shift ;;
        --slave-filename=*) slave_filename="${1#*=}"; shift ;;
        --slave-filename) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then slave_filename="$2"; shift; fi; shift ;;
        --slave-root=*) slave_root="${1#*=}"; shift ;;
        --slave-root) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then slave_root="$2"; shift; fi; shift ;;
        --slave-url-path=*) slave_url_path="${1#*=}"; shift ;;
        --slave-url-path) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then slave_url_path="$2"; shift; fi; shift ;;
        --with-certbot-obtain) certbot_obtain=1; shift ;;
        --without-certbot-obtain) certbot_obtain=0; shift ;;
        --with-nginx-reload) nginx_reload=1; shift ;;
        --without-nginx-reload) nginx_reload=0; shift ;;
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
    title RCM Nginx Virtual Host Autocreate
    _ 'Variation '; yellow PHP Multiple Root; _.
    _ 'Version '; yellow `printVersion`; _.
    cat << 'EOF'
Usage: rcm-nginx-virtual-host-autocreate-php-multiple-root [options]

Options:
   --master-filename *
        Set the filename to created inside /etc/nginx/sites-available directory.
   --master-root *
        Set the value of root directive.
   --slave-fastcgi-pass *
        Set the value of fastcgi_pass directive.
   --master-url-scheme *
        The URL Scheme. Available value: http, https.
   --master-url-port *
        The URL Port. Set the value of listen directive.
   --master-url-host *
        The URL Host. Set the value of server_name directive.
        Only support one value even the directive may have multivalue.
   --master-include *
        The value to include directive. Include file that contains location directive.
   --master-include-2 *
        Additional value to include directive. Include file that contains location directive.
   --slave-url-path
        The URL Path.
   --slave-url-root
        Set the value of root directive.
   --slave-dirname *
        Set the directory to store additional config.
   --slave-filename *
        Set filename of additional config.
   --without-certbot-obtain ^
        Prevent auto obtain certificate if not exists.
        Default value is --with-certbot-obtain.
   --without-nginx-reload ^
        Prevent auto reload nginx after add/edit file config.
        Default value is --with-nginx-reload.
   --master-certbot-certificate-name
        The name of certificate. Leave blank to use default value.
        Default value is --master-url-host.

Global Options.
   --fast
        No delay every subtask.
   --version
        Print version of this script.
   --help
        Show this help.
   --root-sure
        Bypass root checking.

Dependency:
   rcm-certbot-obtain-authenticator-nginx
   rcm-nginx-reload
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Title.
title rcm-nginx-virtual-host-autocreate-php-multiple-root
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
link_symbolic() {
    local source="$1"
    local target="$2"
    local sudo="$3"
    local create
    [ -e "$source" ] || { error Source not exist: $source.; x; }
    [ -f "$source" ] || { error Source exists but not file: $source.; x; }
    [ -n "$target" ] || { error Target not defined.; x; }
    [[ $(type -t backupFile) == function ]] || { error Function backupFile not found.; x; }
    [[ $(type -t backupDir) == function ]] || { error Function backupDir not found.; x; }

    chapter Membuat symbolic link.
    __ source: '`'$source'`'
    __ target: '`'$target'`'
    if [ -f "$target" ];then
        if [ -h "$target" ];then
            __ Path target saat ini sudah merupakan file symbolic link: '`'$target'`'
            local _readlink=$(readlink "$target")
            __; magenta readlink "$target"; _.
            _ $_readlink; _.
            if [[ "$_readlink" =~ ^[^/\.] ]];then
                local target_parent=$(dirname "$target")
                local _dereference="${target_parent}/${_readlink}"
            elif [[ "$_readlink" =~ ^[\.] ]];then
                local target_parent=$(dirname "$target")
                local _dereference="${target_parent}/${_readlink}"
                _dereference=$(realpath -s "$_dereference")
            else
                _dereference="$_readlink"
            fi
            __; _, Mengecek apakah link merujuk ke '`'$source'`':' '
            if [[ "$source" == "$_dereference" ]];then
                _, merujuk.; _.
            else
                _, tidak merujuk.; _.
                __ Melakukan backup.
                backupFile move "$target"
                create=1
            fi
        else
            __ Melakukan backup regular file: '`'"$target"'`'.
            backupFile move "$target"
            create=1
        fi
    elif [ -d "$target" ];then
        __ Melakukan backup direktori: '`'"$target"'`'.
        backupDir "$target"
        create=1
    else
        create=1
    fi
    if [ -n "$create" ];then
        __ Membuat symbolic link: '`'$target'`'.
        local target_parent=$(dirname "$target")
        code mkdir -p "$target_parent"
        mkdir -p "$target_parent"
        local source_relative=$(realpath -s --relative-to="$target_parent" "$source")
        if [ -n "$sudo" ];then
            code sudo -u '"'$sudo'"' ln -s '"'$source_relative'"' '"'$target'"'
            sudo -u "$sudo" ln -s "$source_relative" "$target"
        else
            code ln -s '"'$source_relative'"' '"'$target'"'
            ln -s "$source_relative" "$target"
        fi
        if [ $? -eq 0 ];then
            __; green Symbolic link berhasil dibuat.; _.
        else
            __; red Symbolic link gagal dibuat.; x
        fi
    fi
    ____
}
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
backupDir() {
    local oldpath="$1" i newpath
    i=1
    newpath="${oldpath}.${i}"
    if [ -e "$newpath" ]; then
        let i++
        newpath="${oldpath}.${i}"
        while [ -e "$newpath" ] ; do
            let i++
            newpath="${oldpath}.${i}"
        done
    fi
    mv "$oldpath" "$newpath"
}
dirMustExists() {
    # global used:
    # global modified:
    # function used: __, success, error, x
    if [ -d "$1" ];then
        __; green Direktori '`'$(basename "$1")'`' ditemukan.; _.
    else
        __; red Direktori '`'$(basename "$1")'`' tidak ditemukan.; x
    fi
}
isDirExists() {
    # global used:
    # global modified: found, notfound
    # function used: __
    found=
    notfound=
    if [ -d "$1" ];then
        __ Direktori '`'$(basename "$1")'`' ditemukan.
        found=1
    else
        __ Direktori '`'$(basename "$1")'`' tidak ditemukan.
        notfound=1
    fi
}
findString() {
    local find="$1" find_quoted string path="$2"
    __ Memeriksa baris dengan kalimat: '`'$find'`'.
    find_quoted="$find"
    find_quoted=$(sed -E "s/\s+/\\\s\+/g" <<< "$find_quoted")
    find_quoted=$(sed "s/\./\\\./g" <<< "$find_quoted")
    find_quoted=$(sed "s/\*/\\\*/g" <<< "$find_quoted")
    find_quoted=$(sed "s/;$/\\\s\*;/g" <<< "$find_quoted")
    code grep -E '"'"^\s*${find_quoted}"'"' '"'"\$path"'"'
    if grep -q -E "^\s*${find_quoted}" "$path";then
        string=$(grep -E "$find_quoted" "$path")
        while read -r line; do e "$line"; done <<< "$string"
        __ Baris ditemukan.
        return 0
    else
        __ Baris tidak ditemukan.
        return 1
    fi
}
validateContentMaster() {
    local find path="$1"
    # listen
    find="listen __MASTER_URL_PORT____SSL__;"
    find=$(echo "$find" | sed "s|__MASTER_URL_PORT__|${master_url_port}|g")
    if [ "$master_url_scheme" == https ];then
        find=$(echo "$find" | sed "s|__SSL__| ssl|g")
    else
        find=$(echo "$find" | sed "s|__SSL__||g")
    fi
    if ! findString "$find" "$path";then
        __; yellow File akan dibuat ulang.; _.
            return 1
    fi
    # root
    find="root __MASTER_ROOT__;"
    find=$(echo "$find" | sed "s|__MASTER_ROOT__|${master_root}|g")
    if ! findString "$find" "$path";then
        __; yellow File akan dibuat ulang.; _.
            return 1
    fi
    # server_name
    find="server_name __MASTER_URL_HOST__;"
    find=$(echo "$find" | sed "s|__MASTER_URL_HOST__|${master_url_host}|g")
    if ! findString "$find" "$path";then
        __; yellow File akan dibuat ulang.; _.
            return 1
    fi
    if [ "$master_url_scheme" == https ];then
        # ssl_certificate
        find="ssl_certificate /etc/letsencrypt/live/__MASTER_CERTBOT_CERTIFICATE_NAME__/fullchain.pem"
        find=$(echo "$find" | sed "s|__MASTER_CERTBOT_CERTIFICATE_NAME__|${master_certbot_certificate_name}|g")
        if ! findString "$find" "$path";then
            __; yellow File akan dibuat ulang.; _.
            return 1
        fi
        # ssl_certificate_key
        find="ssl_certificate_key /etc/letsencrypt/live/__MASTER_CERTBOT_CERTIFICATE_NAME__/privkey.pem"
        find=$(echo "$find" | sed "s|__MASTER_CERTBOT_CERTIFICATE_NAME__|${master_certbot_certificate_name}|g")
        if ! findString "$find" "$path";then
            __; yellow File akan dibuat ulang.; _.
            return 1
        fi
        find="include /etc/letsencrypt/options-ssl-nginx.conf"
        if ! findString "$find" "$path";then
            __; yellow File akan dibuat ulang.; _.
            return 1
        fi
        find="ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem"
        if ! findString "$find" "$path";then
            __; yellow File akan dibuat ulang.; _.
            return 1
        fi
    fi
    if [ "$master_url_scheme" == http ];then
        # ssl_certificate
        find="ssl_certificate /etc/letsencrypt/live/__MASTER_CERTBOT_CERTIFICATE_NAME__/fullchain.pem"
        find=$(echo "$find" | sed "s|__MASTER_CERTBOT_CERTIFICATE_NAME__|${master_certbot_certificate_name}|g")
        if findString "$find" "$path";then
            __; yellow File akan dibuat ulang.; _.
            return 1
        fi
        # ssl_certificate_key
        find="ssl_certificate_key /etc/letsencrypt/live/__MASTER_CERTBOT_CERTIFICATE_NAME__/privkey.pem"
        find=$(echo "$find" | sed "s|__MASTER_CERTBOT_CERTIFICATE_NAME__|${master_certbot_certificate_name}|g")
        if findString "$find" "$path";then
            __; yellow File akan dibuat ulang.; _.
            return 1
        fi
        find="include /etc/letsencrypt/options-ssl-nginx.conf"
        if findString "$find" "$path";then
            __; yellow File akan dibuat ulang.; _.
            return 1
        fi
        find="ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem"
        if findString "$find" "$path";then
            __; yellow File akan dibuat ulang.; _.
            return 1
        fi
    fi
    return 0
}
validateContentSlave() {
    local find
    # fastcgi_pass
    find="fastcgi_pass __SLAVE_FASTCGI_PASS__;"
    find=$(echo "$find" | sed "s|__SLAVE_FASTCGI_PASS__|${slave_fastcgi_pass}|g")
    if ! findString "$find" "$path";then
        __; yellow File akan dibuat ulang.; _.
        return 1
    fi
    if [ -z "$slave_url_path" ];then
        # root
        find="root __SLAVE_ROOT__;"
        find=$(echo "$find" | sed "s|__SLAVE_ROOT__|${slave_root}|g")
        if ! findString "$find" "$path";then
            __; yellow File akan dibuat ulang.; _.
            return 1
        fi
    fi

    return 0

    # listen
    # find="listen __MASTER_URL_PORT____SSL__;"
    # find=$(echo "$find" | sed "s|__MASTER_URL_PORT__|${master_url_port}|g")
    # if [ "$master_url_scheme" == https ];then
        # find=$(echo "$find" | sed "s|__SSL__| ssl|g")
    # else
        # find=$(echo "$find" | sed "s|__SSL__||g")
    # fi
    # if ! findString "$find" "$path";then
        # __; yellow File akan dibuat ulang.; _.
            # return 1
    # fi

    # server_name
    # find="server_name __MASTER_URL_HOST__;"
    # find=$(echo "$find" | sed "s|__MASTER_URL_HOST__|${master_url_host}|g")
    # if ! findString "$find" "$path";then
        # __; yellow File akan dibuat ulang.; _.
            # return 1
    # fi

    if [ "$master_url_scheme" == https ];then
        # ssl_certificate
        find="ssl_certificate /etc/letsencrypt/live/__MASTER_CERTBOT_CERTIFICATE_NAME__/fullchain.pem"
        find=$(echo "$find" | sed "s|__MASTER_CERTBOT_CERTIFICATE_NAME__|${master_certbot_certificate_name}|g")
        if ! findString "$find" "$path";then
            __; yellow File akan dibuat ulang.; _.
            return 1
        fi
        # ssl_certificate_key
        find="ssl_certificate_key /etc/letsencrypt/live/__MASTER_CERTBOT_CERTIFICATE_NAME__/privkey.pem"
        find=$(echo "$find" | sed "s|__MASTER_CERTBOT_CERTIFICATE_NAME__|${master_certbot_certificate_name}|g")
        if ! findString "$find" "$path";then
            __; yellow File akan dibuat ulang.; _.
            return 1
        fi
        find="include /etc/letsencrypt/options-ssl-nginx.conf"
        if ! findString "$find" "$path";then
            __; yellow File akan dibuat ulang.; _.
            return 1
        fi
        find="ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem"
        if ! findString "$find" "$path";then
            __; yellow File akan dibuat ulang.; _.
            return 1
        fi
    fi
    if [ "$master_url_scheme" == http ];then
        # ssl_certificate
        find="ssl_certificate /etc/letsencrypt/live/__MASTER_CERTBOT_CERTIFICATE_NAME__/fullchain.pem"
        find=$(echo "$find" | sed "s|__MASTER_CERTBOT_CERTIFICATE_NAME__|${master_certbot_certificate_name}|g")
        if findString "$find" "$path";then
            __; yellow File akan dibuat ulang.; _.
            return 1
        fi
        # ssl_certificate_key
        find="ssl_certificate_key /etc/letsencrypt/live/__MASTER_CERTBOT_CERTIFICATE_NAME__/privkey.pem"
        find=$(echo "$find" | sed "s|__MASTER_CERTBOT_CERTIFICATE_NAME__|${master_certbot_certificate_name}|g")
        if findString "$find" "$path";then
            __; yellow File akan dibuat ulang.; _.
            return 1
        fi
        find="include /etc/letsencrypt/options-ssl-nginx.conf"
        if findString "$find" "$path";then
            __; yellow File akan dibuat ulang.; _.
            return 1
        fi
        find="ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem"
        if findString "$find" "$path";then
            __; yellow File akan dibuat ulang.; _.
            return 1
        fi
    fi
    if [ -z "$slave_url_path" ];then
        find="include __MASTER_INCLUDE_2__;"
        find=$(echo "$find" | sed "s|__MASTER_INCLUDE_2__|${master_include_2}|g")
        if ! findString "$find" "$path";then
            __; yellow File akan dibuat ulang.; _.
            return 1
        fi
    else
        find="include __MASTER_INCLUDE__/*;"
        find=$(echo "$find" | sed "s|__MASTER_INCLUDE__|${master_include}|g")
        if ! findString "$find" "$path";then
            __; yellow File akan dibuat ulang.; _.
            return 1
        fi
    fi

    return 0
}

# Require, validate, and populate value.
chapter Dump variable.
delay=.5; [ -n "$fast" ] && unset delay
if [ -z "$master_filename" ];then
    error "Argument --master-filename required."; x
fi
if [ -z "$master_root" ];then
    error "Argument --master-root required."; x
fi
if [ -z "$master_url_scheme" ];then
    error "Argument --master-url-scheme required."; x
fi
if [ -z "$master_url_port" ];then
    error "Argument --master-url-port required."; x
fi
if [[ "$master_url_port" =~ [^0-9] ]];then
    error "Argument --master-url-port is not valid."; x
fi
if [ -z "$master_url_host" ];then
    error "Argument --master-url-host required."; x
fi
if [ -z "$master_include" ];then
    error "Argument --master-include required."; x
fi
if [ -z "$master_include_2" ];then
    error "Argument --master-include-2 required."; x
fi
if [ -z "$slave_fastcgi_pass" ];then
    error "Argument --slave-fastcgi-pass required."; x
fi
if [ -z "$slave_url_path" ];then
    if [ -z "$slave_root" ];then
        error "Argument --slave-root required."; x
    fi
fi
if [ -z "$slave_dirname" ];then
    error "Argument --slave-dirname required."; x
fi
[ -d "$slave_dirname" ] || dirMustExists "$slave_dirname"
if [ -z "$slave_filename" ];then
    error "Argument --slave-filename required."; x
fi
if [ -z "$certbot_obtain" ];then
    certbot_obtain=1
fi
if [ -z "$nginx_reload" ];then
    nginx_reload=1
fi
if [ -z "$master_certbot_certificate_name" ];then
    master_certbot_certificate_name="$master_url_host"
fi
code 'master_root="'$master_root'"'
code 'master_include="'$master_include'"'
code 'master_include_2="'$master_include_2'"'
code 'master_filename="'$master_filename'"'
code 'master_url_scheme="'$master_url_scheme'"'
code 'master_url_port="'$master_url_port'"'
code 'master_url_host="'$master_url_host'"'
code 'slave_root="'$slave_root'"'
code 'slave_filename="'$slave_filename'"'
code 'slave_dirname="'$slave_dirname'"'
code 'slave_fastcgi_pass="'$slave_fastcgi_pass'"'
code 'slave_url_path="'$slave_url_path'"'
if [ -n "$slave_url_path" ];then
    # Trim leading and trailing slash.
    slave_url_path_clean=$(echo "$slave_url_path" | sed -E 's|(^/\|/$)+||g')
    # Must leading with slash and no trailing slash.
    # Karena akan digunakan pada nginx configuration.
    _slave_url_path_correct="/${slave_url_path_clean}"
    if [ ! "$slave_url_path" == "$_slave_url_path_correct" ];then
        error "Argument --slave-url-path not valid."; x
    fi
fi
code 'slave_url_path_clean="'$slave_url_path_clean'"'
code 'certbot_obtain="'$certbot_obtain'"'
code 'nginx_reload="'$nginx_reload'"'
code 'master_certbot_certificate_name="'$master_certbot_certificate_name'"'
____

path="/etc/nginx/sites-available/$master_filename"
filename="$master_filename"
chapter Mengecek nginx config file: '`'$filename'`'.
code 'path="'$path'"'
isFileExists "$path"
____

create_new=
if [ -n "$found" ];then
    chapter Memeriksa konten.
    validateContentMaster "$path"
    [ ! $? -eq 0 ] && create_new=1;
    ____
else
    create_new=1
fi

if [[ -n "$create_new" && "$url_scheme" == https ]];then
    path="/etc/letsencrypt/live/${master_certbot_certificate_name}"
    chapter Mengecek direktori certbot '`'$path'`'.
    isDirExists "$path"
    ____

    if [ -n "$notfound" ];then
        if [[ "$certbot_obtain" == 1 ]];then
            chapter Mengecek '$PATH'.
            code PATH="$PATH"
            if grep -q '/snap/bin' <<< "$PATH";then
                __ '$PATH' sudah lengkap.
            else
                __ '$PATH' belum lengkap.
                __ Memperbaiki '$PATH'
                PATH=/snap/bin:$PATH
                if grep -q '/snap/bin' <<< "$PATH";then
                    __; green '$PATH' sudah lengkap.; _.
                    __; magenta PATH="$PATH"; _.
                else
                    __; red '$PATH' belum lengkap.; x
                fi
            fi
            ____

            INDENT+="    " \
            PATH=$PATH \
            rcm-certbot-obtain-authenticator-nginx \
                --domain "$master_url_host" \
                ; [ ! $? -eq 0 ] && x
            nginx_reload=1
        fi
    fi

    chapter Memeriksa certificate SSL.
    path="/etc/letsencrypt/live/${master_certbot_certificate_name}/fullchain.pem"
    code 'path="'$path'"'
    [ -f "$path" ] || fileMustExists "$path"
    path="/etc/letsencrypt/live/${master_certbot_certificate_name}/privkey.pem"
    code 'path="'$path'"'
    [ -f "$path" ] || fileMustExists "$path"
    ____
fi

if [ -n "$create_new" ];then
    path="/etc/nginx/sites-available/$master_filename"
    filename="$master_filename"
    chapter Membuat nginx config file: '`'$filename'`'.
    code 'path="'$path'"'
    if [ -f "$path" ];then
        __ Backup file: '`'"$filename"'`'.
        backupFile move "$path"
    fi
    __ Membuat file "$filename".
    cat <<'EOF' > "$path"
server {
    listen [::]:__MASTER_URL_PORT____SSL__;
    listen __MASTER_URL_PORT____SSL____IPV6ONLY__;
    root __MASTER_ROOT__;
    index index.php;
    server_name __MASTER_URL_HOST__;
    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }
    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    # include __MASTER_INCLUDE__/*;
    # include __MASTER_INCLUDE_2__;

    # ssl_certificate /etc/letsencrypt/live/__MASTER_CERTBOT_CERTIFICATE_NAME__/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/__MASTER_CERTBOT_CERTIFICATE_NAME__/privkey.pem;
    # include /etc/letsencrypt/options-ssl-nginx.conf;
    # ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
}
EOF
    fileMustExists "$path"
    sed -i "s|__MASTER_ROOT__|${master_root}|g" "$path"
    sed -i "s|__MASTER_URL_HOST__|${master_url_host}|g" "$path"
    sed -i "s|__MASTER_CERTBOT_CERTIFICATE_NAME__|${master_certbot_certificate_name}|g" "$path"
    sed -i "s|__MASTER_INCLUDE__|${master_include}|g" "$path"
    sed -i "s|__MASTER_INCLUDE_2__|${master_include_2}|g" "$path"
    sed -i "s|__MASTER_URL_PORT__|${master_url_port}|g" "$path"
    if [ "$master_url_scheme" == https ];then
        sed -i "s|__SSL__| ssl|g" "$path"
        # Hanya satu ipv6only=on yang boleh exist pada setiap virtual host.
        if grep -R -q ipv6only=on /etc/nginx/sites-enabled/;then
            sed -i "s|__IPV6ONLY__||g" "$path"
        else
            sed -i "s|__IPV6ONLY__| ipv6only=on|g" "$path"
        fi
        sed -i -E 's|^(\s*)# ssl_certificate (.*);|\1ssl_certificate \2;|g' "$path"
        sed -i -E 's|^(\s*)# ssl_certificate_key (.*);|\1ssl_certificate_key \2;|g' "$path"
        sed -i -E 's|^(\s*)# include /etc/letsencrypt/options-ssl-nginx.conf;|\1include /etc/letsencrypt/options-ssl-nginx.conf;|g' "$path"
        sed -i -E 's|^(\s*)# ssl_dhparam (.*);|\1ssl_dhparam \2;|g' "$path"
    else
        sed -i "s|__SSL__||g" "$path"
        sed -i "s|__IPV6ONLY__||g" "$path"
    fi
    if [ -z "$slave_url_path" ];then
        sed -i 's|# include '"${master_include_2}"';|include '"${master_include_2}"';|g' "$path"
    else
        sed -i 's|# include '"${master_include}"'/\*;|include '"${master_include}"'/\*;|g' "$path"
    fi
    ____

    chapter Memeriksa ulang konten.
    validateContentMaster "$path"
    [ ! $? -eq 0 ] && x
    ____
fi

source="$path"
target="/etc/nginx/sites-enabled/$master_filename"
link_symbolic "$source" "$target"

chapter Enable the line to include sub nginx config file: '`'$filename'`'.
if [ -z "$slave_url_path" ];then
    find="# include __MASTER_INCLUDE_2__;"
    find=$(echo "$find" | sed "s|__MASTER_INCLUDE_2__|${master_include_2}|g")
    if findString "$find" "$path";then
        code sed -i "'"'s|# include '"${master_include_2}"';|include '"${master_include_2}"';|g'"'" "$path"
        sed -i 's|# include '"${master_include_2}"';|include '"${master_include_2}"';|g' "$path"
    fi
else
    find="# include __MASTER_INCLUDE__/*;"
    find=$(echo "$find" | sed "s|__MASTER_INCLUDE__|${master_include}|g")
    if findString "$find" "$path";then
        code sed -i "'"'s|# include '"${master_include}"'/\*;|include '"${master_include}"'/\*;|g'"'" "$path"
        sed -i 's|# include '"${master_include}"'/\*;|include '"${master_include}"'/\*;|g' "$path"
    fi
fi
____

path="${slave_dirname}/${slave_filename}"
filename="$slave_filename"
chapter Mengecek nginx config file: '`'$filename'`'.
code 'path="'$path'"'
isFileExists "$path"
____

create_new=
rcm_nginx_reload=
if [ -n "$found" ];then
    chapter Memeriksa konten.
    validateContentSlave "$path"
    [ ! $? -eq 0 ] && create_new=1;
    ____
else
    create_new=1
fi

if [ -n "$create_new" ];then
    path="${slave_dirname}/${slave_filename}"
    filename="$slave_filename"
    chapter Membuat nginx config file: '`'$filename'`'.
    code 'path="'$path'"'
    if [ -f "$path" ];then
        __ Backup file: '`'"$filename"'`'.
        backupFile move "$path"
    fi
    __ Membuat file "$filename".
    if [ -z "$slave_url_path" ];then
        cat <<'EOF' > "$path"
location / {
    root __SLAVE_ROOT__;
    try_files $uri $uri/ /index.php$is_args$args;
    location ~ ^(.+\.php)(.*)$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass __SLAVE_FASTCGI_PASS__;
    }
}
EOF
        sed -i "s|__SLAVE_ROOT__|${slave_root}|g" "$path"
        sed -i "s|__SLAVE_FASTCGI_PASS__|${slave_fastcgi_pass}|g" "$path"
    else
        cat <<'EOF' > "$path"
location = __SLAVE_URL_PATH__ {
    return 302 __SLAVE_URL_PATH__/;
}
location __SLAVE_URL_PATH__/ {
    try_files $uri $uri/ __SLAVE_URL_PATH__/index.php$is_args$args;
    location ~ ^(.+\.php)(.*)$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass __SLAVE_FASTCGI_PASS__;
    }
}
EOF
        sed -i "s|__SLAVE_URL_PATH__|${slave_url_path}|g" "$path"
        sed -i "s|__SLAVE_FASTCGI_PASS__|${slave_fastcgi_pass}|g" "$path"
    fi
    fileMustExists "$path"
    ____

    chapter Memeriksa ulang konten.
    validateContentSlave "$path"
    [ ! $? -eq 0 ] && x
    ____

    rcm_nginx_reload=1
fi

if [ "$nginx_reload" == 0 ];then
    rcm_nginx_reload=
fi
if [ -n "$rcm_nginx_reload" ];then
    INDENT+="    " \
    rcm-nginx-reload \
        ; [ ! $? -eq 0 ] && x
fi

exit 0

# Aparse-options.sh \
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
# --master-root
# --master-include
# --master-include-2
# --master-filename
# --master-url-port
# --master-url-scheme
# --master-url-host
# --master-certbot-certificate-name
# --slave-root
# --slave-filename
# --slave-dirname
# --slave-fastcgi-pass
# --slave-url-path
# )
# MULTIVALUE=(
# )
# FLAG_VALUE=(
# )
# CSV=(
    # 'long:--with-certbot-obtain,parameter:certbot_obtain'
    # 'long:--without-certbot-obtain,parameter:certbot_obtain,flag_option:reverse'
    # 'long:--with-nginx-reload,parameter:nginx_reload'
    # 'long:--without-nginx-reload,parameter:nginx_reload,flag_option:reverse'
# )
# EOF
# clear

#!/bin/bash

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --domain=*) domain="${1#*=}"; shift ;;
        --domain) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then domain="$2"; shift; fi; shift ;;
        --fast) fast=1; shift ;;
        --php-version=*) php_version="${1#*=}"; shift ;;
        --php-version) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then php_version="$2"; shift; fi; shift ;;
        --project=*) project="${1#*=}"; shift ;;
        --project) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then project="$2"; shift; fi; shift ;;
        --root-sure) root_sure=1; shift ;;
        --subdomain=*) subdomain="${1#*=}"; shift ;;
        --subdomain) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then subdomain="$2"; shift; fi; shift ;;
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
error() { echo -n "$INDENT" >&2; red "$@" >&2; echo >&2; }
success() { echo -n "$INDENT" >&2; green "$@" >&2; echo >&2; }
chapter() { echo -n "$INDENT" >&2; yellow "$@" >&2; echo >&2; }
title() { echo -n "$INDENT" >&2; blue "$@" >&2; echo >&2; }
code() { echo -n "$INDENT" >&2; magenta "$@" >&2; echo >&2; }
x() { echo >&2; exit 1; }
e() { echo -n "$INDENT" >&2; echo "$@" >&2; }
_() { echo -n "$INDENT" >&2; echo -n "$@" >&2; }
_,() { echo -n "$@" >&2; }
_.() { echo >&2; }
__() { echo -n "$INDENT" >&2; echo -n '    ' >&2; [ -n "$1" ] && echo "$@" >&2 || echo -n  >&2; }
____() { echo >&2; [ -n "$delay" ] && sleep "$delay"; }

# Functions.
printVersion() {
    echo '0.2.0'
}
printHelp() {
    title RCM ISPConfig Setup
    _ 'Variation '; yellow Wrapper Nginx Setup PHP-FPM; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-ispconfig-setup-wrapper-nginx-setup-php-fpm.sh [options]

Options:
   --subdomain
        Set the subdomain if any.
   --domain
        Set the domain.
   --project
        Available value: ispconfig, phpmyadmin, roundcube.
   --php-version
        Set the version of PHP FPM.

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
   rcm-nginx-setup-php-fpm.sh
   ispconfig.sh
   curl
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
title rcm-ispconfig-setup-wrapper-nginx-setup-php-fpm.sh
____

# Require, validate, and populate value.
chapter Dump variable.
[ -n "$fast" ] && isfast=' --fast' || isfast=''
delay=.5; [ -n "$fast" ] && unset delay
case "$project" in
    ispconfig|phpmyadmin|roundcube) ;;
    *) project=
esac
until [[ -n "$project" ]];do
    _ Available value:' '; yellow ispconfig, phpmyadmin, roundcube.; _.
    read -p "Argument --project required: " project
    case "$project" in
        ispconfig|phpmyadmin|roundcube) ;;
        *) project=
    esac
done
code 'project="'$project'"'
code 'subdomain="'$subdomain'"'
until [[ -n "$domain" ]];do
    read -p "Argument --domain required: " domain
done
code 'domain="'$domain'"'
if [ -n "$subdomain" ];then
    fqdn_project="${subdomain}.${domain}"
else
    fqdn_project="${domain}"
fi
code 'fqdn_project="'$fqdn_project'"'
code 'php_version="'$php_version'"'
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

# Populate Variable.
chapter Dump variable of '`'ispconfig.sh export'`' command
. ispconfig.sh export >/dev/null
code phpmyadmin_install_dir="$phpmyadmin_install_dir"
code roundcube_install_dir="$roundcube_install_dir"
code ispconfig_install_dir="$ispconfig_install_dir"
code scripts_dir="$scripts_dir"
____

chapter Prepare arguments.
case "$project" in
    ispconfig) root="${ispconfig_install_dir}/interface/web" ;;
    phpmyadmin) root="${phpmyadmin_install_dir}" ;;
    roundcube) root="${roundcube_install_dir}" ;;
esac
code root="$root"
filename="$fqdn_project"
code filename="$filename"
server_name="$fqdn_project"
code server_name="$server_name"
____
_ _______________________________________________________________________;_.;_.;

INDENT+="    " \
rcm-nginx-setup-php-fpm.sh $isfast --root-sure \
    --root="$root" \
    --php-version="$php_version" \
    --filename="$filename" \
    --server-name="$server_name" \
    ; [ ! $? -eq 0 ] && x
_ _______________________________________________________________________;_.;_.;

chapter Mengecek HTTP Response Code.
code curl http://127.0.0.1 -H '"'Host: ${fqdn_project}'"'
code=$(curl -L \
    -o /dev/null -s -w "%{http_code}\n" \
    http://127.0.0.1 -H "Host: ${fqdn_project}")
[[ $code =~ ^[2,3] ]] && {
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
# --domain
# --subdomain
# --project
# --php-version
# )
# FLAG_VALUE=(
# )
# EOF
# clear

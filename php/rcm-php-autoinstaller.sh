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
    echo '0.16.12'
}
printHelp() {
    title RCM PHP Auto-Installer
    _ 'Variation '; yellow Default; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-php-autoinstaller [options]

Options:
   --php-version
        Set version of PHP.

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
   lsb_release
   curl
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Title.
title rcm-php-autoinstaller
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
downloadApplication() {
    local aptnotfound=
    local string_quoted
    chapter Melakukan instalasi aplikasi.
    code apt install "$@"
    [ -z "$aptinstalled" ] && aptinstalled=$(apt --installed list 2>/dev/null)
    for i in "$@"; do
        string_quoted=$(sed "s/\./\\\./g" <<< "$i")
        if ! grep -q "^$string_quoted/" <<< "$aptinstalled";then
            aptnotfound+=" $i"
        fi
    done
    if [ -n "$aptnotfound" ];then
        __ Menginstal.
        code apt install -y"$aptnotfound"
        apt install -y --no-install-recommends $aptnotfound
        aptinstalled=$(apt --installed list 2>/dev/null)
    else
        __ Aplikasi sudah terinstall seluruhnya.
    fi
}
validateApplication() {
    local aptnotfound=
    for i in "$@"; do
        if ! grep -q "^$i/" <<< "$aptinstalled";then
            aptnotfound+=" $i"
        fi
    done
    if [ -n "$aptnotfound" ];then
        __; red Gagal menginstall aplikasi:"$aptnotfound"; x
    fi
}
addRepositoryPpaOndrejPhp() {
    local notfound=
    local string string_quoted
    chapter Mengecek source PPA ondrej/php
    # Based on https://packages.sury.org/php/README.txt
    cd /etc/apt/sources.list.d
    string='https://packages.sury.org/php/'
    code string='"'$string'"'
    string_quoted=$(sed "s/\./\\\./g" <<< "$string")
    if grep --no-filename -R -E "$string_quoted" | grep -q -v -E '^\s*#';then
        __ Sudah terdapat di direktori '`'/etc/apt/sources.list.d'`'.
    else
        notfound=1
        __ Tidak terdapat di direktori '`'/etc/apt/sources.list.d'`'.
    fi
    cd - >/dev/null
    ____

    if [ -n "$notfound" ];then
        chapter Menambahkan source PPA ondrej/php
        curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
        sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
        apt update -y
        cd /etc/apt/sources.list.d
        string='https://packages.sury.org/php/'
        code string='"'$string'"'
        string_quoted=$(sed "s/\./\\\./g" <<< "$string")
        if grep --no-filename -R -E "$string_quoted" | grep -q -v -E '^\s*#';then
            __; green Sudah terdapat di direktori '`'/etc/apt/sources.list.d'`'.; _.
            cd - >/dev/null
        else
            __; red Tidak terdapat di direktori '`'/etc/apt/sources.list.d'`'.;  x
        fi
        ____
    fi
}
addRepositoryPpaOndrejPhpUbuntu() {
    local notfound=
    local string string_quoted
    chapter Mengecek source PPA ondrej/php
    # Based on https://launchpad.net/~ondrej/+archive/ubuntu/php
    cd /etc/apt/sources.list.d
    string='https://ppa.launchpadcontent.net/ondrej/php/ubuntu/'
    code string='"'$string'"'
    string_quoted=$(sed "s/\./\\\./g" <<< "$string")
    if grep --no-filename -R -E "$string_quoted" | grep -q -v -E '^\s*#';then
        __ Sudah terdapat di direktori '`'/etc/apt/sources.list.d'`'.
    else
        notfound=1
        __ Tidak terdapat di direktori '`'/etc/apt/sources.list.d'`'.
    fi
    cd - >/dev/null
    ____

    if [ -n "$notfound" ];then
        chapter Menambahkan source PPA ondrej/php
        code LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/php -y
        code apt update -y
        LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/php -y
        apt update -y
        cd /etc/apt/sources.list.d
        string='https://ppa.launchpadcontent.net/ondrej/php/ubuntu/'
        code string='"'$string'"'
        string_quoted=$(sed "s/\./\\\./g" <<< "$string")
        if grep --no-filename -R -E "$string_quoted" | grep -q -v -E '^\s*#';then
            __; green Sudah terdapat di direktori '`'/etc/apt/sources.list.d'`'.; _.
            cd - >/dev/null
        else
            __; red Tidak terdapat di direktori '`'/etc/apt/sources.list.d'`'.;  x
        fi
        ____
    fi
}

# Requirement, validate, and populate value.
chapter Dump variable.
delay=.5; [ -n "$fast" ] && unset delay
code 'php_version="'$php_version'"'
____

if [ -z "$php_version" ];then
    downloadApplication php
    validateApplication php
else
    if [ -f /etc/os-release ];then
        . /etc/os-release
    fi
    code 'ID="'$ID'"'
    code 'VERSION_ID="'$VERSION_ID'"'
    if [ -z "$ID" ];then
        error OS not supported; x;
    fi
    ____

    eligible=0
    case $ID in
        debian)
            case "$VERSION_ID" in
                11)
                    case "$php_version" in
                        7.4) eligible=1 ;;
                        8.1) eligible=1; addRepositoryPpaOndrejPhp ;;
                        8.2) eligible=1; addRepositoryPpaOndrejPhp ;;
                        8.3) eligible=1; addRepositoryPpaOndrejPhp ;;
                        *) error PHP Version "$php_version" not supported; x;
                    esac
                    ;;
                12)
                    case "$php_version" in
                        7.4) eligible=1 addRepositoryPpaOndrejPhp ;;
                        8.1) eligible=1; addRepositoryPpaOndrejPhp ;;
                        8.2) eligible=1 ;;
                        8.3) eligible=1; addRepositoryPpaOndrejPhp ;;
                        *) error PHP Version "$php_version" not supported; x;
                    esac
                    ;;
                *)
                    error OS "$ID" Version "$VERSION_ID" not supported; x;
            esac
            ;;
        ubuntu)
            case "$VERSION_ID" in
                22.04)
                    case "$php_version" in
                        7.4) eligible=1; addRepositoryPpaOndrejPhpUbuntu ;;
                        8.1) eligible=1 ;;
                        8.2) eligible=1; addRepositoryPpaOndrejPhpUbuntu ;;
                        8.3) eligible=1; addRepositoryPpaOndrejPhpUbuntu ;;
                        *) error PHP Version "$php_version" not supported; x;
                    esac
                    ;;
                24.04)
                    case "$php_version" in
                        8.3) eligible=1 ;;
                        *) error PHP Version "$php_version" not supported; x;
                    esac
                    ;;
                *)
                    error OS "$ID" Version "$VERSION_ID" not supported; x;
            esac
            ;;
        *) error OS "$ID" not supported; x;
    esac
    [ -n "$eligible" ] && {
        downloadApplication php"$php_version"
        validateApplication php"$php_version"
    } || { error Package php"$php_version" not found.; x; }
fi
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
# --php-version
# )
# FLAG_VALUE=(
# )
# EOF
# clear

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
        --hostname=*) hostname="${1#*=}"; shift ;;
        --hostname) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then hostname="$2"; shift; fi; shift ;;
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
e() { echo -n "$INDENT" >&2; echo "$@" >&2; }
_() { echo -n "$INDENT" >&2; echo -n "$@" >&2; }
_,() { echo -n "$@" >&2; }
_.() { echo >&2; }
__() { echo -n "$INDENT" >&2; echo -n '    ' >&2; [ -n "$1" ] && echo "$@" >&2 || echo -n  >&2; }
____() { echo >&2; [ -n "$delay" ] && sleep "$delay"; }

# Functions.
printVersion() {
    echo '0.3.0'
}
printHelp() {
    title RCM Postfix Auto-Installer
    _ 'Variation '; yellow Default; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-postfix-autoinstaller.sh [options]

Options:
   --hostname
        Set the hostname of server.
   --domain
        Set the domain of server.

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
   debconf-set-selections
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
downloadApplication() {
    local aptnotfound=
    chapter Melakukan instalasi aplikasi "$@".
    [ -z "$aptinstalled" ] && aptinstalled=$(apt --installed list 2>/dev/null)
    for i in "$@"; do
        if ! grep -q "^$i/" <<< "$aptinstalled";then
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

# Title.
title rcm-postfix-autoinstaller.sh
____

# Requirement, validate, and populate value.
chapter Dump variable.
delay=.5; [ -n "$fast" ] && unset delay
until [[ -n "$domain" ]];do
    _; read -p "# Argument --domain required: " domain
done
code 'domain="'$domain'"'
until [[ -n "$hostname" ]];do
    _; read -p "# Argument --hostname required: " hostname
done
code 'hostname="'$hostname'"'
fqdn_string="${hostname}.${domain}"
code fqdn_string="$fqdn_string"
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

debconf-set-selections <<< "postfix postfix/mailname string ${fqdn_string}"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
downloadApplication postfix
validateApplication postfix
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
# --hostname
# --domain
# )
# FLAG_VALUE=(
# )
# EOF
# clear

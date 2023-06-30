#!/bin/bash

# Prerequisite.
[ -f "$0" ] || { echo -e "\e[91m" "Cannot run as dot command. Hit Control+c now." "\e[39m"; read; exit 1; }

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --fast) fast=1; shift ;;
        --[^-]*) shift ;;
        *) _new_arguments+=("$1"); shift ;;
    esac
done
set -- "${_new_arguments[@]}"
unset _new_arguments

# Functions.
[[ $(type -t RcmCertbotDigitaloceanAutoinstaller_printVersion) == function ]] || RcmCertbotDigitaloceanAutoinstaller_printVersion() {
    echo '0.1.1'
}
[[ $(type -t RcmCertbotDigitaloceanAutoinstaller_printHelp) == function ]] || RcmCertbotDigitaloceanAutoinstaller_printHelp() {
    cat << EOF
RCM Certbot DigitalOcean Autoinstaller
Variation Default
Version `RcmCertbotDigitaloceanAutoinstaller_printVersion`

EOF
    cat << 'EOF'
Usage: rcm-certbot-digitalocean-autoinstaller.sh [options]

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
   snap
EOF
}

# Help and Version.
[ -n "$help" ] && { RcmCertbotDigitaloceanAutoinstaller_printHelp; exit 1; }
[ -n "$version" ] && { RcmCertbotDigitaloceanAutoinstaller_printVersion; exit 1; }

# Dependency.
while IFS= read -r line; do
    command -v "${line}" >/dev/null || { echo -e "\e[91m""Unable to proceed, ${line} command not found." "\e[39m"; exit 1; }
done <<< `RcmCertbotDigitaloceanAutoinstaller_printHelp | sed -n '/^Dependency:/,$p' | sed -n '2,/^$/p' | sed 's/^ *//g'`

# Common Functions.
[[ $(type -t red) == function ]] || red() { echo -ne "\e[91m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
[[ $(type -t green) == function ]] || green() { echo -ne "\e[92m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
[[ $(type -t yellow) == function ]] || yellow() { echo -ne "\e[93m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
[[ $(type -t blue) == function ]] || blue() { echo -ne "\e[94m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
[[ $(type -t magenta) == function ]] || magenta() { echo -ne "\e[95m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
[[ $(type -t error) == function ]] || error() { echo -n "$INDENT" >&2; red "$@" >&2; echo >&2; }
[[ $(type -t success) == function ]] || success() { echo -n "$INDENT" >&2; green "$@" >&2; echo >&2; }
[[ $(type -t chapter) == function ]] || chapter() { echo -n "$INDENT" >&2; yellow "$@" >&2; echo >&2; }
[[ $(type -t title) == function ]] || title() { echo -n "$INDENT" >&2; blue "$@" >&2; echo >&2; }
[[ $(type -t code) == function ]] || code() { echo -n "$INDENT" >&2; magenta "$@" >&2; echo >&2; }
[[ $(type -t x) == function ]] || x() { echo >&2; exit 1; }
[[ $(type -t e) == function ]] || e() { echo -n "$INDENT" >&2; echo "$@" >&2; }
[[ $(type -t _) == function ]] || _() { echo -n "$INDENT" >&2; echo -n "$@" >&2; }
[[ $(type -t _,) == function ]] || _,() { echo -n "$@" >&2; }
[[ $(type -t _.) == function ]] || _.() { echo >&2; }
[[ $(type -t __) == function ]] || __() { echo -n "$INDENT" >&2; echo -n '    ' >&2; [ -n "$1" ] && echo "$@" >&2 || echo -n  >&2; }
[[ $(type -t ____) == function ]] || ____() { echo >&2; [ -n "$delay" ] && sleep "$delay"; }

# Functions.

# Title.
title RCM Certbot DigitalOcean Autoinstaller
_ 'Variation '; yellow Default; _.
_ 'Version '; yellow `RcmCertbotDigitaloceanAutoinstaller_printVersion`; _.
____

# Require, validate, and populate value.
chapter Dump variable.
delay=.5; [ -n "$fast" ] && unset delay
____

if [ -z "$root_sure" ];then
    chapter Mengecek akses root.
    if [[ "$EUID" -ne 0 ]]; then
        error This script needs to be run with superuser privileges.; x
    else
        __ Privileges.; root_sure=1
    fi
    ____
fi

chapter Mengecek apakah snap certbot-dns-digitalocean installed.
notfound=
if grep '^certbot-dns-digitalocean\s' <<< $(snap list certbot-dns-digitalocean);then
    __ Snap certbot-dns-digitalocean installed.
else
    __ Snap certbot-dns-digitalocean not found.
    notfound=1
fi
____

if [ -n "$notfound" ];then
    chapter Menginstall snap certbot-dns-digitalocean
    code snap install certbot-dns-digitalocean
    code snap refresh certbot
    snap install certbot-dns-digitalocean
    snap refresh certbot
    if grep '^certbot-dns-digitalocean\s' <<< $(snap list certbot-dns-digitalocean);then
        __; green Snap certbot-dns-digitalocean installed.; _.
    else
        __; red Snap certbot-dns-digitalocean not found.; x
    fi
    ____
fi

chapter Mengecek '$PATH'
code PATH="$PATH"
notfound=
if grep -q '/snap/bin' <<< "$PATH";then
  __ '$PATH' sudah lengkap.
else
  __ '$PATH' belum lengkap.
  notfound=1
fi
____

if [[ -n "$notfound" ]];then
    chapter Memperbaiki '$PATH'
    PATH=/snap/bin:$PATH
    if grep -q '/snap/bin' <<< "$PATH";then
      __; green '$PATH' sudah lengkap.; _.
      __; magenta PATH="$PATH"; _.

    else
      __; red '$PATH' belum lengkap.; x
    fi
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
# )
# MULTIVALUE=(
# )
# FLAG_VALUE=(
# )
# CSV=(
# )
# EOF
# clear

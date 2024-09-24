#!/bin/bash

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --domain=*) domain="${1#*=}"; shift ;;
        --domain) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then domain="$2"; shift; fi; shift ;;
        --email=*) email="${1#*=}"; shift ;;
        --email) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then email="$2"; shift; fi; shift ;;
        --fast) fast=1; shift ;;
        --non-interactive) non_interactive=1; shift ;;
        --root-sure) root_sure=1; shift ;;
        --) shift
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    *) _new_arguments+=("$1"); shift ;;
                esac
            done
            ;;
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
    echo '0.11.2'
}
printHelp() {
    title RCM Certbot Setup
    _ 'Variation '; yellow Nginx; _.
    _ 'Version '; yellow `printVersion`; _.
    cat << EOF

Shortcut version of cerbot --nginx.

EOF
    cat << 'EOF'
Usage: rcm-certbot-setup-nginx [options]

Options:
   --domain *
        Main domain to obtain certificate.
   --email
        Email of cerbot registered account. Try --email=auto.
   --non-interactive ^
        Skip confirmation of --email=auto.
   --
        Every arguments after double dash will pass to certbot command.

Global Options:
   --fast
        No delay every subtask.
   --version
        Print version of this script.
   --help
        Show this help.
   --root-sure
        Bypass root checking.

Example:
     rcm-certbot-setup-nginx -- -d domain2.com

Dependency:
   certbot
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Dependency.
while IFS= read -r line; do
    [[ -z "$line" ]] || command -v `cut -d: -f1 <<< "${line}"` >/dev/null || { echo -e "\e[91m""Unable to proceed, "'`'"${line}"'`'" command not found." "\e[39m"; exit 1; }
done <<< `printHelp 2>/dev/null | sed -n '/^Dependency:/,$p' | sed -n '2,/^\s*$/p' | sed 's/^ *//g'`

# Functions.

# Title.
title rcm-certbot-setup-nginx
____

# Require, validate, and populate value.
chapter Dump variable.
delay=.5; [ -n "$fast" ] && unset delay
code non_interactive="$non_interactive"
until [[ -n "$email" ]];do
    e Tips: Try --email=auto
    _; read -p "Argument --email required: " email
done
if [[ $email == auto ]];then
    email=
    _email=$(certbot show_account 2>/dev/null | grep -o -P 'Email contact: \K(.*)')
    if [ -n "$_email" ];then
        if [ -n "$non_interactive" ];then
            selected=y
        else
            _; read -p "Do you wish to use this email: ${_email}? [y/N]: " selected
        fi
        if [[ "$selected" =~ ^[yY]$ ]]; then
            email="$_email"
        fi
    else
        code email=
    fi
fi
if [ -z "$email" ];then
    error "Argument --email required."; x
fi
code 'email="'$email'"'
regex="^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?\$"
if [[ ! $email =~ $regex ]] ; then
    error Email format is not valid; x
fi
if [ -z "$domain" ];then
    error "Argument --domain required."; x
fi
code 'domain="'$domain'"'
code '-- '"$@"
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

chapter Mengecek certificates atas nama '`'$domain'`'
notfound=
if certbot certificates 2>/dev/null | grep -q -o "Certificate Name: ${domain}";then
    __ Certificate obtained.
else
    __ Certificate not found.
    notfound=1
fi
____

if [ -n "$notfound" ];then
    chapter Request Certificate.
    code certbot --non-interactive -i nginx --agree-tos --email="$email" --domain="$domain" "$@"
    certbot --non-interactive -i nginx --agree-tos --email="$email" --domain="$domain" "$@"
    sleep .5
    if certbot certificates 2>/dev/null | grep -q -o "Certificate Name: ${domain}";then
        __; green Certificate obtained.; _.
    else
        __; red Certificate not found.; x
    fi
    ____
fi

exit 0

# parse-options.sh \
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
# --non-interactive
# )
# VALUE=(
# --domain
# --email
# )
# MULTIVALUE=(
# )
# FLAG_VALUE=(
# )
# EOF
# clear

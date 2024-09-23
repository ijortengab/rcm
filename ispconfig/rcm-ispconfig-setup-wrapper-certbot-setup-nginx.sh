#!/bin/bash

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --digitalocean) dns_authenticator=digitalocean; shift ;;
        --dns-authenticator=*) dns_authenticator="${1#*=}"; shift ;;
        --dns-authenticator) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then dns_authenticator="$2"; shift; fi; shift ;;
        --domain=*) domain="${1#*=}"; shift ;;
        --domain) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then domain="$2"; shift; fi; shift ;;
        --fast) fast=1; shift ;;
        --root-sure) root_sure=1; shift ;;
        --standalone) dns_authenticator=standalone; shift ;;
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
    echo '0.11.0'
}
printHelp() {
    title RCM ISPConfig Setup
    _ 'Variation '; yellow Wrapper Certbot Setup Nginx; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-ispconfig-setup-wrapper-certbot-setup-nginx [options]

Options:
   --subdomain
        Set the subdomain if any.
   --domain
        Set the domain.
   --dns-authenticator
        Available value: digitalocean, standalone.

Global Options:
   --fast
        No delay every subtask.
   --version
        Print version of this script.
   --help
        Show this help.
   --root-sure
        Bypass root checking.

Environment Variables:
   MAILBOX_HOST
        Default to hostmaster
   TOKEN
        Default to $HOME/.$dns_authenticator-token.txt
   TOKEN_INI
        Default to $HOME/.$dns_authenticator-token.ini

Dependency:
   rcm-certbot-setup-nginx
   systemctl
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Dependency.
while IFS= read -r line; do
    [[ -z "$line" ]] || command -v "${line}" >/dev/null || { echo -e "\e[91m""Unable to proceed, "'`'"${line}"'`'" command not found." "\e[39m"; exit 1; }
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
ArraySearch() {
    local index match="$1"
    local source=("${!2}")
    for index in "${!source[@]}"; do
       if [[ "${source[$index]}" == "${match}" ]]; then
           _return=$index; return 0
       fi
    done
    return 1
}
vercomp() {
    # https://www.google.com/search?q=bash+compare+version
    # https://stackoverflow.com/a/4025065
    if [[ $1 == $2 ]]; then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++)); do
        if [[ -z ${ver2[i]} ]];then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 2
        fi
    done
    return 0
}

# Title.
title rcm-ispconfig-setup-wrapper-certbot-setup-nginx
____

# Require, validate, and populate value.
chapter Dump variable.
[ -n "$fast" ] && isfast=' --fast' || isfast=''
delay=.5; [ -n "$fast" ] && unset delay
MAILBOX_HOST=${MAILBOX_HOST:=hostmaster}
code 'MAILBOX_HOST="'$MAILBOX_HOST'"'
code 'subdomain="'$subdomain'"'
if [ -z "$domain" ];then
    error "Argument --domain required."; x
fi
code 'domain="'$domain'"'
if [ -n "$subdomain" ];then
    fqdn_project="${subdomain}.${domain}"
else
    fqdn_project="${domain}"
fi
code 'fqdn_project="'$fqdn_project'"'
if [ -z "$dns_authenticator" ];then
    error "Argument --dns-authenticator required."; x
fi
case "$dns_authenticator" in
    digitalocean) ;;
    standalone) ;;
    *) dns_authenticator=
esac
if [ -z "$dns_authenticator" ];then
    error "Argument --dns-authenticator is not valid.";
    _ Available value:' '; yellow digitalocean; _, ', '; yellow standalone; _, .; _.
    x
fi
code 'dns_authenticator="'$dns_authenticator'"'
if [[ "$dns_authenticator" == 'digitalocean' ]]; then
    TOKEN=${TOKEN:=$HOME/.$dns_authenticator-token.txt}
    code 'TOKEN="'$TOKEN'"'
    TOKEN_INI=${TOKEN_INI:=$HOME/.$dns_authenticator-token.ini}
    code 'TOKEN_INI="'$TOKEN_INI'"'
fi
vercomp `stat --version | head -1 | grep -o -E '\S+$'` 8.31
if [[ $? -lt 2 ]];then
    stat_cached=' --cached=never'
else
    stat_cached=''
fi
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

chapter Mengecek DNS Authenticator
__ Menggunakan DNS Authenticator '`'$dns_authenticator'`'
____

chapter Prepare arguments.
domain="$fqdn_project"
code 'domain="'$fqdn_project'"'
____

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
    ____
fi

email=$(certbot show_account 2>/dev/null | grep -o -P 'Email contact: \K(.*)')
if [ -n "$email" ];then
    __ Certbot account has found: "$email"
else
    email="${MAILBOX_HOST}@${domain}"
fi
code 'email="'$email'"'
____

if [[ "$dns_authenticator" == 'digitalocean' ]]; then
    chapter Mengecek Token
    fileMustExists "$TOKEN"
    digitalocean_token=$(<$TOKEN)
    __; magenta 'digitalocean_token="'$digitalocean_token'"'; _.
    isFileExists "$TOKEN_INI"
    if [ -n "$notfound" ];then
        __ Membuat file "$TOKEN_INI"
        cat << EOF > "$TOKEN_INI"
dns_digitalocean_token = $digitalocean_token
EOF
    fi
    fileMustExists "$TOKEN_INI"
    if [[ $(stat "$TOKEN_INI" -c %a) == 600 ]];then
        __ File  '`'"$TOKEN_INI"'`' memiliki permission '`'600'`'.
    else
        __ File  '`'"$TOKEN_INI"'`' tidak memiliki permission '`'600'`'.
        tweak=1
    fi
    if [ -n "$tweak" ];then
        chmod 600 "$TOKEN_INI"
        if [[ $(stat ${stat_cached} "$TOKEN_INI" -c %a) == 600 ]];then
            __; green File  '`'"$TOKEN_INI"'`' memiliki permission '`'600'`'.; _.
        else
            __; red File  '`'"$TOKEN_INI"'`' tidak memiliki permission '`'600'`'.; x
        fi
    fi
    ____

    INDENT+="    " \
    PATH=$PATH \
    rcm-certbot-setup-nginx $isfast --root-sure \
        --domain="$domain" \
        --email="$email" \
        -- \
        --dns-digitalocean \
        --dns-digitalocean-credentials="$TOKEN_INI" \
        ; [ ! $? -eq 0 ] && x
fi
if [[ "$dns_authenticator" == 'standalone' ]]; then
    chapter Mendeteksi command yang menggunakan port 80.
    code 'lsof -i :80'
    lsof -i :80
    _commands_of_port80=()
    while IFS= read -r line; do
        if [ -n "$line" ];then
            _command=$(ps -p $line -o comm -h)
            if ! ArraySearch "$_command" _commands_of_port80[@];then
                _commands_of_port80+=("$_command")
            fi
        fi
    done <<< `lsof -i :80 -t`
    ____

    chapter Mematikan command yang me-listen port 80.
    for _command in "${_commands_of_port80[@]}"; do
        case "$_command" in
            nginx)
                code systemctl stop nginx
                systemctl stop nginx
                ;;
        esac
    done
    ____

    if [[ ! $(lsof -i :80 -t | wc -l) -eq 0 ]];then
        error Terdapat process yang masih me-listen port 80.
        code lsof -i :80 -t
        lsof -i :80 -t
        x
    fi

    INDENT+="    " \
    PATH=$PATH \
    rcm-certbot-setup-nginx $isfast --root-sure \
        --domain="$domain" \
        --email="$email" \
        -- \
        --standalone \
        ; [ ! $? -eq 0 ] && x

    chapter Menghidupkan kembali command yang me-listen port 80.
    code 'lsof -i :80'
    lsof -i :80
    if [[ ! $(lsof -i :80 -t | wc -l) -eq 0 ]];then
        __ Port 80 dari certbot masih exists.
    fi
    until [[ $(lsof -i :80 -t | wc -l) -eq 0 ]];do
        __ Memaksa mematikan proses yang me-listen port 80.
        __; magenta kill -9 $(lsof -i :80 -t | head -1); _.
        kill -9 $(lsof -i :80 -t | head -1)
    done
    for _command in "${_commands_of_port80[@]}"; do
        case "$_command" in
            nginx)
                code systemctl start nginx
                systemctl start nginx
                ;;
        esac
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
# --no-error-require-arguments << EOF
# FLAG=(
# --fast
# --version
# --help
# --root-sure
# )
# VALUE=(
# --domain
# --subdomain
# --dns-authenticator
# )
# MULTIVALUE=(
# )
# FLAG_VALUE=(
# )
# CSV=(
    # long:--digitalocean,parameter:dns_authenticator,type:flag,flag_option:true=digitalocean
    # long:--standalone,parameter:dns_authenticator,type:flag,flag_option:true=standalone
# )
# EOF

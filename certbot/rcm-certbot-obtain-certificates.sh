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
    echo '0.3.0'
}
printHelp() {
    title RCM Certbot Obtain
    _ 'Variation '; yellow Certificates Default; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-certbot-obtain-certificates.sh [options]

Options:
   --subdomain
        Set the subdomain if any.
   --domain *
        Set the domain.
   --dns-authenticator *
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
   certbot
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
link_symbolic() {
    local source="$1"
    local target="$2"
    local create
    _success=
    [ -e "$source" ] || { error Source not exist: $source.; x; }
    [ -n "$target" ] || { error Target not defined.; x; }
    [[ $(type -t backupFile) == function ]] || { error Function backupFile not found.; x; }
    [[ $(type -t isFileExists) == function ]] || { error Function isFileExists not found.; x; }

    chapter Memeriksa file '`'$target'`'
    isFileExists "$target"
    if [ -n "$notfound" ];then
        create=1
    else
        if [ -h "$target" ];then
            __; _, Mengecek apakah file merujuk ke '`'$source'`':
            _dereference=$(stat --cached=never "$target" -c %N)
            match="'$target' -> '$source'"
            if [[ "$_dereference" == "$match" ]];then
                _, ' 'Merujuk.; _.
            else
                _, ' 'Tidak Merujuk.; _.
                __ Melakukan backup.
                backupFile move "$target"
                create=1
            fi
        else
            __ File bukan merupakan symbolic link.
            __ Melakukan backup.
            backupFile move "$target"
            create=1
        fi
    fi
    ____

    if [ -n "$create" ];then
        chapter Membuat symbolic link '`'$target'`'.
        code ln -s \"$source\" \"$target\"
        ln -s "$source" "$target"
        __ Verifikasi
        if [ -h "$target" ];then
            _dereference=$(stat --cached=never "$target" -c %N)
            match="'$target' -> '$source'"
            if [[ "$_dereference" == "$match" ]];then
                __; green Symbolic link berhasil dibuat.; _.
                _success=1
            else
                __; red Symbolic link gagal dibuat.; x
            fi
        fi
        ____
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

# Title.
title rcm-certbot-obtain-certificates.sh
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

chapter Prepare arguments.
domain="$fqdn_project"
code 'domain="'$fqdn_project'"'
____

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
    chapter Prepare arguments.
    email=$(certbot show_account 2>/dev/null | grep -o -P 'Email contact: \K(.*)')
    if [ -n "$email" ];then
        __ Certbot account has found: "$email"
    else
        email="${MAILBOX_HOST}@${domain}"
    fi
    code 'email="'$email'"'
    ____

    chapter Mengecek DNS Authenticator
    __ Menggunakan DNS Authenticator '`'$dns_authenticator'`'
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
            if [[ $(stat --cached=never "$TOKEN_INI" -c %a) == 600 ]];then
                __; green File  '`'"$TOKEN_INI"'`' memiliki permission '`'600'`'.; _.
            else
                __; red File  '`'"$TOKEN_INI"'`' tidak memiliki permission '`'600'`'.; x
            fi
        fi
        ____

        chapter Request Certificate.
        code certbot certonly --non-interactive --agree-tos --email='"'$email'"' --domain='"'$domain'"' --dns-digitalocean --dns-digitalocean-credentials='"'$TOKEN_INI'"'
        certbot certonly --non-interactive --agree-tos --email="$email" --domain="$domain" --dns-digitalocean --dns-digitalocean-credentials="$TOKEN_INI"
        sleep .5
        if certbot certificates 2>/dev/null | grep -q -o "Certificate Name: ${domain}";then
            __; green Certificate obtained.; _.
        else
            __; red Certificate not found.; x
        fi
        ____
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

        chapter Request Certificate.
        code certbot certonly --non-interactive --agree-tos --email="$email" --domain="$domain" --standalone
        certbot certonly --non-interactive --agree-tos --email="$email" --domain="$domain" --standalone
        sleep .5
        if certbot certificates 2>/dev/null | grep -q -o "Certificate Name: ${domain}";then
            __; green Certificate obtained.; _.
        else
            __; red Certificate not found.; x
        fi
        ____

        chapter Menghidupkan kembali command yang me-listen port 80.
        for _command in "${_commands_of_port80[@]}"; do
            case "$_command" in
                nginx)
                    systemctl start nginx
                    ;;
            esac
        done
        ____
    fi
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

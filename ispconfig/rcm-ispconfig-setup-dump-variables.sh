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
        --ip-address=*) ip_address="${1#*=}"; shift ;;
        --ip-address) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then ip_address="$2"; shift; fi; shift ;;
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
    _ 'Variation '; yellow Dump Variables; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-ispconfig-setup-dump-variables.sh [options]

Options:
   --domain *
        Set the domain to setup.
   --hostname
        Set the hostname.
   --ip-address
        Set the IP Address.

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
   SUBDOMAIN_ISPCONFIG
        Default to cp
   SUBDOMAIN_PHPMYADMIN
        Default to db
   SUBDOMAIN_ROUNDCUBE
        Default to mail
   MAILBOX_ADMIN
        Default to admin
   MAILBOX_SUPPORT
        Default to support
   MAILBOX_WEB
        Default to webmaster
   MAILBOX_HOST
        Default to hostmaster
   MAILBOX_POST
        Default to postmaster
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

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
databaseCredentialPhpmyadmin() {
    if [ -f /usr/local/share/phpmyadmin/credential/database ];then
        local PHPMYADMIN_DB_USER PHPMYADMIN_DB_USER_PASSWORD PHPMYADMIN_BLOWFISH
        . /usr/local/share/phpmyadmin/credential/database
        phpmyadmin_db_user=$PHPMYADMIN_DB_USER
        phpmyadmin_db_user_password=$PHPMYADMIN_DB_USER_PASSWORD
        phpmyadmin_blowfish=$PHPMYADMIN_BLOWFISH
    else
        phpmyadmin_db_user=$PHPMYADMIN_DB_USER # global variable
        phpmyadmin_db_user_password=$(pwgen -s 32 -1)
        phpmyadmin_blowfish=$(pwgen -s 32 -1)
        mkdir -p /usr/local/share/phpmyadmin/credential
        cat << EOF > /usr/local/share/phpmyadmin/credential/database
PHPMYADMIN_DB_USER=$phpmyadmin_db_user
PHPMYADMIN_DB_USER_PASSWORD=$phpmyadmin_db_user_password
PHPMYADMIN_BLOWFISH=$phpmyadmin_blowfish
EOF
        chmod 0500 /usr/local/share/phpmyadmin/credential
        chmod 0400 /usr/local/share/phpmyadmin/credential/database
    fi
}
databaseCredentialRoundcube() {
    if [ -f /usr/local/share/roundcube/credential/database ];then
        local ROUNDCUBE_DB_USER ROUNDCUBE_DB_USER_PASSWORD ROUNDCUBE_BLOWFISH
        . /usr/local/share/roundcube/credential/database
        roundcube_db_user=$ROUNDCUBE_DB_USER
        roundcube_db_user_password=$ROUNDCUBE_DB_USER_PASSWORD
        roundcube_blowfish=$ROUNDCUBE_BLOWFISH
    else
        roundcube_db_user=$ROUNDCUBE_DB_USER # global variable
        roundcube_db_user_password=$(pwgen -s 32 -1)
        roundcube_blowfish=$(pwgen -s 32 -1)
        mkdir -p /usr/local/share/roundcube/credential
        cat << EOF > /usr/local/share/roundcube/credential/database
ROUNDCUBE_DB_USER=$roundcube_db_user
ROUNDCUBE_DB_USER_PASSWORD=$roundcube_db_user_password
ROUNDCUBE_BLOWFISH=$roundcube_blowfish
EOF
        chmod 0500 /usr/local/share/roundcube/credential
        chmod 0400 /usr/local/share/roundcube/credential/database
    fi
}
databaseCredentialIspconfig() {
    if [ -f /usr/local/share/ispconfig/credential/database ];then
        local ISPCONFIG_DB_NAME ISPCONFIG_DB_USER ISPCONFIG_DB_USER_PASSWORD
        . /usr/local/share/ispconfig/credential/database
        ispconfig_db_name=$ISPCONFIG_DB_NAME
        ispconfig_db_user=$ISPCONFIG_DB_USER
        ispconfig_db_user_password=$ISPCONFIG_DB_USER_PASSWORD
    else
        ispconfig_db_user_password=$(pwgen -s 32 -1)
        mkdir -p /usr/local/share/ispconfig/credential
        cat << EOF > /usr/local/share/ispconfig/credential/database
ISPCONFIG_DB_USER_PASSWORD=$ispconfig_db_user_password
EOF
        chmod 0500 /usr/local/share/ispconfig/credential
        chmod 0400 /usr/local/share/ispconfig/credential/database
    fi
}
websiteCredentialIspconfig() {
    if [ -f /usr/local/share/ispconfig/credential/website ];then
        local ISPCONFIG_WEB_USER_PASSWORD
        . /usr/local/share/ispconfig/credential/website
        ispconfig_web_user_password=$ISPCONFIG_WEB_USER_PASSWORD
    else
        ispconfig_web_user_password=$(pwgen 6 -1vA0B)
        mkdir -p /usr/local/share/ispconfig/credential
        cat << EOF > /usr/local/share/ispconfig/credential/website
ISPCONFIG_WEB_USER_PASSWORD=$ispconfig_web_user_password
EOF
        chmod 0500 /usr/local/share/ispconfig/credential
        chmod 0400 /usr/local/share/ispconfig/credential/website
    fi
}

# Title.
title rcm-ispconfig-setup-dump-variables.sh
____

# Require, validate, and populate value.
chapter Dump variable.
delay=.5; [ -n "$fast" ] && unset delay
SUBDOMAIN_ISPCONFIG=${SUBDOMAIN_ISPCONFIG:=cp}
code 'SUBDOMAIN_ISPCONFIG="'$SUBDOMAIN_ISPCONFIG'"'
SUBDOMAIN_PHPMYADMIN=${SUBDOMAIN_PHPMYADMIN:=db}
code 'SUBDOMAIN_PHPMYADMIN="'$SUBDOMAIN_PHPMYADMIN'"'
SUBDOMAIN_ROUNDCUBE=${SUBDOMAIN_ROUNDCUBE:=mail}
code 'SUBDOMAIN_ROUNDCUBE="'$SUBDOMAIN_ROUNDCUBE'"'
MAILBOX_ADMIN=${MAILBOX_ADMIN:=admin}
code 'MAILBOX_ADMIN="'$MAILBOX_ADMIN'"'
MAILBOX_SUPPORT=${MAILBOX_SUPPORT:=support}
code 'MAILBOX_SUPPORT="'$MAILBOX_SUPPORT'"'
MAILBOX_WEB=${MAILBOX_WEB:=webmaster}
code 'MAILBOX_WEB="'$MAILBOX_WEB'"'
MAILBOX_HOST=${MAILBOX_HOST:=hostmaster}
code 'MAILBOX_HOST="'$MAILBOX_HOST'"'
MAILBOX_POST=${MAILBOX_POST:=postmaster}
code 'MAILBOX_POST="'$MAILBOX_POST'"'
until [[ -n "$domain" ]];do
    read -p "Argument --domain required: " domain
done
code 'domain="'$domain'"'
code 'ip_address="'$ip_address'"'
code 'hostname="'$hostname'"'
fqdn="${hostname}.${domain}"
code fqdn="$fqdn"
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

chapter PHPMyAdmin: "https://${SUBDOMAIN_PHPMYADMIN}.${domain}"
databaseCredentialPhpmyadmin
e ' - 'username: $phpmyadmin_db_user
e '   'password: $phpmyadmin_db_user_password
databaseCredentialRoundcube
e ' - 'username: $roundcube_db_user
e '   'password: $roundcube_db_user_password
databaseCredentialIspconfig
e ' - 'username: $ispconfig_db_user
e '   'password: $ispconfig_db_user_password
____

chapter Roundcube: "https://${SUBDOMAIN_ROUNDCUBE}.${domain}"
e ' - 'username: $MAILBOX_ADMIN
if [ -n "$domain" ];then
    user="$MAILBOX_ADMIN"
    host="$domain"
    . /usr/local/share/credential/mailbox/$host/$user
    e '   'password: $MAILBOX_USER_PASSWORD
else
    e '   'password: ...
fi
e ' - 'username: $MAILBOX_SUPPORT
if [ -n "$domain" ];then
    user="$MAILBOX_SUPPORT"
    host="$domain"
    . /usr/local/share/credential/mailbox/$host/$user
    e '   'password: $MAILBOX_USER_PASSWORD
else
    e '   'password: ...
fi
____

chapter ISPConfig: "https://${SUBDOMAIN_ISPCONFIG}.${domain}"
websiteCredentialIspconfig
e ' - 'username: admin
e '   'password: $ispconfig_web_user_password
____

chapter Manual Action
e Command to make sure remote user working properly:
__; magenta ispconfig.sh php login.php; _.
e Command to implement '`'ispconfig.sh'`' command autocompletion immediately:
__; magenta source /etc/profile.d/ispconfig-completion.sh; _.
e Command to check PTR Record:
if [ -n "$ip_address" ];then
    __; magenta dig -x "$ip_address" +short
else
    __; magenta dig -x "\$ip_address" +short
fi
____

if [ -n "$ip_address" ];then
    if [[ ! $(dig -x $ip_address +short) == ${fqdn}. ]];then
        error Attention
        e Your PTR Record is different with your variable of FQDN.
        __; magenta fqdn="$fqdn"; _.
        __; magenta dig -x $ip_address +short' # ' $(dig -x $ip_address +short); _.
        e "But it doesn't matter if ${domain} is addon domain."
        ____
        chapter Suggestion.
        e If you user of DigitalOcean, change your droplet name with FQDN.
        e More info: https://www.digitalocean.com/community/questions/how-do-i-setup-a-ptr-record
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
# --ip-address
# )
# MULTIVALUE=(
# )
# FLAG_VALUE=(
# )
# CSV=(
# )
# EOF
# clear

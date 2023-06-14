#!/bin/bash

# Prerequisite.
[ -f "$0" ] || { echo -e "\e[91m" "Cannot run as dot command. Hit Control+c now." "\e[39m"; read; exit 1; }

# Parse arguments. Generated by parse-options.sh
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --digitalocean-token=*) digitalocean_token="${1#*=}"; shift ;;
        --digitalocean-token) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then digitalocean_token="$2"; shift; fi; shift ;;
        --domain=*) domain="${1#*=}"; shift ;;
        --domain) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then domain="$2"; shift; fi; shift ;;
        --fast) fast=1; shift ;;
        --hostname=*) hostname="${1#*=}"; shift ;;
        --hostname) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then hostname="$2"; shift; fi; shift ;;
        --ip-address=*) ip_address="${1#*=}"; shift ;;
        --ip-address) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then ip_address="$2"; shift; fi; shift ;;
        --non-interactive) non_interactive=1; shift ;;
        --timezone=*) timezone="${1#*=}"; shift ;;
        --timezone) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then timezone="$2"; shift; fi; shift ;;
        --[^-]*) shift ;;
        *) _new_arguments+=("$1"); shift ;;
    esac
done
set -- "${_new_arguments[@]}"
unset _new_arguments

# Functions.
[[ $(type -t RcmIspconfigSetupVariation1_printVersion) == function ]] || RcmIspconfigSetupVariation1_printVersion() {
    echo '0.1.2'
}
[[ $(type -t RcmIspconfigSetupVariation1_printHelp) == function ]] || RcmIspconfigSetupVariation1_printHelp() {
    cat << EOF
RCM ISPConfig Setup
Variation 2. Ubuntu 22.04, ISPConfig 3.2.7, PHPMyAdmin 5.2.0, Roundcube 1.6.0,
PHP 7.4, DigitalOcean DNS.
Version `RcmIspconfigSetupVariation1_printVersion`

EOF
    cat << 'EOF'
Usage: rcm-ispconfig-setup-variation1.sh [options]

Options:
   --domain *
        Domain name of the server.
   --hostname *
        Hostname of the server.
   --ip-address *
        Set the IP Address. Use with A record while registered. Tips: Try --ip-address=auto.
   --digitalocean-token *
        Token access from digitalocean.com to consume DigitalOcean API.
   --non-interactive ^
        Skip confirmation of --ip-address=auto.
   --timezone
        Set the timezone of this machine.

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

Dependency:
   wget
   rcm-ubuntu-22.04-setup-basic.sh
   rcm-mariadb-autoinstaller.sh
   rcm-mariadb-setup-ispconfig.sh
   rcm-nginx-autoinstaller.sh
   rcm-nginx-setup-ispconfig.sh
   rcm-php-autoinstaller.sh
   rcm-php-setup-adjust-cli-version.sh
   rcm-php-setup-ispconfig.sh
   rcm-postfix-autoinstaller.sh
   rcm-postfix-setup-ispconfig.sh
   rcm-phpmyadmin-autoinstaller-nginx-php-fpm.sh
   rcm-roundcube-autoinstaller-nginx-php-fpm.sh
   rcm-ispconfig-autoinstaller-nginx-php-fpm.sh
   rcm-ispconfig-setup-internal-command.sh
   rcm-roundcube-setup-ispconfig-integration.sh
   rcm-amavis-setup-ispconfig.sh
   rcm-ispconfig-setup-wrapper-nginx-setup-php-fpm.sh
   rcm-ispconfig-control-manage-domain.sh
   rcm-ispconfig-control-manage-email-mailbox.sh
   rcm-ispconfig-control-manage-email-alias.sh
   rcm-digitalocean-api-manage-domain.sh
   rcm-digitalocean-api-manage-domain-record.sh
   rcm-ispconfig-setup-wrapper-digitalocean.sh
   rcm-certbot-autoinstaller.sh
   rcm-certbot-digitalocean-autoinstaller.sh
   rcm-ispconfig-setup-wrapper-certbot-setup-nginx.sh
   rcm-ispconfig-setup-dump-variables.sh
EOF
}

# Help and Version.
[ -n "$help" ] && { RcmIspconfigSetupVariation1_printHelp; exit 1; }
[ -n "$version" ] && { RcmIspconfigSetupVariation1_printVersion; exit 1; }

# Dependency.
while IFS= read -r line; do
    command -v "${line}" >/dev/null || { echo -e "\e[91m""Unable to proceed, ${line} command not found." "\e[39m"; exit 1; }
done <<< `RcmIspconfigSetupVariation1_printHelp | sed -n '/^Dependency:/,$p' | sed -n '2,/^$/p' | sed 's/^ *//g'`

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
[[ $(type -t backupFile) == function ]] || backupFile() {
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
[[ $(type -t fileMustExists) == function ]] || fileMustExists() {
    # global used:
    # global modified:
    # function used: __, success, error, x
    if [ -f "$1" ];then
        __; green File '`'$(basename "$1")'`' ditemukan.; _.
    else
        __; red File '`'$(basename "$1")'`' tidak ditemukan.; x
    fi
}

# Title.
title RCM ISPConfig Setup
_ 'Variation '; yellow 2; _, . Ubuntu 22.04, ISPConfig 3.2.7, PHPMyAdmin 5.2.0, Roundcube 1.6.0, ; _.
e PHP 7.4, DigitalOcean DNS.
_ 'Version '; yellow `RcmIspconfigSetupVariation1_printVersion`; _.
____

# Require, validate, and populate value.
chapter Dump variable.
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
code 'timezone="'$timezone'"'
until [[ -n "$domain" ]];do
    read -p "Argument --domain required: " domain
done
code 'domain="'$domain'"'
until [[ -n "$hostname" ]];do
    read -p "Argument --hostname required: " hostname
done
code 'hostname="'$hostname'"'
fqdn="${hostname}.${domain}"
code fqdn="$fqdn"
until [[ -n "$digitalocean_token" ]];do
    read -p "Argument --digitalocean-token required: " digitalocean_token
done
code 'digitalocean_token="'$digitalocean_token'"'
code non_interactive="$non_interactive"
php_version=7.4
code php_version="$php_version"
phpmyadmin_version=5.2.0
code phpmyadmin_version="$phpmyadmin_version"
roundcube_version=1.6.0
code roundcube_version="$roundcube_version"
ispconfig_version=3.2.7
code ispconfig_version="$ispconfig_version"
if [[ $ip_address == auto ]];then
    ip_address=
    _ip_address=$(wget -T 3 -t 1 -4qO- "http://ip1.dynupdate.no-ip.com/")
    if [ -n "$_ip_address" ];then
        if [ -n "$non_interactive" ];then
            selected=y
        else
            read -p "Do you wish to use this IP Address: ${_ip_address}? [y/N]: " selected
        fi
        if [[ "$selected" =~ ^[yY]$ ]]; then
            ip_address="$_ip_address"
        fi
    fi
fi
until [[ -n "$ip_address" ]];do
    e Tips: Try --ip-address=auto
    read -p "Argument --ip-address required: " ip_address
done
code ip_address="$ip_address"
if ! grep -q -m 1 -oE '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' <<<  "$ip_address" ;then
    error IP Address version 4 format is not valid; x
fi
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

chapter Menyimpan DigitalOcean Token sebagai file text.
if [ -f $HOME/.digitalocean-token.txt ];then
    _token=$(<$HOME/.digitalocean-token.txt)
    if [[ ! "$_token" == "$digitalocean_token" ]];then
        __ Backup file $HOME/.digitalocean-token.txt
        backupFile move $HOME/.digitalocean-token.txt
        echo "$digitalocean_token" > $HOME/.digitalocean-token.txt
    fi
else
    echo "$digitalocean_token" > $HOME/.digitalocean-token.txt
fi
fileMustExists $HOME/.digitalocean-token.txt
_ _______________________________________________________________________;_.;_.;

INDENT+="    "
source $(command -v rcm-ubuntu-22.04-setup-basic.sh)
INDENT=${INDENT::-4}
_ _______________________________________________________________________;_.;_.;

chapter Mengecek FQDN '(Fully-Qualified Domain Name)'
code fqdn="$fqdn"
current_fqdn=$(hostname -f 2>/dev/null)
adjust=
if [[ "$current_fqdn" == "$fqdn" ]];then
    __ Variable '$fqdn' sama dengan value system hostname saat ini '$(hostname -f)'.
else
    __ Variable '$fqdn' tidak sama dengan value system hostname saat ini '$(hostname -f)'.
    adjust=1
fi
____

if [[ -n "$adjust" ]];then
    chapter Adjust FQDN.
    echo "127.0.1.2"$'\t'"${fqdn}"$'\t'"${hostname}" >> /etc/hosts
    sleep .5
    current_fqdn=$(hostname -f 2>/dev/null)
    if [[ "$current_fqdn" == "$fqdn" ]];then
        __; green Variable '$fqdn' sama dengan value system FQDN saat ini '$(hostname -f)'.; _.
    else
        __; red Variable '$fqdn' tidak sama dengan value system hostname saat ini '$(hostname -f)'.; x
    fi
    ____
fi
_ _______________________________________________________________________;_.;_.;

INDENT+="    ";
source $(command -v rcm-mariadb-autoinstaller.sh)
source $(command -v rcm-mariadb-setup-ispconfig.sh)
source $(command -v rcm-nginx-autoinstaller.sh)
source $(command -v rcm-nginx-setup-ispconfig.sh)
source $(command -v rcm-php-autoinstaller.sh)
source $(command -v rcm-php-setup-adjust-cli-version.sh)
source $(command -v rcm-php-setup-ispconfig.sh)
source $(command -v rcm-postfix-autoinstaller.sh)
source $(command -v rcm-postfix-setup-ispconfig.sh)
source $(command -v rcm-phpmyadmin-autoinstaller-nginx-php-fpm.sh)
source $(command -v rcm-roundcube-autoinstaller-nginx-php-fpm.sh)
source $(command -v rcm-ispconfig-autoinstaller-nginx-php-fpm.sh)
source $(command -v rcm-ispconfig-setup-internal-command.sh)
source $(command -v rcm-roundcube-setup-ispconfig-integration.sh)
source $(command -v rcm-amavis-setup-ispconfig.sh)
source $(command -v rcm-roundcube-setup-ispconfig-integration.sh)
source $(command -v rcm-ispconfig-setup-wrapper-nginx-setup-php-fpm.sh) --project=ispconfig --subdomain="$SUBDOMAIN_ISPCONFIG"
source $(command -v rcm-ispconfig-setup-wrapper-nginx-setup-php-fpm.sh) --project=roundcube --subdomain="$SUBDOMAIN_ROUNDCUBE"
source $(command -v rcm-ispconfig-setup-wrapper-nginx-setup-php-fpm.sh) --project=phpmyadmin --subdomain="$SUBDOMAIN_PHPMYADMIN"
_domain="$domain" # Backup variable.
source $(command -v rcm-ispconfig-setup-wrapper-nginx-setup-php-fpm.sh) --project=ispconfig --subdomain="${SUBDOMAIN_ISPCONFIG}.${_domain}" --domain="localhost"
source $(command -v rcm-ispconfig-setup-wrapper-nginx-setup-php-fpm.sh) --project=roundcube --subdomain="${SUBDOMAIN_ROUNDCUBE}.${_domain}" --domain="localhost"
source $(command -v rcm-ispconfig-setup-wrapper-nginx-setup-php-fpm.sh) --project=phpmyadmin --subdomain="${SUBDOMAIN_PHPMYADMIN}.${_domain}" --domain="localhost"
domain="$_domain" # Restore variable.
source $(command -v rcm-ispconfig-control-manage-domain.sh) add
source $(command -v rcm-ispconfig-control-manage-email-mailbox.sh) --name="$MAILBOX_ADMIN"
source $(command -v rcm-ispconfig-control-manage-email-mailbox.sh) --name="$MAILBOX_SUPPORT"
source $(command -v rcm-ispconfig-control-manage-email-alias.sh) --name="$MAILBOX_HOST" --destination-name="$MAILBOX_ADMIN" --destination-domain="$domain"
source $(command -v rcm-ispconfig-control-manage-email-alias.sh) --name="$MAILBOX_POST" --destination-name="$MAILBOX_ADMIN" --destination-domain="$domain"
source $(command -v rcm-ispconfig-control-manage-email-alias.sh) --name="$MAILBOX_WEB" --destination-name="$MAILBOX_ADMIN" --destination-domain="$domain"
_hostname="$hostname" # Backup variable.
source $(command -v rcm-digitalocean-api-manage-domain.sh) add
source $(command -v rcm-digitalocean-api-manage-domain-record.sh) add    --type a     --hostname=@
source $(command -v rcm-digitalocean-api-manage-domain-record.sh) delete --type cname --hostname="$_hostname"
source $(command -v rcm-digitalocean-api-manage-domain-record.sh) add    --type a     --hostname="$_hostname"
source $(command -v rcm-digitalocean-api-manage-domain-record.sh) delete --type a     --hostname="$SUBDOMAIN_ISPCONFIG"
source $(command -v rcm-digitalocean-api-manage-domain-record.sh) add    --type cname --hostname="$SUBDOMAIN_ISPCONFIG"
source $(command -v rcm-digitalocean-api-manage-domain-record.sh) delete --type a     --hostname="$SUBDOMAIN_PHPMYADMIN"
source $(command -v rcm-digitalocean-api-manage-domain-record.sh) add    --type cname --hostname="$SUBDOMAIN_PHPMYADMIN"
source $(command -v rcm-digitalocean-api-manage-domain-record.sh) delete --type a     --hostname="$SUBDOMAIN_ROUNDCUBE"
source $(command -v rcm-digitalocean-api-manage-domain-record.sh) add    --type cname --hostname="$SUBDOMAIN_ROUNDCUBE"
source $(command -v rcm-digitalocean-api-manage-domain-record.sh) add    --type mx    --hostname=@ --mail-provider="$fqdn"
source $(command -v rcm-ispconfig-setup-wrapper-digitalocean.sh) --type spf   --hostname=@ --mail-provider="$fqdn"
source $(command -v rcm-ispconfig-setup-wrapper-digitalocean.sh) --type dmarc --email="${MAILBOX_POST}@${domain}"
source $(command -v rcm-ispconfig-setup-wrapper-digitalocean.sh) --type dkim  --dns-record-auto
hostname="$_hostname" # Restore variable.
source $(command -v rcm-certbot-autoinstaller.sh)
source $(command -v rcm-certbot-digitalocean-autoinstaller.sh)
_domain="$domain" # Backup variable.
source $(command -v rcm-ispconfig-setup-wrapper-certbot-setup-nginx.sh) --digitalocean --domain="$_domain" --subdomain="$SUBDOMAIN_ISPCONFIG"
source $(command -v rcm-ispconfig-setup-wrapper-certbot-setup-nginx.sh) --digitalocean --domain="$_domain" --subdomain="$SUBDOMAIN_PHPMYADMIN"
source $(command -v rcm-ispconfig-setup-wrapper-certbot-setup-nginx.sh) --digitalocean --domain="$_domain" --subdomain="$SUBDOMAIN_ROUNDCUBE"
domain="$_domain" # Restore variable.
source $(command -v rcm-ispconfig-setup-dump-variables.sh)
INDENT=${INDENT::-4}
_ _______________________________________________________________________;_.;_.;

chapter Finish
e If you want to see the credentials again, please execute this command:
code sudo -E $(command -v rcm-ispconfig-setup-dump-variables.sh)
____

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
# --non-interactive
# )
# VALUE=(
# --timezone
# --hostname
# --domain
# --ip-address
# --digitalocean-token
# )
# MULTIVALUE=(
# )
# FLAG_VALUE=(
# )
# CSV=(
# )
# EOF
# clear

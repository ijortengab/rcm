#!/bin/bash

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
    title RCM ISPConfig Setup
    _ 'Variation '; yellow 2; _, . Ubuntu 22.04, ISPConfig 3.2.7, PHPMyAdmin 5.2.0, Roundcube 1.6.0, PHP 7.4, DigitalOcean DNS; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-ispconfig-setup-variation2.sh [options]

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
   rcm-nginx-autoinstaller.sh
   rcm-php-autoinstaller.sh
   rcm-php-setup-adjust-cli-version.sh
   rcm-postfix-autoinstaller.sh
   rcm-certbot-autoinstaller.sh
   rcm-certbot-digitalocean-autoinstaller.sh
   rcm-digitalocean-api-manage-domain.sh
   rcm-digitalocean-api-manage-domain-record.sh
   rcm-ispconfig-autoinstaller-nginx-php-fpm.sh
   rcm-ispconfig-setup-internal-command.sh
   rcm-roundcube-setup-ispconfig-integration.sh
   rcm-ispconfig-setup-wrapper-nginx-setup-php-fpm.sh
   rcm-ispconfig-setup-wrapper-certbot-setup-nginx.sh
   rcm-ispconfig-control-manage-domain.sh
   rcm-ispconfig-control-manage-email-mailbox.sh
   rcm-ispconfig-control-manage-email-alias.sh
   rcm-ispconfig-setup-wrapper-digitalocean.sh
   rcm-ispconfig-setup-dump-variables.sh
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
userInputBooleanDefaultNo() {
    __;  _, '['; yellow Enter; _, ']'; _, ' '; yellow N; _, 'o and skip.'; _.
    __;  _, '['; yellow Y; _, ']'; _, ' '; yellow Y; _, 'es and continue.'; _.
    boolean=
    while true; do
        __; read -rsn 1 -p "Select: " char
        if [ -z "$char" ];then
            char=n
        fi
        case $char in
            y|Y) echo "$char"; boolean=1; break;;
            n|N) echo "$char"; break ;;
            *) echo
        esac
    done
}
sleepExtended() {
    local countdown=$1
    countdown=$((countdown - 1))
    while [ "$countdown" -ge 0 ]; do
        printf "\r\033[K" >&2
        printf %"$countdown"s | tr " " "." >&2
        printf "\r"
        countdown=$((countdown - 1))
        sleep .9
    done
}

# Title.
title rcm-ispconfig-setup-variation2.sh
____

# Require, validate, and populate value.
chapter Dump variable.
[ -n "$fast" ] && isfast=' --fast' || isfast=''
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
if [ -z "$digitalocean_token" ];then
    error "Argument --digitalocean-token required."; x
fi
code 'digitalocean_token="'$digitalocean_token'"'
if [ -z "$domain" ];then
    error "Argument --domain required."; x
fi
code 'domain="'$domain'"'
if [ -z "$hostname" ];then
    error "Argument --hostname required."; x
fi
code 'hostname="'$hostname'"'
fqdn="${hostname}.${domain}"
code fqdn="$fqdn"
code non_interactive="$non_interactive"
php_version=7.4
code php_version="$php_version"
phpmyadmin_version=5.2.0
code phpmyadmin_version="$phpmyadmin_version"
roundcube_version=1.6.0
code roundcube_version="$roundcube_version"
ispconfig_version=3.2.7
code ispconfig_version="$ispconfig_version"
until [[ -n "$ip_address" ]];do
    e Tips: Try --ip-address=auto
    _; read -p "Argument --ip-address required: " ip_address
done
if [[ $ip_address == auto ]];then
    ip_address=
    _ip_address=$(wget -T 3 -t 1 -4qO- "http://ip1.dynupdate.no-ip.com/")
    if [ -n "$_ip_address" ];then
        if [ -n "$non_interactive" ];then
            boolean=1
        else
            __; _, Do you wish to use this IP Address: "$_ip_address"?; _.
            userInputBooleanDefaultNo
        fi
        if [ -n "$boolean" ]; then
            ip_address="$_ip_address"
        fi
    fi
fi
if [ -z "$ip_address" ];then
    error "Argument --ip-address required."; x
fi
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
        __ Privileges.
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
____
_ -----------------------------------------------------------------------;_.;_.;

INDENT+="    " \
rcm-ubuntu-22.04-setup-basic.sh $isfast --root-sure \
    --timezone="$timezone" \
    ; [ ! $? -eq 0 ] && x
_ -----------------------------------------------------------------------;_.;_.;

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
    code hostnamectl set-hostname "${hostname}"
    hostnamectl set-hostname "${hostname}"
    echo "127.0.1.1"$'\t'"${fqdn}"$'\t'"${hostname}" >> /etc/hosts
    sleep .5
    current_fqdn=$(hostname -f 2>/dev/null)
    if [[ "$current_fqdn" == "$fqdn" ]];then
        __; green Variable '$fqdn' sama dengan value system FQDN saat ini '$(hostname -f)'.; _.
    else
        __; red Variable '$fqdn' tidak sama dengan value system hostname saat ini '$(hostname -f)'.; x
    fi
    ____
fi

chapter Mengecek Name Server domain '`'$domain'`'
code dig NS $domain +trace
stdout=$(dig NS $domain +trace)
found=
if grep -q --ignore-case 'ns.\.digitalocean\.com\.' <<< "$stdout";then
    found=1
fi
if [ -n "$found" ];then
    code dig NS $domain +short
    stdout=$(dig NS $domain +short)
    if [ -n "$stdout" ];then
        e "$stdout"
    fi
    if grep -q --ignore-case 'ns.\.digitalocean\.com\.' <<< "$stdout";then
        __ Name Server pada domain "$domain" sudah mengarah ke DigitalOcean.
    else
        __ Name Server pada domain "$domain" belum mengarah ke DigitalOcean.
    fi
else
    error Name Server pada domain "$domain" tidak mengarah ke DigitalOcean.
    e Memerlukan manual edit pada registrar domain.; x
fi
# Contoh:
# nsid2.rumahweb.net.
# nsid4.rumahweb.org.
# nsid3.rumahweb.biz.
# nsid1.rumahweb.com.
# ns3.digitalocean.com.
# ns1.digitalocean.com.
# ns2.digitalocean.com.
____
_ -----------------------------------------------------------------------;_.;_.;

INDENT+="    " \
rcm-mariadb-autoinstaller.sh $isfast --root-sure \
    && INDENT+="    " \
rcm-nginx-autoinstaller.sh $isfast --root-sure \
    && INDENT+="    " \
rcm-php-autoinstaller.sh $isfast --root-sure \
    --php-version="$php_version" \
    && INDENT+="    " \
rcm-php-setup-adjust-cli-version.sh $isfast --root-sure \
    --php-version="$php_version" \
    && INDENT+="    " \
rcm-postfix-autoinstaller.sh $isfast --root-sure \
    --hostname="$hostname" \
    --domain="$domain" \
    && INDENT+="    " \
rcm-certbot-autoinstaller.sh $isfast --root-sure \
    && INDENT+="    " \
rcm-certbot-digitalocean-autoinstaller.sh $isfast --root-sure \
    ; [ ! $? -eq 0 ] && x
_ -----------------------------------------------------------------------;_.;_.;

chapter Take a break.
e Lets play with DigitalOcean API.
sleepExtended 3
____
_ -----------------------------------------------------------------------;_.;_.;

INDENT+="    " \
rcm-digitalocean-api-manage-domain.sh $isfast --root-sure \
    add \
    --domain="$domain" \
    --ip-address="$ip_address" \
    && INDENT+="    " \
rcm-digitalocean-api-manage-domain-record.sh $isfast --root-sure --digitalocean-domain-exists-sure \
    add \
    --domain="$domain" \
    --type=a \
    --ip-address="$ip_address" \
    --hostname=@ \
    && INDENT+="    " \
rcm-digitalocean-api-manage-domain-record.sh $isfast --root-sure --digitalocean-domain-exists-sure \
    delete \
    --domain="$domain" \
    --type=cname \
    --hostname="$hostname" \
    && INDENT+="    " \
rcm-digitalocean-api-manage-domain-record.sh $isfast --root-sure --digitalocean-domain-exists-sure \
    add \
    --domain="$domain" \
    --type=a \
    --ip-address="$ip_address" \
    --hostname="$hostname" \
    && INDENT+="    " \
rcm-digitalocean-api-manage-domain-record.sh $isfast --root-sure --digitalocean-domain-exists-sure \
    delete \
    --domain="$domain" \
    --type=a \
    --ip-address="$ip_address" \
    --hostname="$SUBDOMAIN_ISPCONFIG" \
    && INDENT+="    " \
rcm-digitalocean-api-manage-domain-record.sh $isfast --root-sure --digitalocean-domain-exists-sure \
    add \
    --domain="$domain" \
    --type=cname \
    --hostname="$SUBDOMAIN_ISPCONFIG" \
    && INDENT+="    " \
rcm-digitalocean-api-manage-domain-record.sh $isfast --root-sure --digitalocean-domain-exists-sure \
    delete \
    --domain="$domain" \
    --type=a \
    --ip-address="$ip_address" \
    --hostname="$SUBDOMAIN_PHPMYADMIN" \
    && INDENT+="    " \
rcm-digitalocean-api-manage-domain-record.sh $isfast --root-sure --digitalocean-domain-exists-sure \
    add \
    --domain="$domain" \
    --type=cname \
    --hostname="$SUBDOMAIN_PHPMYADMIN" \
    && INDENT+="    " \
rcm-digitalocean-api-manage-domain-record.sh $isfast --root-sure --digitalocean-domain-exists-sure \
    delete \
    --domain="$domain" \
    --type=a \
    --ip-address="$ip_address" \
    --hostname="$SUBDOMAIN_ROUNDCUBE" \
    && INDENT+="    " \
rcm-digitalocean-api-manage-domain-record.sh $isfast --root-sure --digitalocean-domain-exists-sure \
    add \
    --domain="$domain" \
    --type=cname \
    --hostname="$SUBDOMAIN_ROUNDCUBE" \
    && INDENT+="    " \
rcm-digitalocean-api-manage-domain-record.sh $isfast --root-sure --digitalocean-domain-exists-sure \
    add \
    --domain="$domain" \
    --type=mx \
    --hostname=@ \
    --mail-provider="$fqdn" \
    ; [ ! $? -eq 0 ] && x
_ -----------------------------------------------------------------------;_.;_.;

chapter Take a break.
e Begin to Install ISPConfig and Friends.
sleepExtended 3
____
_ -----------------------------------------------------------------------;_.;_.;

INDENT+="    " \
rcm-ispconfig-autoinstaller-nginx-php-fpm.sh $isfast --root-sure \
    --digitalocean \
    --hostname="$hostname" \
    --domain="$domain" \
    --ispconfig-version="$ispconfig_version" \
    --roundcube-version="$roundcube_version" \
    --phpmyadmin-version="$phpmyadmin_version" \
    --php-version="$php_version" \
    && INDENT+="    " \
rcm-ispconfig-setup-internal-command.sh $isfast --root-sure \
    --phpmyadmin-version="$phpmyadmin_version" \
    --roundcube-version="$roundcube_version" \
    --ispconfig-version="$ispconfig_version" \
    && INDENT+="    " \
rcm-roundcube-setup-ispconfig-integration.sh $isfast --root-sure \
    ; [ ! $? -eq 0 ] && x
_ -----------------------------------------------------------------------;_.;_.;

chapter Take a break.
e Lets play with Certbot LetsEncrypt with Nginx Plugin.
sleepExtended 3
____
_ -----------------------------------------------------------------------;_.;_.;

INDENT+="    " \
rcm-ispconfig-setup-wrapper-nginx-setup-php-fpm.sh $isfast --root-sure \
    --project=ispconfig \
    --subdomain="$SUBDOMAIN_ISPCONFIG" \
    --domain="$domain" \
    --php-version="$php_version" \
    && INDENT+="    " \
rcm-ispconfig-setup-wrapper-nginx-setup-php-fpm.sh $isfast --root-sure \
    --project=roundcube \
    --subdomain="$SUBDOMAIN_ROUNDCUBE" \
    --domain="$domain" \
    --php-version="$php_version" \
    && INDENT+="    " \
rcm-ispconfig-setup-wrapper-nginx-setup-php-fpm.sh $isfast --root-sure \
    --project=phpmyadmin \
    --subdomain="$SUBDOMAIN_PHPMYADMIN" \
    --domain="$domain" \
    --php-version="$php_version" \
    && INDENT+="    " \
rcm-ispconfig-setup-wrapper-nginx-setup-php-fpm.sh $isfast --root-sure \
    --project=ispconfig \
    --subdomain="${SUBDOMAIN_ISPCONFIG}.${domain}" \
    --domain="localhost" \
    --php-version="$php_version" \
    && INDENT+="    " \
rcm-ispconfig-setup-wrapper-nginx-setup-php-fpm.sh $isfast --root-sure \
    --project=roundcube \
    --subdomain="${SUBDOMAIN_ROUNDCUBE}.${domain}" \
    --domain="localhost" \
    --php-version="$php_version" \
    && INDENT+="    " \
rcm-ispconfig-setup-wrapper-nginx-setup-php-fpm.sh $isfast --root-sure \
    --project=phpmyadmin \
    --subdomain="${SUBDOMAIN_PHPMYADMIN}.${domain}" \
    --domain="localhost" \
    --php-version="$php_version" \
    && INDENT+="    " \
rcm-ispconfig-setup-wrapper-certbot-setup-nginx.sh $isfast --root-sure \
    --digitalocean \
    --domain="$domain" \
    --subdomain="$SUBDOMAIN_ISPCONFIG" \
    && INDENT+="    " \
rcm-ispconfig-setup-wrapper-certbot-setup-nginx.sh $isfast --root-sure \
    --digitalocean \
    --domain="$domain" \
    --subdomain="$SUBDOMAIN_PHPMYADMIN" \
    && INDENT+="    " \
rcm-ispconfig-setup-wrapper-certbot-setup-nginx.sh $isfast --root-sure \
    --digitalocean \
    --domain="$domain" \
    --subdomain="$SUBDOMAIN_ROUNDCUBE" \
    ; [ ! $? -eq 0 ] && x

_ -----------------------------------------------------------------------;_.;_.;

chapter Take a break.
e Lets play with Mailbox.
sleepExtended 3
____
_ -----------------------------------------------------------------------;_.;_.;

INDENT+="    " \
rcm-ispconfig-control-manage-domain.sh $isfast --root-sure \
    add \
    --domain="$domain" \
    && INDENT+="    " \
rcm-ispconfig-control-manage-email-mailbox.sh $isfast --root-sure --ispconfig-domain-exists-sure \
    --name="$MAILBOX_ADMIN" \
    --domain="$domain" \
    && INDENT+="    " \
rcm-ispconfig-control-manage-email-mailbox.sh $isfast --root-sure --ispconfig-domain-exists-sure \
    --name="$MAILBOX_SUPPORT" \
    --domain="$domain" \
    && INDENT+="    " \
rcm-ispconfig-control-manage-email-alias.sh $isfast --root-sure --ispconfig-domain-exists-sure \
    --name="$MAILBOX_HOST" \
    --domain="$domain" \
    --destination-name="$MAILBOX_ADMIN" \
    --destination-domain="$domain" \
    && INDENT+="    " \
rcm-ispconfig-control-manage-email-alias.sh $isfast --root-sure --ispconfig-domain-exists-sure \
    --name="$MAILBOX_POST" \
    --domain="$domain" \
    --destination-name="$MAILBOX_ADMIN" \
    --destination-domain="$domain" \
    && INDENT+="    " \
rcm-ispconfig-control-manage-email-alias.sh $isfast --root-sure --ispconfig-domain-exists-sure \
    --name="$MAILBOX_WEB" \
    --domain="$domain" \
    --destination-name="$MAILBOX_ADMIN" \
    --destination-domain="$domain" \
    && INDENT+="    " \
rcm-ispconfig-setup-wrapper-digitalocean.sh $isfast --root-sure --digitalocean-domain-exists-sure \
    --ip-address="$ip_address" \
    --domain="$domain" \
    --type=spf \
    --hostname=@ \
    --mail-provider="$fqdn" \
    && INDENT+="    " \
rcm-ispconfig-setup-wrapper-digitalocean.sh $isfast --root-sure --digitalocean-domain-exists-sure --ispconfig-domain-exists-sure \
    --ip-address="$ip_address" \
    --domain="$domain" \
    --type=dmarc \
    --email="${MAILBOX_POST}@${domain}" \
    && INDENT+="    " \
rcm-ispconfig-setup-wrapper-digitalocean.sh $isfast --root-sure --digitalocean-domain-exists-sure --ispconfig-domain-exists-sure \
    --ip-address="$ip_address" \
    --domain="$domain" \
    --type=dkim  \
    --dns-record-auto \
    ; [ ! $? -eq 0 ] && x

INDENT+="    " \
rcm-ispconfig-setup-dump-variables.sh $isfast --root-sure \
    --domain="$domain" \
    --hostname="$hostname" \
    --ip-address="$ip_address" \
    ; [ ! $? -eq 0 ] && x
_ -----------------------------------------------------------------------;_.;_.;

chapter Send Welcome email.
code postqueue -f
sleepExtended 3
postqueue -f
____

chapter Finish
e If you want to see the credentials again, please execute this command:
code rcm-ispconfig-setup-dump-variables.sh --domain=$domain
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

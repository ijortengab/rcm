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
        --ispconfig-domain-exists-sure) ispconfig_domain_exists_sure=1; shift ;;
        --name=*) name="${1#*=}"; shift ;;
        --name) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then name="$2"; shift; fi; shift ;;
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
e() { echo -n "$INDENT" >&2; echo "#" "$@" >&2; }
_() { echo -n "$INDENT" >&2; echo -n "#" "$@" >&2; }
_,() { echo -n "$@" >&2; }
_.() { echo >&2; }
__() { echo -n "$INDENT" >&2; echo -n "#" '    ' >&2; [ -n "$1" ] && echo "$@" >&2 || echo -n  >&2; }
____() { echo >&2; [ -n "$delay" ] && sleep "$delay"; }

# Functions.
printVersion() {
    echo '0.11.1'
}
printHelp() {
    title RCM ISPConfig Control
    _ 'Variation '; yellow Manage Email Mailbox; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-ispconfig-control-manage-email-mailbox [options]

Options:
   --name
        The name of mailbox.
   --domain
        The domain of mailbox.
   --ispconfig-domain-exists-sure ^
        Bypass domain exists checking.

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
   ISPCONFIG_DB_USER_HOST
        Default to localhost
   ROUNDCUBE_DB_NAME
        Default to roundcubemail
   ROUNDCUBE_DB_USER_HOST
        Default to localhost

Dependency:
   ispconfig.sh
   php
   mysql
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
getMailUserIdIspconfigByEmail() {
    # Get the mailuser_id from table mail_user in ispconfig database.
    #
    # Globals:
    #   ispconfig_db_user, ispconfig_db_user_password,
    #   ispconfig_db_user_host, ispconfig_db_name
    #
    # Arguments:
    #   $1: user mail
    #   $2: host mail
    #
    # Output:
    #   Write mailuser_id to stdout.
    local email="$1"@"$2"
    local sql="SELECT mailuser_id FROM mail_user WHERE email = '$email';"
    local u="$ispconfig_db_user"
    local p="$ispconfig_db_user_password"
    local mailuser_id=$(mysql \
        --defaults-extra-file=<(printf "[client]\nuser = %s\npassword = %s" "$u" "$p") \
        -h "$ispconfig_db_user_host" "$ispconfig_db_name" -r -N -s -e "$sql"
    )
    echo "$mailuser_id"
}
isEmailIspconfigExist() {
    # Check if the mailuser_id from table mail_user exists in ispconfig database.
    #
    # Globals:
    #   Used: roundcube_db_user, roundcube_db_user_password,
    #         roundcube_db_user_host, roundcube_db_name
    #   Modified: mailuser_id
    #
    # Arguments:
    #   $1: user mail
    #   $2: host mail
    #
    # Return:
    #   0 if exists.
    #   1 if not exists.
    mailuser_id=$(getMailUserIdIspconfigByEmail "$1" "$2")
    if [ -n "$mailuser_id" ];then
        return 0
    fi
    return 1
}
mailboxCredential() {
    local host="$1"
    local user="$2"
    if [ -f /usr/local/share/credential/mailbox/$host/$user ];then
        local MAILBOX_USER_PASSWORD
        . /usr/local/share/credential/mailbox/$host/$user
        mailbox_user_password=$MAILBOX_USER_PASSWORD
    else
        mailbox_user_password=$(pwgen 9 -1vA0B)
        mkdir -p /usr/local/share/credential/mailbox/$host/
        cat << EOF > /usr/local/share/credential/mailbox/$host/$user
MAILBOX_USER_PASSWORD=$mailbox_user_password
EOF
        chmod 0500 /usr/local/share/credential
        chmod 0500 /usr/local/share/credential/mailbox
        chmod 0500 /usr/local/share/credential/mailbox/$host
        chmod 0400 /usr/local/share/credential/mailbox/$host/$user
    fi
}
insertEmailIspconfig() {
    # Insert to table mail_user a new record via SOAP.
    #
    # Globals:
    #   Used: roundcube_db_user, roundcube_db_user_password,
    #         roundcube_db_user_host, roundcube_db_name
    #   Modified: mailuser_id
    #
    # Arguments:
    #   $1: user mail
    #   $2: host mail
    #
    # Return:
    #   0 if exists.
    #   1 if not exists.
    local user="$1"
    local host="$2"
    __ Mengecek credentials Mailbox.
    mailboxCredential $host $user
    if [[ -z "$mailbox_user_password" ]];then
        __; red Informasi credentials tidak lengkap: '`'/usr/local/share/credential/mailbox/$host/$user'`'.; x
    else
        __; magenta mailbox_user_password="$mailbox_user_password"; _.
    fi
    __ Create PHP Script from template '`'mail_user_add'`'.
    template=mail_user_add
    template_temp=$(ispconfig.sh mktemp "${template}.php")
    template_temp_path=$(ispconfig.sh realpath "$template_temp")
    __; magenta template_temp_path="$template_temp_path"; _.
    parameter=''
    parameter+="\t\t'server_id' => '1',\n"
    parameter+="\t\t'email' => '$user@$host',\n"
    parameter+="\t\t'login' => '$user@$host',\n"
    parameter+="\t\t'password' => '$mailbox_user_password',\n"
    parameter+="\t\t'name' => '$user',\n"
    parameter+="\t\t'uid' => '5000',\n"
    parameter+="\t\t'gid' => '5000',\n"
    parameter+="\t\t'maildir' => '/var/vmail/$host/$user',\n"
    parameter+="\t\t'maildir_format' => 'maildir',\n"
    parameter+="\t\t'quota' => '0',\n"
    parameter+="\t\t'cc' => '',\n"
    parameter+="\t\t'forward_in_lda' => 'y',\n"
    parameter+="\t\t'sender_cc' => '',\n"
    parameter+="\t\t'homedir' => '/var/vmail',\n"
    parameter+="\t\t'autoresponder' => 'n',\n"
    parameter+="\t\t'autoresponder_start_date' => NULL,\n"
    parameter+="\t\t'autoresponder_end_date' => NULL,\n"
    parameter+="\t\t'autoresponder_subject' => '',\n"
    parameter+="\t\t'autoresponder_text' => '',\n"
    parameter+="\t\t'move_junk' => 'Y',\n"
    parameter+="\t\t'purge_trash_days' => 0,\n"
    parameter+="\t\t'purge_junk_days' => 0,\n"
    parameter+="\t\t'custom_mailfilter' => NULL,\n"
    parameter+="\t\t'postfix' => 'y',\n"
    parameter+="\t\t'greylisting' => 'n',\n"
    parameter+="\t\t'access' => 'y',\n"
    parameter+="\t\t'disableimap' => 'n',\n"
    parameter+="\t\t'disablepop3' => 'n',\n"
    parameter+="\t\t'disabledeliver' => 'n',\n"
    parameter+="\t\t'disablesmtp' => 'n',\n"
    parameter+="\t\t'disablesieve' => 'n',\n"
    parameter+="\t\t'disablesieve-filter' => 'n',\n"
    parameter+="\t\t'disablelda' => 'n',\n"
    parameter+="\t\t'disablelmtp' => 'n',\n"
    parameter+="\t\t'disabledoveadm' => 'n',\n"
    parameter+="\t\t'disablequota-status' => 'n',\n"
    parameter+="\t\t'disableindexer-worker' => 'n',\n"
    parameter+="\t\t'last_quota_notification' => NULL,\n"
    parameter+="\t\t'backup_interval' => 'none',\n"
    parameter+="\t\t'backup_copies' => '1',\n"
    sed -i -E \
        -e ':a;N;$!ba;s|\$params\s+=\s+[^;]+;|\$params = array(\n'"${parameter}"'\n\t);|g' \
        "$template_temp_path"
    sed -i -E -e '/echo/d' -e '/^\s*$/d' -e 's,\t,    ,g' \
        "$template_temp_path"
    contents=$(<"$template_temp_path")
    __ Execute PHP Script.
    magenta "$contents"; _.
    ispconfig.sh php "$template_temp"
    __ Cleaning Temporary File.
    __; magenta rm "$template_temp_path"; _.
    rm "$template_temp_path"
    mailuser_id=$(getMailUserIdIspconfigByEmail "$1" "$2")
    if [ -n "$mailuser_id" ];then
        return 0
    fi
    return 1
}

# Title.
title rcm-ispconfig-control-manage-email-mailbox
____

# Require, validate, and populate value.
chapter Dump variable.
[ -n "$fast" ] && isfast=' --fast' || isfast=''
ISPCONFIG_DB_USER_HOST=${ISPCONFIG_DB_USER_HOST:=localhost}
if [ -z "$domain" ];then
    error "Argument --domain required."; x
fi
code 'domain="'$domain'"'
if [ -z "$name" ];then
    error "Argument --name required."; x
fi
code 'name="'$name'"'
code 'ispconfig_domain_exists_sure="'$ispconfig_domain_exists_sure'"'
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

if [ -z "$ispconfig_domain_exists_sure" ];then
    _ ___________________________________________________________________;_.;_.;

    INDENT+="    " \
    rcm-ispconfig-control-manage-domain $isfast --root-sure \
        isset \
        --domain="$domain" \
        ; [ $? -eq 0 ] && ispconfig_domain_exists_sure=1
    _ ___________________________________________________________________;_.;_.;

    if [ -n "$ispconfig_domain_exists_sure" ];then
        __; green Domain is exists.; _.
    else
        __; red Domain is not exists.; x
    fi
fi

chapter Mengecek credentials ISPConfig.
ispconfig_db_user_host="$ISPCONFIG_DB_USER_HOST"
code ispconfig_db_user_host="$ispconfig_db_user_host"
databaseCredentialIspconfig
if [[ -z "$ispconfig_db_name" || -z "$ispconfig_db_user" || -z "$ispconfig_db_user_password" ]];then
    __; red Informasi credentials tidak lengkap: '`'/usr/local/share/ispconfig/credential/database'`'.; x
else
    code ispconfig_db_name="$ispconfig_db_name"
    code ispconfig_db_user="$ispconfig_db_user"
    code ispconfig_db_user_password="$ispconfig_db_user_password"
fi
____

user="$name"
host="$domain"
chapter Mengecek mailbox "$user"@"$host"
if isEmailIspconfigExist "$user" "$host";then
    __ Email "$user"@"$host" already exists.
    __; magenta mailuser_id=$mailuser_id; _.
elif insertEmailIspconfig "$user" "$host";then
    __; green "$user"@"$host" created.; _.
    __; magenta mailuser_id=$mailuser_id; _.
else
    __; red Email "$user"@"$host" failed to create.; x
fi

____

chapter Mengecek credentials '`'/usr/local/share/credential/mailbox/$host/$user'`'.
mailboxCredential $host $user
if [[ -z "$mailbox_user_password" ]];then
    __; red Informasi credentials tidak lengkap: '`'/usr/local/share/credential/mailbox/$host/$user'`'.; x
else
    __; magenta host=$host; _.
    __; magenta user=$user; _.
    __; magenta mailbox_user_password="$mailbox_user_password"; _.
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
# --ispconfig-domain-exists-sure
# )
# VALUE=(
# --name
# --domain
# )
# FLAG_VALUE=(
# )
# EOF
# clear

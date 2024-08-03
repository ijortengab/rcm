#!/bin/bash

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --destination-domain=*) destination_domain="${1#*=}"; shift ;;
        --destination-domain) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then destination_domain="$2"; shift; fi; shift ;;
        --destination-name=*) destination_name="${1#*=}"; shift ;;
        --destination-name) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then destination_name="$2"; shift; fi; shift ;;
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
    echo '0.5.0'
}
printHelp() {
    title RCM ISPConfig Control
    _ 'Variation '; yellow Manage Email Alias; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-ispconfig-control-manage-email-alias.sh [options]

Options:
   --name
        The name of email alias.
   --domain
        The domain of email alias.
   --destination-name
        The destination name of email alias.
   --destination-domain
        The destination domain of email alias.
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
    [[ -z "$line" ]] || command -v "${line}" >/dev/null || { echo -e "\e[91m""Unable to proceed, ${line} command not found." "\e[39m"; exit 1; }
done <<< `printHelp 2>/dev/null | sed -n '/^Dependency:/,$p' | sed -n '2,/^$/p' | sed 's/^ *//g'`

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
    code "$contents"
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
getUserIdRoundcubeByUsername() {
    # Get the user_id from table users in roundcube database.
    #
    # Globals:
    #   roundcube_db_user, roundcube_db_user_password,
    #   roundcube_db_user_host, roundcube_db_name
    #
    # Arguments:
    #   $1: Filter by username.
    #
    # Output:
    #   Write user_id to stdout.
    local username="$1"
    local sql="SELECT user_id FROM users WHERE username = '$username';"
    local u="$roundcube_db_user"
    local p="$roundcube_db_user_password"
    local user_id=$(mysql \
        --defaults-extra-file=<(printf "[client]\nuser = %s\npassword = %s" "$u" "$p") \
        -h "$roundcube_db_user_host" "$roundcube_db_name" -r -N -s -e "$sql"
    )
    echo "$user_id"
}
isUsernameRoundcubeExist() {
    # Check if the username from table users exists in roundcube database.
    #
    # Globals:
    #   Used: roundcube_db_user, roundcube_db_user_password,
    #         roundcube_db_user_host, roundcube_db_name
    #   Modified: user_id
    #
    # Arguments:
    #   $1: username to be checked.
    #
    # Return:
    #   0 if exists.
    #   1 if not exists.
    local username="$1"
    user_id=$(getUserIdRoundcubeByUsername "$username")
    if [ -n "$user_id" ];then
        return 0
    fi
    return 1
}
insertUsernameRoundcube() {
    # Insert the username to table users in roundcube database.
    #
    # Globals:
    #   Used: roundcube_db_user, roundcube_db_user_password,
    #         roundcube_db_user_host, roundcube_db_name
    #   Modified: user_id
    #
    # Arguments:
    #   $1: username to be checked.
    #   $2: mail host (if omit, default to localhost)
    #   $3: language (if omit, default to en_US)
    #
    # Return:
    #   0 if exists.
    #   1 if not exists.
    local username="$1"
    local mail_host="$2"; [ -n "$mail_host" ] || mail_host=localhost
    local language="$3"; [ -n "$language" ] || language=en_US
    local now=$(date +%Y-%m-%d\ %H:%M:%S)
    local sql="INSERT INTO users
        (created, last_login, username, mail_host, language)
        VALUES
        ('$now', '$now', '$username', '$mail_host', '$language');"
    local u="$roundcube_db_user"
    local p="$roundcube_db_user_password"
    mysql --defaults-extra-file=<(printf "[client]\nuser = %s\npassword = %s" "$u" "$p") \
        -h "$roundcube_db_user_host" "$roundcube_db_name" -e "$sql"
    user_id=$(getUserIdRoundcubeByUsername "$username")
    if [ -n "$user_id" ];then
        return 0
    fi
    return 1
}
getIdentityIdRoundcubeByEmail() {
    # Get the user_id from table users in roundcube database.
    #
    # Globals:
    #   roundcube_db_user, roundcube_db_user_password,
    #   roundcube_db_user_host, roundcube_db_name
    #
    # Arguments:
    #   $1: Filter by standard.
    #   $2: Filter by email.
    #   $3: Filter by user_id.
    #
    # Output:
    #   Write identity_id to stdout.
    local standard="$1"
    local email="$2"
    local user_id="$3"
    local sql="SELECT identity_id FROM identities WHERE standard = '$standard' and email = '$email' and user_id = '$user_id';"
    local u="$roundcube_db_user"
    local p="$roundcube_db_user_password"
    local identity_id=$(mysql \
        --defaults-extra-file=<(printf "[client]\nuser = %s\npassword = %s" "$u" "$p") \
        -h "$roundcube_db_user_host" "$roundcube_db_name" -r -N -s -e "$sql"
    )
    echo "$identity_id"
}
isIdentitiesRoundcubeExist() {
    # Check if the username from table users exists in roundcube database.
    #
    # Globals:
    #   Used: roundcube_db_user, roundcube_db_user_password,
    #         roundcube_db_user_host, roundcube_db_name
    #   Modified: identity_id
    #
    # Arguments:
    #   $1: username to be checked.
    #
    # Return:
    #   0 if exists.
    #   1 if not exists.
    local standard="$1"
    local email="$2"
    local user_id="$3"
    identity_id=$(getIdentityIdRoundcubeByEmail "$standard" "$email" "$user_id")
    if [ -n "$identity_id" ];then
        return 0
    fi
    return 1
}
insertIdentitiesRoundcube() {
    # Insert the username to table users in roundcube database.
    #
    # Globals:
    #   Used: roundcube_db_user, roundcube_db_user_password,
    #         roundcube_db_user_host, roundcube_db_name
    #   Modified: identity_id
    #
    # Arguments:
    #   $1: standard
    #   $2: email
    #   $3: user_id
    #   $4: name
    #   $5: organization
    #   $6: reply_to
    #   $7: bcc
    #   $8: html_signature (if omit, default to 0)
    #
    # Return:
    #   0 if exists.
    #   1 if not exists.
    local standard="$1"
    local email="$2"
    local user_id="$3"
    local name="$4"
    local organization="$5"
    local reply_to="$6"
    local bcc="$7"
    local html_signature="$8"; [ -n "$html_signature" ] || html_signature=0
    local now=$(date +%Y-%m-%d\ %H:%M:%S)
    local sql="INSERT INTO identities
        (user_id, changed, del, standard, name, organization, email, \`reply-to\`, bcc, html_signature)
        VALUES
        ('$user_id', '$now', 0, $standard, '$name', '$organization', '$email', '$reply_to', '$reply_to', $html_signature);"
    local u="$roundcube_db_user"
    local p="$roundcube_db_user_password"
    mysql --defaults-extra-file=<(printf "[client]\nuser = %s\npassword = %s" "$u" "$p") \
        -h "$roundcube_db_user_host" "$roundcube_db_name" -e "$sql"
    identity_id=$(getIdentityIdRoundcubeByEmail "$standard" "$email" "$user_id")
    if [ -n "$identity_id" ];then
        return 0
    fi
    return 1
}
getForwardingIdIspconfigByEmailAlias() {
    # Get the forwarding_id from table mail_forwarding in ispconfig database.
    #
    # Globals:
    #   ispconfig_db_user, ispconfig_db_user_password,
    #   ispconfig_db_user_host, ispconfig_db_name
    #
    # Arguments:
    #   $1: Filter by email source.
    #   $2: Filter by email destination.
    #
    # Output:
    #   Write forwarding_id to stdout.
    local source="$1"
    local destination="$2"
    local sql="SELECT forwarding_id FROM mail_forwarding WHERE source = '$source' and destination = '$destination' and type = 'alias';"
    local u="$ispconfig_db_user"
    local p="$ispconfig_db_user_password"
    # echo '---'
    # mysql \
        # --defaults-extra-file=<(printf "[client]\nuser = %s\npassword = %s" "$u" "$p") \
        # -h "$ispconfig_db_user_host" "$ispconfig_db_name" -r -N -s -e "$sql"

    # echo '---'
    local forwarding_id=$(mysql \
        --defaults-extra-file=<(printf "[client]\nuser = %s\npassword = %s" "$u" "$p") \
        -h "$ispconfig_db_user_host" "$ispconfig_db_name" -r -N -s -e "$sql"
    )
    echo "$forwarding_id"
}
isEmailAliasIspconfigExist() {
    # Check if the email alias (source and destination)
    # from table mail_forwarding exists in ispconfig database.
    #
    # Globals:
    #   Used: ispconfig_db_user, ispconfig_db_user_password,
    #         ispconfig_db_user_host, ispconfig_db_name
    #   Modified: forwarding_id
    #
    # Arguments:
    #   $1: Filter by email source.
    #   $2: Filter by email destination.
    #
    # Return:
    #   0 if exists.
    #   1 if not exists.
    local source="$1"
    local destination="$2"
    forwarding_id=$(getForwardingIdIspconfigByEmailAlias "$source" "$destination")
    if [ -n "$forwarding_id" ];then
        return 0
    fi
    return 1
}
insertEmailAliasIspconfig() {
    # Insert to table mail_forwarding a new record via SOAP.
    #
    # Globals:
    #   Used: roundcube_db_user, roundcube_db_user_password,
    #         roundcube_db_user_host, roundcube_db_name
    #   Modified: forwarding_id
    #
    # Arguments:
    #   $1: email destination
    #   $2: email alias
    #
    # Return:
    #   0 if exists.
    #   1 if not exists.
    local source="$1"
    local destination="$2"
    __ Create PHP Script from template '`'mail_alias_add'`'.
    template=mail_alias_add
    template_temp=$(ispconfig.sh mktemp "${template}.php")
    template_temp_path=$(ispconfig.sh realpath "$template_temp")
    __; magenta template_temp_path="$template_temp_path"; _.
    parameter=''
    parameter+="\t\t'server_id' => '1',\n"
    parameter+="\t\t'source' => '${source}',\n"
    parameter+="\t\t'destination' => '${destination}',\n"
    parameter+="\t\t'type' => 'alias',\n"
    parameter+="\t\t'active' => 'y',\n"
    sed -i -E \
        -e ':a;N;$!ba;s|\$params\s+=\s+[^;]+;|\$params = array(\n'"${parameter}"'\n\t);|g' \
        "$template_temp_path"
    sed -i -E -e '/echo/d' -e '/^\s*$/d' -e 's,\t,    ,g' \
        "$template_temp_path"
    contents=$(<"$template_temp_path")
    __ Execute PHP Script.
    code "$contents"
    ispconfig.sh php "$template_temp"
    __ Cleaning temporary file.
    __; magenta rm "$template_temp_path"; _.
    rm "$template_temp_path"
    forwarding_id=$(getForwardingIdIspconfigByEmailAlias "$source" "$destination")
    if [ -n "$forwarding_id" ];then
        return 0
    fi
    return 1
}

# Title.
title rcm-ispconfig-control-manage-email-alias.sh
____

# Require, validate, and populate value.
chapter Dump variable.
[ -n "$fast" ] && isfast=' --fast' || isfast=''
ISPCONFIG_DB_USER_HOST=${ISPCONFIG_DB_USER_HOST:=localhost}
ROUNDCUBE_DB_NAME=${ROUNDCUBE_DB_NAME:=roundcubemail}
code 'ROUNDCUBE_DB_NAME="'$ROUNDCUBE_DB_NAME'"'
ROUNDCUBE_DB_USER_HOST=${ROUNDCUBE_DB_USER_HOST:=localhost}
if [ -z "$domain" ];then
    error "Argument --domain required."; x
fi
code 'domain="'$domain'"'
if [ -z "$name" ];then
    error "Argument --name required."; x
fi
code 'name="'$name'"'
if [ -z "$destination_name" ];then
    error "Argument --destination-name required."; x
fi
code 'destination_name="'$destination_name'"'
if [ -z "$destination_domain" ];then
    error "Argument --destination-domain required."; x
fi
code 'destination_domain="'$destination_domain'"'
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
    rcm-ispconfig-control-manage-domain.sh $isfast --root-sure \
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

chapter Mengecek database credentials RoundCube.
roundcube_db_name="$ROUNDCUBE_DB_NAME"
code roundcube_db_name="$roundcube_db_name"
roundcube_db_user_host="$ROUNDCUBE_DB_USER_HOST"
code roundcube_db_user_host="$roundcube_db_user_host"
databaseCredentialRoundcube
if [[ -z "$roundcube_db_user" || -z "$roundcube_db_user_password" ]];then
    __; red Informasi credentials tidak lengkap: '`'/usr/local/share/roundcube/credential/database'`'.; x
else
    code roundcube_db_user="$roundcube_db_user"
    code roundcube_db_user_password="$roundcube_db_user_password"
fi
____

user="$destination_name"
host="$destination_domain"
chapter Mengecek mailbox destination "$user"@"$host"
if isEmailIspconfigExist "$user" "$host";then
    __ Email Destination "$user"@"$host" found.
else
    __; red Email Destination "$user"@"$host" not found.; x
fi
____

user="$name"
host="$domain"
chapter Mengecek mailbox "$user"@"$host"
if isEmailIspconfigExist "$user" "$host";then
    __; red Email Mailbox "$user"@"$host" already exists.; x
else
    __ Email Mailbox "$user"@"$host" not found.
fi
____

destination="$destination_name"@"$destination_domain"
source="$name"@"$domain"
chapter Mengecek alias of "$source"
if isEmailAliasIspconfigExist "$source" "$destination";then
    __ Email "$source" alias of "$destination" already exists.
    __; magenta forwarding_id=$forwarding_id; _.
elif insertEmailAliasIspconfig "$source" "$destination";then
    __; green Email "$source" alias of "$destination" created.; _.
    __; magenta forwarding_id=$forwarding_id; _.
else
    __; red Email "$source" alias of "$destination" failed to create.; x
fi
____

username="$destination_name"@"$destination_domain"
chapter Mengecek username destination "$username" di Roundcube.
if isUsernameRoundcubeExist "$username";then
    __ Username "$username" already exists.
    __; magenta user_id=$user_id; _.
elif insertUsernameRoundcube "$username";then
    __; green Username "$username" created.; _.
    __; magenta user_id=$user_id; _.
else
    __; red Username "$username" failed to create.; x
fi
____

username="$destination_name"@"$destination_domain"
chapter Mengecek Identities destination "$username" di Roundcube.
if isIdentitiesRoundcubeExist 1 "$username" "$user_id";then
    __ Identities "$username" already exists.
    __; magenta identity_id=$identity_id; _.
elif insertIdentitiesRoundcube 1 "$username" "$user_id" "$mailbox_admin";then
    __; green Identities "$username" created.; _.
    __; magenta identity_id=$identity_id; _.
else
    __; red Identities "$username" failed to create.; x
fi
____

source="$name"@"$domain"
destination="$destination_name"@"$destination_domain"
chapter Mengecek Identities "$source" di Roundcube.
__; magenta source=$source; _.
if isIdentitiesRoundcubeExist 0 "$source" "$user_id";then
    __ Identities "$source" alias of "$destination" already exists.
    __; magenta identity_id=$identity_id; _.
elif insertIdentitiesRoundcube 0 "$source" "$user_id";then
    __; green Identities "$source" alias of "$destination" created.; _.
    __; magenta identity_id=$identity_id; _.
else
    __; red Identities "$source" alias of "$user_id" failed to create.; x
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
# --destination-name
# --destination-domain
# )
# FLAG_VALUE=(
# )
# EOF
# clear

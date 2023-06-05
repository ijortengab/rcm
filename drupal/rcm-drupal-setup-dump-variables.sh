#!/bin/bash

# Prerequisite.
[ -f "$0" ] || { echo -e "\e[91m" "Cannot run as dot command. Hit Control+c now." "\e[39m"; read; exit 1; }

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --domain=*) domain="${1#*=}"; shift ;;
        --domain) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then domain="$2"; shift; fi; shift ;;
        --fast) fast=1; shift ;;
        --project-name=*) project_name="${1#*=}"; shift ;;
        --project-name) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then project_name="$2"; shift; fi; shift ;;
        --project-parent-name=*) project_parent_name="${1#*=}"; shift ;;
        --project-parent-name) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then project_parent_name="$2"; shift; fi; shift ;;
        --root-sure) root_sure=1; shift ;;
        --[^-]*) shift ;;
        *) _new_arguments+=("$1"); shift ;;
    esac
done
set -- "${_new_arguments[@]}"
unset _new_arguments

# Functions.
[[ $(type -t RcmDrupalSetupDumpVariables_printVersion) == function ]] || RcmDrupalSetupDumpVariables_printVersion() {
    echo '0.1.0'
}
[[ $(type -t RcmDrupalSetupDumpVariables_printHelp) == function ]] || RcmDrupalSetupDumpVariables_printHelp() {
    cat << EOF
RCM Drupal Setup
Variation Dump Variables
Version `RcmDrupalSetupDumpVariables_printVersion`

EOF
    cat << 'EOF'
Usage: rcm-drupal-setup-dump-variables.sh [options]

Options:
   --project-name
        Set the project name. This should be in machine name format.
   --project-parent-name
        Set the project parent name.
   --domain
        Set the domain.

Global Options.
   --fast
        No delay every subtask.
   --version
        Print version of this script.
   --help
        Show this help.
   --root-sure
        Bypass root checking.

Environment Variables:
   HOME_DIRECTORY
        Default to $HOME
EOF
}

# Help and Version.
[ -n "$help" ] && { RcmDrupalSetupDumpVariables_printHelp; exit 1; }
[ -n "$version" ] && { RcmDrupalSetupDumpVariables_printVersion; exit 1; }

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
[[ $(type -t databaseCredentialDrupal) == function ]] || databaseCredentialDrupal() {
    if [ -f /var/www/project/$project_dir/credential/database ];then
        local DRUPAL_DB_USER DRUPAL_DB_USER_PASSWORD
        . /var/www/project/$project_dir/credential/database
        drupal_db_user=$DRUPAL_DB_USER
        drupal_db_user_password=$DRUPAL_DB_USER_PASSWORD
    else
        drupal_db_user="$project_name"
        [ -n "$project_parent_name" ] && {
            drupal_db_user=$project_parent_name
        }
        drupal_db_user_password=$(pwgen -s 32 -1)
        mkdir -p /var/www/project/$project_dir/credential
        cat << EOF > /var/www/project/$project_dir/credential/database
DRUPAL_DB_USER=$drupal_db_user
DRUPAL_DB_USER_PASSWORD=$drupal_db_user_password
EOF
        chmod 0500 /var/www/project/$project_dir/credential
        chmod 0400 /var/www/project/$project_dir/credential/database
    fi
}
[[ $(type -t websiteCredentialDrupal) == function ]] || websiteCredentialDrupal() {
    local file=/var/www/project/$project_dir/credential/drupal/$drupal_fqdn_localhost
    if [ -f "$file" ];then
        local ACCOUNT_NAME ACCOUNT_PASS
        . "$file"
        account_name=$ACCOUNT_NAME
        account_pass=$ACCOUNT_PASS
    else
        account_name=system
        account_pass=$(pwgen -s 32 -1)
        mkdir -p /var/www/project/$project_dir/credential/drupal
        cat << EOF > "$file"
ACCOUNT_NAME=$account_name
ACCOUNT_PASS=$account_pass
EOF
        chmod 0500 /var/www/project/$project_dir/credential
        chmod 0500 /var/www/project/$project_dir/credential/drupal
        chmod 0400 /var/www/project/$project_dir/credential/drupal/$drupal_fqdn_localhost
    fi
}

# Title.
title RCM Drupal Setup
_ 'Variation '; yellow Dump Variables; _.
_ 'Version '; yellow `RcmDrupalSetupDumpVariables_printVersion`; _.
____

# Require, validate, and populate value.
chapter Dump variable.
HOME_DIRECTORY=${HOME_DIRECTORY:=$HOME}
code 'HOME_DIRECTORY="'$HOME_DIRECTORY'"'
until [[ -n "$project_name" ]];do
    read -p "Argument --project-name required: " project_name
done
code 'domain="'$domain'"'
code 'project_name="'$project_name'"'
code 'project_parent_name="'$project_parent_name'"'
project_dir="$project_name"
drupal_fqdn_localhost="$project_name".drupal.localhost
[ -n "$project_parent_name" ] && {
    drupal_fqdn_localhost="$project_name"."$project_parent_name".drupal.localhost
    project_dir="$project_parent_name"
}
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

if [ -n "$domain" ];then
    fqdn_string="$domain"
else
    fqdn_string="$drupal_fqdn_localhost"
fi

chapter Drupal "http://${fqdn_string}"
websiteCredentialDrupal
e ' - 'username: $account_name
e '   'password: $account_pass
____

if [ -n "$domain" ];then
    chapter Alias Hostname
    e ' - 'http://"$drupal_fqdn_localhost"
    e ' - 'http://"${domain}.localhost"
    ____
fi

chapter Database Credential
databaseCredentialDrupal
e ' - 'username: $drupal_db_user
e '   'password: $drupal_db_user_password
____

list_uri=("${drupal_fqdn_localhost}")
if [ -n "$domain" ];then
    list_uri=("${domain}")
fi
for uri in "${list_uri[@]}";do
    each="cd.${uri}"
    if [ -f "$HOME_DIRECTORY/$each" ];then
        chapter Drush command for $uri
        if [[ "$HOME_DIRECTORY" == "$HOME" ]];then
            code cd
        else
            code cd '"'"$HOME_DIRECTORY"'"'
        fi
        code . "${each}"
        code drush status
        ____
    fi
done

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
# --project-name
# --project-parent-name
# --domain
# )
# MULTIVALUE=(
# )
# FLAG_VALUE=(
# )
# EOF
# clear

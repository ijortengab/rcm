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
    title RCM Drupal Setup
    _ 'Variation '; yellow Drush Alias; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-drupal-setup-drush-alias.sh [options]

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
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Functions.

# Title.
title rcm-drupal-setup-drush-alias.sh
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
        __ Privileges.
    fi
    ____
fi

if [ -n "$domain" ];then
    fqdn_string="$domain"
else
    fqdn_string="$drupal_fqdn_localhost"
fi

chapter Script Shortcut

list_uri=("${drupal_fqdn_localhost}")
if [ -n "$domain" ];then
    list_uri=("${domain}")
fi

for uri in "${list_uri[@]}";do
    each="cd.${uri}"
    __; _, Command:' '; magenta ". $each"; _.
    if [[ -f "$HOME_DIRECTORY/$each" && ! -s "$HOME_DIRECTORY/$each" ]];then
        __ Empty file detected.
        __; magenta rm "$HOME_DIRECTORY/$each"; _.
        rm "$HOME_DIRECTORY/$each"
    fi
    if [ ! -f "$HOME_DIRECTORY/$each" ];then
        __ Membuat file '`'$HOME_DIRECTORY/$each'`'.
        cat << 'EOF' > "$HOME_DIRECTORY/$each"
[[ -f "$0" && ! "$0" == $(command -v bash) ]] && { echo -e "\e[91m""Usage: . "$(basename "$0") "\e[39m"; exit 1; }
echo -e "\e[95m""cd /var/www/project/__PROJECT_DIR__/drupal""\e[39m"
cd /var/www/project/__PROJECT_DIR__/drupal
echo -e "\e[95m""alias drush='vendor/bin/drush --uri=__URI__'""\e[39m"
alias drush='vendor/bin/drush --uri=__URI__'
EOF
        sed -i "s|__PROJECT_DIR__|${project_dir}|g" "$HOME_DIRECTORY/$each"
        sed -i "s|__URI__|${uri}|g" "$HOME_DIRECTORY/$each"
    else
        __ File ditemukan '`'$HOME_DIRECTORY/$each'`'.
    fi
done
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

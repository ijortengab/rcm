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
        --php-version=*) php_version="${1#*=}"; shift ;;
        --php-version) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then php_version="$2"; shift; fi; shift ;;
        --project-name=*) project_name="${1#*=}"; shift ;;
        --project-name) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then project_name="$2"; shift; fi; shift ;;
        --project-parent-name=*) project_parent_name="${1#*=}"; shift ;;
        --project-parent-name) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then project_parent_name="$2"; shift; fi; shift ;;
        --root-sure) root_sure=1; shift ;;
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
    title RCM Drupal Setup
    _ 'Variation '; yellow Wrapper Nginx Setup Drupal; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-drupal-setup-wrapper-nginx-setup-drupal.sh [command] [options]

Options:
   --php-version
        Set the version of PHP FPM.
   --subdomain
        Set the subdomain if any.
   --domain
        Set the domain.
   --project-name
        Set the project name. This should be in machine name format.
   --project-parent-name
        Set the project parent name.

Global Options.
   --fast
        No delay every subtask.
   --version
        Print version of this script.
   --help
        Show this help.
   --root-sure
        Bypass root checking.

Dependency:
   rcm-nginx-setup-drupal.sh
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
validateMachineName() {
    local value="$1" _value
    local parameter="$2"
    if [[ $value = *" "* ]];then
        [ -n "$parameter" ]  && error "Variable $parameter can not contain space."
        return 1;
    fi
    _value=$(sed -E 's|[^a-zA-Z0-9]|_|g' <<< "$value" | sed -E 's|_+|_|g' )
    if [[ ! "$value" == "$_value" ]];then
        error "Variable $parameter can only contain alphanumeric and underscores."
        _ 'Suggest: '; yellow "$_value"; _.
        return 1
    fi
}

# Title.
title rcm-drupal-setup-wrapper-nginx-setup-drupal.sh
____

# Require, validate, and populate value.
chapter Dump variable.
[ -n "$fast" ] && isfast=' --fast' || isfast=''
code 'php_version="'$php_version'"'
until [[ -n "$project_name" ]];do
    _; read -p "Argument --project-name required: " project_name
done
code 'project_name="'$project_name'"'
if ! validateMachineName "$project_name" project_name;then x; fi
code 'project_parent_name="'$project_parent_name'"'
if [ -n "$project_parent_name" ];then
    if ! validateMachineName "$project_parent_name" project_parent_name;then x; fi
fi
code 'subdomain="'$subdomain'"'
until [[ -n "$domain" ]];do
    _; read -p "Argument --domain required: " domain
done
code 'domain="'$domain'"'
if [ -n "$subdomain" ];then
    fqdn_project="${subdomain}.${domain}"
else
    fqdn_project="${domain}"
fi
code 'fqdn_project="'$fqdn_project'"'
project_dir="$project_name"
[ -n "$project_parent_name" ] && {
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

chapter Mengecek direktori project '`'/var/www/project/$project_dir/drupal/web'`'.
notfound=
if [ -d /var/www/project/$project_dir/drupal/web ] ;then
    __ Direktori ditemukan.
else
    __; red Direktori tidak ditemukan.; x
fi
____

chapter Prepare arguments.
root="/var/www/project/$project_dir/drupal/web"
code root="$root"
filename="$fqdn_project"
code filename="$filename"
server_name="$fqdn_project"
code server_name="$server_name"
____
_ _______________________________________________________________________;_.;_.;

INDENT+="    " \
rcm-nginx-setup-drupal.sh $isfast --root-sure \
    --root="$root" \
    --php-version="$php_version" \
    --filename="$filename" \
    --server-name="$server_name" \
    ; [ ! $? -eq 0 ] && x
_ _______________________________________________________________________;_.;_.;

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
# --php-version
# --domain
# --subdomain
# --project-name
# --project-parent-name
# )
# MULTIVALUE=(
# )
# FLAG_VALUE=(
# )
# EOF
# clear

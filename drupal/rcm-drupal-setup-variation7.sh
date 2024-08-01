#!/bin/bash

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --auto-add-group) auto_add_group=1; shift ;;
        --domain=*) domain="${1#*=}"; shift ;;
        --domain) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then domain="$2"; shift; fi; shift ;;
        --domain-strict) domain_strict=1; shift ;;
        --fast) fast=1; shift ;;
        --php-fpm-user=*) php_fpm_user="${1#*=}"; shift ;;
        --php-fpm-user) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then php_fpm_user="$2"; shift; fi; shift ;;
        --prefix=*) prefix="${1#*=}"; shift ;;
        --prefix) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then prefix="$2"; shift; fi; shift ;;
        --project-container=*) project_container="${1#*=}"; shift ;;
        --project-container) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then project_container="$2"; shift; fi; shift ;;
        --project-name=*) project_name="${1#*=}"; shift ;;
        --project-name) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then project_name="$2"; shift; fi; shift ;;
        --project-parent-name=*) project_parent_name="${1#*=}"; shift ;;
        --project-parent-name) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then project_parent_name="$2"; shift; fi; shift ;;
        --root-sure) root_sure=1; shift ;;
        --timezone=*) timezone="${1#*=}"; shift ;;
        --timezone) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then timezone="$2"; shift; fi; shift ;;
        --with-update-system) update_system=1; shift ;;
        --without-update-system) update_system=0; shift ;;
        --with-upgrade-system) upgrade_system=1; shift ;;
        --without-upgrade-system) upgrade_system=0; shift ;;
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
    _ 'Variation '; yellow 7; _, . Debian 12, Drupal 10, PHP 8.3. ; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    nginx_user=
    conf_nginx=`command -v nginx > /dev/null && command -v nginx > /dev/null && nginx -V 2>&1 | grep -o -P -- '--conf-path=\K(\S+)'`
    if [ -f "$conf_nginx" ];then
        nginx_user=`grep -o -P '^user \K([^;]+)' "$conf_nginx"`
    fi
    [ -n "$nginx_user" ] && { nginx_user=" ${nginx_user},"; }
    cat << EOF
Usage: rcm-drupal-setup-variation7.sh [options]

Options:
   --project-name *
        Set the project name. This should be in machine name format.
   --project-parent-name
        Set the project parent name. The parent is not have to installed before.
   --domain
        Set the domain.
   --timezone
        Set the timezone of this machine. Available values: Asia/Jakarta, or other.
   --domain-strict ^
        Prevent installing drupal inside directory sites/default.
   --php-fpm-user
        Set the system user of PHP FPM. Available values:${nginx_user}`cut -d: -f1 /etc/passwd | while read line; do [ -d /home/$line ] && echo " ${line}"; done | tr $'\n' ','` or other.
   --prefix
        Set prefix directory for project. Default to home directory of --php-fpm-user or /usr/local/share.
   --project-container
        Set the container directory for all projects. Available value: drupal-project, drupal, or other. Default to drupal-project.
   --auto-add-group ^
        If Nginx User cannot access PHP-FPM's Directory, auto add group of PHP-FPM User to Nginx User.
   --without-update-system ^
        Skip execute update system. Default to --with-update-system.
   --without-upgrade-system ^
        Skip execute upgrade system. Default to --with-upgrade-system.

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
   nginx
   rcm-debian-12-setup-basic.sh
   rcm-nginx-autoinstaller.sh
   rcm-mariadb-autoinstaller.sh
   rcm-php-autoinstaller.sh
   rcm-php-setup-adjust-cli-version.sh
   rcm-php-setup-drupal.sh
   rcm-wsl-setup-lemp-stack.sh
   rcm-composer-autoinstaller.sh
   rcm-drupal-autoinstaller-nginx.sh
   rcm-drupal-setup-wrapper-nginx-setup-drupal.sh
   rcm-drupal-setup-wrapper-nginx-setup-drupal.sh
   rcm-drupal-setup-drush-alias.sh
   rcm-drupal-setup-dump-variables.sh
   rcm-php-fpm-setup-pool.sh
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Dependency.
while IFS= read -r line; do
    [[ -z "$line" ]] || command -v "${line}" >/dev/null || { echo -e "\e[91m""Unable to proceed, ${line} command not found." "\e[39m"; exit 1; }
done <<< `printHelp 2>/dev/null | sed -n '/^Dependency:/,$p' | sed -n '2,/^$/p' | sed 's/^ *//g'`

#  Functions.
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
title rcm-drupal-setup-variation7.sh
____

# Requirement, validate, and populate value.
chapter Dump variable.
delay=.5; [ -n "$fast" ] && unset delay
code update_system="$update_system"
code upgrade_system="$upgrade_system"
[ -n "$fast" ] && isfast=' --fast' || isfast=''
[ -n "$auto_add_group" ] && is_auto_add_group=' --auto-add-group' || is_auto_add_group=''
[[ "$update_system" == "0" ]] && is_without_update_system=' --without-update-system' || is_without_update_system=''
[[ "$upgrade_system" == "0" ]] && is_without_upgrade_system=' --without-upgrade-system' || is_without_upgrade_system=''

php_version=8.3
code php_version="$php_version"
drupal_version=10
code drupal_version="$drupal_version"
drush_version=12
code drush_version="$drush_version"
if [ -z "$project_name" ];then
    error "Argument --project-name required."; x
fi
code 'project_name="'$project_name'"'
if ! validateMachineName "$project_name" project_name;then x; fi
code 'project_parent_name="'$project_parent_name'"'
if [ -n "$project_parent_name" ];then
    if ! validateMachineName "$project_parent_name" project_parent_name;then x; fi
fi
code 'domain_strict="'$domain_strict'"'
code 'domain="'$domain'"'
is_wsl=
if [ -f /proc/sys/kernel/osrelease ];then
    read osrelease </proc/sys/kernel/osrelease
    if [[ "$osrelease" =~ microsoft || "$osrelease" =~ Microsoft ]];then
        is_wsl=1
    fi
fi
code 'is_wsl="'$is_wsl'"'
nginx_user=
conf_nginx=`command -v nginx > /dev/null && command -v nginx > /dev/null && nginx -V 2>&1 | grep -o -P -- '--conf-path=\K(\S+)'`
if [ -f "$conf_nginx" ];then
    nginx_user=`grep -o -P '^user \K([^;]+)' "$conf_nginx"`
fi
code 'nginx_user="'$nginx_user'"'
if [ -z "$nginx_user" ];then
    error "Variable \$nginx_user failed to populate."; x
fi
if [ -z "$php_fpm_user" ];then
    php_fpm_user="$nginx_user"
fi
code 'php_fpm_user="'$php_fpm_user'"'
if [ -z "$prefix" ];then
    prefix=$(getent passwd "$php_fpm_user" | cut -d: -f6 )
fi
# Jika $php_fpm_user adalah nginx, maka $HOME nya adalah /nonexistent, maka
# perlu kita verifikasi lagi.
if [ ! -d "$prefix" ];then
    prefix=
fi
if [ -z "$prefix" ];then
    prefix=/usr/local/share
    project_container=drupal
fi
if [ -z "$project_container" ];then
    project_container=drupal-project
fi
code 'prefix="'$prefix'"'
code 'project_container="'$project_container'"'
code 'auto_add_group="'$auto_add_group'"'
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

INDENT+="    " \
rcm-debian-12-setup-basic.sh $isfast --root-sure \
    $is_without_update_system \
    $is_without_upgrade_system \
    --timezone="$timezone" \
    && INDENT+="    " \
rcm-nginx-autoinstaller.sh $isfast --root-sure \
    && INDENT+="    " \
rcm-mariadb-autoinstaller.sh $isfast --root-sure \
    && INDENT+="    " \
rcm-php-autoinstaller.sh $isfast --root-sure \
    --php-version="$php_version" \
    && INDENT+="    " \
rcm-php-setup-adjust-cli-version.sh $isfast --root-sure \
    --php-version="$php_version" \
    && INDENT+="    " \
rcm-php-setup-drupal.sh $isfast --root-sure \
    --php-version="$php_version" \
    ; [ ! $? -eq 0 ] && x
if [ -n "$is_wsl" ];then
    INDENT+="    " \
    rcm-wsl-setup-lemp-stack.sh $isfast --root-sure \
        --php-version="$php_version" \
        ; [ ! $? -eq 0 ] && x
fi

INDENT+="    " \
rcm-php-fpm-setup-pool.sh $isfast --root-sure \
    --php-version="$php_version" \
    --php-fpm-user="$php_fpm_user" \
    ; [ ! $? -eq 0 ] && x

INDENT+="    " \
rcm-composer-autoinstaller.sh $isfast --root-sure \
    && INDENT+="    " \
rcm-drupal-autoinstaller-nginx.sh $isfast --root-sure \
    $is_auto_add_group \
    --drupal-version="$drupal_version" \
    --drush-version="$drush_version" \
    --php-version="$php_version" \
    --php-fpm-user="$php_fpm_user" \
    --prefix="$prefix" \
    --project-container="$project_container" \
    --project-name="$project_name" \
    --project-parent-name="$project_parent_name" \
    ; [ ! $? -eq 0 ] && x

if [ -n "$domain" ];then
    INDENT+="    " \
    rcm-drupal-setup-wrapper-nginx-setup-drupal.sh $isfast --root-sure \
        --php-version="$php_version" \
        --project-name="$project_name" \
        --project-parent-name="$project_parent_name" \
        --domain="$domain" \
        --php-fpm-user="$php_fpm_user" \
        --prefix="$prefix" \
        --project-container="$project_container" \
        && INDENT+="    " \
    rcm-drupal-setup-wrapper-nginx-setup-drupal.sh $isfast --root-sure \
        --php-version="$php_version" \
        --project-name="$project_name" \
        --project-parent-name="$project_parent_name" \
        --subdomain="$domain" \
        --domain="localhost" \
        --php-fpm-user="$php_fpm_user" \
        --prefix="$prefix" \
        --project-container="$project_container" \
        ; [ ! $? -eq 0 ] && x
fi

INDENT+="    " \
rcm-drupal-setup-drush-alias.sh $isfast --root-sure \
    --project-name="$project_name" \
    --project-parent-name="$project_parent_name" \
    --domain="$domain" \
    && INDENT+="    " \
rcm-drupal-setup-dump-variables.sh $isfast --root-sure \
    --project-name="$project_name" \
    --project-parent-name="$project_parent_name" \
    --domain="$domain" \
    ; [ ! $? -eq 0 ] && x

chapter Finish
e If you want to see the credentials again, please execute this command:
[ -n "$project_parent_name" ] && has_project_parent_name=' --project-parent-name='"'${project_parent_name}'" || has_project_parent_name=''
[ -n "$domain" ] && has_domain=' --domain='"'${domain}'" || has_domain=''
code rcm-drupal-setup-dump-variables.sh${isfast} --project-name="'${project_name}'"${has_project_parent_name}${has_domain}
e If you want to see all project, please execute this command:
code . cd-drupal
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
# --domain-strict
# --auto-add-group
# )
# VALUE=(
# --project-name
# --project-parent-name
# --timezone
# --domain
# --php-fpm-user
# --prefix
# --project-container
# )
# MULTIVALUE=(
# )
# FLAG_VALUE=(
# )
# CSV=(
    # 'long:--with-update-system,parameter:update_system'
    # 'long:--without-update-system,parameter:update_system,flag_option:reverse'
    # 'long:--with-upgrade-system,parameter:upgrade_system'
    # 'long:--without-upgrade-system,parameter:upgrade_system,flag_option:reverse'
# )
# EOF
# clear

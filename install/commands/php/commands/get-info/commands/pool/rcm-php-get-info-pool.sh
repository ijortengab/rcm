#!/bin/bash

RCM_EXTENSION_VERSION=0.19.0-alpha.13

# Usage Functions.
usage() {
    cat << EOF
Usage: rcm php get-info pool [options]

Options:
   --php-version=VERSION
        Set version of PHP.
   --pool-name=NAME
        Set the pool name.
   --key=KEY
        Set the key which will get the value.

Global Options:
   --version
        Print version of this script.
   --help
        Show this help.

Dependency:
EOF
}

# Prevent scripts from being executed directly.
[ -f "${RCM_LIB}/require.sh" ] && source "${RCM_LIB}/require.sh" || { usage >&2; exit 1; }

_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --key=*) key="${1#*=}"; shift ;;
        --key) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then key="$2"; shift; fi; shift ;;
        --php-version=*) php_version="${1#*=}"; shift ;;
        --php-version) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then php_version="$2"; shift; fi; shift ;;
        --pool-name=*) pool_name="${1#*=}"; shift ;;
        --pool-name) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then pool_name="$2"; shift; fi; shift ;;
        --[^-]*) shift ;;
        *) _new_arguments+=("$1"); shift ;;
    esac
done
set -- "${_new_arguments[@]}"
unset _new_arguments

# Define variables and constants.
PHP_FPM_POOL_DIRECTORY=${PHP_FPM_POOL_DIRECTORY:=/etc/php/[php-version]/fpm/pool.d}

# Help and Version.
[ -n "$help" ] && { usage; exit 0; }
[ -n "$version" ] && { e $RCM_EXTENSION_VERSION; x; }

# Require.
require vendor/ijortengab/rcm/functions/utility/php-pool.sh

# ------------------------------------------------------------------------------

# Title.
title rcm php get-info pool
____

# Dependency.
require command php

chapter Mapping operand as value of options.
if [ -n "$1" ];then
    code --php-version=$1
    php_version="$1"; shift
fi
if [ -n "$1" ];then
    code --pool-name=$1
    pool_name=$1; shift
fi
if [ -n "$1" ];then
    code --key=$1
    key=$1; shift
fi
____

# Requirement, validate, and populate value.
chapter Variable dump.
if [ -z "$php_version" ];then
    error "Argument --php-version required."; x
fi
code 'php_version="'$php_version'"'
if [ -z "$pool_name" ];then
    error "Argument --pool-name required."; x
fi
code 'pool_name="'$pool_name'"'
if [ -z "$key" ];then
    error "Argument --key required."; x
fi
code 'key="'$key'"'
____

if [ "$EUID" -ne 0 ];then
    find='[php-version]'
    replace="$php_version"
    PHP_FPM_POOL_DIRECTORY="${PHP_FPM_POOL_DIRECTORY/"$find"/"$replace"}"
    if [ ! -d "$PHP_FPM_POOL_DIRECTORY" ];then
        error PHP Version is not exists in system.; x
    fi
    contents=
    while read file; do
        contents+=$(cat - < "$file")
        contents+=$'\n'
    done <<< `ls "$PHP_FPM_POOL_DIRECTORY"/*.conf`
    echo "$contents" | php-pool get-info $pool_name $key \
    ; [ ! $? -eq 0 ] && x
else
    # Dependency.
    require command php-fpm$php_version
    php-fpm$php_version -tt 2>&1 | sed -E 's/.*NOTICE:[[:blank:]]+//' | sed '$d' | php-pool get-info $pool_name $key \
    ; [ ! $? -eq 0 ] && x
fi

# parse-options.sh \
# --without-end-options-double-dash \
# --compact \
# --clean \
# --no-hash-bang \
# --no-original-arguments \
# --no-error-invalid-options \
# --no-error-require-arguments << EOF | clip
# FLAG=(
# --version
# --help
# )
# VALUE=(
# --php-version
# --pool-name
# --key
# )
# MULTIVALUE=(
# )
# FLAG_VALUE=(
# )
# CSV=(
# )
# EOF
# clear

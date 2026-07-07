#!/bin/bash

RCM_EXTENSION_VERSION=0.19.0-alpha.12

# Usage Functions.
usage() {
    cat << EOF
Usage: rcm php get-info pool [options]

Options:
   --php-version=VERSION
        Set version of PHP.
   --php-fpm-user=USER
        Set the Unix user that used by PHP FPM.
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
        --php-fpm-user=*) php_fpm_user="${1#*=}"; shift ;;
        --php-fpm-user) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then php_fpm_user="$2"; shift; fi; shift ;;
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

# Help and Version.
[ -n "$help" ] && { usage; exit 0; }
[ -n "$version" ] && { e $RCM_EXTENSION_VERSION; x; }

# ------------------------------------------------------------------------------

# Define variables and constants.
PHP_FPM_POOL_DIRECTORY=${PHP_FPM_POOL_DIRECTORY:=/etc/php/[php-version]/fpm/pool.d}

php=$(cat <<'EOF'
$mode = $_SERVER['argv'][1];
switch ($mode) {
    case 'get':
        $file = $_SERVER['argv'][2];
        $section_name = $_SERVER['argv'][3];
        $what = $_SERVER['argv'][4];
        if (file_exists($file)) {
            $array = parse_ini_file($file, true);
            if (array_key_exists($section_name, $array)) {
                if (array_key_exists($what, $array[$section_name])) {
                    echo $array[$section_name][$what];
                    exit(0);
                }
            }
        }
        exit(1);
        break;
}
EOF
)

# Requirement, validate, and populate value.
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
# Rename variable.
section_name="$pool_name"
code 'section_name="'$section_name'"'
find='[php-version]'
replace="$php_version"
PHP_FPM_POOL_DIRECTORY="${PHP_FPM_POOL_DIRECTORY/"$find"/"$replace"}"

found=
found_file=
while read file; do
    if grep -q -F "[$section_name]" <<< `sed '/^;/d' "$file"`;then
        found=1
        found_file="$file"
        break;
    fi
done <<< `ls "$PHP_FPM_POOL_DIRECTORY"/*.conf`

if [ -z "$found_file" ];then
    error File config that contains section is not found.; x
elif [ -n "$php_fpm_user" ];then
    user=$(php -r "$php" get "$found_file" "$section_name" "user")
    if [ ! "$php_fpm_user" == "$user" ];then
        error File config that contains section is not belong to user '`'"$php_fpm_user"'`'.; x
    fi
fi
php -r "$php" get "$found_file" "$section_name" "$key"

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
# --php-fpm-user
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

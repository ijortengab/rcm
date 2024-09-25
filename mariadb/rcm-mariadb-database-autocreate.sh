#!/bin/bash

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --db-name=*) db_name="${1#*=}"; shift ;;
        --db-name) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then db_name="$2"; shift; fi; shift ;;
        --fast) fast=1; shift ;;
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
    echo '0.14.0'
}
printHelp() {
    title RCM MariaDB Database Autocreate
    _ 'Variation '; yellow Default; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-mariadb-database-autocreate [options]

Options:
   --db-name *
        The database name.

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
   mysql
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Dependency.
while IFS= read -r line; do
    [[ -z "$line" ]] || command -v `cut -d: -f1 <<< "${line}"` >/dev/null || { echo -e "\e[91m""Unable to proceed, "'`'"${line}"'`'" command not found." "\e[39m"; exit 1; }
done <<< `printHelp 2>/dev/null | sed -n '/^Dependency:/,$p' | sed -n '2,/^\s*$/p' | sed 's/^ *//g'`

# Title.
title rcm-mariadb-database-autocreate
____

# Requirement, validate, and populate value.
chapter Dump variable.
if [ -z "$db_name" ];then
    error "Argument --db-name required."; x
fi
code 'db_name="'$db_name'"'
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

chapter Mengecek database '`'$db_name'`'.
code 'mysql --silent --skip-column-names -e ''"''select schema_name from information_schema.schemata where schema_name = '"'""$db_name""'"'"'
msg=$(mysql --silent --skip-column-names -e "select schema_name from information_schema.schemata where schema_name = '$db_name'")
notfound=
if [[ $msg == $db_name ]];then
    __ Database ditemukan.
else
    __ Database tidak ditemukan.
    notfound=1
fi
____

if [ -n "$notfound" ];then
    chapter Membuat database.
    code 'mysql -e ''"''create database '"$db_name"' character set utf8 collate utf8_general_ci;''"'
    mysql -e "create database $db_name character set utf8 collate utf8_general_ci;"
    code 'mysql --silent --skip-column-names -e ''"''select schema_name from information_schema.schemata where schema_name = '"'""$db_name""'"'"'
    msg=$(mysql --silent --skip-column-names -e "select schema_name from information_schema.schemata where schema_name = '$db_name'")
    if [[ $msg == $db_name ]];then
        __; green Database ditemukan.; _.
    else
        __; red Database tidak ditemukan.; x
    fi
    ____
fi

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
# --db-name
# )
# MULTIVALUE=(
# )
# FLAG_VALUE=(
# )
# EOF
# clear

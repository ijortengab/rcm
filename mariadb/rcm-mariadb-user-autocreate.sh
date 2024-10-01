#!/bin/bash

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --db-user=*) db_user="${1#*=}"; shift ;;
        --db-user) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then db_user="$2"; shift; fi; shift ;;
        --db-user-host=*) db_user_host="${1#*=}"; shift ;;
        --db-user-host) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then db_user_host="$2"; shift; fi; shift ;;
        --db-user-password=*) db_user_password="${1#*=}"; shift ;;
        --db-user-password) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then db_user_password="$2"; shift; fi; shift ;;
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
    echo '0.16.3'
}
printHelp() {
    title RCM MariaDB User Autocreate
    _ 'Variation '; yellow Default; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-mariadb-user-autocreate [options]

Options:
   --db-user *
        The database user.
   --db-user-password *
        The database user password.
   --db-user-host
        Host of the the database user come from. Default value: localhost.

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
title rcm-mariadb-user-autocreate
____

# Requirement, validate, and populate value.
chapter Dump variable.
if [ -z "$db_user" ];then
    error "Argument --db-user required."; x
fi
code 'db_user="'$db_user'"'
if [ -z "$db_user_password" ];then
    error "Argument --db-user-password required."; x
fi
code 'db_user_password="'$db_user_password'"'
if [ -z "$db_user_host" ];then
    db_user_host=localhost
fi
code 'db_user_host="'$db_user_host'"'
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

chapter Mengecek Database user '`'$db_user'`'.
code mysql --silent --skip-column-names -e '"''select COUNT(*) FROM mysql.user WHERE user = '"'""$db_user""'"';''"'
msg=$(mysql --silent --skip-column-names -e "select COUNT(*) FROM mysql.user WHERE user = '$db_user';")
notfound=
if [ $msg -gt 0 ];then
    __ Database user ditemukan.
else
    __ Database user tidak ditemukan.
    notfound=1
fi
____

if [ -n "$notfound" ];then
    chapter Membuat user database.
    code 'mysql -e ''"''create user '"'""${db_user}""'"'@'"'""${db_user_host}""'"' identified by '"'""${db_user_password}""'"';''"'
    mysql -e "create user '${db_user}'@'${db_user_host}' identified by '${db_user_password}';"
    msg=$(mysql --silent --skip-column-names -e "select COUNT(*) FROM mysql.user WHERE user = '$db_user';")
    if [ $msg -gt 0 ];then
        __; green Database user ditemukan.; _.
    else
        __; red Database user tidak ditemukan; x
    fi
    ____
else
    chapter Mengecek password user.
    u="$db_user"
    p="$db_user_password"
    code 'mysql --defaults-extra-file=<(printf ''"''[client]\nuser = %s\npassword = %s''"'' ''"'"$u"'"'' ''"'"$p"'"'') -h ''"'"$db_user_host"'"'' -r -N -s -e ''"''"'
    if mysql --defaults-extra-file=<(printf "[client]\nuser = %s\npassword = %s" "$u" "$p") -h "$db_user_host" -r -N -s -e "";then
        __ User password valid.
    else
        __; red User password tidak valid; x
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
# --db-user
# --db-user-host
# --db-user-password
# )
# MULTIVALUE=(
# )
# FLAG_VALUE=(
# )
# EOF
# clear

#!/bin/bash

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --db-suffix-name=*) db_suffix_name="${1#*=}"; shift ;;
        --db-suffix-name) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then db_suffix_name="$2"; shift; fi; shift ;;
        --fast) fast=1; shift ;;
        --project-name=*) project_name="${1#*=}"; shift ;;
        --project-name) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then project_name="$2"; shift; fi; shift ;;
        --project-parent-name=*) project_parent_name="${1#*=}"; shift ;;
        --project-parent-name) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then project_parent_name="$2"; shift; fi; shift ;;
        --root-sure) root_sure=1; shift ;;
        --with-autocreate-db) autocreate_db=1; shift ;;
        --without-autocreate-db) autocreate_db=0; shift ;;
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
    echo '0.10.0'
}
printHelp() {
    title RCM MariaDB Setup Project Database
    _ 'Variation '; yellow Default; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-mariadb-setup-project-database [options]

Options:
   --project-name *
        Set the project name. This should be in machine name format.
   --project-parent-name
        Set the project parent name. The parent is not have to exists before.
   --db-suffix-name
        The database suffix name.

Global Options.
   --fast
        No delay every subtask.
   --version
        Print version of this script.
   --help
        Show this help.
   --root-sure
        Bypass root checking.

Environment Variables.
   MARIADB_PREFIX_MASTER
        Default to /usr/local/share/mariadb
   MARIADB_USERS_CONTAINER_MASTER
        Default to users

Dependency:
   mysql
   pwgen
   rcm-mariadb-database-autocreate
   rcm-mariadb-user-autocreate
   rcm-mariadb-assign-grant-all
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
databaseCredential() {
    if [ -f "${MARIADB_PREFIX_MASTER}/${MARIADB_USERS_CONTAINER_MASTER}/${db_user}" ];then
        local DB_USER DB_USER_PASSWORD
        . "${MARIADB_PREFIX_MASTER}/${MARIADB_USERS_CONTAINER_MASTER}/${db_user}"
        db_user=$DB_USER
        db_user_password=$DB_USER_PASSWORD
    else
        mkdir -p "${MARIADB_PREFIX_MASTER}/${MARIADB_USERS_CONTAINER_MASTER}"
        db_user_password=$(pwgen -s 32 -1)
        cat << EOF > "${MARIADB_PREFIX_MASTER}/${MARIADB_USERS_CONTAINER_MASTER}/${db_user}"
DB_USER=$db_user
DB_USER_PASSWORD=$db_user_password
EOF
        chmod 0500 "${MARIADB_PREFIX_MASTER}/${MARIADB_USERS_CONTAINER_MASTER}"
        chmod 0400 "${MARIADB_PREFIX_MASTER}/${MARIADB_USERS_CONTAINER_MASTER}/${db_user}"
    fi
}

# Title.
title rcm-mariadb-setup-project-database
____

# Requirement, validate, and populate value.
chapter Dump variable.
if [ -z "$project_name" ];then
    error "Argument --project-name required."; x
fi
code 'project_name="'$project_name'"'
code 'project_parent_name="'$project_parent_name'"'
code 'db_suffix_name="'$db_suffix_name'"'
db_user="$project_name"
db_user_host="localhost"
db_name="$project_name"
[ -n "$project_parent_name" ] && {
    db_user="$project_parent_name"
    db_name="${project_parent_name}__${project_name}"
}
[ -n "$db_suffix_name" ] && {
    db_name="${db_name}__${db_suffix_name}"
}
code 'db_user="'$db_user'"'
code 'db_user_host="'$db_user_host'"'
code 'db_name="'$db_name'"'
MARIADB_PREFIX_MASTER=${MARIADB_PREFIX_MASTER:=/usr/local/share/mariadb}
code 'MARIADB_PREFIX_MASTER="'$MARIADB_PREFIX_MASTER'"'
MARIADB_USERS_CONTAINER_MASTER=${MARIADB_USERS_CONTAINER_MASTER:=users}
code 'MARIADB_USERS_CONTAINER_MASTER="'$MARIADB_USERS_CONTAINER_MASTER'"'
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

chapter Mengecek database credentials: '`'$MARIADB_PREFIX_MASTER/$MARIADB_USERS_CONTAINER_MASTER/$db_user'`'.
databaseCredential
if [[ -z "$db_user" ]];then
    __; red Informasi credentials tidak lengkap: '`'$MARIADB_PREFIX_MASTER/$MARIADB_USERS_CONTAINER_MASTER/$db_user'`'.; x
else
    code db_user="$db_user"
fi
if [[ -z "$db_user_password" ]];then
    __; red Informasi credentials tidak lengkap: '`'$MARIADB_PREFIX_MASTER/$MARIADB_USERS_CONTAINER_MASTER/$db_user'`'.; x
else
    code db_user_password="$db_user_password"
fi
____

INDENT+="    " \
rcm-mariadb-user-autocreate $isfast --root-sure \
    --db-user="$db_user" \
    --db-user-host="$db_user_host" \
    --db-user-password="$db_user_password" \
    ; [ ! $? -eq 0 ] && x
if [[ ! "$autocreate_db" == "0" ]];then
    INDENT+="    " \
    rcm-mariadb-database-autocreate $isfast --root-sure \
        --db-name="$db_name" \
        && INDENT+="    " \
    rcm-mariadb-assign-grant-all $isfast --root-sure \
        --db-name="$db_name" \
        --db-user="$db_user" \
        --db-user-host="$db_user_host" \
        --database-exists-sure \
        --user-exists-sure \
        ; [ ! $? -eq 0 ] && x
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
# --project-name
# --project-parent-name
# --db-suffix-name
# )
# MULTIVALUE=(
# )
# FLAG_VALUE=(
# )
# CSV=(
    # 'long:--with-autocreate-db,parameter:autocreate_db'
    # 'long:--without-autocreate-db,parameter:autocreate_db,flag_option:reverse'
# )
# EOF
# clear

#!/bin/bash

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --database-exists-sure) database_exists_sure=1; shift ;;
        --db-name=*) db_name="${1#*=}"; shift ;;
        --db-name) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then db_name="$2"; shift; fi; shift ;;
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
    echo '0.3.0'
}
printHelp() {
    title RCM MariaDB Setup Database
    _ 'Variation '; yellow Default; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-mariadb-setup-database.sh [options]

Options:
   --database-exists-sure
        Bypass database checking.
   --db-name
        The database name.
   --db-user
        The database user.
   --db-user-host
        The database user from host.
   --db-user-password
        The database user password.

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
    [[ -z "$line" ]] || command -v "${line}" >/dev/null || { echo -e "\e[91m""Unable to proceed, ${line} command not found." "\e[39m"; exit 1; }
done <<< `printHelp 2>/dev/null | sed -n '/^Dependency:/,$p' | sed -n '2,/^$/p' | sed 's/^ *//g'`

# Title.
title rcm-mariadb-setup-database.sh
____

# Requirement, validate, and populate value.
chapter Dump variable.
until [[ -n "$db_name" ]];do
    _; read -p "# Argument --db-name required: " db_name
done
code 'db_name="'$db_name'"'
code 'db_user="'$db_user'"'
if [ -n "$db_user" ];then
    until [[ -n "$db_user_password" ]];do
        _; read -p "# Argument --db-user-password required: " db_user_password
    done
    code 'db_user_password="'$db_user_password'"'
    until [[ -n "$db_user_host" ]];do
        _; read -p "# Argument --db-user-host required: " db_user_host
    done
    code 'db_user_host="'$db_user_host'"'
fi
code 'database_exists_sure="'$database_exists_sure'"'
____

if [ -z "$database_exists_sure" ];then
    chapter Mengecek database '`'$db_name'`'.
    msg=$(mysql --silent --skip-column-names -e "select schema_name from information_schema.schemata where schema_name = '$db_name'")
    notfound=
    if [[ $msg == $db_name ]];then
        __ Database ditemukan.
        database_exists_sure=1
    else
        __ Database tidak ditemukan
        notfound=1
    fi
    ____

    if [ -n "$notfound" ];then
        chapter Membuat database.
        mysql -e "create database $db_name character set utf8 collate utf8_general_ci;"
        msg=$(mysql --silent --skip-column-names -e "select schema_name from information_schema.schemata where schema_name = '$db_name'")
        if [[ $msg == $db_name ]];then
            __; green Database ditemukan.; _.
        else
            __; red Database tidak ditemukan; x
        fi
        ____
    fi
fi

if [ -n "$db_user" ];then
    chapter Mengecek user database '`'$db_user'`'.
    msg=$(mysql --silent --skip-column-names -e "select COUNT(*) FROM mysql.user WHERE user = '$db_user';")
    notfound=
    if [ $msg -gt 0 ];then
        __ User database ditemukan.
    else
        __ User database tidak ditemukan.
        notfound=1
    fi
    ____

    if [ -n "$notfound" ];then
        chapter Membuat user database.
        mysql -e "create user '${db_user}'@'${db_user_host}' identified by '${db_user_password}';"
        msg=$(mysql --silent --skip-column-names -e "select COUNT(*) FROM mysql.user WHERE user = '$db_user';")
        if [ $msg -gt 0 ];then
            __; green User database ditemukan.; _.
        else
            __; red User database tidak ditemukan; x
        fi
        ____
    fi

    chapter Mengecek grants user '`'$db_user'`' ke database '`'$db_name'`'.
    notfound=
    msg=$(mysql "$db_name" --silent --skip-column-names -e "show grants for ${db_user}@${db_user_host}")
    # GRANT USAGE ON *.* TO `xxx`@`localhost` IDENTIFIED BY PASSWORD '*650AEE8441BAF8090D260F1E4A0430DD2AF92FBA'
    # GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, REFERENCES, INDEX, ALTER, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, CREATE VIEW, SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, EVENT, TRIGGER ON `xxx\\_%`.* TO `xxx`@`localhost`
    # GRANT USAGE ON *.* TO `yyy`@`localhost` IDENTIFIED BY PASSWORD '*23FF9BDB84CBF879F19D46CB6B85F0550CB64F5C'
    # GRANT ALL PRIVILEGES ON `yyy_drupal`.* TO `yyy`@`localhost`
    # GRANT ALL PRIVILEGES ON `yyy_drupal\\_%`.* TO `yyy`@`localhost`
    # "The first grant was auto-generated." Source: https://phoenixnap.com/kb/mysql-show-user-privileges
    if grep -q "GRANT.*ON.*${db_name}.*TO.*${db_user}.*@.*${db_user_host}.*" <<< "$msg";then
        __ Granted.
    else
        __ Not granted.
        notfound=1
    fi
    ____

    if [ -n "$notfound" ];then
        chapter Memberi grants user '`'$db_user'`' ke database '`'$db_name'`'.
        mysql -e "grant all privileges on \`${db_name}\`.* TO '${db_user}'@'${db_user_host}';"
        mysql -e "grant all privileges on \`${db_name}\_%\`.* TO '${db_user}'@'${db_user_host}';"
        msg=$(mysql "$db_name" --silent --skip-column-names -e "show grants for ${db_user}@${db_user_host}")
        if grep -q "GRANT.*ON.*${db_name}.*TO.*${db_user}.*@.*${db_user_host}.*" <<< "$msg";then
            __; green Granted.; _.
        else
            __; red Not granted.; x
        fi
        ____
    fi
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
# --database-exists-sure
# )
# VALUE=(
# --db-name
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

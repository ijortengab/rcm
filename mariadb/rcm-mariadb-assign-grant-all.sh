#!/bin/bash

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --database-exists-sure) database_exists_sure=1; shift ;;
        --db-name=*) db_name="${1#*=}"; shift ;;
        --db-name) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then db_name="$2"; shift; fi; shift ;;
        --db-user=*) db_user="${1#*=}"; shift ;;
        --db-user) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then db_user="$2"; shift; fi; shift ;;
        --db-user-host=*) db_user_host="${1#*=}"; shift ;;
        --db-user-host) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then db_user_host="$2"; shift; fi; shift ;;
        --fast) fast=1; shift ;;
        --user-exists-sure) user_exists_sure=1; shift ;;
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
e() { echo -n "$INDENT" >&2; echo -n "$@" >&2; }
_() { echo -n "$INDENT" >&2; echo -n "#"' ' >&2; [ -n "$1" ] && echo -n "$@" >&2; }
_,() { echo -n "$@" >&2; }
_.() { echo >&2; }
__() { echo -n "$INDENT" >&2; echo -n "# ${RCM_INDENT}" >&2; [ -n "$1" ] && echo "$@" >&2; }
____() { echo >&2; [ -n "$RCM_DELAY" ] && sleep "$RCM_DELAY"; }

# Define variables and constants.
RCM_DELAY=${RCM_DELAY:=.5}; [ -n "$fast" ] && unset RCM_DELAY
RCM_INDENT='    '; [ "$(tput cols)" -le 80 ] && RCM_INDENT='  '

# Functions.
printVersion() {
    echo '0.17.3'
}
printHelp() {
    title RCM MariaDB Assign
    _ 'Variation '; yellow Grant All; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    # Label for --db-name.
    unset count
    declare -i count
    count=0
    single_line=
    while read line;do
        if [ $count -gt 0 ];then
            single_line+=", "
        fi
        count+=1
        single_line+="${line}"
    done <<< `mysql --silent --skip-column-names -e "show databases;"`
    if [ -n "$single_line" ];then
        single_line=" Available values: ${single_line}."
    fi
    db_name_label_suffix="${single_line}"
    # Label for --db-user.
    # Karena user boleh terdapat karakter titik, sehingga perlu kita akalin.
    unset count
    declare -i count
    count=0
    single_line=
    multi_line=
    while read line;do
        if [ $count -gt 0 ];then
            single_line+=", "
        fi
        count+=1
        single_line+="[${count}]"
        multi_line+=$'\n''        '"[${count}]: "${line}
    done <<< `mysql --silent --skip-column-names -e "select User from mysql.user;"`
    if [ -n "$single_line" ];then
        single_line=" Available values: ${single_line}."
    fi
    if [ -n "$multi_line" ];then
        multi_line="$multi_line"
    fi
    db_user_label_suffix="${single_line}${multi_line}"
    cat << EOF
Usage: rcm-mariadb-assign-grant-all [options]

Options:
   --db-name *
        The database name.${db_name_label_suffix}
   --db-user *
        The database user.${db_user_label_suffix}
   --db-user-host
        Host of the the database user come from. Default value: localhost.
   --database-exists-sure ^
        Bypass database checking.
   --user-exists-sure ^
        Bypass database user checking.

Global Options.
   --fast
        No delay every subtask.
   --version
        Print version of this script.
   --help
        Show this help.

Dependency:
   mysql
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Title.
title rcm-mariadb-assign-grant-all
____

[ "$EUID" -ne 0 ] && { error This script needs to be run with superuser privileges.; x; }

# Dependency.
while IFS= read -r line; do
    [[ -z "$line" ]] || command -v `cut -d: -f1 <<< "${line}"` >/dev/null || { error Unable to proceed, command not found: '`'`cut -d: -f1 <<< "${line}"`'`'.; x; }
done <<< `printHelp 2>/dev/null | sed -n '/^Dependency:/,$p' | sed -n '2,/^\s*$/p' | sed 's/^ *//g'`

# Requirement, validate, and populate value.
chapter Dump variable.
if [ -z "$db_name" ];then
    error "Argument --db-name required."; x
fi
code 'db_name="'$db_name'"'
if [ -z "$db_user" ];then
    error "Argument --db-user required."; x
fi
code 'db_user="'$db_user'"'
if [ -z "$db_user_host" ];then
    db_user_host=localhost
fi
code 'db_user_host="'$db_user_host'"'
code 'database_exists_sure="'$database_exists_sure'"'
code 'user_exists_sure="'$user_exists_sure'"'
____

if [ -z "$database_exists_sure" ];then
    chapter Mengecek database '`'$db_name'`'.
    code 'mysql --silent --skip-column-names -e ''"''select schema_name from information_schema.schemata where schema_name = '"'""$db_name""'"'"'
    msg=$(mysql --silent --skip-column-names -e "select schema_name from information_schema.schemata where schema_name = '$db_name'")
    notfound=
    if [[ $msg == $db_name ]];then
        __ Database ditemukan.
    else
        __; red Database tidak ditemukan; x
    fi
    ____
fi

if [ -z "$user_exists_sure" ];then
    chapter Mengecek database user '`'$db_user'`'.
    code mysql --silent --skip-column-names -e '"''select COUNT(*) FROM mysql.user WHERE user = '"'""$db_user""'"';''"'
    msg=$(mysql --silent --skip-column-names -e "select COUNT(*) FROM mysql.user WHERE user = '$db_user';")
    notfound=
    if [ $msg -gt 0 ];then
        __ Database user ditemukan.
    else
        __; red Database user tidak ditemukan; x
        notfound=1
    fi
    ____
fi

chapter Mengecek grants user '`'$db_user'`' ke database '`'$db_name'`'.
notfound=
# GRANT USAGE ON *.* TO `xxx`@`localhost` IDENTIFIED BY PASSWORD '*650AEE8441BAF8090D260F1E4A0430DD2AF92FBA'
# GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, REFERENCES, INDEX, ALTER, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, CREATE VIEW, SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, EVENT, TRIGGER ON `xxx\\_%`.* TO `xxx`@`localhost`
# GRANT USAGE ON *.* TO `yyy`@`localhost` IDENTIFIED BY PASSWORD '*23FF9BDB84CBF879F19D46CB6B85F0550CB64F5C'
# GRANT ALL PRIVILEGES ON `yyy_drupal`.* TO `yyy`@`localhost`
# GRANT ALL PRIVILEGES ON `yyy_drupal\\_%`.* TO `yyy`@`localhost`
# "The first grant was auto-generated." Source: https://phoenixnap.com/kb/mysql-show-user-privileges
# GRANT USAGE ON *.* TO `roundcube`@`localhost` IDENTIFIED BY PASSWORD '*C75329CD384E7527992AED32A0A0DF1FA0342B15'
# GRANT ALL PRIVILEGES ON `roundcubemail`.* TO `roundcube`@`localhost`
__; magenta mysql '"'$db_name'"' --silent --skip-column-names -e '"'show grants for ${db_user}@${db_user_host}'"'; _.
while read line; do e "$line"; _.; done <<< `mysql "$db_name" --silent --skip-column-names -e "show grants for ${db_user}@${db_user_host}"`
msg=$(mysql "$db_name" --silent --skip-column-names -e "show grants for ${db_user}@${db_user_host}")
__; magenta grep -F "'"GRANT ALL PRIVILEGES ON '`'$db_name'`'.* TO '`'$db_user'`'@'`'$db_user_host'`'"'"; _.
if grep -q -F 'GRANT ALL PRIVILEGES ON `'"$db_name"'`.* TO `'"$db_user"'`@`'"$db_user_host"'`' <<< "$msg";then
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
    if grep -q -F 'GRANT ALL PRIVILEGES ON `'"$db_name"'`.* TO `'"$db_user"'`@`'"$db_user_host"'`' <<< "$msg";then
        __; green Granted.; _.
    else
        __; red Not granted.; x
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
# --database-exists-sure
# --user-exists-sure
# )
# VALUE=(
# --db-name
# --db-user
# --db-user-host
# )
# MULTIVALUE=(
# )
# FLAG_VALUE=(
# )
# EOF
# clear

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
    echo '0.4.0'
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
   BINARY_DIRECTORY
        Default to $__DIR__
EOF
}
vercomp() {
    # https://www.google.com/search?q=bash+compare+version
    # https://stackoverflow.com/a/4025065
    if [[ $1 == $2 ]]; then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++)); do
        if [[ -z ${ver2[i]} ]];then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 2
        fi
    done
    return 0
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Functions.
resolve_relative_path() {
    if [ -d "$1" ];then
        cd "$1" || return 1
        pwd
    elif [ -e "$1" ];then
        if [ ! "${1%/*}" = "$1" ]; then
            cd "${1%/*}" || return 1
        fi
        echo "$(pwd)/${1##*/}"
    else
        return 1
    fi
}
fileMustExists() {
    # global used:
    # global modified:
    # function used: __, success, error, x
    if [ -f "$1" ];then
        __; green File '`'$(basename "$1")'`' ditemukan.; _.
    else
        __; red File '`'$(basename "$1")'`' tidak ditemukan.; x
    fi
}
isFileExists() {
    # global used:
    # global modified: found, notfound
    # function used: __
    found=
    notfound=
    if [ -f "$1" ];then
        __ File '`'$(basename "$1")'`' ditemukan.
        found=1
    else
        __ File '`'$(basename "$1")'`' tidak ditemukan.
        notfound=1
    fi
}
backupFile() {
    local mode="$1"
    local oldpath="$2" i newpath
    i=1
    newpath="${oldpath}.${i}"
    if [ -f "$newpath" ]; then
        let i++
        newpath="${oldpath}.${i}"
        while [ -f "$newpath" ] ; do
            let i++
            newpath="${oldpath}.${i}"
        done
    fi
    case $mode in
        move)
            mv "$oldpath" "$newpath" ;;
        copy)
            local user=$(stat -c "%U" "$oldpath")
            local group=$(stat -c "%G" "$oldpath")
            cp "$oldpath" "$newpath"
            chown ${user}:${group} "$newpath"
    esac
}
link_symbolic() {
    local source="$1"
    local target="$2"
    local create
    _success=
    [ -e "$source" ] || { error Source not exist: $source.; x; }
    [ -n "$target" ] || { error Target not defined.; x; }
    [[ $(type -t backupFile) == function ]] || { error Function backupFile not found.; x; }
    [[ $(type -t isFileExists) == function ]] || { error Function isFileExists not found.; x; }

    chapter Memeriksa file '`'$target'`'
    isFileExists "$target"
    if [ -n "$notfound" ];then
        create=1
    else
        if [ -h "$target" ];then
            __; _, Mengecek apakah file merujuk ke '`'$source'`':
            _dereference=$(stat ${stat_cached} "$target" -c %N)
            match="'$target' -> '$source'"
            if [[ "$_dereference" == "$match" ]];then
                _, ' 'Merujuk.; _.
            else
                _, ' 'Tidak merujuk.; _.
                __ Melakukan backup.
                backupFile move "$target"
                create=1
            fi
        else
            __ File bukan merupakan symbolic link.
            __ Melakukan backup.
            backupFile move "$target"
            create=1
        fi
    fi
    ____

    if [ -n "$create" ];then
        chapter Membuat symbolic link '`'$target'`'.
        code ln -s \"$source\" \"$target\"
        ln -s "$source" "$target"
        __ Verifikasi
        if [ -h "$target" ];then
            _dereference=$(stat ${stat_cached} "$target" -c %N)
            match="'$target' -> '$source'"
            if [[ "$_dereference" == "$match" ]];then
                __; green Symbolic link berhasil dibuat.; _.
                _success=1
            else
                __; red Symbolic link gagal dibuat.; x
            fi
        fi
        ____
    fi
}

# Title.
title rcm-drupal-setup-drush-alias.sh
____

# Require, validate, and populate value.
chapter Dump variable.
delay=.5; [ -n "$fast" ] && unset delay
__FILE__=$(resolve_relative_path "$0")
__DIR__=$(dirname "$__FILE__")
BINARY_DIRECTORY=${BINARY_DIRECTORY:=$__DIR__}
code 'BINARY_DIRECTORY="'$BINARY_DIRECTORY'"'
if [ -z "$project_name" ];then
    error "Argument --project-name required."; x
fi
code 'domain="'$domain'"'
code 'project_name="'$project_name'"'
code 'project_parent_name="'$project_parent_name'"'
project_dir="$project_name"
drupal_fqdn_localhost="$project_name".drupal.localhost
[ -n "$project_parent_name" ] && {
    drupal_fqdn_localhost="$project_name"."$project_parent_name".drupal.localhost
    project_dir="$project_parent_name"
}
vercomp `stat --version | head -1 | grep -o -E '\S+$'` 8.31
if [[ $? -lt 2 ]];then
    stat_cached=' --cached=never'
else
    stat_cached=''
fi
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

list_uri=("${drupal_fqdn_localhost}")
if [ -n "$domain" ];then
    list_uri=("${domain}")
fi

for uri in "${list_uri[@]}";do
    filename="cd-drupal-${uri}"
    chapter Script Shortcut ${filename}
    __; _, Command:' '; magenta ". ${filename}"; _.
    fullpath="/usr/local/share/drupal/${project_dir}/${filename}"
    if [[ -f "$fullpath" && ! -s "$fullpath" ]];then
        __ Empty file detected.
        __; magenta rm "$fullpath"; _.
        rm "$fullpath"
    fi
    if [ ! -f "$fullpath" ];then
        __ Membuat file '`'"$fullpath"'`'.
        touch "$fullpath"
        chmod a+x "$fullpath"
        cat << 'EOF' > "$fullpath"
[[ -f "$0" && ! "$0" == $(command -v bash) ]] && { echo -e "\e[91m""Usage: . "$(basename "$0") "\e[39m"; exit 1; }
_prefix_master=/usr/local/share
_project_container_master=drupal
_project_dir=__PROJECT_DIR__
_target="${_prefix_master}/${_project_container_master}/${_project_dir}/drupal"
_dereference=$(stat ${stat_cached} "$_target" -c %N)
PROJECT_DIR=$(grep -Eo "' -> '.*'$" <<< "$_dereference" | sed -E "s/' -> '(.*)'$/\1/")
DRUPAL_ROOT="${PROJECT_DIR}/web"
echo export PROJECT_DIR='"'$PROJECT_DIR'"'
echo export DRUPAL_ROOT='"'$DRUPAL_ROOT'"'
echo -e alias "\e[95m"drush"\e[39m"='"'$PROJECT_DIR/vendor/bin/drush --uri=__URI__'"'
echo cd '"$PROJECT_DIR"'
echo '[ -f .aliases ] && . .aliases'
export PROJECT_DIR="$PROJECT_DIR"
export DRUPAL_ROOT="$DRUPAL_ROOT"
alias drush="$PROJECT_DIR/vendor/bin/drush --uri=__URI__"
cd "$PROJECT_DIR"
[ -f .aliases ] && . .aliases
EOF
        sed -i "s|__PROJECT_DIR__|${project_dir}|g" "$fullpath"
        sed -i "s|__URI__|${uri}|g" "$fullpath"
    else
        __ File ditemukan '`'"$fullpath"'`'.
    fi
    ____

    link_symbolic "$fullpath" "$BINARY_DIRECTORY/$filename"
done

chapter Script Shortcut General
isFileExists "/usr/local/share/drupal/cd-drupal"
if [ -n "$notfound" ];then
    __ Membuat file "/usr/local/share/drupal/cd-drupal"
    code touch '"'/usr/local/share/drupal/cd-drupal'"'
    code chmod a+x '"'/usr/local/share/drupal/cd-drupal'"'
    touch "/usr/local/share/drupal/cd-drupal"
    chmod a+x "/usr/local/share/drupal/cd-drupal"
    cat << 'EOF' > "/usr/local/share/drupal/cd-drupal"
#!/bin/bash

[[ -f "$0" && ! "$0" == $(command -v bash) ]] && { echo -e "\e[91m""Usage: . "$(basename "$0") "\e[39m"; exit 1; }
_prefix_master=/usr/local/share
_project_container_master=drupal
[[ ! -d "${_prefix_master}/${_project_container_master}" ]] && { echo -e "\e[91m""There's no Drupal Directory Master : ${_prefix_master}/${_project_container_master}" "\e[39m"; }
if [[ -d "${_prefix_master}/${_project_container_master}" ]];then
    echo -e There are Drupal project available. Press the "\e[93m"yellow"\e[39m" number key to select.
    unset count
    declare -i count
    count=0
    source=()
    while read line; do
        basename=$(basename "$line")
        count+=1
        if [ $count -lt 10 ];then
            echo -ne '['"\e[93m"$count"\e[39m"']' "$basename" "\n"
        else
            echo '['$count']' "$basename"
        fi
        source+=("$basename")
    done <<< `find "${_prefix_master}/${_project_container_master}" -mindepth 1 -maxdepth 1 -type d`
    echo -ne '['"\e[93m"Enter"\e[39m"']' "\e[93m"T"\e[39m"ype the number key instead. "\n"
    count_max="${#source[@]}"
    if [ $count_max -gt 9 ];then
        count_max=9
    fi
    project_dir=
    while true; do
        read -rsn 1 -p "Select: " char;
        if [ -z "$char" ];then
            char=t
        fi
        case $char in
            t|T) echo "$char"; break ;;
            [1-$count_max])
                echo "$char"
                i=$((char - 1))
                project_dir="${source[$i]}"
                break ;;
            *) echo
        esac
    done
    until [ -n "$project_dir" ];do
        read -p "Type the value: " project_dir
        if [[ $project_dir =~ [^0-9] ]];then
            project_dir=
        fi
        if [ -n "$project_dir" ];then
            project_dir=$((project_dir - 1))
            project_dir="${source[$project_dir]}"
        fi
    done
    echo -e Project "\e[93m""$project_dir""\e[39m" selected.
    echo
    unset count
    declare -i count
    count=0
    source=()
    while read line; do
        if grep -q '^_project_dir='"$project_dir" "$line";then
            if [ "${#source[@]}" -eq 0 ];then
                echo -e There are Site available. Press the "\e[93m"yellow"\e[39m" number key to select.
            fi
            basename=$(basename "$line" | cut -c11-)
            count+=1
            if [ $count -lt 10 ];then
                echo -ne '['"\e[93m"$count"\e[39m"']' "$basename" "\n"
            else
                echo '['$count']' "$basename"
            fi
            source+=("$basename")
        fi
    done <<< `ls /usr/local/share/drupal/$project_dir/cd-drupal-*`
    count_max="${#source[@]}"
    if [ $count_max -gt 9 ];then
        count_max=9
    fi
    if [ "${#source[@]}" -eq 0 ];then
        echo -e There are no site available.
    else
        echo -ne '['"\e[93m"Enter"\e[39m"']' "\e[93m"T"\e[39m"ype the number key instead. "\n"
        value=
        while true; do
            read -rsn 1 -p "Select: " char;
            if [ -z "$char" ];then
                char=t
            fi
            case $char in
                t|T) echo "$char"; break ;;
                [1-$count_max])
                    echo "$char"
                    i=$((char - 1))
                    value="${source[$i]}"
                    break ;;
                *) echo
            esac
        done
        until [ -n "$value" ];do
            read -p "Type the value: " value
            if [[ $value =~ [^0-9] ]];then
                value=
            fi
            if [ -n "$value" ];then
                value=$((value - 1))
                value="${source[$value]}"
            fi
        done
        echo -e Site "\e[93m""$value""\e[39m" selected.
    fi
    echo
    echo -e We will execute: "\e[95m". cd-drupal-${value}"\e[39m"
    echo -ne '['"\e[93m"Esc"\e[39m"']' "\e[93m"Q"\e[39m"uit. "\n"
    echo -ne '['"\e[93m"Enter"\e[39m"']' Continue. "\n"
    exe=
    while true; do
        read -rsn 1 -p "Select: " char;
        if [ -z "$char" ];then
            printf "\r\033[K" >&2
            exe=1
            break
        fi
        case $char in
            $'\33') echo "q"; break ;;
            q|Q) echo "$char"; break ;;
            *) echo
        esac
    done
    if [ -n "$exe" ];then
        echo
        echo -e "\e[95m". cd-drupal-${value}"\e[39m"
        . cd-drupal-${value}
    fi
fi
EOF
    fileMustExists "/usr/local/share/drupal/cd-drupal"
fi
____

link_symbolic "/usr/local/share/drupal/cd-drupal" "$BINARY_DIRECTORY/cd-drupal"

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

#!/bin/bash

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --fast) fast=1; shift ;;
        --timezone=*) timezone="${1#*=}"; shift ;;
        --timezone) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then timezone="$2"; shift; fi; shift ;;
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
e() { echo -n "$INDENT" >&2; echo -n "$@" >&2; }
_() { echo -n "$INDENT" >&2; echo -n "#"' ' >&2; [ -n "$1" ] && echo -n "$@" >&2; }
_,() { echo -n "$@" >&2; }
_.() { echo >&2; }
__() { echo -n "$INDENT" >&2; echo -n "#" '    ' >&2; [ -n "$1" ] && echo "$@" >&2; }
____() { echo >&2; [ -n "$RCM_DELAY" ] && sleep "$RCM_DELAY"; }

# Define variables and constants.
RCM_DELAY=${RCM_DELAY:=.5}; [ -n "$fast" ] && unset RCM_DELAY

# Functions.
printVersion() {
    echo '0.16.19'
}
printHelp() {
    title RCM Debian 11 Setup Server
    _ 'Variation '; yellow Basic; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-debian-11-setup-basic [options]

Options:
   --timezone
        Set the timezone of this machine. Available values: Asia/Jakarta, or other.
   --without-update-system ^
        Skip execute update system. Default to --with-update-system.
   --without-upgrade-system ^
        Skip execute upgrade system. Default to --with-upgrade-system.

Global Options:
   --fast
        No delay every subtask.
   --version
        Print version of this script.
   --help
        Show this help.
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Title.
title rcm-debian-11-setup-basic
____

[ "$EUID" -ne 0 ] && { error This script needs to be run with superuser privileges.; x; }

# Dependency.
while IFS= read -r line; do
    [[ -z "$line" ]] || command -v `cut -d: -f1 <<< "${line}"` >/dev/null || { error Unable to proceed, command not found: '`'`cut -d: -f1 <<< "${line}"`'`'.; x; }
done <<< `printHelp 2>/dev/null | sed -n '/^Dependency:/,$p' | sed -n '2,/^\s*$/p' | sed 's/^ *//g'`

# Functions.
downloadApplication() {
    local aptnotfound=
    chapter Melakukan instalasi aplikasi.
    code apt install "$@"
    [ -z "$aptinstalled" ] && aptinstalled=$(apt --installed list 2>/dev/null)
    for i in "$@"; do
        if ! grep -q "^$i/" <<< "$aptinstalled";then
            aptnotfound+=" $i"
        fi
    done
    if [ -n "$aptnotfound" ];then
        __ Menginstal.
        code apt install -y"$aptnotfound"
        apt install -y --no-install-recommends $aptnotfound
        aptinstalled=$(apt --installed list 2>/dev/null)
    else
        __ Aplikasi sudah terinstall seluruhnya.
    fi
}
validateApplication() {
    local aptnotfound=
    for i in "$@"; do
        if ! grep -q "^$i/" <<< "$aptinstalled";then
            aptnotfound+=" $i"
        fi
    done
    if [ -n "$aptnotfound" ];then
        __; red Gagal menginstall aplikasi:"$aptnotfound"; x
    fi
}
backupFile() {
    local mode="$1"
    local oldpath="$2" i newpath
    local target_dir="$3"
    i=1
    dirname=$(dirname "$oldpath")
    basename=$(basename "$oldpath")
    if [ -n "$target_dir" ];then
        case "$target_dir" in
            parent) dirname=$(dirname "$dirname") ;;
            *) dirname="$target_dir"
        esac
    fi
    [ -d "$dirname" ] || { echo 'Directory is not exists.' >&2; return 1; }
    newpath="${dirname}/${basename}.${i}"
    if [ -f "$newpath" ]; then
        let i++
        newpath="${dirname}/${basename}.${i}"
        while [ -f "$newpath" ] ; do
            let i++
            newpath="${dirname}/${basename}.${i}"
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
findString() {
    # global debug
    # global find_quoted
    # $find_quoted agar bisa di gunakan oleh sed.
    local find="$1" string path="$2" tempfile="$3" deletetempfile
    if [ -z "$tempfile" ];then
        tempfile=$(mktemp -p /dev/shm)
        deletetempfile=1
    fi
    _; _, Memeriksa baris dengan kalimat: '`'$find'`'.;_.
    find_quoted="$find"
    find_quoted=$(sed -E "s/\s+/\\\s\+/g" <<< "$find_quoted")
    find_quoted=$(sed "s/\./\\\./g" <<< "$find_quoted")
    find_quoted=$(sed "s/\*/\\\*/g" <<< "$find_quoted")
    find_quoted=$(sed "s/;$/\\\s\*;/g" <<< "$find_quoted")
    if [[ ! "${find_quoted:0:1}" == '^' ]];then
        find_quoted="^\s*${find_quoted}"
    fi
    _; magenta grep -E '"'"${find_quoted}"'"' '"'"\$path"'"'; _.
    if grep -E "${find_quoted}" "$path" > "$tempfile";then
        string="$(< "$tempfile")"
        while read -r line; do e "$line"; _.; done <<< "$string"
        __ Baris ditemukan.
        [ -n "$deletetempfile" ] && rm "$tempfile"
        return 0
    else
        __ Baris tidak ditemukan.
        [ -n "$deletetempfile" ] && rm "$tempfile"
        return 1
    fi
}

# Requirement, validate, and populate value.
chapter Dump variable.
[ -z "$update_system" ] && update_system=1
[ "$update_system" == 0 ] && update_system=
[ -z "$upgrade_system" ] && upgrade_system=1
[ "$upgrade_system" == 0 ] && upgrade_system=
code update_system="$update_system"
code upgrade_system="$upgrade_system"
if [ -f /etc/os-release ];then
    . /etc/os-release
fi
if [ -z "$ID" ];then
    error OS not supported; x;
fi
code 'ID="'$ID'"'
code 'VERSION_ID="'$VERSION_ID'"'
case $ID in
    debian)
        case "$VERSION_ID" in
            11)
                repository_required=$(cat <<EOF
deb http://deb.debian.org/debian bullseye main
deb-src http://deb.debian.org/debian bullseye main
deb http://security.debian.org/debian-security bullseye-security main
deb-src http://security.debian.org/debian-security bullseye-security main
deb http://deb.debian.org/debian bullseye-updates main
deb-src http://deb.debian.org/debian bullseye-updates main
EOF
)
                application=
                application+=' cron git'
                application+=' lsb-release apt-transport-https ca-certificates software-properties-common'
                application+=' sudo patch curl wget net-tools apache2-utils openssl rkhunter'
                application+=' binutils dnsutils pwgen daemon apt-listchanges lrzip p7zip'
                application+=' p7zip-full zip unzip bzip2 lzop arj nomarch cabextract'
                application+=' libnet-ident-perl libnet-dns-perl libauthen-sasl-perl'
                application+=' libdbd-mysql-perl libio-string-perl libio-socket-ssl-perl'
            ;;
            *) error OS "$ID" version "$VERSION_ID" not supported; x;
        esac
        ;;
    *) error OS "$ID" not supported; x;
esac
code 'timezone="'$timezone'"'
if [ -n "$timezone" ];then
    if [ ! -f /usr/share/zoneinfo/$timezone ];then
        __ Timezone is not valid.
        timezone=
        code 'timezone="'$timezone'"'
    fi
fi
____

chapter Mengecek shell default
is_dash=
if [[ $(realpath /bin/sh) =~ dash$ ]];then
    __ '`'sh'`' command is linked to dash.
    is_dash=1
else
    __ '`'sh'`' command is linked to $(realpath /bin/sh).
fi
____

if [[ -n "$is_dash" ]];then
    chapter Disable dash
    __ '`sh` command link to dash. Disable now.'
    echo "dash dash/sh boolean false" | debconf-set-selections
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash
    if [[ $(realpath /bin/sh) =~ dash$ ]];then
        __ '`'sh'`' command link to dash.
    else
        __; green '`'sh'`' command link to $(realpath /bin/sh).; _.
        is_dash=
    fi
    ____
fi

if [[ -n "$is_dash" ]];then
    chapter Disable dash again.
    __ '`sh` command link to dash. Override now.'
    path=$(command -v sh)
    cd $(dirname $path)
    ln -sf bash sh
    if [[ $(realpath /bin/sh) =~ dash$ ]];then
        __; red '`'sh'`' command link to dash.; x
    else
        __; green '`'sh'`' command link to $(realpath /bin/sh).; _.
    fi
    ____
fi

adjust=
if [ -n "$timezone" ];then
    chapter Mengecek timezone.
    current_timezone=$(realpath /etc/localtime | cut -d/ -f5,6)
    if [[ "$current_timezone" == "$timezone" ]];then
        __ Timezone is match: ${current_timezone}
    else
        __ Timezone is different: ${current_timezone}
        adjust=1
    fi
    ____
fi

if [[ -n "$adjust" ]];then
    chapter Adjust timezone.
    __ Backup file '`'/etc/localtime'`'
    backupFile move /etc/localtime
    __; magenta ln -s /usr/share/zoneinfo/$timezone /etc/localtime; _.
    ln -s /usr/share/zoneinfo/$timezone /etc/localtime
    current_timezone=$(realpath /etc/localtime | cut -d/ -f5,6)
    if [[ "$current_timezone" == "$timezone" ]];then
        __; green Timezone is match: ${current_timezone}; _.
    else
        __; red Timezone is different: ${current_timezone}; x
    fi
    ____
fi

chapter Update Repository
path=/etc/apt/sources.list
code path='"'$path'"'
while IFS= read -r string; do
    array=($string)
    deb="${array[0]}"
    uri="${array[1]}"
    suite="${array[2]}"
    if ! findString "${deb} ${uri}/? ${suite} " "$path"; then
        CONTENT+="$string"$'\n'
        update_now=1
    fi
done <<< "$repository_required"

[ -z "$CONTENT" ] || {
    CONTENT=$'\n'"# Customize. ${NOW}"$'\n'"$CONTENT"
    echo "$CONTENT" >> /etc/apt/sources.list
}
if [ -n "$update_now" ];then
    code apt -y update
    apt -y update
else
    if [ -n "$update_system" ];then
        code apt -y update
        apt -y update
    fi
    if [ -n "$upgrade_system" ];then
        code apt -y upgrade
        apt -y upgrade
    fi
fi
____

downloadApplication $application
validateApplication $application
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
# )
# VALUE=(
# --timezone
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

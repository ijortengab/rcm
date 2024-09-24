#!/bin/bash

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
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
    echo '0.11.2'
}
printHelp() {
    title RCM Amavis Setup
    _ 'Variation '; yellow ISPConfig; _.
    _ 'Version '; yellow `printVersion`; _.
    cat << EOF

Troubleshooter for Amavis that not running Port 10026.
Reference: https://www.howtoforge.com/community/threads/bullseye-for-ispconfig.87450/page-2#post-427169

EOF
    cat << 'EOF'
Usage: rcm-amavis-setup-ispconfig [options]

Global Options:
   --fast
        No delay every subtask.
   --version
        Print version of this script.
   --help
        Show this help.
   --root-sure
        Bypass root checking.

Dependency:
   systemctl
   netstat
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Dependency.
while IFS= read -r line; do
    [[ -z "$line" ]] || command -v `cut -d: -f1 <<< "${line}"` >/dev/null || { echo -e "\e[91m""Unable to proceed, "'`'"${line}"'`'" command not found." "\e[39m"; exit 1; }
done <<< `printHelp 2>/dev/null | sed -n '/^Dependency:/,$p' | sed -n '2,/^\s*$/p' | sed 's/^ *//g'`

# Functions.
RcmAmavisSetupIspconfig_startTweak() {
    __; magenta chown -R root:amavis /etc/amavis/; _.
    __; magenta chmod 644 /etc/amavis/50-user~; _.
    __; magenta chmod 644 /etc/amavis/conf.d/50-user; _.
    __; magenta service amavis restart; _.
    __; magenta chmod 750 /etc/amavis/conf.d; _.
    tweak=
    restart=
    if [ $(stat /etc/amavis -c %G) == amavis ];then
        __ Directory '`'/etc/amavis'`' bagian dari Group '`'amavis'`'.
    else
        __ Directory '`'/etc/amavis'`' bukan bagian dari Group '`'amavis'`'.
        tweak=1
    fi
    if [ -n "$tweak" ];then
        chown -R root:amavis /etc/amavis/
        restart=1
        if [ $(stat ${stat_cached} /etc/amavis -c %G) == amavis ];then
            __; green Directory '`'/etc/amavis'`' bagian dari Group '`'amavis'`'.; _.
        else
            __; red Directory '`'/etc/amavis'`' bukan bagian dari Group '`'amavis'`'.; x
        fi
    fi
    if [ -f /etc/amavis/50-user~ ];then
        tweak=
        if [[ $(stat /etc/amavis/50-user~ -c %a) == 644 ]];then
            __ File  '`'/etc/amavis/50-user~'`' memiliki permission '`'644'`'.
        else
            __ File  '`'/etc/amavis/50-user~'`' tidak memiliki permission '`'644'`'.
            tweak=1
        fi
        if [ -n "$tweak" ];then
            chmod 644 /etc/amavis/50-user~
            restart=1
            if [[ -f /etc/amavis/50-user~ && $(stat ${stat_cached} /etc/amavis/50-user~ -c %a) == 644 ]];then
                __; green File  '`'/etc/amavis/50-user~'`' memiliki permission '`'644'`'.; _.
            else
                __; red File  '`'/etc/amavis/50-user~'`' tidak memiliki permission '`'644'`'.; x
            fi
        fi
    fi
    if [ -f /etc/amavis/conf.d/50-user ];then
        tweak=
        if [[ $(stat /etc/amavis/conf.d/50-user -c %a) == 644 ]];then
            __ File  '`'/etc/amavis/conf.d/50-user'`' memiliki permission '`'644'`'.
        else
            __ File  '`'/etc/amavis/conf.d/50-user'`' tidak memiliki permission '`'644'`'.
            tweak=1
        fi
        if [ -n "$tweak" ];then
            chmod 644 /etc/amavis/conf.d/50-user
            restart=1
            if [[ -f /etc/amavis/conf.d/50-user && $(stat ${stat_cached} /etc/amavis/conf.d/50-user -c %a) == 644 ]];then
                __; green File  '`'/etc/amavis/conf.d/50-user'`' memiliki permission '`'644'`'.; _.
            else
                __; red File  '`'/etc/amavis/conf.d/50-user'`' tidak memiliki permission '`'644'`'.; x
            fi
        fi
    fi
    if [ -d /etc/amavis/conf.d ];then
        tweak=
        if [[ $(stat /etc/amavis/conf.d -c %a) == 750 ]];then
            __ Directory  '`'/etc/amavis/conf.d'`' memiliki permission '`'750'`'.
        else
            __ Directory  '`'/etc/amavis/conf.d'`' tidak memiliki permission '`'750'`'.
            tweak=1
        fi
        if [ -n "$tweak" ];then
            chmod 750 /etc/amavis/conf.d
            restart=1
            if [[ -d /etc/amavis/conf.d && $(stat ${stat_cached} /etc/amavis/conf.d -c %a) == 750 ]];then
                __; green Directory  '`'/etc/amavis/conf.d'`' memiliki permission '`'750'`'.; _.
            else
                __; red Directory  '`'/etc/amavis/conf.d'`' tidak memiliki permission '`'750'`'.; x
            fi
        fi
    fi
    msg=$(systemctl show amavis.service --no-page | grep ActiveState | grep -o -P "ActiveState=\K(\S+)")
    if [ ! "$msg" == 'active' ];then
        restart=1
    fi
    if [ -n "$restart" ];then
        __; magenta restart="$restart"; _.
        __ Merestart amavis.
        code systemctl restart amavis.service
        systemctl restart amavis.service
        countdown=5
        while [ "$countdown" -ge 0 ]; do
            printf "\r\033[K" >&2
            printf %"$countdown"s | tr " " "." >&2
            printf "\r"
            countdown=$((countdown - 1))
            sleep .8
        done
    fi
    stdout=$(netstat -tpn --listening | grep 10026 | grep amavisd)
    if [ -z "$stdout" ];then
        __; red Port 10026 tidak ditemukan.; x
    else
        __; green Port 10026 ditemukan.; _.
    fi
    ____
}
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

# Title.
title rcm-amavis-setup-ispconfig
____

# Requirement, validate, and populate value.
chapter Dump variable.
delay=.5; [ -n "$fast" ] && unset delay
declare -i countdown
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

chapter Memastikan amavis terinstall dan running.
stdout=$(systemctl show amavis.service --no-page | grep MainPID | grep -o -P "^MainPID=\K(\S+)")
if [ -n "$stdout" ];then
    __ Amavis Service berjalan dengan Main PID=$stdout
else
    __ Amavis Service tidak berjalan.
fi
____

chapter Memastikan amavis port 10026 listening.
stdout=$(netstat -tpn --listening | grep 10026 | grep amavisd)
if [ -n "$stdout" ];then
    skip=1
    __ Port 10026 ditemukan.
else
    __ Port 10026 tidak ditemukan.
    RcmAmavisSetupIspconfig_startTweak
fi
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
# )
# VALUE=(
# )
# FLAG_VALUE=(
# )
# EOF
# clear

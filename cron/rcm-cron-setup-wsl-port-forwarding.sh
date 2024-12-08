#!/bin/bash

# Parse arguments. Generated by parse-options.sh
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --fast) fast=1; shift ;;
        --guest-port=*) guest_port="${1#*=}"; shift ;;
        --guest-port) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then guest_port="$2"; shift; fi; shift ;;
        --host-port=*) host_port="${1#*=}"; shift ;;
        --host-port) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then host_port="$2"; shift; fi; shift ;;
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
e() { echo -n "$INDENT" >&2; echo -n "$@" >&2; }
_() { echo -n "$INDENT" >&2; echo -n "#" "$@" >&2; }
_,() { echo -n "$@" >&2; }
_.() { echo >&2; }
__() { echo -n "$INDENT" >&2; echo -n "#" '    ' >&2; [ -n "$1" ] && echo "$@" >&2 || echo -n  >&2; }
____() { echo >&2; [ -n "$delay" ] && sleep "$delay"; }

# Functions.
printVersion() {
    echo '0.16.8'
}
printHelp() {
    title RCM Cron Setup
    _ 'Variation '; yellow WSL Port Forwarding; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-cron-setup-wsl-port-forwarding [options]

Options:
   --host-port *
        Set the host port that will be forwarded.
   --guest-port *
        Set the guest port as destination form host port.

Global Options:
   --fast
        No delay every subtask.
   --version
        Print version of this script.
   --help
        Show this help.
   --root-sure
        Bypass root checking.

Environment Variables:
   BASENAME
        Default to host-port-__HOST_PORT__-forward-guest-port-__GUEST_PORT__

Dependency:
   crontab
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Title.
title rcm-cron-setup-wsl-port-forwarding
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

# Dependency.
while IFS= read -r line; do
    [[ -z "$line" ]] || command -v `cut -d: -f1 <<< "${line}"` >/dev/null || { error Unable to proceed, command not found: '`'$line'`'.; x; }
done <<< `printHelp 2>/dev/null | sed -n '/^Dependency:/,$p' | sed -n '2,/^\s*$/p' | sed 's/^ *//g'`

# Functions.
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

# Require, validate, and populate value.
chapter Dump variable.
BASENAME=${BASENAME:=host-port-__HOST_PORT__-forward-guest-port-__GUEST_PORT__}
code 'BASENAME="'$BASENAME'"'
if [ -z "$host_port" ];then
    error "Argument --host-port required."; x
fi
code 'host_port="'$host_port'"'
if [ -z "$guest_port" ];then
    error "Argument --guest-port required."; x
fi
code 'guest_port="'$guest_port'"'
basename_string=$(sed -e "s,__HOST_PORT__,$host_port," -e "s,__GUEST_PORT__,$guest_port," <<< "$BASENAME" )
code 'basename_string="'$basename_string'"'
case `uname` in
    CYGWIN*) is_cygwin=1 ;;
    *) is_cygwin= ;;
esac
code 'is_cygwin="'$is_cygwin'"'
delay=.5; [ -n "$fast" ] && unset delay
____

if [ -z "$root_sure" ];then
    chapter Mengecek '`'Run as Administrator'`'.
    admin=$(/usr/bin/id -G | /usr/bin/grep -Eq '\<544\>' && echo yes || echo no)
    if [[ "$admin" == 'yes' ]]; then
        __ Run as admin.;
    else
        __ Run as Standard user.
    fi
    ____
fi

filename_string="/var/log/${basename_string}.log"
chapter Mengecek file log '`'$filename_string'`'
isFileExists "$filename_string"
if [ -n "$notfound" ];then
    __ Membuat file.
    touch "$filename_string"
    fileMustExists "$filename_string"
fi
____

filename_string="/usr/local/${basename_string}.sh"
chapter Mengecek shell script '`'$filename_string'`'
isFileExists "$filename_string"
if [ -n "$notfound" ];then
    __ Membuat file.
    mkdir -p $(dirname "$filename_string")
    touch "$filename_string"
    chmod a+x "$filename_string"
    string=$(cat << 'EOF'
#!/bin/bash
echo $(date +%Y%m%d-%H%M%S) '[notice]' Begin trigger.
begin=$SECONDS
PATH=/cygdrive/c/Windows/system32:$PATH
host_port=__HOST_PORT__
guest_port=__GUEST_PORT__
declare -i count
count=0
until [[ $(wsl --list --running --quiet | wc -l) -gt 0 ]]; do
    count+=1
    if [ $count -eq 60 ];then
        echo $(date +%Y%m%d-%H%M%S) '[notice]' Timeout, wait a minute.
        echo $(date +%Y%m%d-%H%M%S) '[notice]' Command to stop this process: '`'kill $$'`'.
        sleep 59
        count=0
    fi
    sleep 1
done
count=0
connectaddress=$(wsl ip address show dev eth0 | grep 'inet ' | grep -P -o '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' | head -1)
until [[ -n "$connectaddress" ]]; do
    count+=1
    if [ $count -eq 60 ];then
        echo $(date +%Y%m%d-%H%M%S) '[notice]' Timeout, wait a minute.
        echo $(date +%Y%m%d-%H%M%S) '[notice]' Command to stop this process: '`'kill $$'`'.
        sleep 59
        count=0
    fi
    sleep 1
    connectaddress=$(wsl ip address show dev eth0 | grep 'inet ' | grep -P -o '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' | head -1)
done
tempfile=$(mktemp)
netsh interface portproxy delete v4tov4 listenport=$host_port 2>&1 >> "$tempfile"
netsh advfirewall firewall delete rule name=$host_port 2>&1 >> "$tempfile"
netsh interface portproxy add v4tov4 listenport=$host_port connectport=$guest_port connectaddress="$connectaddress" 2>&1 >> "$tempfile"
netsh advfirewall firewall add rule name=$host_port dir=in action=allow protocol=TCP localport=$host_port 2>&1 >> "$tempfile"
netsh interface portproxy show v4tov4 2>&1 >> "$tempfile"
ifs="$IFS"
while IFS= read line; do
    echo $(date +%Y%m%d-%H%M%S) '[debug] ' "$line"
done < "$tempfile"
IFS="$ifs"
rm "$tempfile"
end=$SECONDS
duration=$(( end - begin ))
echo -n $(date +%Y%m%d-%H%M%S) '[notice]' End trigger.' '
hours=$((duration / 3600)); minutes=$(( (duration % 3600) / 60 )); seconds=$(( (duration % 3600) % 60 ));
runtime=`printf "%02d:%02d:%02d" $hours $minutes $seconds`
echo -n Duration: $runtime; if [ $duration -gt 60 ];then echo -n " (${duration} seconds)"; fi; echo -n '.'; echo
EOF
    )
    string=$(sed -e "s,__HOST_PORT__,$host_port," -e "s,__GUEST_PORT__,$guest_port," <<< "$string" )
    echo "$string" > "$filename_string"
    fileMustExists "$filename_string"
fi
____

chapter Mengecek cronjob.
line='@reboot /usr/local/'"$basename_string"'.sh >> /var/log/'"$basename_string"'.log'
code '"'"$line"'"'
crontab=$(crontab -l | sed '/^#.*$/d')
notfound=
if grep -q -F "$line" <<< "$crontab"; then
    __ Cronjob ditemukan
else
    __ Cronjob tidak ditemukan
    notfound=1
fi
____

if [ -n "$notfound" ];then
    chapter Menambah cronjob.
    if [ -n "$is_cygwin" ];then
        crontab=$(crontab -l | sed '/^# DO NOT EDIT THIS FILE/,+2d')
    else
        crontab=$(crontab -l)
    fi
    (echo "$crontab"; echo "$line") | crontab -
    crontab=$(crontab -l | sed '/^#.*$/d')
    if grep -q -F "$line" <<< "$crontab"; then
        __; green Cronjob ditemukan; _.
    else
        __; red Cronjob tidak ditemukan; x
    fi
    ____
fi

chapter Dump crontab.
code crontab -l
_; _.
crontab -l;
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
# --host-port
# --guest-port
# )
# MULTIVALUE=(
# )
# FLAG_VALUE=(
# )
# EOF
# clear

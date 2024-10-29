#!/bin/bash

# Parse arguments. Generated by parse-options.sh
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
    echo '0.16.4'
}
printHelp() {
    title RCM Cron Setup
    _ 'Variation '; yellow WSL Autorun CROND; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-cron-setup-wsl-autorun-crond

Environment Variables:
   BASENAME
        Default to host-trigger-wsl-autorun-crond

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
   crontab
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Title.
title rcm-cron-setup-wsl-autorun-crond
____

# Dependency.
while IFS= read -r line; do
    [[ -z "$line" ]] || command -v `cut -d: -f1 <<< "${line}"` >/dev/null || { echo -e "\e[91m""Unable to proceed, "'`'"${line}"'`'" command not found." "\e[39m"; exit 1; }
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
BASENAME=${BASENAME:=host-trigger-wsl-autorun-crond}
code 'BASENAME="'$BASENAME'"'
case `uname` in
    CYGWIN*) is_cygwin=1 ;;
    *) is_cygwin= ;;
esac
code 'is_cygwin="'$is_cygwin'"'
delay=.5; [ -n "$fast" ] && unset delay
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

filename_string="/var/log/${BASENAME}.log"
chapter Mengecek file log '`'$filename_string'`'
isFileExists "$filename_string"
if [ -n "$notfound" ];then
    __ Membuat file.
    touch "$filename_string"
    fileMustExists "$filename_string"
fi
____

filename_string="/usr/local/${BASENAME}.sh"
chapter Mengecek shell script '`'$filename_string'`'
isFileExists "$filename_string"
if [ -n "$notfound" ];then
    __ Membuat file.
    mkdir -p $(dirname "$filename_string")
    touch "$filename_string"
    chmod a+x "$filename_string"
    cat << 'EOF' > "$filename_string"
#!/bin/bash
echo $(date +%Y%m%d-%H%M%S) '[notice]' Begin trigger.
begin=$SECONDS
PATH=/cygdrive/c/Windows/system32:$PATH
declare -i count
count=0
until [[ $(wsl --list --running --quiet | wc -l) -gt 0 ]]; do
    tempfile=$(mktemp)
    wsl -u root /etc/init.d/cron start 2>&1 >> "$tempfile"
    ifs="$IFS"
    while IFS= read line; do
        echo $(date +%Y%m%d-%H%M%S) '[debug] ' "$line"
    done < "$tempfile"
    IFS="$ifs"
    rm "$tempfile"
    count+=1
    if [ $count -eq 60 ];then
        echo $(date +%Y%m%d-%H%M%S) '[notice]' Timeout, wait a minute.
        echo $(date +%Y%m%d-%H%M%S) '[notice]' Command to stop this process: '`'kill $$'`'.
        sleep 59
        count=0
    fi
    sleep 1
done
end=$SECONDS
duration=$(( end - begin ))
echo -n $(date +%Y%m%d-%H%M%S) '[notice]' End trigger.' '
hours=$((duration / 3600)); minutes=$(( (duration % 3600) / 60 )); seconds=$(( (duration % 3600) % 60 ));
runtime=`printf "%02d:%02d:%02d" $hours $minutes $seconds`
echo -n Duration: $runtime; if [ $duration -gt 60 ];then echo -n " (${duration} seconds)"; fi; echo -n '.'; echo
EOF
    fileMustExists "$filename_string"
fi
____

chapter Mengecek cronjob.
line='@reboot /usr/local/'"$BASENAME"'.sh >> /var/log/'"$BASENAME"'.log'
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
e $'\n'; crontab -l

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
# MULTIVALUE=(
# )
# FLAG_VALUE=(
# )
# EOF
# clear

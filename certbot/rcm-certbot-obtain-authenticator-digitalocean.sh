#!/bin/bash

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --certbot-dns-digitalocean-sure) certbot_dns_digitalocean_sure=1; shift ;;
        --domain=*) domain+=("${1#*=}"); shift ;;
        --domain) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then domain+=("$2"); shift; fi; shift ;;
        --fast) fast=1; shift ;;
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
MAILBOX_HOST=${MAILBOX_HOST:=hostmaster}
TOKEN=${TOKEN:=[HOME]/.digitalocean-token.txt}
TOKEN_INI=${TOKEN_INI:=[HOME]/.digitalocean-token.ini}

# Functions.
printVersion() {
    echo '0.17.3'
}
printHelp() {
    title RCM Certbot Obtain
    _ 'Variation '; yellow Authenticator DigitalOcean; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << EOF
Usage: rcm-certbot-obtain-authenticator-digitalocean [options]

Options:
   --domain
        Set the domain. Multivalue.

Global Options:
   --fast
        No delay every subtask.
   --version
        Print version of this script.
   --help
        Show this help.
   --certbot-dns-digitalocean-sure
        Bypass certbot-dns-digitalocean checking.

Environment Variables:
   MAILBOX_HOST
        Default to $MAILBOX_HOST
   TOKEN
        Default to $TOKEN
   TOKEN_INI
        Default to $TOKEN_INI

Dependency:
   snap
   certbot
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Title.
title rcm-certbot-obtain-authenticator-digitalocean
____

[ "$EUID" -ne 0 ] && { error This script needs to be run with superuser privileges.; x; }

# Dependency.
while IFS= read -r line; do
    [[ -z "$line" ]] || command -v `cut -d: -f1 <<< "${line}"` >/dev/null || { error Unable to proceed, command not found: '`'`cut -d: -f1 <<< "${line}"`'`'.; x; }
done <<< `printHelp 2>/dev/null | sed -n '/^Dependency:/,$p' | sed -n '2,/^\s*$/p' | sed 's/^ *//g'`

# Functions.
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
Rcm_certbot() {
    # Global, untuk debug.
    local certbot_request line cache_file_basename
    local start end runtime line_number
    local expired="$1"
    local url="$2"
    local table=$HOME/.cache/rcm/rcm.table.cache
    local table_lock=$HOME/.cache/rcm/rcm.table.cache.lock
    local cache_file=
    local do_delete_record_cache_file=
    _Rcm_certbot() {
        if [ -f "$table" ];then
            # todo, cek jika multiline.
            line=$(grep -n -F "$url"' ' "$table")
            if [ -z "$line" ];then
                certbot_request=1
            else
                cache_file_basename=$(cut -d' ' -f2 <<< "$line")
                cache_file=$HOME/.cache/rcm/"$cache_file_basename"
            fi
        else
            certbot_request=1
        fi
        if [ -n "$cache_file" ];then
            if [ -f "$cache_file" ];then
                if [ -s "$cache_file" ];then
                    start=`date -r "$cache_file" +'%s'`
                    end=`date +%s`
                    runtime=$((end-start))
                    if [ $runtime -gt $expired ];then
                        do_delete_record_cache_file=1
                    fi
                else
                    do_delete_record_cache_file=1
                fi
            else
                do_delete_record_cache_file=1
            fi
        fi
        if [ -n "$do_delete_record_cache_file" ];then
            line_number=$(cut -d':' -f1 <<< "$line")
            sed -i $line_number'd' "$table"
            certbot_request=1
            if [ -f "$cache_file" ];then
                rm "$cache_file"
            fi
            cache_file=
        fi
        exit_code=0
        if [ -n "$certbot_request" ];then
            mkdir -p $HOME/.cache/rcm
            cache_file=$(mktemp --tmpdir=$HOME/.cache/rcm rcm.certbot.XXXXXXXXXXXX.cache)
            cache_file_basename=$(basename "$cache_file")
            certificate_name=$(sed 's|certbot://||' <<< "$url")
            msg='Another instance of Certbot is already running.'
            while true; do
                certbot certificates --cert-name="$certificate_name" 2>/dev/null > "$cache_file"
                exit_code=$?
                if [[ $(head -1 "$cache_file") == "$msg" ]];then
                    e Retrying...; _.
                    code sleep 3
                    sleep 3
                else
                    break
                fi
            done
            mkdir -p $(dirname "$table")
            echo "$url" "$cache_file_basename" >> "$table"
        fi
    }
    until [[ ! -e "$table_lock" ]];do
        sleep .1
        # Jika lebih dari 1 menit, maka hapus saja.
        start=`date -r "$table_lock" +'%s'`
        end=`date +%s`
        runtime=$((end-start))
        if [ $runtime -gt 60 ];then
            rm "$table_lock"
        fi
    done
    touch "$table_lock"
    _Rcm_certbot
    rm "$table_lock"
    if [ ! -f "$cache_file" ];then
        exit $exit_code
    fi
    if [ ! $exit_code -eq 0 ];then
        exit $exit_code
    fi
    cat "$cache_file"
}

# Require, validate, and populate value.
chapter Dump variable.
[ -n "$fast" ] && isfast=' --fast' || isfast=''
code 'MAILBOX_HOST="'$MAILBOX_HOST'"'
code 'TOKEN="'$TOKEN'"'
find='[HOME]'
replace="$HOME"
TOKEN="${TOKEN/"$find"/"$replace"}"
code 'TOKEN="'$TOKEN'"'
code 'TOKEN_INI="'$TOKEN_INI'"'
find='[HOME]'
replace="$HOME"
TOKEN_INI="${TOKEN_INI/"$find"/"$replace"}"
code 'TOKEN_INI="'$TOKEN_INI'"'
code 'domain=('"${domain[@]}"')'
if [[ "${#domain[@]}" -eq 0 ]];then
    error Argument --domain is required.; x
fi
vercomp `stat --version | head -1 | grep -o -E '\S+$'` 8.31
if [[ $? -lt 2 ]];then
    stat_cached=' --cached=never'
else
    stat_cached=''
fi
# domain pertama adalah Certificate Name.
certificate_name=${domain[0]}
code 'certificate_name="'$certificate_name'"'
tempfile=
____

if [ -z "$certbot_dns_digitalocean_sure" ];then
    chapter Mengecek apakah snap certbot-dns-digitalocean installed.
    notfound=
    if grep '^certbot-dns-digitalocean\s' <<< $(snap list certbot-dns-digitalocean);then
        __ Snap certbot-dns-digitalocean installed.
    else
        error Snap certbot-dns-digitalocean not found.; x
    fi
    ____
fi

chapter Populate variable email.
email=$(certbot show_account 2>/dev/null | grep -o -P 'Email contact: \K(.*)')
if [ -n "$email" ];then
    __ Certbot account has found: "$email"
else
    email="${MAILBOX_HOST}@${domain[0]}"
fi
code 'email="'$email'"'
____

chapter Mengecek Token.
isFileExists "$TOKEN"
if [ -n "$notfound" ];then
    error File '`'$TOKEN'`' tidak ditemukan.; x
fi
digitalocean_token=$(<$TOKEN)
__; magenta 'digitalocean_token="'$digitalocean_token'"'; _.
isFileExists "$TOKEN_INI"
if [ -n "$notfound" ];then
    __ Membuat file "$TOKEN_INI"
    cat << EOF > "$TOKEN_INI"
dns_digitalocean_token = $digitalocean_token
EOF
    fileMustExists "$TOKEN_INI"
fi
if [[ $(stat "$TOKEN_INI" -c %a) == 600 ]];then
    __ File  '`'"$TOKEN_INI"'`' memiliki permission '`'600'`'.
else
    __ File  '`'"$TOKEN_INI"'`' tidak memiliki permission '`'600'`'.
    tweak=1
fi
if [ -n "$tweak" ];then
    chmod 600 "$TOKEN_INI"
    if [[ $(stat ${stat_cached} "$TOKEN_INI" -c %a) == 600 ]];then
        __; green File  '`'"$TOKEN_INI"'`' memiliki permission '`'600'`'.; _.
    else
        __; red File  '`'"$TOKEN_INI"'`' tidak memiliki permission '`'600'`'.; x
    fi
fi
____

chapter Obtain Certificate.
arguments=()
for each in "${domain[@]}"; do
    arguments+=(--domain "$each")
done
set -- "${arguments[@]}"
if [ -z "$tempfile" ];then
    tempfile=$(mktemp -p /dev/shm -t rcm-certbot-obtain-authenticator-digitalocean.XXXXXX)
    deletetempfile=1
fi
# https://eff-certbot.readthedocs.io/en/latest/using.html#combination
msg='Another instance of Certbot is already running.'
while true; do
    code certbot -v certonly --non-interactive --agree-tos --email="$email" \
        --dns-digitalocean --dns-digitalocean-credentials="$TOKEN_INI" "$@"
    certbot -v certonly --non-interactive --agree-tos --email="$email" \
        --dns-digitalocean --dns-digitalocean-credentials="$TOKEN_INI" "$@" 2>&1 | tee "$tempfile"
    if [[ $(head -1 "$tempfile") == "$msg" ]];then
        e Retrying...; _.
        code sleep 3
        sleep 3
    else
        break
    fi
done
____

chapter Verifikasi Certificate.
code certbot certificates --cert-name='"'"$certificate_name"
# Verifikasi terutama jika exit code tidak 0.
# Tidak perlu pakai cache.
if Rcm_certbot 0 "certbot://${certificate_name}" 2>/dev/null | tee "$tempfile" | grep -q -F 'Certificate Name: ';then
    while IFS= read -r line; do e "$line"; _.; done < $tempfile
else
    error Error has been occurred. The certificate has not found.
    [ -n "$deletetempfile" ] && rm "$tempfile"
    x
fi
____

[ -n "$deletetempfile" ] && rm "$tempfile"

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
# --certbot-dns-digitalocean-sure
# )
# VALUE=(
# )
# MULTIVALUE=(
# --domain
# )
# FLAG_VALUE=(
# )
# CSV=(
# )
# EOF
# clear

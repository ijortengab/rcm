#!/bin/bash

# Parse arguments. Generated by parse-options.sh
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --additional-config-file=*) additional_config_file="${1#*=}"; shift ;;
        --additional-config-file) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then additional_config_file="$2"; shift; fi; shift ;;
        --fast) fast=1; shift ;;
        --fqdn=*) fqdn="${1#*=}"; shift ;;
        --fqdn) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then fqdn="$2"; shift; fi; shift ;;
        --non-interactive) non_interactive=1; shift ;;
        --root-sure) root_sure=1; shift ;;
        --ssl-cert=*) ssl_cert="${1#*=}"; shift ;;
        --ssl-cert) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then ssl_cert="$2"; shift; fi; shift ;;
        --ssl-key=*) ssl_key="${1#*=}"; shift ;;
        --ssl-key) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then ssl_key="$2"; shift; fi; shift ;;
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
_() { echo -n "$INDENT" >&2; echo -n "#"' ' >&2; [ -n "$1" ] && echo "$@" >&2; }
_,() { echo -n "$@" >&2; }
_.() { echo >&2; }
__() { echo -n "$INDENT" >&2; echo -n "#" '    ' >&2; [ -n "$1" ] && echo "$@" >&2; }
___() { echo -n "$INDENT" >&2; echo -n "#" '        ' >&2; [ -n "$1" ] && echo "$@" >&2 || echo -n  >&2; }
____() { echo >&2; [ -n "$delay" ] && sleep "$delay"; }

# Define variables.
POSTFIX_CONFIG_DIR=${POSTFIX_CONFIG_DIR:=/etc/postfix}
POSTFIX_CONFIG_FILE_MAIN=${POSTFIX_CONFIG_FILE_MAIN:=${POSTFIX_CONFIG_DIR}/main.cf}

# Functions.
printVersion() {
    echo '0.16.14'
}
printHelp() {
    title RCM Postfix Multiple Certificate
    _ 'Variation '; yellow Default; _, . ; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << EOF
Usage: rcm-postfix-multiple-certificate [options]

Reference:
 - https://serverfault.com/questions/928926/postfix-multi-domains-and-multi-certs-on-one-ip
 - https://serverfault.com/questions/920436/set-up-certs-for-multiple-domains-in-postfix-and-dovecot
 - https://www.postfix.org/announcements/postfix-3.4.0.html

Options:
   --fqdn *
        The FQDN of certificate to be added.
   --ssl-cert *
        Fullpath of SSL Certificate chain.
   --ssl-key *
        Fullpath of SSL Certificate private key.
   --additional-config-file *
        Extra file to store the list of FQDN.

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
   POSTFIX_CONFIG_DIR
        Default to $POSTFIX_CONFIG_DIR
   POSTFIX_CONFIG_FILE_MAIN
        Default to $POSTFIX_CONFIG_FILE_MAIN

Dependency:
   postconf
   postmap
   systemctl
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Title.
title rcm-postfix-multiple-certificate
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
findString() {
    # global debug
    # global find_quoted
    # $find_quoted agar bisa di gunakan oleh sed.
    local find="$1" string path="$2" tempfile="$3" deletetempfile
    if [ -z "$tempfile" ];then
        tempfile=$(mktemp -p /dev/shm)
        deletetempfile=1
    fi
    _; _, ' 'Memeriksa baris dengan kalimat: '`'$find'`'.;_.
    find_quoted="$find"
    find_quoted=$(sed -E "s/\s+/\\\s\+/g" <<< "$find_quoted")
    find_quoted=$(sed "s/\./\\\./g" <<< "$find_quoted")
    find_quoted=$(sed "s/\*/\\\*/g" <<< "$find_quoted")
    find_quoted=$(sed "s/;$/\\\s\*;/g" <<< "$find_quoted")
    if [[ ! "${find_quoted:0:1}" == '^' ]];then
        find_quoted="^\s*${find_quoted}"
    fi
    _; magenta grep -E '"'"${find_quoted}"'"' '"'"\$path"'"'
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
ArrayDiff() {
    local e
    local source=("${!1}")
    local reference=("${!2}")
    _return=()
    # inArray is alternative of ArraySearch.
    inArray () {
        local e match="$1"
        shift
        for e; do [[ "$e" == "$match" ]] && return 0; done
        return 1
    }
    if [[ "${#reference[@]}" -gt 0 ]];then
        for e in "${source[@]}";do
            if ! inArray "$e" "${reference[@]}";then
                _return+=("$e")
            fi
        done
    else
        _return=("${source[@]}")
    fi
}
verifyKey() {
    local key=$1
    local output=$2
    case "$key" in
        smtpd_tls_chain_files)
            value=$(echo "$output" | sed -E 's|^(.*)\s*=\s*(.*)\s*$|\2|')
            if [ -n "$value" ];then
                IFS=',' read -ra _array <<< "$value"
                array=(); for each in "${_array[@]}"; do array+=($each); done # Trim whitespace.
                references=(/etc/postfix/smtpd.key /etc/postfix/smtpd.cert)
                ArrayDiff references[@] array[@]
                if [ "${#_return[@]}" -eq 0 ];then
                    return 0
                fi
            fi
            ;;
        tls_server_sni_maps)
            if [[ "$output" == "tls_server_sni_maps = hash:${additional_config_file}" ]];then
                return 0
            fi
            ;;
        *)
            value=$(echo "$output" | sed -E 's|'"$find_quoted"'(.*)|\1|')
            read -ra _array -d '' <<< "$value"
            array=(); for each in "${_array[@]}"; do array+=($each); done # Trim whitespace.
            references=($ssl_key $ssl_cert)
            ArrayDiff references[@] array[@]
            if [ "${#_return[@]}" -eq 0 ];then
                return 0
            fi
    esac
    return 1
}

# Require, validate, and populate value.
chapter Dump variable.
code 'POSTFIX_CONFIG_DIR="'$POSTFIX_CONFIG_DIR'"'
code 'POSTFIX_CONFIG_FILE_MAIN="'$POSTFIX_CONFIG_FILE_MAIN'"'
if [ -z "$additional_config_file" ];then
    error "Argument --additional-config-file required."; x
fi
code 'additional_config_file="'$additional_config_file'"'
if [ -z "$fqdn" ];then
    error "Argument --fqdn required."; x
fi
code 'fqdn="'$fqdn'"'
if [ -z "$ssl_cert" ];then
    error "Argument --ssl-cert required."; x
fi
code 'ssl_cert="'$ssl_cert'"'
if [ -z "$ssl_key" ];then
    error "Argument --ssl-key required."; x
fi
code 'ssl_key="'$ssl_key'"'
[ -f "$ssl_cert" ] || fileMustExists "$ssl_cert"
[ -f "$ssl_key" ] || fileMustExists "$ssl_key"
# Exit code sama-sama bernilai 0 pada unknown parameter, sehingga perlu kita gunakan output.
tempfile_error=$(mktemp -p /dev/shm -t rcm-postfix-multiple-certificate.XXXXXX)
tempfile_output=$(mktemp -p /dev/shm -t rcm-postfix-multiple-certificate.XXXXXX)
____

restart=
for key in smtpd_tls_cert_file smtpd_tls_key_file; do
    chapter Memastikan key '`'$key'`' disabled.
    postconf -n $key 2> $tempfile_error > $tempfile_output
    error="$(<"$tempfile_error")"
    if [ -n "$error" ];then
        error "$error"; rm $tempfile_error; rm $tempfile_output; x
    fi
    output="$(<"$tempfile_output")"
    if [ -n "$output" ];then
        e "$output"; _.
        __ Key '`'$key'`' is enable. Try to disabled.
        code "postconf -# ${key}"
        postconf -# $key
        restart=1
    else
        __ Key '`'$key'`' has been disabled.
    fi
    ____
done

key=smtpd_tls_chain_files
chapter Memastikan key '`'$key'`' enabled.
path="${POSTFIX_CONFIG_DIR}/smtpd.key"
[ -f $path ] || fileMustExists $path
path="${POSTFIX_CONFIG_DIR}/smtpd.cert"
[ -f $path ] || fileMustExists $path
postconf -n $key 2> $tempfile_error > $tempfile_output
error="$(<"$tempfile_error")"
if [ -n "$error" ];then
    error "$error"; rm $tempfile_error; rm $tempfile_output; x
fi
output="$(<"$tempfile_output")"
found=
if [ -n "$output" ];then
    __ Key ditemukan.
    e "$output"; _.
    __ Verifikasi.
    if verifyKey "$key" "$output";then
        found=1
        __ Key ditemukan, dan value cocok.
    else
        __ Key ditemukan, namun value tidak cocok.
        __ Disable and create new one.
        code "postconf -# ${key}"
        postconf -# $key
    fi
fi
if [ -z "$found" ];then
    __ Append value of key '`'$key'`'
    cat << EOF >> "$POSTFIX_CONFIG_FILE_MAIN"
$key =
 ${POSTFIX_CONFIG_DIR}/smtpd.key,
 ${POSTFIX_CONFIG_DIR}/smtpd.cert
EOF
    __ Verifikasi.
    if verifyKey "$key" "$(postconf -n $key)";then
        __ Verifikasi berhasil.
        restart=1
    else
        error Verifikasi gagal.; rm $tempfile_error; rm $tempfile_output; x
    fi
fi
____

key=tls_server_sni_maps
chapter Memastikan key '`'$key'`' enabled.
path="${additional_config_file}"
code 'path="'$path'"'
postconf -n $key 2> $tempfile_error > $tempfile_output
error="$(<"$tempfile_error")"
if [ -n "$error" ];then
    error "$error"; rm $tempfile_error; rm $tempfile_output; x
fi
output="$(<"$tempfile_output")"
found=
if [ -n "$output" ];then
    __ Key ditemukan.
    e "$output"; _.
    __ Verifikasi.
    if verifyKey "$key" "$output";then
        found=1
        __ Key ditemukan, dan value cocok.
    else
        __ Key ditemukan, namun value tidak cocok.
        __ Disable and create new one.
        code "postconf -# ${key}"
        postconf -# $key
    fi
fi
if [ -z "$found" ];then
    __ Set value of key '`'$key'`'
    postconf "${key}=hash:${path}"
    __ Verifikasi.
    if verifyKey "$key" "$(postconf -n $key)";then
        __ Verifikasi berhasil.
        restart=1
    else
        error Verifikasi gagal.; rm $tempfile_error; rm $tempfile_output; x
    fi
fi
____

path="${additional_config_file}"
filename=$(basename "$path")
chapter Mengecek file '`'$filename'`'.
code path='"'$path'"'
isFileExists "$path"
____

# Saat ini tidak support untuk format multiline. Contoh:
# ```
# drupal.id
#  /etc/letsencrypt/live/drupal.id/privkey.pem
#  /etc/letsencrypt/live/drupal.id/fullchain.pem
# ```
# Multiline akan dianggap false.
# @todo support multiline.
if [ -n "$found" ];then
    chapter Mengecek fqdn '`'$fqdn'`'.
    code path='"'$path'"'
	if findString "^${fqdn} " "$path" "$tempfile_output";then
        __ Verifikasi.
        if verifyKey - "$(<"$tempfile_output")";then
            __ Key ditemukan, dan value cocok.
        else
            notfound=1
            __ Key ditemukan, namun value tidak cocok.
            __ Disable and create new one.
            code sed -i -E "'"'s|'"'"'"'"$find_quoted"'"'"'"'.*|# \0|'"'" "$path"
            sed -i -E 's|'"$find_quoted"'.*|# \0|' "$path"
        fi
    else
		notfound=1
	fi
	____
fi
if [ -n "$notfound" ];then
    chapter Menambah FQDN '`'$fqdn'`' ke file '`'$filename'`'.
    dirname=$(dirname "$path")
    code mkdir -p '"'$dirname'"'
    mkdir -p "$dirname"
    cat << EOF >> "$path"
${fqdn} ${ssl_key} ${ssl_cert}
EOF
	__ Melakukan verifikasi.
	if ! findString "${fqdn} ${ssl_key} ${ssl_cert}" "$path";then
        error Gagal menambahkan.; rm $tempfile_error; rm $tempfile_output; x
	fi
	__; green Berhasil ditambahkan; _.
    code postmap -F hash:"$path"
    postmap -F hash:"$path"
	restart=1
	____
fi

if [ -n "$restart" ];then
    chapter Restart postfix.
    code systemctl restart postfix
    systemctl restart postfix
    ____
fi

rm $tempfile_error
rm $tempfile_output

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
# --non-interactive
# )
# VALUE=(
# --fqdn
# --ssl-cert
# --ssl-key
# --additional-config-file
# )
# MULTIVALUE=(
# )
# FLAG_VALUE=(
# )
# CSV=(
# )
# EOF
# clear

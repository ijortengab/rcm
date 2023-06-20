#!/bin/bash

# Prerequisite.
[ -f "$0" ] || { echo -e "\e[91m" "Cannot run as dot command. Hit Control+c now." "\e[39m"; read; exit 1; }

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

# Functions.
[[ $(type -t RcmPostfixSetupIspconfig_printVersion) == function ]] || RcmPostfixSetupIspconfig_printVersion() {
    echo '0.1.1'
}
[[ $(type -t RcmPostfixSetupIspconfig_printHelp) == function ]] || RcmPostfixSetupIspconfig_printHelp() {
    cat << EOF
RCM Postfix Setup
Variation ISPConfig
Version `RcmPostfixSetupIspconfig_printVersion`

EOF
    cat << 'EOF'
Usage: rcm-postfix-setup-ispconfig.sh [options]

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
   POSTFIX_CONFIG_FILE
        Default to /etc/postfix/master.cf

Dependency:
   systemctl
EOF
}

# Help and Version.
[ -n "$help" ] && { RcmPostfixSetupIspconfig_printHelp; exit 1; }
[ -n "$version" ] && { RcmPostfixSetupIspconfig_printVersion; exit 1; }

# Dependency.
while IFS= read -r line; do
    command -v "${line}" >/dev/null || { echo -e "\e[91m""Unable to proceed, ${line} command not found." "\e[39m"; exit 1; }
done <<< `RcmPostfixSetupIspconfig_printHelp | sed -n '/^Dependency:/,$p' | sed -n '2,/^$/p' | sed 's/^ *//g'`

# Common Functions.
[[ $(type -t red) == function ]] || red() { echo -ne "\e[91m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
[[ $(type -t green) == function ]] || green() { echo -ne "\e[92m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
[[ $(type -t yellow) == function ]] || yellow() { echo -ne "\e[93m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
[[ $(type -t blue) == function ]] || blue() { echo -ne "\e[94m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
[[ $(type -t magenta) == function ]] || magenta() { echo -ne "\e[95m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
[[ $(type -t error) == function ]] || error() { echo -n "$INDENT" >&2; red "$@" >&2; echo >&2; }
[[ $(type -t success) == function ]] || success() { echo -n "$INDENT" >&2; green "$@" >&2; echo >&2; }
[[ $(type -t chapter) == function ]] || chapter() { echo -n "$INDENT" >&2; yellow "$@" >&2; echo >&2; }
[[ $(type -t title) == function ]] || title() { echo -n "$INDENT" >&2; blue "$@" >&2; echo >&2; }
[[ $(type -t code) == function ]] || code() { echo -n "$INDENT" >&2; magenta "$@" >&2; echo >&2; }
[[ $(type -t x) == function ]] || x() { echo >&2; exit 1; }
[[ $(type -t e) == function ]] || e() { echo -n "$INDENT" >&2; echo "$@" >&2; }
[[ $(type -t _) == function ]] || _() { echo -n "$INDENT" >&2; echo -n "$@" >&2; }
[[ $(type -t _,) == function ]] || _,() { echo -n "$@" >&2; }
[[ $(type -t _.) == function ]] || _.() { echo >&2; }
[[ $(type -t __) == function ]] || __() { echo -n "$INDENT" >&2; echo -n '    ' >&2; [ -n "$1" ] && echo "$@" >&2 || echo -n  >&2; }
[[ $(type -t ____) == function ]] || ____() { echo >&2; [ -n "$delay" ] && sleep "$delay"; }

# Functions.

[[ $(type -t downloadApplication) == function ]] || downloadApplication() {
    local aptnotfound=
    chapter Melakukan instalasi aplikasi "$@".
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
[[ $(type -t validateApplication) == function ]] || validateApplication() {
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
[[ $(type -t backupFile) == function ]] || backupFile() {
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
[[ $(type -t ArraySearch) == function ]] || ArraySearch() {
    local index match="$1"
    local source=("${!2}")
    for index in "${!source[@]}"; do
       if [[ "${source[$index]}" == "${match}" ]]; then
           _return=$index; return 0
       fi
    done
    return 1
}
[[ $(type -t ArrayDiff) == function ]] || ArrayDiff() {
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
[[ $(type -t ArrayIntersect) == function ]] || ArrayIntersect() {
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
            if inArray "$e" "${reference[@]}";then
                _return+=("$e")
            fi
        done
    else
        _return=("${source[@]}")
    fi
}
[[ $(type -t postfixConfigEditor) == function ]] || postfixConfigEditor() {
    # global modified append_contents
    # global used POSTFIX_CONFIG_FILE reference_contents
    local mode=$1
    append_contents=
    # Rules 1. Cleaning line start with hash (#).
    local input_contents=$(sed -e '/^\s*#.*$/d' -e '/^\s*$/d' <"$POSTFIX_CONFIG_FILE")
    while IFS= read -r line; do
        reference_list_services_headonly=$(grep -v -E "^[[:blank:]]+" <<< "$reference_contents")
    done <<< "$reference_contents"
    while IFS= read -r reference_each_service_headonly; do
        reference_each_service_headonly_simple_space=$(sed -E 's,\s+, ,g' <<< "$reference_each_service_headonly")
        __ Mengecek service: "$reference_each_service_headonly_simple_space"
        reference_each_service_headonly_quoted=$(sed -E "s,\s+,\\\s+,g" <<< "$reference_each_service_headonly") # pregQuoteSpace
        count=0
        # Grep new line. Credit: https://stackoverflow.com/a/49192452
        input_each_service_fullbody_multiple=$(grep -zoP '(^|\n)'"$reference_each_service_headonly_quoted"'.*(\n[\s]+.*)+' <<< "$input_contents" | xargs -0 | sed '/^\s*$/d')
        input_each_service_fullbody_flatty_multiple=
        # Replace new line. Credit: https://unix.stackexchange.com/a/114948
        [ -n "$input_each_service_fullbody_multiple" ] && {
            input_each_service_fullbody_flatty_multiple=$(sed -E ':a;N;$!ba;s/\n\s+/ /g'  <<< "$input_each_service_fullbody_multiple")
            count=$(cat <<< "$input_each_service_fullbody_flatty_multiple" | wc -l)
        }
        __ Menemukan $count baris.
        if [ $count -eq 0 ];then
            reference_each_service_fullbody=$(grep -zoP '(^|\n)'"$reference_each_service_headonly_quoted"'.*(\n[\s]+.*)+' <<< "$reference_contents" | xargs -0 | sed '/^\s*$/d')
            append_contents+="$reference_each_service_fullbody"$'\n'
            continue
        fi
        # Rules 3. Bisa jadi terdapat lebih dari satu kali. Kita ambil yang paling bawah.
        input_each_service_fullbody_flatty=$(tail -1 <<< "$input_each_service_fullbody_flatty_multiple")
        input_each_service_argumentsonly_flatty=$(sed -E -e "s/$reference_each_service_headonly_quoted//" <<< "$input_each_service_fullbody_flatty")
        # Populate array of keys and value from input.
        input_each_service_list_arguments=$(grep -oP '\s+-o\s+\K([^\s]+)' <<< "$input_each_service_argumentsonly_flatty" )
        input_each_service_list_arguments_keys=()
        input_each_service_list_arguments_values=()
        while IFS= read -r each; do
            if [[ $each = *" "* ]];then # Skip contain space
                continue;
            fi
            if grep -q -E '^[^=]+=.*' <<< "$each";then
                _key=$(echo "$each" | cut -d'=' -f 1)
                _value=$(echo "$each" | cut -d'=' -f 2)
                input_each_service_list_arguments_keys+=("$_key")
                input_each_service_list_arguments_values+=("$_value")
            fi
        done <<< "$input_each_service_list_arguments"
        reference_each_service_fullbody=$(grep -zoP '(^|\n)'"$reference_each_service_headonly_quoted"'.*(\n[\s]+.*)+' <<< "$reference_contents" | xargs -0)
        reference_each_service_fullbody_flatty=$(sed -E ':a;N;$!ba;s/\n\s+/ /g'  <<< "$reference_each_service_fullbody")
        reference_each_service_argumentsonly_flatty=$(sed -E -e "s/$reference_each_service_headonly_quoted//" <<< "$reference_each_service_fullbody_flatty" )
        # Populate array of keys and value from reference.
        reference_each_service_list_arguments=$(grep -oP '\s+-o\s+\K([^\s]+)' <<< "$reference_each_service_argumentsonly_flatty" )
        reference_each_service_list_arguments_keys=()
        reference_each_service_list_arguments_values=()
        while IFS= read -r each; do
            if [[ $each = *" "* ]];then # Skip contian space
                continue;
            fi
            if grep -q -E '^[^=]+=.*' <<< "$each";then
                _key=$(echo "$each" | cut -d'=' -f 1)
                _value=$(echo "$each" | cut -d'=' -f 2)
                reference_each_service_list_arguments_keys+=("$_key")
                reference_each_service_list_arguments_values+=("$_value")
            fi
        done <<< "$reference_each_service_list_arguments"
        ArrayDiff reference_each_service_list_arguments_keys[@] input_each_service_list_arguments_keys[@]
        array_diff_result=("${_return[@]}"); unset _return # Clear karena parameter akan digunakan lagi oleh ArraySearch.
        ArrayIntersect reference_each_service_list_arguments_keys[@] input_each_service_list_arguments_keys[@]
        array_intersect_result=("${_return[@]}"); unset _return # Clear karena parameter akan digunakan lagi oleh ArraySearch.
        is_modified=
        if [ "${#array_diff_result[@]}" -gt 0 ];then
            is_modified=1
            for each in "${array_diff_result[@]}"; do
                ArraySearch "$each" reference_each_service_list_arguments_keys[@]
                reference_key="$_return"; unset _return; # Clear.
                reference_value="${reference_each_service_list_arguments_values[$reference_key]}"
                input_each_service_list_arguments_keys+=("$each")
                input_each_service_list_arguments_values+=("$reference_value")
            done
        fi
        if [ "${#array_intersect_result[@]}" -gt 0 ];then
            for each in "${array_intersect_result[@]}"; do
                ArraySearch "$each" reference_each_service_list_arguments_keys[@]
                reference_key="$_return"; unset _return; # Clear.
                reference_value="${reference_each_service_list_arguments_values[$reference_key]}"
                ArraySearch "$each" input_each_service_list_arguments_keys[@]
                input_key="$_return"; unset _return; # Clear.
                input_value="${input_each_service_list_arguments_values[$input_key]}"
                if [[ ! "$reference_value" == "$input_value" ]];then
                    is_modified=1
                    input_each_service_list_arguments_values[$input_key]="$reference_value"
                fi
            done
        fi
        if [ -n "$is_modified" ];then
            append_contents+="$reference_each_service_headonly"$'\n'
            for ((i = 0 ; i < ${#input_each_service_list_arguments_keys[@]} ; i++)); do
                key="${input_each_service_list_arguments_keys[$i]}"
                value="${input_each_service_list_arguments_values[$i]}"
                append_contents+="  -o ${key}=${value}"$'\n'
            done
        fi
    done <<< "$reference_list_services_headonly"
    if [[ $mode == 'is_different' && -n "$append_contents" ]];then
        return 0
    fi
    return 1
}

# Title.
title RCM Postfix Setup
_ 'Variation '; yellow ISPConfig; _.
_ 'Version '; yellow `RcmPostfixSetupIspconfig_printVersion`; _.
____

# Requirement, validate, and populate value.
chapter Dump variable.
POSTFIX_CONFIG_FILE=${POSTFIX_CONFIG_FILE:=/etc/postfix/master.cf}
code 'POSTFIX_CONFIG_FILE="'$POSTFIX_CONFIG_FILE'"'
____

if [ -z "$root_sure" ];then
    chapter Mengecek akses root.
    if [[ "$EUID" -ne 0 ]]; then
        error This script needs to be run with superuser privileges.; x
    else
        __ Privileges.; root_sure=1
    fi
    ____
fi

application=
application+=' postfix-mysql postfix-doc'
application+=' dovecot-core dovecot-imapd dovecot-pop3d dovecot-mysql dovecot-sieve dovecot-lmtpd'
application+=' getmail6 amavisd-new postgrey spamassassin'
downloadApplication $application
validateApplication $application
____

chapter Mengecek UnitFileState service SpamAssassin. # Menginstall PHP di Debian, biasanya auto install juga SpamAssassin.
msg=$(systemctl show spamassassin.service --no-page | grep UnitFileState | grep -o -P "UnitFileState=\K(\S+)")
disable=
if [[ -z "$msg" ]];then
    __ UnitFileState service SpamAssassin not found.
elif [[ "$msg"  == 'enabled' ]];then
    __ UnitFileState service SpamAssassin enabled.
    disable=1
else
    __ UnitFileState service SpamAssassin: $msg.
fi
____

if [ -n "$disable" ];then
    chapter Mematikan service SpamAssassin.
    code systemctl disable --now spamassassin
    systemctl disable --now spamassassin
    msg=$(systemctl show spamassassin.service --no-page | grep UnitFileState | grep -o -P "UnitFileState=\K(\S+)")
    if [[ $msg == 'disabled' ]];then
        __; green Berhasil disabled.; _.
    else
        __; red Gagal disabled.; _.
        __ UnitFileState state: $msg.
        exit
    fi
    ____
fi

# Reference: http://www.postfix.org/master.5.html
# SYNTAX
# The general format of the master.cf file is as follows:
# 1. Empty  lines and whitespace-only lines are ignored, as are lines
#    whose first non-whitespace character is a `#'.
# 2. A logical line starts with  non-whitespace  text.  A  line  that
#    starts with whitespace continues a logical line.
# 3. Each  logical  line defines a single Postfix service.  Each ser-
#    vice is identified by its name  and  type  as  described  below.
#    When multiple lines specify the same service name and type, only
#    the last one is remembered.  Otherwise, the order  of  master.cf
#    service definitions does not matter.
#
# Source: https://github.com/servisys/ispconfig_setup/blob/master/distros/debian11/install_postfix.sh
# service    type private unpriv chroot wakeup maxproc command + args
# submission inet n       -      y      -      -       smtpd
reference_contents=$(cat << 'EOF'
submission inet n       -       y       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_tls_auth_only=yes
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
smtps     inet  n       -       y       -       -       smtpd
  -o syslog_name=postfix/smtps
  -o smtpd_tls_wrappermode=yes
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
EOF
)

chapter Mengecek konfigurasi Postfix.
is_different=
if postfixConfigEditor is_different;then
    is_different=1
    __ Diperlukan modifikasi file '`'$POSTFIX_CONFIG_FILE'`'.
else
    __ File '`'$POSTFIX_CONFIG_FILE'`' tidak ada perubahan.
fi
____

if [ -n "$is_different" ];then
    chapter Memodifikasi file '`'$POSTFIX_CONFIG_FILE'`'.
    __ Backup file $POSTFIX_CONFIG_FILE
    backupFile copy $POSTFIX_CONFIG_FILE
    echo "$append_contents" >> $POSTFIX_CONFIG_FILE
    if postfixConfigEditor is_different;then
        __; red Modifikasi file '`'$POSTFIX_CONFIG_FILE'`' gagal.; x
    else
        __; green Modifikasi file '`'$POSTFIX_CONFIG_FILE'`' berhasil.; _.
        __; magenta systemctl restart postfix; _.
        systemctl restart postfix
    fi
    ____
fi

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
# CSV=(
# )
# EOF
# clear

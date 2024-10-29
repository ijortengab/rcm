#!/bin/bash

# Parse arguments. Generated by parse-options.sh
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --domain=*) domain="${1#*=}"; shift ;;
        --domain) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then domain="$2"; shift; fi; shift ;;
        --fast) fast=1; shift ;;
        --hostname=*) hostname="${1#*=}"; shift ;;
        --hostname) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then hostname="$2"; shift; fi; shift ;;
        --hostname-origin=*) hostname_origin="${1#*=}"; shift ;;
        --hostname-origin) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then hostname_origin="$2"; shift; fi; shift ;;
        --ip-address=*) ip_address="${1#*=}"; shift ;;
        --ip-address) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then ip_address="$2"; shift; fi; shift ;;
        --mail-provider=*) mail_provider="${1#*=}"; shift ;;
        --mail-provider) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then mail_provider="$2"; shift; fi; shift ;;
        --name-exists-sure) name_exists_sure=1; shift ;;
        --name-server=*) name_server="${1#*=}"; shift ;;
        --name-server) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then name_server="$2"; shift; fi; shift ;;
        --reverse) reverse=1; shift ;;
        --root-sure) root_sure=1; shift ;;
        --type=*) type="${1#*=}"; shift ;;
        --type) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then type="$2"; shift; fi; shift ;;
        --value=*) value="${1#*=}"; shift ;;
        --value) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then value="$2"; shift; fi; shift ;;
        --value-summarize=*) value_summarize="${1#*=}"; shift ;;
        --value-summarize) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then value_summarize="$2"; shift; fi; shift ;;
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
    title RCM Dig Is Record Exists
    _ 'Variation '; yellow Default; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-dig-is-record-exists [command] [options]

Options:
   --domain *
        Domain name to be checked.
   --type
        Available value: a, cname, mx, txt.
   --ip-address
        Set the IP Address of A record.
   --hostname
        Set the hostname.
   --hostname-origin
        Set the source alias of CNAME record.
   --mail-provider
        Set the Mail Provider of MX record.
   --value
        Set the value of TXT record.
   --value-summarize
        Set the summarize value of TXT record. Just for notification.
   --name-server
        Set the Name server. Default value is - (dash). Available values: [1], [2], or other.
        [1]: 8.8.8.8
        [2]: 1.1.1.1

Global Options:
   --fast
        No delay every subtask.
   --version
        Print version of this script.
   --help
        Show this help.
   --root-sure
        Bypass root checking.
   --reverse
        Reverse the result.
   --name-exists-sure
        Bypass domain exists checking.

Dependency:
   dig
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Title.
title rcm-dig-is-record-exists
____

# Dependency.
while IFS= read -r line; do
    [[ -z "$line" ]] || command -v `cut -d: -f1 <<< "${line}"` >/dev/null || { error Unable to proceed, command not found: '`'$line'`'.; x; }
done <<< `printHelp 2>/dev/null | sed -n '/^Dependency:/,$p' | sed -n '2,/^\s*$/p' | sed 's/^ *//g'`

# Functions.
# Global Used: add_name_server, tempfile.
isRecordExist() {
    local type="$1" found name_dot name_dot_escape
    local data_escape stdout
    local domain="$2"
    local name="$3"
    local data="$4"
    [ -n "$5" ] && tempfile="$5" || tempfile=$(mktemp -p /dev/shm -t rcm-dig-is-record-exists.XXXXXX)
    if [ "$data" == '@' ];then
        data="$domain"
    fi
    code dig "$type" $name${add_name_server}
    dig "$type" $name $add_name_server | tee "$tempfile"
    name_dot="${name}."
    name_dot_escape=${name_dot//\./\\.}
    stdout=$(<"$tempfile")
    case "$type" in
        TXT)
            if grep -q -E --ignore-case ^"$name_dot_escape"'\s+''[0-9]+''\s+'IN'\s+'"$type"'\s+'\".*\" <<< "$stdout";then
                echo "$stdout" | grep -E --ignore-case ^"$name_dot_escape"'\s+''[0-9]+''\s+'IN'\s+'"$type"'\s+'\".*\" > "$tempfile"
                stdout=$(<"$tempfile")
                php=$(cat <<-'EOF'
$data = $_SERVER['argv'][1];
echo '"'.implode('" "', str_split($data, 255)).'"';
EOF
                )
                data=$(php -r "$php" "$data" )
                if grep -q -F "$data" <<< "$stdout";then
                    return 0
                else
                    return 1
                fi
            else
                return 1
            fi
            ;;
        *)
            data_escape=${data//\./\\.}
            data_escape=${data_escape//\*/\.*}
            data_escape=${data_escape//\ /\\ }
            code grep -E --ignore-case "'"^"$name_dot_escape"'\s+''[0-9]+''\s+'IN'\s+'"$type"'\s+'"$data_escape""'"
            if grep -q -E --ignore-case ^"$name_dot_escape"'\s+''[0-9]+''\s+'IN'\s+'"$type"'\s+'"$data_escape" <<< "$stdout";then
                return 0
            fi
            return 1
            ;;
    esac
}

# Require, validate, and populate value.
chapter Dump variable.
delay=.5; [ -n "$fast" ] && unset delay
[ -n "$fast" ] && isfast=' --fast' || isfast=''
if [ -z "$domain" ];then
    error "Argument --domain required."; x
fi
code 'domain="'$domain'"'
code 'name_server="'$name_server'"'
if [[ "$name_server" == - ]];then
    name_server=
fi
[ -n "$name_server" ] && option_name_server=' --name-server='"$name_server" || option_name_server=''
[ -n "$name_server" ] && add_name_server=' @'"$name_server" || add_name_server=''
[ -n "$name_server" ] && label_name_server=' in DNS '"$name_server" || label_name_server=''
if [ -z "$type" ];then
    error "Argument --type required."; x
fi
case "$type" in
    a|cname|txt|mx) ;;
    *) type=
esac
if [ -z "$type" ];then
    error "Argument --type is not valid.";
    _ Available value:' '; yellow a; _, ', '; yellow cname; _, ', '; yellow mx; _, ', '; yellow txt; _, .; _.
    x
fi
code 'type="'$type'"'
type_uppercase=${type^^}
case "$type" in
    a)
        if [ -z "$ip_address" ];then
            error "Argument --ip-address required"; x
        fi
        ;;
    mx)
        if [ -z "$mail_provider" ];then
            error "Argument --mail-provider required"; x
        fi
        ;;
    cname)
        if [ -z "$hostname" ];then
            error "Argument --hostname required"; x
        fi
        ;;
    txt)
        if [ -z "$hostname" ];then
            error "Argument --hostname required"; x
        fi
        if [ -z "$value" ];then
            error "Argument --value required"; x
        fi
        ;;
esac
code 'type_uppercase="'$type_uppercase'"'
code 'ip_address="'$ip_address'"'
code 'hostname="'$hostname'"'
code 'mail_provider="'$mail_provider'"'
code 'value="'$value'"'
code 'value_summarize="'$value_summarize'"'
____

if [ -z "$name_exists_sure" ];then
    INDENT+="    " \
    rcm-dig-is-name-exists $isfast --root-sure \
        --domain="$domain" \
        $option_name_server \
        ; [ ! $? -eq 0 ] && x
fi

record_found=
if [[ "$type" == a ]];then
    data="$ip_address"
    [ -z "$hostname" ] && hostname=@
    [[ "$hostname" == '@' ]] && fqdn_string="$domain" || fqdn_string="${hostname}.${domain}"
    chapter Query "$type_uppercase" Record for FQDN '`'${fqdn_string}'`'
    if isRecordExist "$type_uppercase" "$domain" "$fqdn_string" "$data" "$mktemp";then
        record_found=1
        log="${type_uppercase} Record of "'`'"${fqdn_string}"'`'" point to IP "'`'"${ip_address}"'`'" FOUND${label_name_server}."
    else
        log="${type_uppercase} Record of "'`'"${fqdn_string}"'`'" point to IP "'`'"${ip_address}"'`'" NOT FOUND${label_name_server}."
    fi
    ____
fi
if [[ "$type" == cname ]];then
    data='@'
    datadot='@'
    [ -n "$hostname_origin" ] && {
        data="$hostname_origin"
        datadot="$data".
    }
    [ -n "$hostname_origin" ] && alias_to="$hostname_origin" || alias_to="$domain"
    [[ "$hostname" == @ ]] && fqdn_string="$domain" || fqdn_string="${hostname}.${domain}"
    chapter Query "$type_uppercase" Record for FQDN '`'${fqdn_string}'`'
    if isRecordExist "$type_uppercase" "$domain" "$fqdn_string" "$data" "$mktemp";then
        record_found=1
        log="${type_uppercase} Record of "'`'"${fqdn_string}"'`'" alias to "'`'"${alias_to}"'`'" FOUND${label_name_server}."
    else
        log="${type_uppercase} Record of "'`'"${fqdn_string}"'`'" alias to "'`'"${alias_to}"'`'" NOT FOUND${label_name_server}."
    fi
    ____
fi
if [[ "$type" == mx ]];then
    data="* $mail_provider"
    [ -z "$hostname" ] && hostname=@
    datadot="$data".
    [[ "$hostname" == '@' ]] && fqdn_string="$domain" || fqdn_string="${hostname}.${domain}"
    chapter Query "$type_uppercase" Record for FQDN '`'${fqdn_string}'`'
    if isRecordExist "$type_uppercase" "$domain" "$fqdn_string" "$data" "$mktemp";then
        record_found=1
        log="${type_uppercase} Record of "'`'"${fqdn_string}"'`'" handled by "'`'"${mail_provider}"'`'" FOUND${label_name_server}."
    else
        log="${type_uppercase} Record of "'`'"${fqdn_string}"'`'" handled by "'`'"${mail_provider}"'`'" NOT FOUND${label_name_server}."
    fi
    ____
fi
if [[ "$type" == txt ]];then
    data="$value"
    [[ "$hostname" == '@' ]] && fqdn_string="$domain" || fqdn_string="${hostname}.${domain}"
    chapter Query "$type_uppercase" Record for FQDN '`'${fqdn_string}'`'
    if isRecordExist "$type_uppercase" "$domain" "$fqdn_string" "$data" "$mktemp";then
        record_found=1
        log="${type_uppercase} Record of "'`'"${fqdn_string}"'`'" about "'`'"${value_summarize}"'`'" FOUND${label_name_server}."
    else
        log="${type_uppercase} Record of "'`'"${fqdn_string}"'`'" about "'`'"${value_summarize}"'`'" NOT FOUND${label_name_server}."
    fi
    ____
fi

chapter Result
rm "$tempfile"
if [ -n "$record_found" ];then
    result='success'
    if [ -n "$reverse" ];then
        result='error'
    fi
    $result "$log"
else
    result='error'
    if [ -n "$reverse" ];then
        result='success'
    fi
    $result "$log"
fi

[ "$result" == error ] && x
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
# --name-exists-sure
# --reverse
# )
# VALUE=(
# --domain
# --ip-address
# --type
# --hostname
# --hostname-origin
# --mail-provider
# --value
# --value-summarize
# --name-server
# )
# FLAG_VALUE=(
# )
# CSV=(
# )
# EOF
# clear

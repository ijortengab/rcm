#!/bin/bash

# Parse arguments. Generated by parse-options.sh
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --digitalocean-domain-exists-sure) digitalocean_domain_exists_sure=1; shift ;;
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

# Command.
command="$1"; shift
if [ -n "$command" ];then
    case "$command" in
        add|delete) ;;
        *) echo -e "\e[91m""Command ${command} is unknown.""\e[39m"; exit 1
    esac
fi

# Functions.
printVersion() {
    echo '0.12.0'
}
printHelp() {
    title RCM DigitalOcean API
    _ 'Variation '; yellow Manage Domain Record; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-digitalocean-api-manage-domain-record [command] [options]

Available commands: add, delete.

Options:
   --domain
        Set the domain to add or delete.
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
   --digitalocean-domain-exists-sure ^
        Bypass domain exists checking.

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
   php
   curl
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
isDomainExists() {
    local domain=$1 code
    local dumpfile=$2
    [ -z "$dumpfile" ] && dumpfile=$(mktemp -t digitalocean.XXXXXX)
    __; magenta "curl https://api.digitalocean.com/v2/domains/$domain"; _.
    code=$(curl -X GET \
        -H "Authorization: Bearer $digitalocean_token" \
        -o "$dumpfile" -s -w "%{http_code}\n" \
        "https://api.digitalocean.com/v2/domains/$domain")
    sleep .2 # Delay
    json=$(<"$dumpfile")
    json_pretty=$(php -r "echo json_encode(json_decode(fgets(STDIN)), JSON_PRETTY_PRINT).PHP_EOL;" <<< "$json")
    __ Standard Output.
    magenta "$json_pretty"; _.
    if [[ $code == 200 ]];then
        return 0
    elif [[ $code == 404 ]];then
        return 1
    fi
    error Unexpected result with response code: $code.; x
}
isRecordExist() {
    local type="$1" php json json_pretty
    local domain="$2"
    local name="$3"
    local data="$4"
    local dumpfile="$5"
    [ -z "$dumpfile" ] && dumpfile=$(mktemp -t digitalocean.XXXXXX)
    __; magenta "curl https://api.digitalocean.com/v2/domains/$domain/records?type=$type&name=$name"; _.
    code=$(curl -X GET \
        -o "$dumpfile" -s -w "%{http_code}\n" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $digitalocean_token" \
        "https://api.digitalocean.com/v2/domains/$domain/records?type=$type&name=$name")
    sleep .2 # Delay
    json=$(<"$dumpfile")
    json_pretty=$(php -r "echo json_encode(json_decode(fgets(STDIN)), JSON_PRETTY_PRINT).PHP_EOL;" <<< "$json")
    __ Standard Output.
    magenta "$json_pretty"; _.
    if [[ ! $code == 200 ]];then
        error Unexpected result with response code: $code.; x
    fi
    php=$(cat <<-'EOF'
$object = json_decode(fgets(STDIN));
$data = $_SERVER['argv'][1];
if (is_object($object) && isset($object->domain_records)) {
    foreach ($object->domain_records as $domain_record) {
        if ($domain_record->data == $data) {
            exit(0);
        }
    }
}
exit(1);
EOF
)
    php -r "$php" "$data" <<< "$json"
    return $?
}
insertRecord() {
    if [[ ! "$command" == add ]];then
        return 1
    fi
    local type="$1" domain="$2" name="$3" reference code
    local data="$4"
    local dumpfile="$5"
    [ -z "$dumpfile" ] && dumpfile=$(mktemp -t digitalocean.XXXXXX)
    local priority=NULL
    [[ $type == 'MX' ]] && priority=10
    reference="$(php -r "echo json_encode([
        'type' => '$type',
        'name' => '$name',
        'data' => '$data',
        'priority' => $priority,
        'port' => NULL,
        'ttl' => 1800,
        'weight' => NULL,
        'flags' => NULL,
        'tag' => NULL,
    ]);")"
    __; magenta "curl -X POST -d '$reference' https://api.digitalocean.com/v2/domains/records"; _.
    code=$(curl -X POST \
        -H "Authorization: Bearer $digitalocean_token" \
        -H "Content-Type: application/json" \
        -o "$dumpfile" -s -w "%{http_code}\n" \
        -d "$reference" \
        "https://api.digitalocean.com/v2/domains/$domain/records")
    sleep .2 # Delay
    json=$(<"$dumpfile")
    json_pretty=$(php -r "echo json_encode(json_decode(fgets(STDIN)), JSON_PRETTY_PRINT).PHP_EOL;" <<< "$json")
    __ Standard Output.
    magenta "$json_pretty"; _.
    if [[ $code == 201 ]];then
        return 0
    fi
    error Unexpected result with response code: $code.; x
}
deleteRecord() {
    local domain="$1" id="$2"
    local dumpfile="$3"
    [ -z "$dumpfile" ] && dumpfile=$(mktemp -t digitalocean.XXXXXX)
    __; magenta "curl -X DELETE https://api.digitalocean.com/v2/domains/$domain/records/$id"; _.
    code=$(curl -X DELETE \
        -H "Authorization: Bearer $digitalocean_token" \
        -H "Content-Type: application/json" \
        -o "$dumpfile" -s -w "%{http_code}\n" \
        "https://api.digitalocean.com/v2/domains/$domain/records/$id")
    sleep .2 # Delay
    json=$(<"$dumpfile")
    json_pretty=$(php -r "echo json_encode(json_decode(fgets(STDIN)), JSON_PRETTY_PRINT).PHP_EOL;" <<< "$json")
    __ Standard Output.
    magenta "$json_pretty"; _.
    if [[ $code == 204 ]];then
        return 0
    fi
    error Unexpected result with response code: $code.; x
}
getIdRecords() {
    local mktemp="$1"
    json=$(<"$mktemp")
    php=$(cat <<-'EOF'
$object = json_decode(fgets(STDIN));
if (isset($object->meta->total) && $object->meta->total > 0) {
    foreach ($object->domain_records as $each) {
        echo $each->id."\n";
    }
}
EOF
)
    php -r "$php" <<< "$json"
}

# Title.
title rcm-digitalocean-api-manage-domain-record
____

# Require, validate, and populate value.
chapter Dump variable.
TOKEN=${TOKEN:=$HOME/.digitalocean-token.txt}
code 'TOKEN="'$TOKEN'"'
code 'digitalocean_domain_exists_sure="'$digitalocean_domain_exists_sure'"'
case "$type" in
    a|cname|txt|mx) ;;
    *) type=
esac
until [[ -n "$type" ]];do
    _ Available value:' '; yellow a, cname, mx, txt.; _.
    _; read -p "Argument --type required: " type
    case "$type" in
        a|cname|txt|mx) ;;
        *) type=
    esac
done
code 'type="'$type'"'
type_uppercase=${type^^}
case "$type" in
    a)
        until [[ -n "$ip_address" ]];do
            _; read -p "Argument --ip-address required: " ip_address
        done
        ;;
    mx)
        until [[ -n "$mail_provider" ]];do
            _; read -p "Argument --mail-provider required: " mail_provider
        done
        ;;
    cname)
        until [[ -n "$hostname" ]];do
            _; read -p "Argument --hostname required: " hostname
        done
        ;;
    txt)
        until [[ -n "$hostname" ]];do
            _; read -p "Argument --hostname required: " hostname
        done
        until [[ -n "$value" ]];do
            _; read -p "Argument --value required: " value
        done
        ;;
esac
code 'type_uppercase="'$type_uppercase'"'
if [ -z "$domain" ];then
    error "Argument --domain required."; x
fi
code 'domain="'$domain'"'
code 'ip_address="'$ip_address'"'
code 'hostname="'$hostname'"'
code 'mail_provider="'$mail_provider'"'
code 'value="'$value'"'
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

chapter Mengecek Token
fileMustExists "$TOKEN"
digitalocean_token=$(<$TOKEN)
__; magenta 'digitalocean_token="'$digitalocean_token'"'; _.
____

if [ -z "$digitalocean_domain_exists_sure" ];then
    chapter Query DNS Record for Domain '`'${domain}'`'
    if isDomainExists $domain;then
        __ Domain '`'"$domain"'`' found in DNS Digital Ocean.
    else
        __; red Domain '`'"$domain"'`' not found in DNS Digital Ocean.; x
    fi
    ____
fi

if [[ "$command" == delete ]];then
    mktemp=$(mktemp -t digitalocean.XXXXXX)
else
    mktemp=
fi
record_found=
if [[ $type == a ]];then
    data="$ip_address"
    [ -z "$hostname" ] && hostname=@
    [[ "$hostname" == '@' ]] && fqdn_string="$domain" || fqdn_string="${hostname}.${domain}"
    chapter Query $type_uppercase Record for FQDN '`'${fqdn_string}'`'
    if isRecordExist $type_uppercase $domain $fqdn_string $data $mktemp;then
        record_found=1
        __ DNS $type_uppercase Record of '`'${fqdn_string}'`' point to IP '`'${ip_address}'`' found in DNS Digital Ocean.
    elif insertRecord $type_uppercase $domain "$hostname" $data;then
        __; green DNS $type_uppercase Record of '`'${fqdn_string}'`' point to IP '`'${ip_address}'`' created in DNS Digital Ocean.; _.
    fi
    ____
fi
if [[ $type == cname ]];then
    data='@'
    datadot='@'
    [ -n "$hostname_origin" ] && {
        data="$hostname_origin"
        datadot="$data".
    }
    [ -n "$hostname_origin" ] && alias_to="$hostname_origin" || alias_to="$domain"
    fqdn_string="${hostname}.${domain}"
    chapter Query $type_uppercase Record for FQDN '`'${fqdn_string}'`'
    if isRecordExist $type_uppercase $domain $fqdn_string $data $mktemp;then
        record_found=1
        __ DNS $type_uppercase Record of '`'$fqdn_string'`' alias to '`'${alias_to}'`' found in DNS Digital Ocean.
    elif insertRecord $type_uppercase $domain "$hostname" "$datadot";then
        __; green DNS $type_uppercase Record of '`'$fqdn_string'`' alias to '`'${alias_to}'`' created in DNS Digital Ocean.; _.
    fi
    ____
fi
if [[ $type == mx ]];then
    data="$mail_provider"
    # {
        # "id": "unprocessable_entity",
        # "message": "Data needs to end with a dot (.)",
        # "request_id": "5cbdf147-e0de-476c-870f-95aa76d9b360"
    # }
    # Unexpected result with response code: 422.
    datadot="$data".
    [[ "$hostname" == '@' ]] && fqdn_string="$domain" || fqdn_string="${hostname}.${domain}"
    chapter Query $type_uppercase Record for FQDN '`'${fqdn_string}'`'
    if isRecordExist $type_uppercase $domain $fqdn_string "$data" $mktemp;then
        record_found=1
        __ DNS $type_uppercase Record of '`'$fqdn_string'`' handled by '`'${mail_provider}'`' found in DNS Digital Ocean.
    elif insertRecord $type_uppercase $domain "$hostname" "$datadot";then
        __; green DNS $type_uppercase Record of '`'$fqdn_string'`' handled by '`'${mail_provider}'`' created in DNS Digital Ocean.; _.
    fi
    ____
fi
if [[ $type == txt ]];then
    data="$value"
    [[ "$hostname" == '@' ]] && fqdn_string="$domain" || fqdn_string="${hostname}.${domain}"
    chapter Query $type_uppercase Record for FQDN '`'${fqdn_string}'`'
    if isRecordExist $type_uppercase $domain $fqdn_string "$data" $mktemp;then
        record_found=1
        __; _, DNS $type_uppercase Record of '`'$fqdn_string'`' found in DNS Digital Ocean.
        [ -n "$value_summarize" ] && _, ' The value is about '"$value_summarize".; _.;
    elif insertRecord $type_uppercase $domain "$hostname" "$data";then
        __; green DNS $type_uppercase Record of '`'$fqdn_string'`' created in DNS Digital Ocean.
        [ -n "$value_summarize" ] && _, ' The value is about '"$value_summarize".; _.;
    fi
    ____
fi
if [[ "$command" == delete && -n "$record_found" ]];then
    while IFS= read -r line; do
        __ Delete record id "$line" of domain "$domain"
        if deleteRecord $domain $line;then
            __; green DNS $type_uppercase Record of '`'"$hostname"'`' from '`'${domain}'`' deleted in DNS Digital Ocean.; _.
        fi
    done <<< $(getIdRecords "$mktemp")
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
# --root-sure
# --digitalocean-domain-exists-sure
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
# )
# FLAG_VALUE=(
# )
# CSV=(
# )
# EOF
# clear

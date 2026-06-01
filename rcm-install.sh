#!/bin/bash

# Rapid Construct Massive
#
# (c) IjorTengab <ijortengab@systemix.id> <ijortengab@gmail.com>
#
# https://github.com/ijortengab/rcm
#
# Command to download: `wget git.io/rcm`
#
RCM_EXTENSION_VERSION=0.19.0-alpha.4

# Usage Functions.
usage() {
    cat << EOF
Usage: rcm-install [options]
       rcm-install <extension> [extension-version] [options]

Options:
    --extension *
        The name of extenstion to install.
    --url
        The URL of Repository.
    --extension-version
        The version of extenstion. Default value is \`latest\`.
    --path
        Path to the script from root of repository.
        Default value is rcm/rcm-[--extension].sh

Other options (For expert only):
    --source
        The extension as a source to read the value of URL.

Global Options:
   --version
        Print version of this script.
   --help
        Show this help.
   --verbose, -v
        Verbose mode. Causes rcm to print debugging messages about its progress.
        Multiple -v options increase the verbosity.
        The maximum is 3.

Environment Variables:
   BINARY_DIRECTORY
        Default to $BINARY_DIRECTORY

RCM Config:
   --no-timer
   --no-confirmation

Mapping Operand:
   --extension
   --extension-version

Download:
   [rcm-composer-autoinstaller](https://github.com/ijortengab/rcm/raw/master/composer/rcm-composer-autoinstaller.sh)
   [rcm-cron-setup-wsl-autorun-crond](https://github.com/ijortengab/rcm/raw/master/cron/rcm-cron-setup-wsl-autorun-crond.sh)
   [rcm-cron-setup-wsl-autorun-sshd](https://github.com/ijortengab/rcm/raw/master/cron/rcm-cron-setup-wsl-autorun-sshd.sh)
   [rcm-cron-setup-wsl-port-forwarding](https://github.com/ijortengab/rcm/raw/master/cron/rcm-cron-setup-wsl-port-forwarding.sh)
   [rcm-debian-11-setup-basic](https://github.com/ijortengab/rcm/raw/master/debian/rcm-debian-11-setup-basic.sh)
   [rcm-debian-12-setup-basic](https://github.com/ijortengab/rcm/raw/master/debian/rcm-debian-12-setup-basic.sh)
   [rcm-dig-apt](https://github.com/ijortengab/rcm/raw/master/dig/rcm-dig-apt.sh)
   [rcm-dig-has-address](https://github.com/ijortengab/rcm/raw/master/dig/rcm-dig-has-address.sh)
   [rcm-dig-is-name-exists](https://github.com/ijortengab/rcm/raw/master/dig/rcm-dig-is-name-exists.sh)
   [rcm-dig-is-record-exists](https://github.com/ijortengab/rcm/raw/master/dig/rcm-dig-is-record-exists.sh)
   [rcm-dig-watch-domain-exists](https://github.com/ijortengab/rcm/raw/master/dig/rcm-dig-watch-domain-exists.sh)
   [rcm-dovecot-multiple-certificate](https://github.com/ijortengab/rcm/raw/master/dovecot/rcm-dovecot-multiple-certificate.sh)
   [rcm-exec](https://github.com/ijortengab/rcm/raw/master/rcm-exec.sh)
   [rcm-get](https://github.com/ijortengab/rcm/raw/master/rcm-get.sh)
   [rcm-install](https://github.com/ijortengab/rcm/raw/master/rcm-install.sh)
   [rcm-mariadb-apt](https://github.com/ijortengab/rcm/raw/master/mariadb/rcm-mariadb-apt.sh)
   [rcm-mariadb-assign-grant-all](https://github.com/ijortengab/rcm/raw/master/mariadb/rcm-mariadb-assign-grant-all.sh)
   [rcm-mariadb-database-autocreate](https://github.com/ijortengab/rcm/raw/master/mariadb/rcm-mariadb-database-autocreate.sh)
   [rcm-mariadb-setup-project-database](https://github.com/ijortengab/rcm/raw/master/mariadb/rcm-mariadb-setup-project-database.sh)
   [rcm-mariadb-user-autocreate](https://github.com/ijortengab/rcm/raw/master/mariadb/rcm-mariadb-user-autocreate.sh)
   [rcm-nginx-apt](https://github.com/ijortengab/rcm/raw/master/nginx/rcm-nginx-apt.sh)
   [rcm-nginx-reload](https://github.com/ijortengab/rcm/raw/master/nginx/rcm-nginx-reload.sh)
   [rcm-nginx-setup-front-controller-php](https://github.com/ijortengab/rcm/raw/master/nginx/rcm-nginx-setup-front-controller-php.sh)
   [rcm-nginx-setup-hello-world-static](https://github.com/ijortengab/rcm/raw/master/nginx/rcm-nginx-setup-hello-world-static.sh)
   [rcm-nginx-setup-php-project](https://github.com/ijortengab/rcm/raw/master/nginx/rcm-nginx-setup-php-project.sh)
   [rcm-nginx-setup-static](https://github.com/ijortengab/rcm/raw/master/nginx/rcm-nginx-setup-static.sh)
   [rcm-nginx-variables-export](https://github.com/ijortengab/rcm/raw/master/nginx/rcm-nginx-variables-export.sh)
   [rcm-nginx-virtual-host-autocreate-php-multiple-root](https://github.com/ijortengab/rcm/raw/master/nginx/rcm-nginx-virtual-host-autocreate-php-multiple-root.sh)
   [rcm-nginx-virtual-host-autocreate-php](https://github.com/ijortengab/rcm/raw/master/nginx/rcm-nginx-virtual-host-autocreate-php.sh)
   [rcm-paragraph](https://github.com/ijortengab/rcm/raw/master/rcm-paragraph.sh)
   [rcm-php-apt](https://github.com/ijortengab/rcm/raw/master/php/rcm-php-apt.sh)
   [rcm-php-fpm-setup-project-config](https://github.com/ijortengab/rcm/raw/master/php/rcm-php-fpm-setup-project-config.sh)
   [rcm-php-setup-adjust-cli-version](https://github.com/ijortengab/rcm/raw/master/php/rcm-php-setup-adjust-cli-version.sh)
   [rcm-phpmyadmin-autoinstaller-nginx](https://github.com/ijortengab/rcm/raw/master/phpmyadmin/rcm-phpmyadmin-autoinstaller-nginx.sh)
   [rcm-plugin](https://github.com/ijortengab/rcm/raw/master/rcm-plugin.sh)
   [rcm-postfix-apt](https://github.com/ijortengab/rcm/raw/master/postfix/rcm-postfix-apt.sh)
   [rcm-postfix-multiple-certificate](https://github.com/ijortengab/rcm/raw/master/postfix/rcm-postfix-multiple-certificate.sh)
   [rcm-resolve](https://github.com/ijortengab/rcm/raw/master/rcm-resolve.sh)
   [rcm-roundcube-autoinstaller-nginx](https://github.com/ijortengab/rcm/raw/master/roundcube/rcm-roundcube-autoinstaller-nginx.sh)
   [rcm-ssh-setup-open-ssh-tunnel](https://github.com/ijortengab/rcm/raw/master/ssh/rcm-ssh-setup-open-ssh-tunnel.sh)
   [rcm-ssh-setup-sshd-listen-port](https://github.com/ijortengab/rcm/raw/master/ssh/rcm-ssh-setup-sshd-listen-port.sh)
   [rcm-system-ram-swap-4gb](https://github.com/ijortengab/rcm/raw/master/system/rcm-system-ram-swap-4gb.sh)
   [rcm-ubuntu-22.04-setup-basic](https://github.com/ijortengab/rcm/raw/master/ubuntu/rcm-ubuntu-22.04-setup-basic.sh)
   [rcm-ubuntu-24.04-setup-basic.sh)(https://github.com/ijortengab/rcm/raw/master/ubuntu/rcm-ubuntu-24.04-setup-basic.sh)
   [rcm-update](https://github.com/ijortengab/rcm/raw/master/rcm-update.sh)
   [rcm-wsl-setup-lemp-stack](https://github.com/ijortengab/rcm/raw/master/wsl/rcm-wsl-setup-lemp-stack.sh)
EOF
}

[ -f "${RCM_LIB}/require.sh" ] && source "${RCM_LIB}/require.sh" || { usage >&2; exit 1; }

# Parse arguments. Generated by parse-options.sh
_new_arguments=()
_n=
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --extension=*) extension="${1#*=}"; shift ;;
        --extension) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then extension="$2"; shift; fi; shift ;;
        --extension-version=*) extension_version="${1#*=}"; shift ;;
        --extension-version) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then extension_version="$2"; shift; fi; shift ;;
        --path=*) path="${1#*=}"; shift ;;
        --path) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then path="$2"; shift; fi; shift ;;
        --quiet|-q) quiet=1; shift ;;
        --source=*) source="${1#*=}"; shift ;;
        --source) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then source="$2"; shift; fi; shift ;;
        --url=*) url="${1#*=}"; shift ;;
        --url) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then url="$2"; shift; fi; shift ;;
        --verbose|-v) verbose="$((verbose+1))"; shift ;;
        --)
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    *) _new_arguments+=("$1"); shift ;;
                esac
            done
            ;;
        --[^-]*) shift ;;
        *) _new_arguments+=("$1"); shift ;;
    esac
done
set -- "${_new_arguments[@]}"
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -[^-]*) OPTIND=1
            while getopts ":qv" opt; do
                case $opt in
                    q) quiet=1 ;;
                    v) verbose="$((verbose+1))" ;;
                esac
            done
            _n="$((OPTIND-1))"
            _n=${!_n}
            shift "$((OPTIND-1))"
            if [[ "$_n" == '--' ]];then
                while [[ $# -gt 0 ]]; do
                    case "$1" in
                        *) _new_arguments+=("$1"); shift ;;
                    esac
                done
            fi
            ;;
        --) shift
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    *) _new_arguments+=("$1"); shift ;;
                esac
            done
            ;;
        *) _new_arguments+=("$1"); shift ;;
    esac
done
set -- "${_new_arguments[@]}"
unset _new_arguments
unset _n

# Define variables and constants.
BINARY_DIRECTORY=${BINARY_DIRECTORY:=[__DIR__]}
# If not set in argument, try load from environment.
[ -z "$verbose" ] && verbose="$RCM_VERBOSE"
# If quiet set in argument, override the verbose.
[ -n "$quiet" ] && verbose=0
# The default of verbose is debug.
[ -z "$verbose" ] && verbose=3
RCM_TLD_SPECIAL=${RCM_TLD_SPECIAL:=example test onion invalid local localhost alt}
quiet=; loud=; louder=; debug=;
[[ -z "$verbose" || "$verbose" -lt 1 ]] && quiet=1 || quiet=
[[ "$verbose" -gt 0 ]] && loud=1
[[ "$verbose" -gt 1 ]] && loud=1 && louder=1
[[ "$verbose" -gt 2 ]] && loud=1 && louder=1 && debug=1
# If set in environment, set to variable.
[ -n "$RCM_TABLE_DOWNLOADS" ] && table_downloads="$RCM_TABLE_DOWNLOADS"

# Help and Version.
[ -n "$help" ] && { usage; exit 0; }
[ -n "$version" ] && { e $RCM_EXTENSION_VERSION; x; }

# Functions before execute command.
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
link_symbolic() {
    local source="$1"
    local target="$2"
    local sudo="$3"
    local source_mode="$4"
    local create
    [ "$sudo" == - ] && sudo=
    [ "$source_mode" == absolute ] || source_mode=
    [ -e "$source" ] || { error Source not exist: $source.; x; }
    [ -f "$source" ] || { error Source exists but not file: $source.; x; }
    [ -n "$target" ] || { error Target not defined.; x; }
    [[ $(type -t backupFile) == function ]] || { error Function backupFile not found.; x; }
    [[ $(type -t backupDir) == function ]] || { error Function backupDir not found.; x; }
    chapter Membuat symbolic link.
    __ source: '`'$source'`'
    __ target: '`'$target'`'
    if [ -f "$target" ];then
        if [ -h "$target" ];then
            __ Path target saat ini sudah merupakan file symbolic link: '`'$target'`'
            local _readlink=$(readlink "$target")
            __; magenta readlink "$target"; _.
            _ $_readlink; _.
            if [[ "$_readlink" =~ ^[^/\.] ]];then
                local target_parent=$(dirname "$target")
                local _dereference="${target_parent}/${_readlink}"
            elif [[ "$_readlink" =~ ^[\.] ]];then
                local target_parent=$(dirname "$target")
                local _dereference="${target_parent}/${_readlink}"
                _dereference=$(realpath -s "$_dereference")
            else
                _dereference="$_readlink"
            fi
            __; _, Mengecek apakah link merujuk ke '`'$source'`':' '
            if [[ "$source" == "$_dereference" ]];then
                _, merujuk.; _.
            else
                _, tidak merujuk.; _.
                __ Melakukan backup.
                backupFile move "$target"
                create=1
            fi
        else
            __ Melakukan backup regular file: '`'"$target"'`'.
            backupFile move "$target"
            create=1
        fi
    elif [ -d "$target" ];then
        __ Melakukan backup direktori: '`'"$target"'`'.
        backupDir "$target"
        create=1
    else
        create=1
    fi
    if [ -n "$create" ];then
        __ Membuat symbolic link: '`'$target'`'.
        local target_parent=$(dirname "$target")
        code mkdir -p "$target_parent"
        mkdir -p "$target_parent"
        if [ -z "$source_mode" ];then
            source=$(realpath -s --relative-to="$target_parent" "$source")
        fi
        if [ -n "$sudo" ];then
            code sudo -u '"'$sudo'"' ln -s '"'$source'"' '"'$target'"'
            sudo -u "$sudo" ln -s "$source" "$target"
        else
            code ln -s '"'$source'"' '"'$target'"'
            ln -s "$source" "$target"
        fi
        if [ $? -eq 0 ];then
            __; green Symbolic link berhasil dibuat.; _.
        else
            __; red Symbolic link gagal dibuat.; x
        fi
    fi
    ____
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
backupDir() {
    local oldpath="$1" i newpath
    # Trim trailing slash.
    oldpath=$(echo "$oldpath" | sed -E 's|/+$||g')
    i=1
    newpath="${oldpath}.${i}"
    if [ -e "$newpath" ]; then
        let i++
        newpath="${oldpath}.${i}"
        while [ -e "$newpath" ] ; do
            let i++
            newpath="${oldpath}.${i}"
        done
    fi
    mv "$oldpath" "$newpath"
}

# Define variables and constants.
__FILE__=$(resolve_relative_path "$0")
__DIR__=$(dirname "$__FILE__")
find='[__DIR__]'
replace="$__DIR__"
BINARY_DIRECTORY="${BINARY_DIRECTORY/"$find"/"$replace"}"

# ------------------------------------------------------------------------------

# Title.
title rcm-install
____

# Functions.
ArraySearch() {
    local index match="$1"
    local source=("${!2}")
    for index in "${!source[@]}"; do
       if [[ "${source[$index]}" == "${match}" ]]; then
           _return=$index; return 0
       fi
    done
    return 1
}
Rcm_parse_url() {
    # Reset
    PHP_URL_SCHEME=
    PHP_URL_HOST=
    PHP_URL_PORT=
    PHP_URL_USER=
    PHP_URL_PASS=
    PHP_URL_PATH=
    PHP_URL_QUERY=
    PHP_URL_FRAGMENT=
    PHP_URL_SCHEME="$(echo "$1" | grep :// | sed -e's,^\(.*\)://.*,\1,g')"
    _PHP_URL_SCHEME_SLASH="${PHP_URL_SCHEME}://"
    _PHP_URL_SCHEME_REVERSE="$(echo ${1/${_PHP_URL_SCHEME_SLASH}/})"
    if grep -q '#' <<< "$_PHP_URL_SCHEME_REVERSE";then
        PHP_URL_FRAGMENT=$(echo $_PHP_URL_SCHEME_REVERSE | cut -d# -f2)
        _PHP_URL_SCHEME_REVERSE=$(echo $_PHP_URL_SCHEME_REVERSE | cut -d# -f1)
    fi
    if grep -q '\?' <<< "$_PHP_URL_SCHEME_REVERSE";then
        PHP_URL_QUERY=$(echo $_PHP_URL_SCHEME_REVERSE | cut -d? -f2)
        _PHP_URL_SCHEME_REVERSE=$(echo $_PHP_URL_SCHEME_REVERSE | cut -d? -f1)
    fi
    _PHP_URL_USER_PASS="$(echo $_PHP_URL_SCHEME_REVERSE | grep @ | cut -d@ -f1)"
    PHP_URL_PASS=`echo $_PHP_URL_USER_PASS | grep : | cut -d: -f2`
    if [ -n "$PHP_URL_PASS" ]; then
        PHP_URL_USER=`echo $_PHP_URL_USER_PASS | grep : | cut -d: -f1`
    else
        PHP_URL_USER=$_PHP_URL_USER_PASS
    fi
    _PHP_URL_HOST_PORT="$(echo ${_PHP_URL_SCHEME_REVERSE/$_PHP_URL_USER_PASS@/} | cut -d/ -f1)"
    PHP_URL_HOST="$(echo $_PHP_URL_HOST_PORT | sed -e 's,:.*,,g')"
    if grep -q -E ':[0-9]+$' <<< "$_PHP_URL_HOST_PORT";then
        PHP_URL_PORT="$(echo $_PHP_URL_HOST_PORT | sed -e 's,^.*:,:,g' -e 's,.*:\([0-9]*\).*,\1,g' -e 's,[^0-9],,g')"
    fi
    _PHP_URL_HOST_PORT_LENGTH=${#_PHP_URL_HOST_PORT}
    _LENGTH="$_PHP_URL_HOST_PORT_LENGTH"
    if [ -n "$_PHP_URL_USER_PASS" ];then
        _PHP_URL_USER_PASS_LENGTH=${#_PHP_URL_USER_PASS}
        _LENGTH=$((_LENGTH + 1 + _PHP_URL_USER_PASS_LENGTH))
    fi
    PHP_URL_PATH="${_PHP_URL_SCHEME_REVERSE:$_LENGTH}"

    # Debug
    # e '"$PHP_URL_SCHEME"' "$PHP_URL_SCHEME"
    # e '"$PHP_URL_HOST"' "$PHP_URL_HOST"
    # e '"$PHP_URL_PORT"' "$PHP_URL_PORT"
    # e '"$PHP_URL_USER"' "$PHP_URL_USER"
    # e '"$PHP_URL_PASS"' "$PHP_URL_PASS"
    # e '"$PHP_URL_PATH"' "$PHP_URL_PATH"
    # e '"$PHP_URL_QUERY"' "$PHP_URL_QUERY"
    # e '"$PHP_URL_FRAGMENT"' "$PHP_URL_FRAGMENT"
}
urlCompleteComponent() {
    local tld_special _url_port _tld _url_path_correct
    [[ $(type -t Rcm_parse_url) == function ]] || { error Function Rcm_parse_url not found.; x; }
    [[ $(type -t ArraySearch) == function ]] || { error Function ArraySearch not found.; x; }
    [[ -n "$url" ]] || { error Global variable url is not found or empty value.; x; }
    [[ -n "$RCM_TLD_SPECIAL" ]] || { error Global variable RCM_TLD_SPECIAL is not found or empty value.; x; }
    Rcm_parse_url "$url"
    if [ -z "$PHP_URL_HOST" ];then
        error Argument --url is not valid: '`'"$url"'`'.; x
    fi
    [ -n "$PHP_URL_SCHEME" ] && url_scheme="$PHP_URL_SCHEME" || url_scheme=https
    if [ -z "$PHP_URL_PORT" ];then
        case "$url_scheme" in
            http) url_port=80;;
            https) url_port=443;;
        esac
    else
        url_port="$PHP_URL_PORT"
    fi
    url_host="$PHP_URL_HOST"
    url_path="$PHP_URL_PATH"
    url_path_clean=
    url_path_clean_trailing=
    if [[ "$url_path" == '/' ]];then
        url_path=
    fi
    if [ -n "$url_path" ];then
        # Trim leading and trailing slash.
        url_path_clean=$(echo "$url_path" | sed -E 's|(^/+\|/+$)||g')
        url_path_clean_trailing=$(echo "$url_path" | sed -E 's|/+$||g')
        # Must leading with slash.
        # Karena akan digunakan pada nginx configuration.
        _url_path_correct="/${url_path_clean}"
        if [ ! "$url_path_clean_trailing" == "$_url_path_correct" ];then
            error "Argument --url-path not valid."; x
        fi
    fi
    _tld="${url_host##*.}"
    # Explode by space.
    read -ra tld_special -d '' <<< "$RCM_TLD_SPECIAL"
    is_tld_special=
    if ArraySearch "$_tld" tld_special[@];then
        # Paksa menjadi http.
        url_scheme=http
        if [ -z "$PHP_URL_PORT" ];then
            url_port=80
        fi
        is_tld_special=1
    fi
    _url_port=
    if [ -n "$url_port" ];then
        if [[ "$url_scheme" == https && "$url_port" == 443 ]];then
            _url_port=
        elif [[ "$url_scheme" == http && "$url_port" == 80 ]];then
            _url_port=
        else
            _url_port=":${url_port}"
        fi
    fi
    # Modify variable url, auto add scheme.
    # Modify variable url, auto trim trailing slash, auto add port.
    url="${url_scheme}://${url_host}${_url_port}${url_path_clean_trailing}"
}
Rcm_wget() {
    # Global, untuk debug.
    local http_request line cache_file_basename
    local start end runtime line_number
    http_request=
    local expired="$1"
    local url="$2"
    local table=$HOME/.cache/rcm/rcm.table.cache
    local cache_file=
    if [ -f "$table" ];then
        line=$(grep -n -F "$url"' ' "$table")
        if [ -z "$line" ];then
            http_request=1
        else
            cache_file_basename=$(cut -d' ' -f2 <<< "$line")
            cache_file=$HOME/.cache/rcm/"$cache_file_basename"
        fi
    else
        http_request=1
    fi
    local do_delete_record_cache_file=
    if [ -n "$cache_file" ];then
        if [ -f "$cache_file" ];then
            start=`date -r "$cache_file" +'%s'`
            end=`date +%s`
            runtime=$((end-start))
            if [ $runtime -gt $expired ];then
                do_delete_record_cache_file=1
            fi
        else
            do_delete_record_cache_file=1
        fi
    fi
    if [ -n "$do_delete_record_cache_file" ];then
        line_number=$(cut -d':' -f1 <<< "$line")
        sed -i $line_number'd' "$table"
        http_request=1
        if [ -f "$cache_file" ];then
            rm "$cache_file"
        fi
        cache_file=
    fi
    if [ -n "$http_request" ];then
        mkdir -p $HOME/.cache/rcm
        cache_file=$(mktemp --tmpdir=$HOME/.cache/rcm rcm.wget.XXXXXXXXXXXX.cache)
        cache_file_basename=$(basename "$cache_file")
        # echo wget -q -O "$cache_file" "$url"
        wget -q -O "$cache_file" "$url"
        touch "$cache_file" # wajib karena wget mengubah modified sesuai http header response.
        mkdir -p $(dirname "$table")
        echo "$url" "$cache_file_basename" >> "$table"
    fi
    if [ ! -f "$cache_file" ];then
        exit 1
    fi
    cat "$cache_file"
}
Rcm_event_dispatcher() {
    # global command argument_placeholders command_prepend tempfile
    local key value
    local label="$1"; shift
    local to_execute command_raw _command_arguments _command _arguments
    local line  find replace
    to_execute=`${command} --help 2>/dev/null | sed -n '/^'"$label"'[:\.]$/,$p' | sed -n '1,/^\s*$/p' | sed -n '2,/^\s*$/p'`
    if [ -n "$to_execute" ];then
        until [[ -z "$to_execute" ]];do
            command_raw=`sed -n 1p <<< "$to_execute" | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//'`
            to_execute=`sed -n '2,$p' <<< "$to_execute"`
            _command_arguments=$(echo "$command_raw" | sed -n -E 's/\s*([^\)]+\))/\1/p')
            _command=$(echo "$_command_arguments" | sed -n -E 's/^([^\(]+)\(([^\)]*)\)$/\1/p')
            _arguments=$(echo "$_command_arguments" | sed -n -E 's/^([^\(]+)\(([^\)]*)\)$/\2/p')
            if command -v "$_command" > /dev/null;then
                if [ -n "$argument_placeholders" ];then
                    while read line; do
                        find=$(echo ${line} | sed -E 's|^([^:]+):.*|\1|' | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
                        replace=$(echo ${line} | sed -E 's|^[^:]+:(.*)|\1|' | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
                        # description="${description/"$find"/"$replace"}"
                        if [ -n "$_arguments" ];then
                            _arguments="${_arguments/"$find"/"$replace"}"
                        fi
                    done <<< "$argument_placeholders"
                fi
            fi
            [ -n "$_arguments" ] && _arguments=' '"$_arguments"
            chapter "$label" command.
            code ${_command}${_arguments}
            ____

            if [ -z "$tempfile" ];then
                tempfile=$(mktemp -p /dev/shm -t rcm.XXXXXX)
            fi
            RCM_PROMPT_CHAIN= INDENT+="$RCM_INDENT" ${_command}${_arguments} \
                > "$tempfile" \
                ; [ ! $? -eq 0 ] && { rm "$tempfile"; x; }

            while IFS= read -r to_export; do
                key=$(cut -d= -f1 <<< "$to_export")
                value=$(cut -d= -f2- <<< "$to_export")
                [ -z "$value" ] && value=-
                code export "$key"="$value"
                export "$key"="$value"
                [ -n "$command_prepend" ] && command_prepend+=" "
                command_prepend+="${key}=${value}"
            done < "$tempfile"
            if [ -s "$tempfile" ];then
                ____
            fi

        done
    fi
}

# Mapping operand to value of options.
chapter Mapping operand as value of options.
if [ -n "$1" ];then
    code --extension=$1
    extension=$1; shift
fi
if [ -n "$1" ];then
    code --extension-version=$1
    extension_version=$1; shift
fi
____

# Require, validate, and populate value.
chapter Variable dump.
code 'verbose="'$verbose'"'
code 'quiet="'$quiet'"'
code 'loud="'$loud'"'
code 'louder="'$louder'"'
code 'debug="'$debug'"'
if [ -z "$extension" ];then
    error "Argument --extension required."; x
fi
code 'extension="'$extension'"'
rcm_extension="rcm-${extension}"
if command -v $rcm_extension >/dev/null;then
    current_version=`$rcm_extension --version`
    _ 'Command has exists '; magenta $rcm_extension; _, ' version: '; yellow $current_version; _.
    ____

    exit 0
fi
if [ -z "$extension_version" ];then
    extension_version=latest
fi
code 'extension_version="'$extension_version'"'
boolean=
[ -n "$source" ] && boolean+=1 || boolean+=0
[ -n "$url" ] && boolean+=1 || boolean+=0
if [ "$boolean" == 00 ];then
    error "Argument --source or --url is required."; x
fi
if [ "$boolean" == 11 ];then
    error "Argument --source and --url cannot both be present."; x
fi
boolean=
[ -n "$source" ] && boolean+=1 || boolean+=0
[ -n "$path" ] && boolean+=1 || boolean+=0
if [ "$boolean" == 11 ];then
    error "Argument --source and --path cannot both be present."; x
fi
code 'source="'$source'"'
if [ -n "$source" ];then
    _url=
    if [ "$source" == install ];then
        _help=`usage 2>/dev/null`
        _download=$(echo "$_help" | sed -n '/^Download:/,$p' | sed -n '1,/^\s*$/p' | sed -n '2,/^\s*$/p' | sed 's/^ *//g')
        _url=$(grep -F '['$rcm_extension']' <<< "$_download" | tail -1 | sed -E 's/.*\((.*)\).*/\1/')
        if [ -n "$_url" ];then
            # Ini berarti rcm extension internal. Maka gunakan version yang sama dengan rcm.
            extension_version=`printVersion`
        fi
    else
        _help=$("rcm-${source}" --help 2>/dev/null)
        _download=$(echo "$_help" | sed -n '/^Download:/,$p' | sed -n '1,/^\s*$/p' | sed -n '2,/^\s*$/p' | sed 's/^ *//g')
    fi
    # Insert table. Rcm_resolve_dependencies_insert_table().
    if [ -n "$_download" ];then
        while IFS= read -r _line; do
            if ! grep -q -F -- "$_line" <<< "$table_downloads";then
                [ -n "$_line" ] && table_downloads+="$_line"$'\n'
            fi
        done <<< "$_download"
    fi
    if [ -z "$_url" ];then
        _url=$(grep -F '['$rcm_extension']' <<< "$table_downloads" | tail -1 | sed -E 's/.*\((.*)\).*/\1/')
    fi
    if [ -n "$_url" ];then
        Rcm_parse_url "$_url"
        if [[ "$PHP_URL_HOST" == github.com ]];then
            github_media_type=$(cut -d/ -f 4 <<< $PHP_URL_PATH)
            if [[ $github_media_type == raw ]];then
                github_owner_repo=$(cut -d/ -f 2,3 <<< $PHP_URL_PATH)
                github_file_path=$(cut -d/ -f 6- <<< $PHP_URL_PATH)
                url="https://github.com/${github_owner_repo}"
                path="$github_file_path"
            fi
        fi
    fi
fi
code 'extension_version="'$extension_version'"'
if [ -z "$url" ];then
    error "Argument --url required."; x
fi
code 'url="'$url'"'
if [ -z "$path" ];then
    path="rcm/rcm-${extension}.sh"
fi
code 'path="'$path'"'
tempfile=
urlCompleteComponent
if [ ! "$url_host" == github.com ];then
    error Only supports URLs from Github.; x
fi
table=$HOME/.config/rcm/rcm.table.extension
github_owner_repo=$(cut -d/ -f 2,3 <<< $url_path)
version="$extension_version"
blob_path="$path"
____

chapter Download from Github.
url_tarball=
if [ "$version" == latest ];then
    tag_name=$(Rcm_wget 3600 https://api.github.com/repos/$github_owner_repo/releases/latest | grep '^  "tag_name": ".*",$' | sed -E 's/  "tag_name": "(.*)",/\1/')
    if [ -z "$tag_name" ];then
        error "The repository does not have any releases."; x
    fi
    version=$(sed -E 's/v?(.*)/\1/' <<< "$tag_name")
    url_tarball='https://api.github.com/repos/'$github_owner_repo'/tarball/'$tag_name
fi
if command -v "$rcm_extension" >/dev/null;then
    current_version=`$rcm_extension --version`
    if [ "$current_version" == "$version" ];then
        if [ -n "$loud" ];then
            _ 'You are already using the extension '; magenta $rcm_extension; _, ' version: '; yellow $version; _.
        fi
        exit 0
    fi
fi
if [ -z "$url_tarball" ];then
    tag_name=$(Rcm_wget 3600 https://api.github.com/repos/$github_owner_repo/releases/tags/$version | grep '^  "tag_name": ".*",$' | sed -E 's/  "tag_name": "(.*)",/\1/')
    if [ -z "$tag_name" ];then
        error "The repository does not have that release tag."; x
    fi
    url_tarball='https://api.github.com/repos/'$github_owner_repo'/tarball/'$tag_name
fi
cache_directory=$HOME/.cache/rcm/$github_owner_repo/$version
if [ ! -d "$cache_directory" ];then
    if [ -n "$loud" ];then
        _ 'Downloading version: '; yellow $version; _.
    fi
    tempdir=$(mktemp -d)
    cd "$tempdir"
    wget -q -O "${tag_name}.tar.gz" "$url_tarball"
    if [ ! -f "${tag_name}.tar.gz" ];then
        error Failed to download file: "${tag_name}.tar.gz".
        rm -rf "$tempdir"
        x
    fi
    tar xfz "${tag_name}.tar.gz"
    found_directory_extracted=$(find -maxdepth 1 -mindepth 1 -type d)
    if [ ! -d "$found_directory_extracted" ];then
        error Failed to extract archieve: "${tag_name}.tar.gz".;
        cd - >/dev/null
        rm -rf "$tempdir"
        x
    fi
    mkdir -p $(dirname "$cache_directory");
    mv $(realpath "$found_directory_extracted") "$cache_directory"
    # Cleaning.
    cd - >/dev/null
    rm -rf "$tempdir"
else
    if [ -n "$loud" ];then
        _ 'Using downloaded version: '; yellow $version; _.
    fi
fi
source="${cache_directory}/${blob_path}"
target="${BINARY_DIRECTORY}/${rcm_extension}"

if [ ! -f "$source" ];then
    error File is not found: "$source".; x
fi
# @todo, jika binary directory adalah prefix $HOME, maka
# symbolic link.
do=
if [ -f "$target" ];then
    if [ -h "$target" ];then
        if [ -n "$debug" ];then
            __ Backup symlink "$target".
        fi
        backupFile move "$target"
        do=link
    else
        if [ -n "$debug" ];then
            __ Backup file "$target".
        fi
        backupFile move "$target"
        do=copy
    fi
else
    do=copy
fi
# @todo,
# saat ini paksa ke copy semua aja dulu.
do=copy
case "$do" in
    link)
        ____

        link_symbolic "$source" "$target" - absolute
        ;;
    copy)
        if [ -n "$loud" ];then
            code cp '"'$source'"' '"'$target'"'
        fi
        cp "$source" "$target"
esac

if ! command -v $rcm_extension >/dev/null;then
    error Command '`'$rcm_extension'`' not found, unable to auto download.; x
fi

current_version=`$rcm_extension --version`
if [ -n "$loud" ];then
    _ 'Success install '; magenta $rcm_extension; _, ' version: '; yellow $current_version; _.
fi
____

command="${rcm_extension}"
Rcm_event_dispatcher 'Post Install'
[ -n "$tempfile" ] && rm "$tempfile"

exit 0

# parse-options.sh \
# --compact \
# --clean \
# --no-hash-bang \
# --no-original-arguments \
# --no-error-invalid-options \
# --with-end-options-double-dash \
# --no-error-require-arguments << EOF | clip
# INCREMENT=(
    # '--verbose|-v'
# )
# FLAG=(
# --version
# --help
# '--quiet|-q'
# )
# VALUE=(
# --url
# --path
# --extension
# --extension-version
# --source
# )
# MULTIVALUE=(
# )
# FLAG_VALUE=(
# )
# CSV=(
# )
# EOF
# clear

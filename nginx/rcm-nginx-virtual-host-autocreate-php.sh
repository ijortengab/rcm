#!/bin/bash

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --certbot-certificate-name=*) certbot_certificate_name="${1#*=}"; shift ;;
        --certbot-certificate-name) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then certbot_certificate_name="$2"; shift; fi; shift ;;
        --fastcgi-pass=*) fastcgi_pass="${1#*=}"; shift ;;
        --fastcgi-pass) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then fastcgi_pass="$2"; shift; fi; shift ;;
        --fast) fast=1; shift ;;
        --filename=*) filename="${1#*=}"; shift ;;
        --filename) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then filename="$2"; shift; fi; shift ;;
        --root=*) root="${1#*=}"; shift ;;
        --root) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then root="$2"; shift; fi; shift ;;
        --tempfile-trigger-reload=*) tempfile_trigger_reload="${1#*=}"; shift ;;
        --tempfile-trigger-reload) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then tempfile_trigger_reload="$2"; shift; fi; shift ;;
        --url-host=*) url_host="${1#*=}"; shift ;;
        --url-host) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then url_host="$2"; shift; fi; shift ;;
        --url-port=*) url_port="${1#*=}"; shift ;;
        --url-port) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then url_port="$2"; shift; fi; shift ;;
        --url-scheme=*) url_scheme="${1#*=}"; shift ;;
        --url-scheme) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then url_scheme="$2"; shift; fi; shift ;;
        --with-certbot-obtain) certbot_obtain=1; shift ;;
        --without-certbot-obtain) certbot_obtain=0; shift ;;
        --with-nginx-reload) nginx_reload=1; shift ;;
        --without-nginx-reload) nginx_reload=0; shift ;;
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

if [ -n "$RCM_VERBOSE" ];then
    verbose="$RCM_VERBOSE"
fi
[[ -z "$verbose" || "$verbose" -lt 1 ]] && quiet=1 || quiet=
[[ "$verbose" -gt 0 ]] && loud=1
[[ "$verbose" -gt 1 ]] && loud=1 && louder=1
[[ "$verbose" -gt 2 ]] && loud=1 && louder=1 && debug=1

# Functions.
printVersion() {
    echo '0.16.22'
}
printHelp() {
    title RCM Nginx Virtual Host Autocreate
    _ 'Variation '; yellow PHP General; _.
    _ 'Version '; yellow `printVersion`; _.
    cat << 'EOF'
Usage: rcm-nginx-virtual-host-autocreate-php [options]

Options:
   --filename *
        Set the filename to created inside /etc/nginx/sites-available directory.
   --root *
        Set the value of root directive.
   --fastcgi-pass *
        Set the value of fastcgi_pass directive.
   --url-scheme *
        The URL Scheme. Available value: http, https.
   --url-port *
        The URL Port. Set the value of listen directive.
   --url-host *
        The URL Host. Set the value of server_name directive.
        Only support one value even the directive may have multivalue.
   --without-certbot-obtain ^
        Prevent auto obtain certificate if not exists.
        Default value is --with-certbot-obtain.
   --without-nginx-reload ^
        Prevent auto reload nginx after add/edit file config.
        Default value is --with-nginx-reload.
   --certbot-certificate-name
        The name of certificate. Leave blank to use default value.
        Default value is --url-host.

Global Options.
   --fast
        No delay every subtask.
   --version
        Print version of this script.
   --help
        Show this help.

Dependency:
   rcm-certbot-obtain-authenticator-nginx
   rcm-nginx-reload
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Title.
title rcm-nginx-virtual-host-autocreate-php
____

[ "$EUID" -ne 0 ] && { error This script needs to be run with superuser privileges.; x; }

# Dependency.
while IFS= read -r line; do
    [[ -z "$line" ]] || command -v `cut -d: -f1 <<< "${line}"` >/dev/null || { error Unable to proceed, command not found: '`'`cut -d: -f1 <<< "${line}"`'`'.; x; }
done <<< `printHelp 2>/dev/null | sed -n '/^Dependency:/,$p' | sed -n '2,/^\s*$/p' | sed 's/^ *//g'`

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
# Required function: ArraySearch.
# Karakter operator yang berlaku adalah: = != < > <= >= ~ !~
tokenToBinary () {
    local token=$1; shift;
    [ -z "$token" ] && { error 'Argument <token> is empty. '; x; }
    local token_list=$1; shift;
    [ -z "$token_list" ] && { error 'Argument <token_list> is empty. '; x; }
    local string=$1; shift;
    [ -z "$string" ] && { error 'Argument <string> is empty. '; x; }
    [[ $(type -t ArraySearch) == function ]] || { error Function ArraySearch not found.; x; }
    local array
    # Jika terjadi pengulangan, contoh:
    # a contains 80  a contains 8080
    # Maka kita ambil yang paling akhir.
    local token_list_last=$(echo "$token_list" | grep "^[$token]\s" | tail -1)
    local operator=$(echo "$token_list_last" | cut -d' ' -f2 )
    local value=$(echo "$token_list_last" | cut -d' ' -f3- )
    case "$operator" in
        =)
            if [[ "$string" == "$value" ]];then echo 1; else echo 0; fi
            ;;
        '<>')
            if [[ "$string" == "$value" ]];then echo 0; else echo 1; fi
            ;;
        '<')
            if [[ "$string" -lt "$value" ]];then echo 1; else echo 0; fi
            ;;
        '>')
            if [[ "$string" -gt "$value" ]];then echo 1; else echo 0; fi
            ;;
        '<=')
            if [[ "$string" -le "$value" ]];then echo 1; else echo 0; fi
            ;;
        '>=')
            if [[ "$string" -ge "$value" ]];then echo 1; else echo 0; fi
            ;;
        '[]')
            read -ra array -d '' <<< "$string"
            if ArraySearch "$value" array[@];then echo 1; else echo 0; fi
            ;;
        '![]')
            read -ra array -d '' <<< "$string"
            if ArraySearch "$value" array[@];then echo 0; else echo 1; fi
            ;;
        '~')
            if grep -q -E "$value" <<< "$string";then echo 1; else echo 0; fi
            ;;
        '!~')
            if grep -q -E "$value" <<< "$string";then echo 0; else echo 1; fi
            ;;
        *)
            echo 0
            error Operator is not valid: '`'$operator'`'; x
    esac
}
# Required function: tokenToBinary.
# Reference: https://github.com/parsecsv/parsecsv-for-php/blob/main/src/Csv.php#L1055
resolveCondition() {
    local condition=$1; shift;
    local token_list=$1; shift;
    local string=$1; shift;
    local i
    i=0
    binary="$condition"
    conditionToBinary() {
        local condition=$1; shift;
        [ -z "$condition" ] && { error 'Argument <condition> is empty. '; x; }
        local token_list=$1; shift;
        local string=$1; shift;
        local each array
        local or=
        local and=
        conditionToBinaryOr () {
            local condition=$1; shift;
            [ -z "$condition" ] && { error 'Argument <condition> is empty. '; x; }
            local token_list=$1; shift;
            local string=$1; shift;
            local each array
            local or=
            IFS='|' read -ra array <<< "$condition"
            for each in "${array[@]}"; do
                if [ -n "$token_list" ];then
                    or+=$(conditionToBinaryAnd "$each" "$token_list" "$string")
                else
                    or+=$(conditionToBinaryAnd "$each")
                fi
            done
            [[ "$or" =~ 1 ]] && echo 1 || echo 0
        }
        conditionToBinaryAnd () {
            local condition=$1; shift;
            [ -z "$condition" ] && { error 'Argument <condition> is empty. '; x; }
            local token_list=$1; shift;
            local string=$1; shift;
            local each array
            local and=
            IFS='&' read -ra array <<< "$condition"
            for each in "${array[@]}"; do
                if [ -n "$token_list" ];then
                    and+=$(tokenToBinary "$each" "$token_list" "$string")
                else
                    and+="$each"
                fi
            done
            [[ "$and" =~ 0 ]] && echo 0 || echo 1
        }
        conditionToBinaryOr "$condition" "$token_list" "$string"
    }
    until [[ "$binary" =~ ^(0|1)$ ]];do
        i=$(( i + 1 ))
        # e 'Looping ke-' "$i" ; _.
        # e '< "$binary"' "$binary" ; _.
        if [[ $(echo "$binary" | grep -i -o -E '\([^\(\)]+\)' | grep -o -E '[^\(\)]+' | wc -l) -eq 0 ]];then
            if [[ "$binary" =~ ^[a-z]$ ]];then
                # e '< "$binary"' "$binary"; _.
                binary=$(conditionToBinary "$binary" "$token_list" "$string")
                # e '> "$binary"' "$binary"; _.
            else
                # error Token tidak valid: '`'$token'`'; x
                # e '< "$binary"' "$binary"; _.
                binary=$(conditionToBinary "$binary")
                # e '> "$binary"' "$binary"; _.
            fi
        else
            while IFS= read insideBraces; do
                find="(${insideBraces})"
                # e '"$find"' "$find" ; _.
                replace=$(conditionToBinary "$insideBraces" "$token_list" "$string")
                # e '"$replace"' "$replace" ; _.
                # _ Jangan gunakan replace all, karena bisa jadi ada tanda kurung yang sama.
                # _ Contoh: binary='(a&b)|c|(a&c)|((m&r|(a&b)))'
                # e '< "$binary"' "$binary" ; _.
                binary="${binary/"$find"/"$replace"}"
                # e '> "$binary"' "$binary" ; _.
            done <<< `echo "$binary" | grep -o -E '\([^\(\)]+\)' | grep -o -E   '[^\(\)]+'`
        fi
        # e '> "$binary"' "$binary"; _.
        # __ Limit adalah 100 ya gaes.
        # __ 100 lopping belum ketemu juga, artinya set error dan kembalikan false
        if [[ $i == 100 ]];then
            error Kesalahan Logic.
            binary=0
        fi
    done
    echo "$binary"
}
# Required function: resolveCondition.
nginxGrep(){
    validateToken() {
        # global token
        if [[ ! "$token" =~ ^[a-z]$ ]];then
            error Token tidak valid: '`'$token'`'; x
        fi
    }
    # Mengubah operator dari text string menjadi simbol, sekaligus validasi.
    # Karakter operator yang berlaku adalah: = != < > <= >= ~ !~
    validateOperator() {
        # global operator
        case "$operator" in
            is|equals|=)
                operator='=' ;;
            '!='|'is not'|'<>')
                operator='<>' ;;
            '<'|'is less than')
                operator='<' ;;
            '>'|'is greater than')
                operator='>' ;;
            '<='|'is less than or equals')
                operator='<=' ;;
            '>='|'is greater than or equals')
                operator='>=' ;;
            '[]'|'contains')
                operator='[]' ;;
            '![]'|'does not contain')
                operator='![]' ;;
            '~'|'match')
                operator='~' ;;
            '!~'|'does not match')
                operator='!~' ;;
            *)
                error Operator is not valid: '`'$operator'`'; x
        esac
    }
    [[ $(type -t resolveCondition) == function ]] || { error Function resolveCondition not found.; x; }
    local i token operator
    local directive=$1; shift
    # Jika total argument setelah directive adalah 7, 10, 13, dst.,
    # maka berarti conditional complex. Contohnya.
    # nginxGrep listen '(a&b)' a contains 8080 b contains ssl < a.txt
    # nginxGrep listen '(a&b)|c' a contain6s 8080 b contains ssl c contains ipv6only=on < a.txt
    token_list=
    if [[ $# -gt 6 && $(( $# % 3 )) == 1 ]];then
        condition=$1; shift
        while [ $# -gt 0 ];do
            token=$1
            validateToken
            operator=$2
            validateOperator
            token_list+="${token} ${operator} $3"
            token_list+=$'\n'
            shift 3;
        done
    # Jika total argument setelah directive adalah 1, maka mencari fix value.
    # Contohnya:
    # nginxGrep listen 8080
    elif [[ $# -eq 1 ]];then
        condition=a
        token_list+="a = $1"
        token_list+=$'\n'
    # Jika total argument setelah directive adalah 2, maka berarti conditional
    # sederhana. Contohnya.
    # nginxGrep listen contains ssl
    # nginxGrep listen 'is not contain' ssl
    elif [[ $# -eq 2 ]];then
        condition=a
        operator=$1
        validateOperator
        token_list+="a ${operator} $2"
        token_list+=$'\n'
    fi
    lines_directive=()
    if [ ! -t 0 ]; then
        i=0
        _ Mencari directive: '`'${directive}'`'; _.
        [ -n "$debug" ] && { _; magenta grep -E "^\s*${directive}\s+[^;]+;\s*\$"; _.; }
        while IFS= read line; do
            i=$(( i + 1 ))
            if [ "${#line}" -eq 0 ];then
                [ -n "$debug" ] && { __; }
            else
                [ -n "$debug" ] && { _; yellow "$line"; _, ' # Line:' $i; }
            fi
            if grep -q -E "^\s*${directive}\s+[^;]+;\s*\$" <<< "$line";then
                [ -n "$debug" ] && { _, ' '; green Baris ditemukan.; }
                lines_directive+=("$line")
            fi
            [ -n "$debug" ] && { _.; }
        done </dev/stdin
    fi
    if [ "${#lines_directive[@]}" -eq 0 ];then
        return 1
    fi
    [ -n "$debug" ] && { _; _.; }
    [ -n "$debug" ] && { _ Dump variable '`'\$condition'`'.; _.; }
    [ -n "$debug" ] && { e; magenta $condition; _.; }
    [ -n "$debug" ] && { _; _.; }
    [ -n "$debug" ] && { _ Dump variable '`'\$token_list'`'.; _.; }
    [ -n "$debug" ] && { while IFS= read line; do [ -n "$line" ] || continue; e; magenta "$line"; _. ; done <<< "$token_list"; }
    # _; _.
    # Directive bisa berulang.
    # Contoh: directive listen bisa berulang sebanyak dua kali.
    # Jadi jika satu saja sudah solve, maka langsung break saja.
    local resolved
    for line in "${lines_directive[@]}"; do
        # e '"$line"' "$line" ; _.
        directive_reverse=$(echo "$line" | sed -E -e "s;\s*${directive}\s+(.*);\1;" -e 's|;\s*$||')
        # e '"$directive_reverse"' "$directive_reverse" ; _.
        resolved=$(resolveCondition "$condition" "$token_list" "$directive_reverse")
        # e '"$resolved"' "$resolved" ; _.
        if [ "$resolved" == 1 ];then
            [ -n "$debug" ] && { _; _.; }
            _ Condition solved pada baris:' '; yellow  "$line"; _.
            [ -n "$debug" ] && { _; _.; }
            return 0
        fi
    done
    return 1
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
    _; magenta grep -E '"'"${find_quoted}"'"' '"'"\$path"'"'; _.; _.
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
validateContent() {
    local path="$1"

    # listen
    if [ "$url_scheme" == https ];then
        if ! nginxGrep listen '(a&b)|(a&b&c)' a contains "$url_port" b contains ssl c contains ipv6only=on < "$path";then
            __; yellow File akan dibuat ulang.; _.
            return 1
        fi
    else
        if ! nginxGrep listen contains "$url_port" < "$path";then
            __; yellow File akan dibuat ulang.; _.
            return 1
        fi
    fi
    # root
    if ! nginxGrep root "$root" < "$path";then
        __; yellow File akan dibuat ulang.; _.
        return 1
    fi
    # server_name
    if ! nginxGrep server_name contains "$url_host" < "$path";then
        __; yellow File akan dibuat ulang.; _.
        return 1
    fi
    # fastcgi_pass
    if ! nginxGrep fastcgi_pass is "$fastcgi_pass" < "$path";then
        __; yellow File akan dibuat ulang.; _.
        return 1
    fi
    if [ "$url_scheme" == https ];then
        # ssl_certificate
        if ! nginxGrep ssl_certificate is "/etc/letsencrypt/live/${certbot_certificate_name}/fullchain.pem" < "$path";then
            __; yellow File akan dibuat ulang.; _.
            return 1
        fi
        # ssl_certificate_key
        if ! nginxGrep ssl_certificate_key is "/etc/letsencrypt/live/${certbot_certificate_name}/privkey.pem" < "$path";then
            __; yellow File akan dibuat ulang.; _.
            return 1
        fi
        # include
        if ! nginxGrep include is /etc/letsencrypt/options-ssl-nginx.conf < "$path";then
            __; yellow File akan dibuat ulang.; _.
            return 1
        fi
        # include
        if ! nginxGrep ssl_dhparam is /etc/letsencrypt/ssl-dhparams.pem < "$path";then
            __; yellow File akan dibuat ulang.; _.
            return 1
        fi
    fi
    if [ "$url_scheme" == http ];then
        # ssl_certificate
        if nginxGrep ssl_certificate is "/etc/letsencrypt/live/${certbot_certificate_name}/fullchain.pem" < "$path";then
            __; yellow File akan dibuat ulang.; _.
            return 1
        fi
        # ssl_certificate_key
        if nginxGrep ssl_certificate_key is "/etc/letsencrypt/live/${certbot_certificate_name}/privkey.pem" < "$path";then
            __; yellow File akan dibuat ulang.; _.
            return 1
        fi
        # include
        if nginxGrep include is /etc/letsencrypt/options-ssl-nginx.conf < "$path";then
            __; yellow File akan dibuat ulang.; _.
            return 1
        fi
        # include
        if nginxGrep ssl_dhparam is /etc/letsencrypt/ssl-dhparams.pem < "$path";then
            __; yellow File akan dibuat ulang.; _.
            return 1
        fi
    fi
    return 0
}
isDirExists() {
    # global used:
    # global modified: found, notfound
    # function used: __
    found=
    notfound=
    if [ -d "$1" ];then
        __ Direktori '`'$(basename "$1")'`' ditemukan.
        found=1
    else
        __ Direktori '`'$(basename "$1")'`' tidak ditemukan.
        notfound=1
    fi
}
validateContentRedirect() {
    local path="$1"
    # listen
    if ! nginxGrep listen contains 80 < "$path";then
        __; yellow File akan dibuat ulang.; _.
        return 1
    fi
    # server_name
    if ! nginxGrep server_name contains "$url_host" < "$path";then
        __; yellow File akan dibuat ulang.; _.
        return 1
    fi
    return 0
}

# Require, validate, and populate value.
chapter Dump variable.
if [ -z "$filename" ];then
    error "Argument --filename required."; x
fi
if [ -z "$root" ];then
    error "Argument --root required."; x
fi
if [ -z "$fastcgi_pass" ];then
    error "Argument --fastcgi-pass required."; x
fi
if [ -z "$url_scheme" ];then
    error "Argument --url-scheme required."; x
fi
if [ -z "$url_port" ];then
    error "Argument --url-port required."; x
fi
if [ -z "$url_host" ];then
    error "Argument --url-host required."; x
fi
[ "$certbot_obtain" == 0 ] && certbot_obtain=
[ -z "$nginx_reload" ] && nginx_reload=1
[ "$nginx_reload" == 0 ] && nginx_reload=
case "$url_scheme" in
    http|https) ;;
    *) error "Argument --url-scheme is not valid."; x
esac
if [[ "$url_port" =~ [^0-9] ]];then
    error "Argument --url-port is not valid."; x
fi
if [ -z "$certbot_certificate_name" ];then
    certbot_certificate_name="$url_host"
fi
code 'filename="'$filename'"'
code 'root="'$root'"'
code 'fastcgi_pass="'$fastcgi_pass'"'
code 'url_scheme="'$url_scheme'"'
code 'url_port="'$url_port'"'
code 'url_host="'$url_host'"'
code 'certbot_obtain="'$certbot_obtain'"'
code 'nginx_reload="'$nginx_reload'"'
code 'certbot_certificate_name="'$certbot_certificate_name'"'
code 'tempfile_trigger_reload="'$tempfile_trigger_reload'"'
rcm_nginx_reload=
____

path="/etc/nginx/sites-available/$filename"
chapter Mengecek nginx config file: '`'$filename'`'.
code 'path="'$path'"'
isFileExists "$path"
____

create_new=
if [ -n "$found" ];then
    chapter Memeriksa konten.
    validateContent "$path"
    [ ! $? -eq 0 ] && create_new=1;
    ____
else
    create_new=1
fi

if [[ -n "$create_new" && "$url_scheme" == https ]];then
    path="/etc/letsencrypt/live/${certbot_certificate_name}"
    chapter Mengecek direktori certbot '`'$path'`'.
    isDirExists "$path"
    ____

    if [ -n "$notfound" ];then
        if [ -n "$certbot_obtain" ];then
            chapter Mengecek '$PATH'.
            code PATH="$PATH"
            if grep -q '/snap/bin' <<< "$PATH";then
                __ '$PATH' sudah lengkap.
            else
                __ '$PATH' belum lengkap.
                __ Memperbaiki '$PATH'
                PATH=/snap/bin:$PATH
                if grep -q '/snap/bin' <<< "$PATH";then
                    __; green '$PATH' sudah lengkap.; _.
                    __; magenta PATH="$PATH"; _.
                else
                    __; red '$PATH' belum lengkap.; x
                fi
            fi
            ____

            INDENT+="    " \
            PATH=$PATH \
            rcm-certbot-obtain-authenticator-nginx \
                --domain "$url_host" \
                ; [ ! $? -eq 0 ] && x
            nginx_reload=1
        fi
    fi

    chapter Memeriksa certificate SSL.
    path="/etc/letsencrypt/live/${certbot_certificate_name}/fullchain.pem"
    code 'path="'$path'"'
    [ -f "$path" ] || fileMustExists "$path"
    path="/etc/letsencrypt/live/${certbot_certificate_name}/privkey.pem"
    code 'path="'$path'"'
    [ -f "$path" ] || fileMustExists "$path"
    ____
fi

if [ -n "$create_new" ];then
    path="/etc/nginx/sites-available/$filename"
    chapter Membuat nginx config file: '`'$filename'`'.
    code 'path="'$path'"'
    if [ -f "$path" ];then
        __ Backup file "$filename".
        backupFile move "$path"
    fi
    __ Membuat file "$filename".
    cat <<'EOF' > "$path"
server {
    listen __URL_PORT____SSL__;
    listen [::]:__URL_PORT____SSL____IPV6ONLY__;
    root __ROOT__;
    index index.php;
    server_name __URL_HOST__;
    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }
    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }
    location / {
        try_files $uri $uri/ /index.php$is_args$args;
    }
    location ~ ^(.+\.php)(.*)$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass __FASTCGI_PASS__;
        fastcgi_read_timeout 3600;
    }
    # ssl_certificate /etc/letsencrypt/live/__CERTBOT_CERTIFICATE_NAME__/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/__CERTBOT_CERTIFICATE_NAME__/privkey.pem;
    # include /etc/letsencrypt/options-ssl-nginx.conf;
    # ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # error_page 497 301 =307 https://$host:$server_port$request_uri;
}
EOF
    fileMustExists "$path"
    sed -i "s|__ROOT__|${root}|g" "$path"
    sed -i "s|__URL_HOST__|${url_host}|g" "$path"
    sed -i "s|__CERTBOT_CERTIFICATE_NAME__|${certbot_certificate_name}|g" "$path"
    sed -i "s|__FASTCGI_PASS__|${fastcgi_pass}|g" "$path"
    sed -i "s|__URL_PORT__|${url_port}|g" "$path"
    if [ "$url_scheme" == https ];then
        sed -i "s|__SSL__| ssl|g" "$path"
        # Hanya satu ipv6only=on yang boleh exist pada setiap virtual host.
        if grep -R -q ipv6only=on /etc/nginx/sites-enabled/;then
            sed -i "s|__IPV6ONLY__||g" "$path"
        else
            sed -i "s|__IPV6ONLY__| ipv6only=on|g" "$path"
        fi
        sed -i -E 's|^(\s*)# ssl_certificate (.*);|\1ssl_certificate \2;|g' "$path"
        sed -i -E 's|^(\s*)# ssl_certificate_key (.*);|\1ssl_certificate_key \2;|g' "$path"
        sed -i -E 's|^(\s*)# include /etc/letsencrypt/options-ssl-nginx.conf;|\1include /etc/letsencrypt/options-ssl-nginx.conf;|g' "$path"
        sed -i -E 's|^(\s*)# ssl_dhparam (.*);|\1ssl_dhparam \2;|g' "$path"
    else
        sed -i "s|__SSL__||g" "$path"
        sed -i "s|__IPV6ONLY__||g" "$path"
    fi
    ____

    chapter Memeriksa ulang konten.
    validateContent "$path"
    [ ! $? -eq 0 ] && x
    ____

    rcm_nginx_reload=1
fi

source="$path"
target="/etc/nginx/sites-enabled/$filename"
link_symbolic "$source" "$target"

path="/etc/nginx/sites-available/${filename}-redirect"
filename_redirect="${filename}-redirect"
chapter Mengecek nginx config file: '`'$filename_redirect'`'.
isFileExists "$path"
____

if [[ "$url_scheme" == https && "$url_port" == 443 ]];then
    create_new=
    if [ -n "$found" ];then
        chapter Memeriksa konten.
        validateContentRedirect "$path"
        [ ! $? -eq 0 ] && create_new=1;
        ____
    else
        create_new=1
    fi
    if [ -n "$create_new" ];then
        path="/etc/nginx/sites-available/${filename}-redirect"
        filename_redirect="${filename}-redirect"
        chapter Membuat nginx config file: '`'$filename_redirect'`'.
        code 'path="'$path'"'
        if [ -f "$path" ];then
            __ Backup file: '`'"$filename_redirect"'`'.
            backupFile move "$path"
        fi
        __ Membuat file "$filename_redirect".
        cat <<'EOF' > "$path"
server {
    if ($host = __URL_HOST__) {
        return 301 https://$host$request_uri;
    }
    listen [::]:80;
    listen 80;
    server_name __URL_HOST__;
    return 404;
}
EOF
        fileMustExists "$path"
        sed -i "s|__URL_HOST__|${url_host}|g" "$path"
        ____

        chapter Memeriksa ulang konten.
        validateContentRedirect "$path"
        [ ! $? -eq 0 ] && x
        ____

        rcm_nginx_reload=1
    fi
    path="/etc/nginx/sites-available/${filename}-redirect"
    source="$path"
    target="/etc/nginx/sites-enabled/${filename}-redirect"
    link_symbolic "$source" "$target"
else
    # Nginx reload agar symlink di sites-enabled auto hapus.
    if [ -n "$found" ];then
        chapter Menonaktifkan file config.
        __ Backup file: '`'"$filename_redirect"'`'.
        backupFile move "$path"
        rcm_nginx_reload=1
        ____
    fi
fi

# Credit: https://stackoverflow.com/questions/15429043/how-to-redirect-on-the-same-port-from-http-to-https-with-nginx-reverse-proxy
if [[ "$url_scheme" == https && ! "$url_port" == 443 ]];then
    chapter Redirect to https if accessed with http
    path="/etc/nginx/sites-available/$filename"
    find="    error_page 497"
    if findString "# ${find}" "$path";then
        code sed -i -E "'"'s|'"${find_quoted}"'|'"${find}"'|g'"'" "$path"
        sed -i -E 's|'"${find_quoted}"'|'"${find}"'|g' "$path"
    fi
    if ! nginxGrep error_page contains 497 < "$path";then
        error Enable gagal.; x
    fi
    ____
fi

if [ -z "$nginx_reload" ];then
    if [ -n "$rcm_nginx_reload" ];then
        if [ -f "$tempfile_trigger_reload" ];then
            echo 1 > "$tempfile_trigger_reload"
        fi
    fi
    rcm_nginx_reload=
fi
if [ -n "$rcm_nginx_reload" ];then
    INDENT+="    " \
    rcm-nginx-reload \
        ; [ ! $? -eq 0 ] && x
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
# )
# VALUE=(
# --root
# --fastcgi-pass
# --filename
# --url-port
# --url-scheme
# --url-host
# --certbot-certificate-name
# --tempfile-trigger-reload
# )
# MULTIVALUE=(
# )
# FLAG_VALUE=(
# )
# CSV=(
    # 'long:--with-certbot-obtain,parameter:certbot_obtain'
    # 'long:--without-certbot-obtain,parameter:certbot_obtain,flag_option:reverse'
    # 'long:--with-nginx-reload,parameter:nginx_reload'
    # 'long:--without-nginx-reload,parameter:nginx_reload,flag_option:reverse'
# )
# EOF
# clear

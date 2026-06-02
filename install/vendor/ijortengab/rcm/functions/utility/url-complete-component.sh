#!/bin/bash

require vendor/ijortengab/bash/functions/array-search.sh
require vendor/ijortengab/rcm/functions/utility/parse-url.sh

url-complete-component() {
    local tld_special _url_port _tld _url_path_correct
    [[ $(type -t parse-url) == function ]] || { error Function parse-url not found.; x; }
    [[ $(type -t array-search) == function ]] || { error Function array-search not found.; x; }
    [[ -n "$url" ]] || { error Global variable url is not found or empty value.; x; }
    [[ -n "$RCM_TLD_SPECIAL" ]] || { error Global variable RCM_TLD_SPECIAL is not found or empty value.; x; }
    parse-url "$url"
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
    if array-search "$_tld" tld_special[@];then
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

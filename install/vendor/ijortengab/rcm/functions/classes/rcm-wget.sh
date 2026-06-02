#!/bin/bash

rcm-wget() {
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

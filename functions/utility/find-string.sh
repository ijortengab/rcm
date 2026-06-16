#!/bin/bash

find-string() {
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
    _; magenta grep -E '"'"${find_quoted}"'"' '"'"\$path"'"'; _.
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

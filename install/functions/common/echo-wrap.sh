#!/bin/bash

echo-wrap() {
    local paragraph="$1" indent_first_line=$2 words_array
    local current_line first_line last
    local max=0
    local min=0
    local _indent_first_line
    [ -z "$indent_first_line" ] && indent_first_line=1
    indent_first_line=$((indent_first_line*${#RCM_INDENT}))
    _indent_first_line=$((indent_first_line + 2))
    # Angka 2 adalah tambahan dari '# '.
    max=$(tput cols)
    _max=$((100 + ${#INDENT} + $_indent_first_line))
    if [ $max -gt $_max ];then
        max=100
        min=80
    else
        max=$((max - ${#INDENT} - 6))
        min="$max"
    fi

    local i=0
    words_array=($paragraph)
    local count="${#words_array[@]}"
    current_line=
    first_line=1
    for each in "${words_array[@]}"; do
        let i++
        [ "$i" == "$count" ] && last=1 || last=
        if [ -z "$current_line" ]; then
            if [ -n "$first_line" ];then
                first_line=
                current_line="$each"
                _; printf %"${indent_first_line}"s >&2; _, "$each"
            else
                current_line="$each"
                _; printf %"${indent_first_line}"s >&2; _, "$each"
            fi
            if [ -n "$last" ];then
                _.
            fi
        else
            _current_line="${current_line} ${each}"
            if [ "${#_current_line}" -le $min ];then
                current_line+=" ${each}"
                _, " ${each}"
                if [ -n "$last" ];then
                    _.
                fi
            elif [ "${#_current_line}" -le $max ];then
                _, " ${each}"; _.
                current_line=
            else
                _.;
                _; printf %"${indent_first_line}"s >&2;
                _, "$each"
                current_line="$each"
                if [ -n "$last" ];then
                    _.
                fi
            fi
        fi
    done
}

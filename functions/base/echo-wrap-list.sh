#!/bin/bash

echo-wrap-list() {
    # global words_array
    local inline_description="$1"
    local current_line first_line last
    declare -i max
    declare -i min

    max=$(tput cols)
    # Angka 11 adalah 4+2+5.
    # Angka 4 adalah tambahan indent.
    # Angka 2 adalah tambahan dari '# '.
    # Angka 5 adalah tambahan dari ', or '.
    _max=$((100 + ${#INDENT} + 11))
    if [ $max -gt $_max ];then
        max=100
        min=80
    else
        max=$((max - ${#INDENT} - 11))
        min="$max"
    fi

    declare -i i; i=0
    WRAP_LINE=1
    local count="${#words_array[@]}"
    current_line=
    first_line=1
    for each in "${words_array[@]}"; do
        i+=1
        [ "$i" == "$count" ] && last=1 || last=
        if [ -z "$current_line" ]; then
            if [ -n "$first_line" ];then
                first_line=
                current_line="${inline_description} ${each}"
                __; _, "${inline_description} "; yellow "$each"
            else
                if [ -n "$last" ];then
                    __; _, 'or '; yellow "$each"
                    current_line="or ${each}"
                else
                    __; yellow "$each"
                    current_line="$each"
                fi
            fi
            if [ -n "$last" ];then
                _, '.'; _.
            fi
        else
            if [ -n "$last" ];then
                _current_line="${current_line}, or ${each}"
            else
                _current_line="${current_line}, ${each}"
            fi
            if [ "${#_current_line}" -le $min ];then
                if [ -n "$last" ];then
                    _, ', or '; yellow "$each"; _, '.'; _.
                else
                    _, ', '; yellow "$each"
                fi
                current_line+=", ${each}"
            elif [ "${#_current_line}" -le $max ];then
                if [ -n "$last" ];then
                    _, ', or '; yellow "$each"; _, '.'; _.
                else
                    _, ', '; yellow "$each"; _, ','; _.
                    WRAP_LINE=$((WRAP_LINE+1))
                fi
                current_line=
            else
                WRAP_LINE=$((WRAP_LINE+1))
                if [ -n "$last" ];then
                    _.; __; _, 'or '; yellow "$each"; _, '.'; _.
                    current_line="or ${each}"
                else
                    _, ,; _.; __; yellow "$each"
                    current_line="$each"
                fi
            fi
        fi
    done
}

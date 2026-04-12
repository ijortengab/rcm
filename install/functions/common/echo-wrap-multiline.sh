#!/bin/bash

echo-wrap-multiline() {
    # global words_array RCM_INDENT
    local inline_description="$1"
    local current_line first_line
    local each
    declare -i max
    declare -i min

    max=$(tput cols)
    # Angka 2 adalah tambahan dari ' \'.
    _max=$((100 + ${#INDENT} + 2))
    if [ $max -gt $_max ];then
        max=100
        min=80
    else
        max=$((max - ${#INDENT} - 2))
        min="$max"
    fi

    declare -i i; i=0
    local count="${#words_array[@]}"
    current_line=
    first_line=1
    for each in "${words_array[@]}"; do
        i+=1
        [ "$i" == "$count" ] && last=1 || last=
        if [ -z "$current_line" ]; then
            if [ -z "$first_line" ];then
                current_line="${RCM_INDENT}${each}"
                e; magenta "${RCM_INDENT}$each";
            else
                first_line=
                if [ -n "$inline_description" ];then
                    e; _, "${inline_description} "; magenta "$each"
                    current_line="${inline_description} ${each}"
                else
                    e; magenta "$each"
                    current_line="$each"
                fi
            fi
            if [ -n "$last" ];then
                _.
            fi
        else
            _current_line="${current_line} ${each}"
            if [ "${#_current_line}" -le $min ];then
                if [ -n "$last" ];then
                    _, ' '; magenta "$each"; _.
                else
                    _, ' '; magenta "$each"
                fi
                current_line+=" ${each}"
            elif [ "${#_current_line}" -le $max ];then
                if [ -n "$last" ];then
                    _, ' '; magenta "${each}"''; _.
                else
                    _, ' '; magenta "${each}"' \'; _.
                fi
                current_line=
            else
                magenta ' \'; _.; e; magenta "${RCM_INDENT}$each"
                current_line="${RCM_INDENT}${each}"
                if [ -n "$last" ];then
                    _.
                fi
            fi
        fi
    done
}

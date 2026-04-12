#!/bin/bash

echo-wrap-color() {
    cleaningTag() {
        # global each
        # global color
        local string="$1"
        opentag=$(echo "$string" | grep -E -o '<[^</>]+>')
        if [ -n "$opentag" ];then
            color=$(echo "$opentag" | grep -E -o '[^<>]+')
            string=${string//"$opentag"/}
            closetag="</${color}>"
            if grep -q -F "$closetag" <<< "$string";then
                color_stop=1
                string=${string//"$closetag"/}
            fi
        fi
        each="$string"
    }
    cleaningCloseTag() {
        # global each
        # global color
        local string="$1"
        closetag="</${color}>"
        if grep -q -F "$closetag" <<< "$string";then
            color_stop=1
            string=${string//"$closetag"/}
        fi
        each="$string"
    }
    colorStop() {
        # global color_stop
        if [ -n "$color_stop" ];then
            color=$default_color
            color_stop=
        fi
    }
    local paragraph="$1" words_array default_color="$2"
    [ -z $default_color ] && default_color=_,
    color="$default_color"
    local current_line first_line last
    local max=0
    local min=0
    max=$(tput cols)
    # Angka 6 adalah 4+2.
    # Angka 4 adalah tambahan indent.
    # Angka 2 adalah tambahan dari '# '.
    _max=$((100 + ${#INDENT} + ${#RCM_INDENT} + 2))
    if [ $max -gt $_max ];then
        max=100
        min=80
    else
        max=$((max - ${#INDENT} - ${#RCM_INDENT} - 2))
        min="$max"
    fi
    local i=0
    words_array=($paragraph)
    local count="${#words_array[@]}"
    current_line=
    first_line=1

    wordWrapSentence() {
        for each in "${words_array[@]}"; do
            cleaningTag "$each"
            cleaningCloseTag "$each"
            let i++
            [ "$i" == "$count" ] && last=1 || last=
            if [ -z "$current_line" ]; then
                if [ -n "$first_line" ];then
                    first_line=
                    current_line="$each"
                    __; $color "$each"
                else
                    current_line="$each"
                    __; $color "$each"
                fi
                if [ -n "$last" ];then
                    _.
                fi
            else
                _current_line="${current_line} ${each}"
                if [ "${#_current_line}" -le $min ];then
                    current_line+=" ${each}"
                    $color " ${each}"
                    if [ -n "$last" ];then
                        _.
                    fi
                elif [ "${#_current_line}" -le $max ];then
                    $color " ${each}"; _.
                    current_line=
                else
                    _.; __; $color "$each"
                    current_line="$each"
                    if [ -n "$last" ];then
                        _.
                    fi
                fi
            fi
            colorStop
        done
    }
    temp=$(wordWrapSentence 2>&1)
    echo "$temp" >&2
}

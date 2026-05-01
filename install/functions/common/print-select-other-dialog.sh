#!/bin/bash

print-select-other-dialog() {
    declare -i count
    declare -i new_line
    local source=("${!1}")
    local what="$2"
    local each reference_key
    if [ -z "$what" ];then
        what=value
        if [ "${#source[@]}" -gt 1 ];then
            what=values
        fi
    fi
    _; _.
    words_array=("${source[@]}")
    words_array+=(other)
    echo-wrap-list "Available ${what}:"
    _; _.
    __; _, '['; yellow Enter; _, ']'; _, ' '; yellow T; _, 'ype the value.'; _.
    __; _, '['; yellow Backspace; _, ']'; _, ' '; yellow S; _, 'witch to select list.'; _.
    if [ -z "$is_required" ];then
        __; _, '['; yellow Esc; _, ']'; _, ' '; yellow L; _, 'eave blank and skip.'; _.
    fi
    _; _.
    __ Press the yellow key to select.
    local select_mode=
    local type_mode=
    local skip=
    while true; do
        __; read -rsn 1 -p "Select: " char;
        if [ -z "$char" ];then
            char=t
        fi
        case $char in
            t|T) type_mode=1; echo "$char" >&2; break ;;
            s|S) select_mode=1; echo "$char" >&2; break ;;
            $'\177') select_mode=1; echo "s" >&2; break ;;
            *)
                if [ -n "$is_required" ];then
                    echo >&2; new_line+=1
                else
                    case $char in
                        $'\33') skip=1; echo "l" >&2; break ;;
                        l|L) skip=1; echo "$char" >&2; break ;;
                        *) echo >&2; new_line+=1
                    esac
                fi
        esac
    done
    # Credit: https://stackoverflow.com/questions/5861428/bash-script-erase-previous-line
    PREVIOUS_LINE=5
    if [ -z "$is_required" ];then
        PREVIOUS_LINE=$((PREVIOUS_LINE+1))
    fi
    if [[ -n "$select_mode" ]];then
        PREVIOUS_LINE=$((PREVIOUS_LINE+WRAP_LINE+1+new_line))
        for ((i = 0 ; i < $PREVIOUS_LINE ; i++)); do
            printf '\e[A\e[K' >&2
        done
        __ Available values:
        for ((i = 0 ; i < ${#source[@]} ; i++)); do
            count+=1
            if [ $count -lt 10 ];then
                __; _, '['; yellow $count; _, ']'; _, ' '; _, "${source[$i]}"; _.
            else
                __; _, '['$count']' "${source[$i]}"; _.
            fi
        done
        _; _.
        __; _, '['; yellow Enter; _, ']'; _, ' '; _, 'Type the '; yellow N; _, 'umber key.'; _.
        __; _, '['; yellow Backspace; _, ']'; _, ' '; _, 'Switch to '; yellow T; _, 'ype other value.'; _.
        if [ -z "$is_required" ];then
            __; _, '['; yellow Esc; _, ']'; _, ' '; yellow L; _, 'eave blank and skip.'; _.
        fi
        _; _.
        __ Press the yellow key to select.
        count_max="${#source[@]}"
        if [ $count_max -gt 9 ];then
            count_max=9
        fi
        while true; do
            __; read -rsn 1 -p "Select: " char;
            if [ -z "$char" ];then
                char=n
            fi
            case $char in
                t|T) type_mode=1; echo "$char" >&2; break ;;
                $'\177') type_mode=1; echo "s" >&2; break ;;
                n|N) echo "$char" >&2; break ;;
                [1-$count_max])
                    echo "$char" >&2
                    i=$((char - 1))
                    value="${source[$i]}"
                    break ;;
                *)
                    if [ -n "$is_required" ];then
                        echo >&2
                    else
                        case $char in
                            $'\33') skip=1; echo "l" >&2; break ;;
                            l|L) skip=1; echo "$char" >&2; break ;;
                            *) echo >&2
                        esac
                    fi
            esac
        done
        if [[ -z "$type_mode" && -z "$skip" ]];then
            if [ -z "$value" ];then
                _; _.
            fi
            until [ -n "$value" ];do
                __; read -p "Type the number: " value
                if [[ $value =~ [^0-9] ]];then
                    value=
                    __; red Please type one of available number.;_.
                fi
                if [[ $value =~ ^0 ]];then
                    value=
                    __; red Please type one of available number.;_.
                fi
                if [ -n "$value" ];then
                    value=$((value - 1))
                    value="${source[$value]}"
                    if [ -z "$value" ];then
                        __; red Please type one of available number.;_.
                    fi
                fi
            done
            _; _.
            echo-wrap-color "Argument <magenta>${parameter}</magenta> filled with value <yellow>$value</yellow> which is selected from the list." green
        fi
    fi
    if [[ -n "$type_mode" ]];then
        _; _.
        if [ -z "$value" ];then
            if [ -n "$is_required" ];then
                __; read -p "Type the value: " value
            elif [ -z "$skip" ];then
                __; read -p "Type the value or leave blank to skip: " value
            fi
            is_typing=1
        fi
    fi
}

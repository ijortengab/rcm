#!/bin/bash

rcm-yaml() {

    # Required Global Function.
    [[ $(type -t array) == function ]] || { error "The array function is required."; x; }
    [[ $(type -t array-pop) == function ]] || { error "The array-pop function is required."; x; }

    local command
    local value
    local count below
    local default_indent='  '

    # Command.
    if [ -n "$1" ];then
        command=
        case "$1" in
            init) command="$1"; shift ;;
            find) command="$1"; shift ;;
            column) command="$1"; shift ;;
        esac
        if [ -z "$command" ];then
            error Command unknown: '`'"$1"'`'.; x
        fi
    fi

    action-compare() {
        array "$@"
    }

    action-get() {
        array "$@"
    }

    action-increase() {
        local value
        array "$@"
        value="$_return_value"
        if [ -z "$value" ];then
            value=0
        fi
        value=$((value + 1))
        array "$@" = $value
        rebuild
    }

    action-set() {
        local args=()
        local value
        while [ $# -gt 0 ]; do
            args+=("$1"); shift
        done
        array-pop args[@]; args=("${_return_array[@]}")
        value="$_return_value"
        array "${args[@]}" = "$value"
        rebuild
    }

    action-append() {
        local args=()
        local value
        while [ $# -gt 0 ]; do
            args+=("$1"); shift
        done
        array-pop args[@]; args=("${_return_array[@]}")
        value="$_return_value"
        array "${args[@]}" '[]' "$value"
        rebuild
    }

    rebuild() {
        if [[ "${array:(-1)}" == $'\n' ]];then
            array="${array::(-1)}"
        fi
        part_2=$(sed -E -e 's,^,  ,' -e '1s,^  ,- ,' <<< "$array")

        if [ -n "$part_1" ];then
            if [[ ! "${part_1:(-1)}" == $'\n' ]];then
                part_1+=$'\n'
            fi
        fi
        if [ -n "$part_2" ];then
            if [[ ! "${part_2:(-1)}" == $'\n' ]];then
                part_2+=$'\n'
            fi
        fi
        if [ -n "$part_3" ];then
            if [[ ! "${part_3:(-1)}" == $'\n' ]];then
                part_3+=$'\n'
            fi
        fi
        # Reset.
        RCM_YAML=
        [ -n "$part_1" ] && RCM_YAML+="${part_1}"
        [ -n "$part_2" ] && RCM_YAML+="${part_2}"
        [ -n "$part_3" ] && RCM_YAML+="${part_3}"
    }

    command-init() {
        RCM_YAML='# Created at '`date +%Y%m%d-%H%M%S`$'\n'
    }

    command-find() {
        [ -z "$RCM_YAML" ] && { error "Variable RCM_YAML is required."; x; }
        # global part_1
        # global part_2
        # global part_3
        # global array
        local key="$1"; shift
        local parameter="$1"; shift
        local count find found below each
        local line_number_found
        local action

        find='^- '"$key"': '"$parameter"'$'
        line_number_found=$(grep -n -- "$find" <<< "$RCM_YAML" | head -1 | cut -d: -f1)

        if [ -z "$line_number_found" ];then
            return 1
        fi
        find='^- '"$key"': '
        unset count; declare -i count; count=$line_number_found
        while true; do
            count+=1
            below=`sed -n ${count}p <<< "$RCM_YAML"`
            if [ -z "$below" ];then
                break
            fi
            if grep -q -- "$find" <<< "$below"; then
                break
            fi
        done

        if [[ "$line_number_found" -eq 1 ]];then
            part_1=
        else
            part_1=$(sed -n '1,'$((line_number_found - 1))'p' <<< "$RCM_YAML")
        fi
        part_2=$(sed -n $line_number_found','$((count - 1))'p' <<< "$RCM_YAML")
        array=$(sed -E 's,^[ -][ ],,' <<< "$part_2")
        part_3=$(sed -n $count',$p' <<< "$RCM_YAML")

        if [[ "$1" == then && -n "$2" ]];then
            action="$2"
            shift 2
            # Execute action.
            if [[ $(type -t "action-${action}") == function ]];then
                action-${action} "$@"
            else
                error The '`'"action-${action}"'`' function is not defined yet.; x
            fi
        fi
    }

    # Reference: https://www.php.net/manual/en/function.array-column.php
    command-column() {
        [ -z "$RCM_YAML" ] && { error "Variable RCM_YAML is required."; x; }
        local array_local="$RCM_YAML"
        local count find found below each
        local storage=()
        local array

        find="$1"
        array="${array_local}"
        array

        for array in "${_return_array[@]}"; do
            array "$find"
            storage+=("${_return_value}")
        done

        # Clone to global variable.
        _return_array=("${storage[@]}")
    }

    # Execute command.
    if [ -n "$command" ];then
        if [[ $(type -t "command-${command}") == function ]];then
            command-${command} "$@"
        else
            error The '`'"command-${command}"'`' function is not defined yet.; x
        fi
    fi
}

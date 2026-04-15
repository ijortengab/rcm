#!/bin/bash

rcm-prompt-options-option() {
    local bypass_dialog=

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --bypass-dialog) bypass_dialog=1; shift ;;
            --[^-]*) shift ;;
            *) shift ;;
        esac
    done

    # Required Global variable.
    [ -z "$RCM_OPTION" ] && { error "Variable RCM_OPTION is required."; x; }

    # Local variable as property.
    local option="$RCM_OPTION"
    local count below
    local parameter
    local is_required=
    local is_flag=
    local value_addon=
    local description=
    local placeholders=
    local find
    local or_other=
    local available_values=()
    local available_values_command=
    local available_values_arguments=
    local available_values_command_executed=
    local save_history=1
    local history_value=
    local default_value=
    local prepopulate_value=
    local boolean=
    local value=
    local prepopulate_boolean=

    parse-parameter() {
        local first_line_trimmed residue
        # global option
        # global parameter
        # global is_required is_flag value_addon
        first_line_trimmed=`sed -n 1p <<< "$option" | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//'`
        # Contoh YANG BENAR:
        # --path
        # --path=DIR
        # --path[=DIR]
        # Contoh YANG SALAH:
        # --path=[DIR]
        parameter=`echo "$first_line_trimmed" | grep -E -o -- '^--[^-_\[\=0-9][^\[\=]+'`
        if [ -z "$parameter" ];then
            error Format of parameter is not correct: '`'"$first_line_trimmed"'`'.; x
        fi
        residue="${first_line_trimmed##$parameter}"
        if [ -n "$residue" ];then
            while true;do
                if grep -q -E -o '^\[\=.+\]$' <<< "${residue}";then
                    break
                fi
                if grep -q -E -o '^=.+$' <<< "${residue}";then
                    is_required=1
                    break
                fi
                break
            done
        else
            is_flag=1
        fi
        if [[ "$parameter" == '--' ]];then
            is_required=
            is_flag=
            value_addon=multivalue
        fi
    }

    parse-description() {
        # global option
        # global description
        # global placeholders
        local count below
        unset count
        declare -i count
        count=2
        while true; do
            below=`sed -n ${count}p <<< "$option" | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//'`
            if [ -z "$below" ];then
                break
            fi
            if [[ "${below:0:1}" == '[' ]];then
                placeholders+="$below"
                placeholders+=$'\n'
            else
                description+="$below"
                description+=$'\n'
            fi
            count+=1
        done
    }

    parse-available-values() {
        local found="$1"
        local each line
        # global available_values
        # global description
        # global placeholders
        # global or_other
        description=`echo "$description" | sed -E 's/ *Available values?: ([^\.]+)\.//i'`
        if grep -i -q -E 'or others?' <<< "$found";then
            or_other=1
            found=`echo "$found" | sed -E 's/or others?$//'`
        fi
        if [ -n "$placeholders" ];then
            IFS=',' read -ra found <<< "$found"
            available_values=()
            for each in "${found[@]}"; do
                each=$(echo "${each}" | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
                if [ -z "$each" ];then
                    continue
                fi
                if grep -q -F "${each}: " <<< "$placeholders";then
                    line=`grep -F "${each}: " <<< "$placeholders"`
                    line=$(echo "${line}" | cut -d: -f2 | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
                    available_values+=("$line")
                else
                    available_values+=("$each")
                fi
            done
        else
            IFS=',' read -ra found <<< "$found"
            available_values=()
            for each in "${found[@]}"; do
                each=$(echo "${each}" | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
                if [ -z "$each" ];then
                    continue
                fi
                available_values+=("$each")
            done
        fi
    }

    parse-available-values-from-command() {
        local found="$1"
        local line
        local find replace
        # global available_values
        # global description
        # global or_other
        # global available_values_source
        # global history_value
        # global save_history
        # global available_values_command=
        # global available_values_arguments=
        description=`echo "$description" | sed -E 's/ *Values? available from command:\s*[^\(\ ]+\((\)|[^\)]+\))(\.|, or others?\.)//i'`
        if grep -i -q -E 'or others?' <<< "$found";then
            or_other=1
        fi
        # Tidak ada history jika value dari command.
        history_value=
        save_history=
        line=$(echo "$found" | sed -n -E 's/^Values? available from command:\s*([^\)]+\))(\.$|, or others?\.$)/\1/p')
        available_values_command=$(echo "$line" | sed -n -E 's/^([^\(]+)\(([^\)]*)\)$/\1/p')
        available_values_arguments=$(echo "$line" | sed -n -E 's/^([^\(]+)\(([^\)]*)\)$/\2/p')
        if [ -n "$available_values_arguments" ];then
            if [ -n "$RCM_ARGUMENT_PLACEHOLDERS" ];then
                while read line; do
                    find=$(echo ${line} | sed -E 's|^([^:]+):.*|\1|' | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
                    replace=$(echo ${line} | sed -E 's|^[^:]+:(.*)|\1|' | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
                    available_values_arguments="${available_values_arguments/"$find"/"$replace"}"
                done <<< "$RCM_ARGUMENT_PLACEHOLDERS"
            fi
        fi
    }

    parse-default-value() {
        local found="$1"
        # global description
        # global default_value
        description=`echo "$description" | sed -E 's/ *Default value from variable:? ([^\.]+)\.//i'`
        default_value="${!found}"
    }

    parse-prepopulate-value() {
        local found="$1"
        local find replace
        # global description
        # global prepopulate_value
        description=`echo "$description" | sed -E 's/ *Prepopulate value from variable:? ([^\.]+)\.//i'`
        if [ -n "$RCM_ARGUMENT_PLACEHOLDERS" ];then
            while read line; do
                find=$(echo ${line} | sed -E 's|^([^:]+):.*|\1|' | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
                replace=$(echo ${line} | sed -E 's|^[^:]+:(.*)|\1|' | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
                found="${found/"$find"/"$replace"}"
            done <<< "$RCM_ARGUMENT_PLACEHOLDERS"
        fi
        prepopulate_value="${!found}"
    }

    print-list-values-dialog() {
        # global available_values_command
        # global available_values_arguments
        # global available_values_command_executed
        local _command="$available_values_command"
        local _arguments="$available_values_arguments"
        if [[ -n "$available_values_command" && -z "$available_values_command_executed" ]];then
            available_values_command_executed=1
            if command -v "$_command" > /dev/null;then
                _; _.
                [ -n "$_arguments" ] && _arguments=' '"$_arguments"
                echo-wrap-color "Value available from command: <magenta>${_command}${_arguments}</magenta>"
                mktemp=$(mktemp -p /dev/shm)
                ${_command}${_arguments} > "$mktemp"
                exit_code=$?
                while read line;do
                    [ -n "$line" ] && available_values+=("$line")
                done < "$mktemp"
                rm "$mktemp"
            fi
        fi

        while [[ $# -gt 0 ]]; do
            ArrayRemove "$1" available_values[@]
            available_values=("${_return[@]}")
            unset _return
            shift
        done
        if [ "${#available_values[@]}" -gt 0 ];then
            if [ -n "$or_other" ];then
                print-select-other-dialog available_values[@]
            elif [[ "${#available_values[@]}" -eq 1 && -n "$is_required" ]];then
                value="${available_values[0]}"
                _; _.
                __; _, "Available value: "; yellow "$value";  _, '.'; _.
                if [ -z "$autoyes" ];then
                    _; _.
                    echo-wrap 'The one and only available value is selected.'
                    read-true
                    if [ -z "$RCM_BOOLEAN" ];then
                        value=' '
                    fi
                else
                    _; _.
                    echo-wrap-color "Argument <magenta>${parameter}</magenta> filled with the only available value <yellow>$value</yellow> automatically." green
                fi
            else
                print-select-dialog available_values[@]
            fi
        else
            _; _.
            if [[ -n "$available_values_command" && ! $exit_code -eq 0 ]];then
                is_required=
                __; _, Argument; _, ' '; _, "$parameter"; _, ' ';  _, set to skip by command,' '; _, pass; _, .; _.
            elif [[ -n "$available_values_command" && -z "$or_other" ]];then
                __; _, No value available,' '; red Process Terminated; _, .; x
            else
                if [ -n "$default_value" ];then
                    __; _, Leave blank will use default value.; _.
                    label=$(_, 'Type the value [' 2>&1; yellow "$default_value" 2>&1; _, ']: ' 2>&1)
                    __; read -p "$label" value
                    [ -z "$value" ] && value=' '
                elif [ -n "$is_required" ];then
                    __; read -p "Type the value: " value
                else
                    __; read -p "Type the value or leave blank to skip: " value
                fi
                is_typing=1
            fi
        fi
    }

    print-backup-dialog() {
        _; _.
        echo-wrap-color "Restore the value: <yellow>$backup_value</yellow>. Would you like to use that value?"
        read-true
        if [ -n "$RCM_BOOLEAN" ];then
            _; _.
            value="$backup_value";
            if [ -n "$is_flag" ];then
                echo-wrap-color "Argument <magenta>${parameter}</magenta> added with value <yellow>$value</yellow> which is restored." green
            else
                echo-wrap-color "Argument <magenta>${parameter}</magenta> filled with value <yellow>$value</yellow> which is restored." green
            fi
        fi
    }

    print-backup-flag-dialog() {
        _; _.
        echo-wrap "This argument has been added before. Would you like to restore this argument?"
        read-true
        if [ -n "$RCM_BOOLEAN" ];then
            _; _.
            echo-wrap-color "Argument <magenta>${parameter}</magenta> added which is restored." green
        fi
    }

    print-history-dialog() {
        local count_max=$(wc -l <<< "$history_value")
        if [ $count_max -gt 9 ];then
            count_max=9
        fi
        unset count
        declare -i count
        count=0
        _; _.
        echo-wrap 'There are values available from history.'

        while read opt; do
            count+=1
            __; _, '['; yellow $count; _, ']'; _, ' '; _, "$opt"; _.
        done <<< "$history_value"
        _; _.
        __;  _, '['; yellow Enter; _, ']'; _, ' '; yellow S; _, 'kip and continue.'; _.
        _; _.
        __ Press the yellow key to select.
        while true; do
            __; read -rsn 1 -p "Select: " char;
            if [ -z "$char" ];then
                char=s
            fi
            case $char in
                s|S) echo "$char" >&2; break ;;
                [1-$count_max])
                    echo "$char" >&2
                    value=$(sed -n ${char}p <<< "$history_value")
                    save_history=
                    break ;;
                *) echo >&2
            esac
        done
    }

    print-select-dialog() {
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
        echo-wrap-list "Available ${what}:"
        _; _.
        __; _, '['; yellow Enter; _, ']'; _, ' '; yellow T; _, 'ype the value.'; _.
        __; _, '['; yellow Backspace; _, ']'; _, ' '; yellow S; _, 'witch to select list.'; _.
        if [ -z "$is_required" ];then
            __; _, '['; yellow Esc; _, ']'; _, ' '; yellow L; _, 'eave blank and skip.'; _.
        fi
        _; _.
        __ Press the yellow key to select.
        select_mode=
        local type_mode=
        local skip=
        while true; do
            __; read -rsn 1 -p "Select: " char;
            if [ -z "$char" ];then
                char=t
            fi
            if [ -n "$is_required" ];then
                case $char in
                    t|T) type_mode=1; echo "$char" >&2; break ;;
                    s|S) select_mode=1; echo "$char" >&2; break ;;
                    $'\177') select_mode=1; echo "s" >&2; break ;;
                    *) echo >&2; new_line+=1
                esac
            else
                case $char in
                    t|T) type_mode=1; echo "$char" >&2; break ;;
                    s|S) select_mode=1; echo "$char" >&2; break ;;
                    $'\177') select_mode=1; echo "s" >&2; break ;;
                    $'\33') skip=1; echo "l" >&2; break ;;
                    l|L) skip=1; echo "$char" >&2; break ;;
                    *) echo >&2; new_line+=1
                esac
            fi
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
            __ "Available ${what}:"
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
            if [[ -z "$skip" ]];then
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
        fi
        while true; do
            if [ -n "$value" ];then
                ArraySearch "$value" source[@]
                reference_key="$_return"; unset _return; # Clear.
                if [ -n "$reference_key" ];then
                    break
                else
                    __; red Please type one of available values.;_.
                    value=
                fi
            else
                if [ -n "$is_required" ];then
                    __; read -p "Type the value: " value
                elif [ -z "$skip" ];then
                    __; read -p "Type the value or leave blank to skip: " value
                    if [ -z "$value" ];then
                        break
                    fi
                else
                    break
                fi
            fi
        done
    }

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

    parse-parameter

    parse-description

    is_typing=
    is_press=
    is_flagged=

    if grep -q -i -E '(^|\.\s)Multivalue\.' <<< "$description";then
        value_addon=multivalue
    fi
    values=()
    flags=1
    backup_value=
    backup_flag=
    if [ -f "$backup_storage" ];then
        backup_value=$(grep -- "^${parameter}=.*$" "$backup_storage" | tail -1 | sed -E 's|'"^${parameter}=(.*)$"'|\1|')
        backup_flag=$(grep -q -- "^${parameter}$" "$backup_storage" && echo 1)
    fi
    if [ -f "$history_storage" ];then
        history_value=$(grep -- "^${parameter}=.*$" "$history_storage" | tail -9 | sed -E 's|'"^${parameter}=(.*)$"'|\1|')
    fi

    while true; do
        find=`echo "$description" | grep -i -o -E 'Available values?:[^\.]+\.'| sed -n -E 's/^Available values?: ([^\.]+)\.$/\1/ip'`
        if [ -n "$find" ];then
            parse-available-values "$find"
            break
        fi
        find=`echo "$description" | grep -i -o -E 'Values? available from command:\s*[^\(\ ]+\((\)|[^\)]+\))(\.|, or others?\.)'`
        if [ -n "$find" ];then
            parse-available-values-from-command "$find"
            break
        fi
        break
    done

    while true; do
        find=`echo "$description" | grep -i -o -E 'Prepopulate value from variable:? [^\.]+\.'| sed -n -E 's/^Prepopulate value from variable:? ([^\.]+)\.$/\1/ip'`
        if [ -n "$find" ];then
            parse-prepopulate-value "$find"
            break
        fi
        find=`echo "$description" | grep -i -o -E 'Default value from variable:? [^\.]+\.'| sed -n -E 's/^Default value from variable:? ([^\.]+)\.$/\1/ip'`
        if [ -n "$find" ];then
            parse-default-value "$find"
            break
        fi
        break
    done

    if [ -n "$RCM_ARGUMENT_PLACEHOLDERS" ];then
        while read line; do
            find=$(echo ${line} | sed -E 's|^([^:]+):.*|\1|' | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
            replace=$(echo ${line} | sed -E 's|^[^:]+:(.*)|\1|' | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
            description="${description/"$find"/"$replace"}"
        done <<< "$RCM_ARGUMENT_PLACEHOLDERS"
    fi
    _; _.
    if [ -n "$is_flag" ];then
        _ 'Argument '; magenta "${parameter}";_, ' is '; _, optional;_, '.'; _.
    else
        if [ -n "$is_required" ];then
            _ 'Argument '; magenta "${parameter}";_, ' is '; yellow required;_, '.'; _.
        else
            _ 'Argument '; magenta "${parameter}";_, ' is '; _, optional;_, '.'; _.
            _; _.
            __; _, Do you want fill with value?; _.
            read-false
            if [ -z "$RCM_BOOLEAN" ]; then
                backup_value=
                history_value=
                value=' '
            fi
        fi
    fi
    if [ -n "$description" ];then
        _; _.
        while read line; do
            echo-wrap "$line"
        done <<< "$description"
    fi

    if [ -n "$is_flag" ];then
        for each in "${RCM_PREPOPULATE_ARGUMENT_OPTIONS[@]}";do
            if grep -q -- "^${parameter}-\$" <<< "$each";then
                prepopulate_boolean=0
                break
            elif grep -q -- "^${parameter}-=" <<< "$each";then
                # Ada argument lupa dihapus, contoh: --with-roundcube- mail.example.org
                # maka set sebagai skip.
                prepopulate_boolean=0
                break
            elif grep -q -- "^${parameter}\$" <<< "$each";then
                prepopulate_boolean=1
                if [[ "$value_addon" == 'multivalue' ]];then
                    ArrayRemove "$parameter" RCM_PREPOPULATE_ARGUMENT_OPTIONS[@]
                    RCM_PREPOPULATE_ARGUMENT_OPTIONS=("${_return[@]}")
                    unset _return
                fi
                break
            fi
        done
        # Reset first.
        RCM_BOOLEAN=
        if [[ "$prepopulate_boolean" == 0 ]];then
            _; _.
            __; _, Argument; _, ' '; _, "$parameter"; _, ' ';  _, set to skip by user,' '; _, pass; _, .; _.
            backup_flag=
            boolean=' '
        elif [[ "$prepopulate_boolean" == 1 ]];then
            _; _.
            if [ -n "$value" ];then
                echo-wrap-color "Argument <magenta>${parameter}</magenta> prepopulated with value <yellow>${value}</yellow>.'" green
            else
                echo-wrap-color "Argument <magenta>${parameter}</magenta> prepopulated." green
                if [[ "$value_addon" == 'multivalue' ]];then
                    found=
                    for each in "${RCM_PREPOPULATE_ARGUMENT_OPTIONS[@]}";do
                        if grep -q -- "^${parameter}\$" <<< "$each";then
                            found=1
                            let flags++
                            echo-wrap-color "Argument <magenta>${parameter}</magenta> prepopulated." green
                        fi
                    done
                    # Biar tidak membingunkan kedepannya, hapus saja semua dari array.
                    if [ -n "$found" ];then
                        ArrayRemoveAll "$parameter" RCM_PREPOPULATE_ARGUMENT_OPTIONS[@]
                        RCM_PREPOPULATE_ARGUMENT_OPTIONS=("${_return[@]}")
                        unset _return
                    fi
                fi
            fi
            backup_flag=
            boolean=1
        fi

        # Jika $parameter merupakan other option, maka skip semua dialog.
        # jika tidak ada prepopulate value.
        if [ -n "$bypass_dialog" ];then
            if [ -z "$prepopulate_boolean" ];then
                backup_flag=
                boolean=' '
            fi
        fi

        if [ -n "$backup_flag" ];then
            print-backup-flag-dialog
            boolean="$RCM_BOOLEAN"
        fi
        if [ -z "$boolean" ];then
            _; _.
            __; _, Add this argument?; _.
            read-false
            boolean="$RCM_BOOLEAN"
            is_press=1
        fi
        if [[ "$boolean" == ' ' ]];then
            boolean=
        fi
        # Populate placeholders.
        if [ -n "$RCM_ARGUMENT_PLACEHOLDERS" ];then
            RCM_ARGUMENT_PLACEHOLDERS+=$'\n'
        fi
        if [ -n "$boolean" ]; then
            is_flagged=1
                i=1
                until [[ $i -gt $flags ]];do
                    RCM_ARGUMENT_PASS+=("${parameter}")
                    RCM_ARGUMENT_PREVIEW+=("${parameter}")
                    RCM_ARGUMENT_PREVIEW_REAL+=("${parameter}")
                    let i++
                done
            # Populate placeholders.
            if [ -n "$value" ];then
                RCM_ARGUMENT_PLACEHOLDERS+='['"$parameter"']: '"$value"
                RCM_ARGUMENT_PLACEHOLDERS+=$'\n'
                RCM_ARGUMENT_PLACEHOLDERS+='['"$parameter"'^^]: '"${value^^}"
            else
                RCM_ARGUMENT_PLACEHOLDERS+='['"$parameter"']: '"1"
            fi
        else
            # Populate placeholders.
            RCM_ARGUMENT_PLACEHOLDERS+='['"$parameter"']: '"0"
            RCM_ARGUMENT_PREVIEW+=("${parameter}-")
        fi
        if [ -n "$boolean" ];then
            if [ -n "$is_press" ];then
                if [ -n "$value" ];then
                    if [ -n "$is_typing" ];then
                        _; _.
                        echo-wrap-color "Argument <magenta>${parameter}</magenta> added with value <yellow>$value</yellow> manually." green
                    fi
                else
                    _; _.
                    echo-wrap-color "Argument <magenta>${parameter}</magenta> added manually." green
                fi
            fi
        fi
    elif [[ "$parameter" == '--' ]];then
        _ 'Argument '; magenta ${parameter};_, ' is '; _, optional;_, '.'; _.
        if [ -n "$description" ];then
            _; _.
            while read line; do
                echo-wrap "$line"
            done <<< "$description"
        fi
        __; _, Add value?; _.
        read-false
        if [ -n "$RCM_BOOLEAN" ]; then
            if [ -n "$history_value" ];then
                print-history-dialog
                if [ -n "$value" ];then
                    _; _.
                    echo-wrap-color "Argument <magenta>${parameter}</magenta> filled with value <yellow>$value</yellow> which is selected from the list of history." green
                fi
            fi
            if [ -z "$value" ];then
                __; read -p "Type the value: " value
            fi
            if [ -n "$value" ];then
                RCM_ARGUMENT_PASS+=("${parameter} ${value}")
                RCM_ARGUMENT_PREVIEW+=("${parameter} ${value}")
                RCM_ARGUMENT_PREVIEW_REAL+=("${parameter} ${value}")
            fi
        fi
    else
        if [ -n "$default_value" ];then
            _; _.
            echo-wrap-color "Default value: <yellow>${default_value}</yellow>."
        fi
        if [ -n "$prepopulate_value" ];then
            backup_value=
            history_value=
        fi
        for each in "${RCM_PREPOPULATE_ARGUMENT_OPTIONS[@]}";do
            if grep -q -- "^${parameter}-\$" <<< "$each";then
                _; _.
                __; _, Argument; _, ' '; _, "$parameter"; _, ' ';  _, set to skip by user,' '; _, pass; _, .; _.
                backup_value=
                history_value=
                is_required=
                value=' '
                break
            fi
        done
        # Jika tidak multivalue, tapi di prepopulate berkali-kali, maka
        # kita menggunakan last value.
        for each in "${RCM_PREPOPULATE_ARGUMENT_OPTIONS[@]}";do
            if grep -q -- "^${parameter}=" <<< "$each";then
                value=$(echo "$each" | sed -n -E 's|^[^=]+=(.*)|\1|p')
                if [[ "$value_addon" == 'multivalue' ]];then
                    values+=("$value")
                fi
                _; _.
                echo-wrap-color "Argument <magenta>${parameter}</magenta> prepopulated with value <yellow>$value</yellow>." green
                backup_value=
            fi
        done

        # Jika $parameter merupakan other option, maka skip semua dialog.
        # jika tidak ada prepopulate value.
        if [ -n "$bypass_dialog" ];then
            if [ -z "$value" ];then
                backup_value=
                value=' '
            fi
        fi

        # Backup dialog belum mendukung multivalue.
        if [ -n "$backup_value" ];then
            print-backup-dialog
        fi
        if [ -z "$value" ];then
            # History dialog belum mendukung multivalue.
            if [ -n "$history_value" ];then
                print-history-dialog
                if [ -n "$value" ];then
                    _; _.
                    echo-wrap-color "Argument <magenta>${parameter}</magenta> filled with value <yellow>$value</yellow> which is selected from the list of history." green
                fi
            fi
        fi
        if [[ -z "$value" && -n "$prepopulate_value" ]];then
            # Value from prepopulate argument tetap diutamakan
            # daripada variable.
            value="$prepopulate_value"
            _; _.
            echo-wrap-color "Argument <magenta>${parameter}</magenta> filled with value <yellow>$value</yellow> from environment variable." green
        fi
        # Available value dialog juga belum mendukung multivalue.
        if [ -z "$value" ];then
            print-list-values-dialog
        fi
        if [ -n "$is_required" ];then
            until [[ -n "$value" ]];do
                __; read -p "Type the value: " value
                is_typing=1
            done
        fi
        if [[ "$value" == ' ' ]];then
            value=
        fi
        if [[ -z "$value" && -n "$default_value" ]];then
            value="$default_value"
            suffix=' automatically'
        fi
        # Populate placeholders.
        if [ -n "$RCM_ARGUMENT_PLACEHOLDERS" ];then
            RCM_ARGUMENT_PLACEHOLDERS+=$'\n'
        fi
        if [ -n "$value" ];then
            # Sanitize user input
            # Menghapus karakter aneh karena menekan arrow up/down/right/left di keyboard.
            # Credit: https://stackoverflow.com/a/47918586
            if [ "${#values[@]}" -eq 0 ];then
                values=("$value")
            fi
            for value in "${values[@]}";do
                value=$(echo "$value" | tr -cd '\11\12\15\40-\176' | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
                RCM_ARGUMENT_PASS+=("${parameter}=${value}")
                [[ "$value" =~ ' ' ]] && _value="'$value'" || _value="$value"
                RCM_ARGUMENT_PREVIEW+=("${parameter}=${_value}")
                RCM_ARGUMENT_PREVIEW_REAL+=("${parameter}=${_value}")
                if [ "${#available_values[@]}" -gt 0 ];then
                    ArrayRemove "$value" available_values[@]
                    available_values=("${_return[@]}")
                    unset _return
                fi
            done
            # Placeholder tidak berlaku untuk multivalue. @todo, masukkan ke dokumentasi.
            # Hanya berlaku nilai terakhir.
            RCM_ARGUMENT_PLACEHOLDERS+='['"$parameter"']: '"$value"
            RCM_ARGUMENT_PLACEHOLDERS+=$'\n'
            RCM_ARGUMENT_PLACEHOLDERS+='['"$parameter"'^^]: '"${value^^}"
        else
            RCM_ARGUMENT_PLACEHOLDERS+='['"$parameter"']: -'
            RCM_ARGUMENT_PREVIEW+=("${parameter}-")
        fi
        if [[ -n "$value" && -n "$is_typing" ]];then
            _; _.
            [ -z "$suffix" ] && suffix=' manually'
            echo-wrap-color "Argument <magenta>${parameter}</magenta> filled with value <yellow>$value</yellow>${suffix}." green
        fi
    fi
    # Backup to text file.
    if [ -n "$value" ];then
        # Belum support history untuk kasus multivalue.
        mkdir -p $(dirname "$backup_storage")
        echo "${parameter}=${value}" >> "$backup_storage"
        if [ -f "$history_storage" ];then
            if grep -q -- "^${parameter}=${value}\$" "$history_storage";then
                save_history=
            fi
            if [[ "$value" =~ []\[] ]];then
                if grep -q -F -- "${parameter}=${value}" "$history_storage";then
                    save_history=
                fi
            fi
        fi
        if [ -n "$save_history" ];then
            mkdir -p $(dirname "$history_storage");
            echo "${parameter}=${value}" >> "$history_storage"
        fi
    fi
    # Backup to text file for flag.
    if [ -n "$boolean" ];then
        mkdir -p $(dirname "$backup_storage")
        echo "${parameter}" >> "$backup_storage"
    fi
    if [[ "$value_addon" == 'multivalue' ]];then
        again=1
        until [ -z "$again" ]; do
            is_press=
            RCM_BOOLEAN=
            if [ -n "$is_flag" ];then
                if [[ -n "$is_flagged" ]];then
                    # Reset condition before multivalue.
                    is_flagged=
                    _; _.
                    __ Add this argument again?
                    read-false
                    is_press=1
                fi
            else
                if [[ -n "$value" ]];then
                    # Reset condition before multivalue.
                    value_before="$value"
                    value=
                    _; _.
                    __ Add another value?
                    read-false
                    is_press=1
                fi
            fi
            if [ -n "$RCM_BOOLEAN" ];then
                if [ -n "$is_flag" ];then
                    RCM_ARGUMENT_PASS+=("${parameter}")
                    RCM_ARGUMENT_PREVIEW+=("${parameter}")
                    RCM_ARGUMENT_PREVIEW_REAL+=("${parameter}")
                    is_flagged=1
                elif [[ "$parameter" == '--' ]];then
                    if [ -n "$history_value" ];then
                        print-history-dialog
                        if [ -n "$value" ];then
                            _; _.
                            echo-wrap-color "Argument <magenta>${parameter}</magenta> filled with value <yellow>$value</yellow> which is selected from the list of history." green
                        fi
                    fi
                    if [ -z "$value" ];then
                        _; _.
                        __; read -p "Type the value or leave blank to skip: " value
                        is_typing=1
                    fi
                    if [ -n "$value" ];then
                        RCM_ARGUMENT_PASS+=("${value}")
                        RCM_ARGUMENT_PREVIEW+=("${value}")
                        RCM_ARGUMENT_PREVIEW_REAL+=("${value}")
                    fi
                else
                    print-list-values-dialog "$value_before"
                    if [ -n "$value" ];then
                        # Sanitize user input
                        # Menghapus karakter aneh karena menekan arrow up/down/right/left di keyboard.
                        # Credit: https://stackoverflow.com/a/47918586
                        value=$(echo "$value" | tr -cd '\11\12\15\40-\176' | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
                        RCM_ARGUMENT_PASS+=("${parameter}=${value}")
                        [[ "$value" =~ ' ' ]] && _value="'$value'" || _value="$value"
                        RCM_ARGUMENT_PREVIEW+=("${parameter}=${_value}")
                        RCM_ARGUMENT_PREVIEW_REAL+=("${parameter}=${_value}")
                    fi
                fi
                # Backup to text file.
                if [ -n "$value" ];then
                    mkdir -p $(dirname "$backup_storage");
                    echo "${parameter}=${value}" >> "$backup_storage"
                    if [ -f "$history_storage" ];then
                        if grep -q -- "^${parameter}=${value}\$" "$history_storage";then
                            save_history=
                        fi
                    fi
                    if [ -n "$save_history" ];then
                        mkdir -p $(dirname "$history_storage");
                        echo "${parameter}=${value}" >> "$history_storage"
                    fi
                fi
                if [[ -n "$value" && "$is_typing" ]];then
                    _; _.
                    echo-wrap-color "Argument <magenta>${parameter}</magenta> filled again with value <yellow>$value</yellow> manually." green
                fi
                if [[ -n "$is_flagged" && "$is_press" ]];then
                    _; _.
                    echo-wrap-color "Argument <magenta>${parameter}</magenta> added again manually." green
                fi
            else
                again=
            fi
        done
    fi

}

# parse-options.sh \
# --compact \
# --clean \
# --no-hash-bang \
# --no-original-arguments \
# --no-error-invalid-options \
# --no-rebuild-arguments \
# --without-end-options-first-operand \
# --without-end-options-double-dash \
# --no-error-require-arguments << EOF | clip
# INCREMENT=(
# )
# FLAG=(
# '--bypass-dialog'
# )
# VALUE=(
# )
# MULTIVALUE=(
# )
# FLAG_VALUE=(
# )
# CSV=(
# )
# OPERAND=(
# )
# EOF
# clear

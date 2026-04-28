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
    local conditional

    parse-parameter() {
        local type
        local is_multiple
        local is_required
        local first_line_trimmed residue

        # global option
        # global parameter
        # global is_required is_flag value_addon
        first_line_trimmed=`sed -n 1p <<< "$option" | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//'`

        # Contoh:
        # --path
        # --path=DIR
        # --path[=DIR]
        # --path=[DIR]
        parameter=`echo "$first_line_trimmed" | grep -E -o -- '^--[^-_\[\=0-9\.][^\[\=\.]+'`
        if [ -z "$parameter" ];then
            error Format of parameter is not correct: '`'"$first_line_trimmed"'`'.; x
        fi
        residue="${first_line_trimmed##$parameter}"
        if [ -n "$residue" ];then
            if [[ "$residue" =~ \.\.\.$ ]];then
                value_addon=multivalue
                is_multiple=1
                residue="${residue::-3}"
            fi
        fi
        if [ -n "$residue" ];then
            while true;do
                if grep -q -E -o '^\=\[.+\]$' <<< "${residue}";then
                    type=value
                    break
                fi
                if grep -q -E -o '^\[\=.+\]$' <<< "${residue}";then
                    type=flag_value
                    break
                fi
                if grep -q -E -o '^=.+$' <<< "${residue}";then
                    type=value
                    is_required=1
                    break
                fi
                break
            done
        else
            type=flag
            is_flag=1
        fi

        if [ -n "$is_multiple" ];then
            case "$type" in
                flag) type=increment ;;
                value) type=multivalue ;;
                flag_value) type=flag_multivalue ;;
            esac
        fi
        if [[ "$parameter" == '--' ]];then
            is_required=
            is_flag=
            value_addon=multivalue
        fi
        # @todo, support comment starts with # character.
        RCM_YAML+='- parameter: '"$parameter"$'\n'
        RCM_YAML+='  type: '$type$'\n'
        if [ -n "$is_required" ];then
            RCM_YAML+='  validate:'$'\n'
            RCM_YAML+='    is_required: '$is_required$'\n'
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

    parse-conditional() {
        # global conditional
        local found="$1"
        description=`echo "$description" | sed -E 's/ *'"${found}"'//i'`
        while true; do
            match=`echo "$found" | grep -i -o -E 'Conditional: Bypass if --[^-_\[\=0-9\.][^\[\=\.]+ has no value\.' | sed -E 's/^Conditional: Bypass if (.*) has no value./\1/i'`
            if [ -n "$match" ];then
                if ! has-value "${match}";then
                    conditional="$found"
                    rcm-yaml find parameter "${parameter}" then set conditional bypass 1
                fi
                break
            fi
            break
        done
    }

    has-value() {
        if [ -z "$1" ];then
            error 'Argument <parameter> is required'; x
        fi
        local parameter="$1"
        local type
        rcm-yaml find parameter "${parameter}" then get type
        type="$_return_value"
        case "$type" in
            value)
                rcm-yaml find parameter "${parameter}" then get value
                value="$_return_value"
                if [ -n "$value" ];then
                    return 0
                else
                    return 1
                fi
        esac
    }

    print-available-values-dialog() {
        # global available_values_command
        # global available_values_arguments
        # global available_values_command_executed
        # global value
        # global available_values
        # global or_other
        # global is_required
        # global autoyes
        local command="$available_values_command"
        local arguments="$available_values_arguments"
        local is_executed="$available_values_command_executed"
        if [[ -n "$command" && -z "$is_executed" ]];then
            available_values_command_executed=1
            if command -v "$command" > /dev/null;then
                _; _.
                [ -n "$arguments" ] && arguments=' '"$arguments"
                echo-wrap-color "Value available from command: <magenta>${command}${arguments}</magenta>"
                mktemp="$(${command}${arguments})"
                while read line;do
                    [ -n "$line" ] && available_values+=("$line")
                done <<< "$mktemp"
            fi
        fi

        while [[ $# -gt 0 ]]; do
            ArrayRemove "$1" available_values[@]
            available_values=("${_return[@]}")
            unset _return
            shift
        done

        while true; do
            if [ "${#available_values[@]}" -eq 0 ];then
                if [[ -n "$command" && -z "$or_other" ]];then
                    __; _, No value available,' '; red Process Terminated; _, .; x
                fi
                break
            fi
            if [ "${#available_values[@]}" -eq 1 ];then
                value="${available_values[0]}"
                if [[ -n "$is_required"  && -z "$or_other" ]];then
                    _; _.
                    echo-wrap-color "Argument <magenta>${parameter}</magenta> filled with the only available value <yellow>$value</yellow> automatically." green
                    break
                fi
                _; _.
                __; _, "Available value: "; yellow "$value";  _, '.'; _.
                if [ -n "$autoyes" ];then
                    _; _.
                    echo-wrap-color "Argument <magenta>${parameter}</magenta> filled with the only available value <yellow>$value</yellow> automatically." green
                else
                    _; _.
                    echo-wrap 'The one and only available value is selected.'
                    read-true
                    if [ -z "$RCM_BOOLEAN" ];then
                        value=
                    fi
                fi
                break
            fi
            if [ -n "$or_other" ];then
                print-select-other-dialog available_values[@]
            else
                print-select-dialog available_values[@]
            fi
            break
        done
    }

    print-backup-dialog() {
        _; _.
        echo-wrap-color "Restore the value: <yellow>$backup_value</yellow>. Would you like to use that value?"
        read-true
        # Reset.
        value=
        if [ -n "$RCM_BOOLEAN" ];then
            _; _.
            value="$backup_value";
            if [[ "$type" == flag_value ]];then
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
            case "$type" in
                *multivalue)
                    ;;
                increment)
                    ;;
                *)
                    _; _.
                    echo-wrap-color "Argument <magenta>${parameter}</magenta> added which is restored." green
                    ;;
            esac
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

    sanitize-value() {
        # Sanitize user input
        # Menghapus karakter aneh karena menekan arrow up/down/right/left di keyboard.
        # Credit: https://stackoverflow.com/a/47918586
        if [ -n "$value" ];then
            value=$(echo "$value" | tr -cd '\11\12\15\40-\176' | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
        fi
    }

    print-fill-a-value-dialog() {
        _; _.
        echo-wrap "Do you want fill with value?"
        read-false
        # Reset.
        value=
        if [ -n "$RCM_BOOLEAN" ];then
            __; read -p "Type the value or leave blank to skip: " value
            sanitize-value
            if [ -n "$value" ];then
                is_typing=1
            fi
        fi
    }

    print-flag-dialog() {
        _; _.
        _ 'Argument '; magenta "${parameter}";_, ' is '; _, optional;_, '.'; _.
        if [ -n "$description" ];then
            _; _.
            while read line; do
                echo-wrap "$line"
            done <<< "$description"
        fi
        for each in "${RCM_PREPOPULATE_ARGUMENTS[@]}";do
            if grep -q -- "^${parameter}" <<< "$each";then
                while true; do
                    if [[ "$each" == "${parameter}-" ]];then
                        rcm-yaml find parameter "${parameter}" then set prepopulate bypass 1
                        break
                    fi
                    if [[ "$each" == "${parameter}" ]];then
                        rcm-yaml find parameter "${parameter}" then set prepopulate flag 1
                        break
                    fi
                    break
                done
            fi
        done
        while true; do
            # Bypass.
            rcm-yaml find parameter "${parameter}" then get conditional bypass
            if [ -n "$_return_value" ];then
                _; _.
                echo-wrap-color "Argument <magenta>${parameter}</magenta> skip by conditional." yellow
                if [ -n "$conditional" ];then
                    _; _.
                    echo-wrap "$conditional"
                fi
                break
            fi
            # Bypass.
            rcm-yaml find parameter "${parameter}" then get prepopulate bypass
            if [ -n "$_return_value" ];then
                _; _.
                __; _, Argument; _, ' '; _, "$parameter"; _, ' ';  _, set to skip by user,' '; _, pass; _, .; _.
                break
            fi
            # Prepopulate.
            rcm-yaml find parameter "${parameter}" then get prepopulate flag
            if [ -n "$_return_value" ];then
                _; _.
                echo-wrap-color "Argument <magenta>${parameter}</magenta> prepopulated." green
                rcm-yaml find parameter "${parameter}" then set flag 1
                break
            fi
            # Restore.
            if [ -n "$backup_flag" ];then
                print-backup-flag-dialog
                if [ -n "$RCM_BOOLEAN" ];then
                    rcm-yaml find parameter "${parameter}" then set flag 1
                fi
                # Note. Langusng break jika menolak restore, artinya false.
                break
            fi
            # Todo, how about other options.
            _; _.
            __; _, Add this argument?; _.
            read-false
            if [ -n "$RCM_BOOLEAN" ];then
                _; _.
                echo-wrap-color "Argument <magenta>${parameter}</magenta> added manually." green
                rcm-yaml find parameter "${parameter}" then set flag 1
                break
            fi
            break
        done

        # Save value.
        rcm-yaml find parameter "${parameter}" then get flag
        if [ -n "$_return_value" ];then
            RCM_ARGUMENT_PASS+=("${parameter}")
            RCM_ARGUMENT_PREVIEW+=("${parameter}")
            RCM_ARGUMENT_PREVIEW_REAL+=("${parameter}")
        else
            RCM_ARGUMENT_PREVIEW+=("${parameter}-")
        fi

        # Backup to text file for flag.
        if [ -n "$_return_value" ];then
            mkdir -p $(dirname "$backup_storage")
            echo "${parameter}" >> "$backup_storage"
        fi
    }

    print-value-dialog() {
        rcm-yaml find parameter "${parameter}" then get validate is_required
        is_required="$_return_value"
        _; _.
        if [ -n "$is_required" ];then
            _ 'Argument '; magenta "${parameter}";_, ' is '; yellow requires;_, ' a value.'; _.
        else
            _ 'Argument '; magenta "${parameter}";_, ' is '; _, optional;_, ' and may have value.'; _.
        fi
        if [ -n "$description" ];then
            _; _.
            while read line; do
                echo-wrap "$line"
            done <<< "$description"
        fi

        for each in "${RCM_PREPOPULATE_ARGUMENTS[@]}";do
            if grep -q -- "^${parameter}" <<< "$each";then
                while true; do
                    if [[ "$each" == "${parameter}-" ]];then
                        rcm-yaml find parameter "${parameter}" then set prepopulate bypass 1
                        break
                    fi
                    if [[ "$each" =~ "${parameter}=" ]];then
                        value="${each#$parameter=}"
                        rcm-yaml find parameter "${parameter}" then set prepopulate value "$value"
                        break
                    fi
                    break
                done
            fi
        done
        while true; do
            # Bypass.
            rcm-yaml find parameter "${parameter}" then get conditional bypass
            if [ -n "$_return_value" ];then
                _; _.
                echo-wrap-color "Argument <magenta>${parameter}</magenta> skip by conditional." yellow
                if [ -n "$conditional" ];then
                    _; _.
                    echo-wrap "$conditional"
                fi
                break
            fi
            # Bypass.
            if [ -z "$is_required" ];then
                # Tidak ada bypass jika required.
                rcm-yaml find parameter "${parameter}" then get prepopulate bypass
                if [ -n "$_return_value" ];then
                    _; _.
                    __; _, Argument; _, ' '; _, "$parameter"; _, ' ';  _, set to skip by user,' '; _, pass; _, .; _.
                    break
                fi
            fi
            # Prepopulate.
            rcm-yaml find parameter "${parameter}" then get prepopulate value
            if [ -n "$_return_value" ];then
                _; _.
                value="$_return_value"
                echo-wrap-color "Argument <magenta>${parameter}</magenta> prepopulated with value <yellow>${value}</yellow> ." green
                rcm-yaml find parameter "${parameter}" then set value "$value"
                break
            fi
            # Restore.
            if [ -n "$backup_value" ];then
                print-backup-dialog
                if [ -n "$value" ];then
                    rcm-yaml find parameter "${parameter}" then set value "$value"
                    break
                fi
            fi

            print-available-values-dialog

            if [ -z "$value" ];then
                while true; do
                    if [ -n "$default_value" ];then
                        _; _.
                        __; _, Leave blank will use default value.; _.
                        label=$(_, 'Type the value [' 2>&1; yellow "$default_value" 2>&1; _, ']: ' 2>&1)
                        __; read -p "$label" value
                        if [ -n "$value" ];then
                            is_typing=1
                        else
                            value="$default_value"
                            _; _.
                            echo-wrap-color "Argument <magenta>${parameter}</magenta> filled with value <yellow>$value</yellow> automatically." green
                        fi
                        break
                    fi
                    if [ -n "$is_required" ];then
                        _; _.
                        until [[ -n "$value" ]];do
                            __; read -p "Type the value: " value
                            sanitize-value
                        done
                        is_typing=1
                        break
                    fi
                    print-fill-a-value-dialog
                    break
                done
            fi
            if [ -n "$is_typing" ];then
                _; _.
                echo-wrap-color "Argument <magenta>${parameter}</magenta> filled with value <yellow>$value</yellow> manually." green
            fi
            if [ -n "$value" ];then
                rcm-yaml find parameter "${parameter}" then set value "$value"
            fi
            break
        done

        # Save value.
        rcm-yaml find parameter "${parameter}" then get value
        value="$_return_value"
        if [ -n "$value" ];then
            [[ "$value" =~ ' ' ]] && value="'$value'"
            RCM_ARGUMENT_PASS+=("${parameter}=${value}")
            RCM_ARGUMENT_PREVIEW+=("${parameter}=${value}")
            RCM_ARGUMENT_PREVIEW_REAL+=("${parameter}=${value}")
        else
            RCM_ARGUMENT_PREVIEW+=("${parameter}-")
        fi

        # Backup to text file for value.
        if [ -n "$value" ];then
            mkdir -p $(dirname "$backup_storage")
            echo "${parameter}=${value}" >> "$backup_storage"
        fi

        # Save to placeholders.
        if [ -n "$value" ];then
            RCM_ARGUMENT_PLACEHOLDERS+='['"$parameter"']: '"$value"
            RCM_ARGUMENT_PLACEHOLDERS+=$'\n'
            RCM_ARGUMENT_PLACEHOLDERS+='['"$parameter"'^^]: '"${value^^}"
        fi
    }

    print-flag-value-dialog() {
        _; _.
        _ 'Argument '; magenta "${parameter}";_, ' is '; _, optional; _, ' and may have value.'; _.
        if [ -n "$description" ];then
            _; _.
            while read line; do
                echo-wrap "$line"
            done <<< "$description"
        fi
        for each in "${RCM_PREPOPULATE_ARGUMENTS[@]}";do
            if grep -q -- "^${parameter}" <<< "$each";then
                while true; do
                    if [[ "$each" == "${parameter}-" ]];then
                        rcm-yaml find parameter "${parameter}" then set prepopulate bypass 1
                        break
                    fi
                    if [[ "$each" == "${parameter}" ]];then
                        rcm-yaml find parameter "${parameter}" then set prepopulate flag 1
                        break
                    fi
                    if [[ "$each" =~ "${parameter}=" ]];then
                        value="${each#$parameter=}"
                        rcm-yaml find parameter "${parameter}" then set prepopulate flag 1
                        rcm-yaml find parameter "${parameter}" then set prepopulate value "$value"
                        break
                    fi
                    break
                done
            fi
        done
        while true; do
            # Bypass.
            rcm-yaml find parameter "${parameter}" then get conditional bypass
            if [ -n "$_return_value" ];then
                _; _.
                echo-wrap-color "Argument <magenta>${parameter}</magenta> skip by conditional." yellow
                if [ -n "$conditional" ];then
                    _; _.
                    echo-wrap "$conditional"
                fi
                break
            fi
            # Bypass.
            rcm-yaml find parameter "${parameter}" then get prepopulate bypass
            if [ -n "$_return_value" ];then
                _; _.
                __; _, Argument; _, ' '; _, "$parameter"; _, ' ';  _, set to skip by user,' '; _, pass; _, .; _.
                break
            fi
            # Prepopulate.
            rcm-yaml find parameter "${parameter}" then get prepopulate flag
            if [ -n "$_return_value" ];then
                rcm-yaml find parameter "${parameter}" then set flag 1
                rcm-yaml find parameter "${parameter}" then get prepopulate value
                if [ -n "$_return_value" ];then
                    value="$_return_value"
                    _; _.
                    echo-wrap-color "Argument <magenta>${parameter}</magenta> prepopulated with value <yellow>${value}</yellow> ." green
                    rcm-yaml find parameter "${parameter}" then set value "$value"
                else
                    _; _.
                    echo-wrap-color "Argument <magenta>${parameter}</magenta> prepopulated." green
                fi
                break
            fi
            # Restore.
            if [ -n "$backup_value" ];then
                backup_flag=1
            fi
            if [ -n "$backup_flag" ];then
                print-backup-flag-dialog
                if [ -n "$RCM_BOOLEAN" ];then
                    rcm-yaml find parameter "${parameter}" then set flag 1
                    if [ -n "$backup_value" ];then
                        print-backup-dialog
                    fi
                    if [ -z "$value" ];then
                        print-fill-a-value-dialog
                    fi
                    # User may leave blank.
                    if [ -n "$value" ];then
                        rcm-yaml find parameter "${parameter}" then set value "$value"
                    fi
                fi
                # Note. Langusng break jika menolak restore, artinya false.
                break
            fi

            # Todo, how about other options.
            # Todo, how about prepopulate value from variable.
            _; _.
            __; _, Add this argument?; _.
            read-false
            if [ -n "$RCM_BOOLEAN" ];then
                _; _.
                echo-wrap-color "Argument <magenta>${parameter}</magenta> added manually." green
                rcm-yaml find parameter "${parameter}" then set flag 1
                print-fill-a-value-dialog
                if [ -n "$value" ];then
                    _; _.
                    echo-wrap-color "Argument <magenta>${parameter}</magenta> filled with value <yellow>$value</yellow> manually." green
                    rcm-yaml find parameter "${parameter}" then set value "$value"
                fi
                break
            fi
            break
        done

        # Save value.
        rcm-yaml find parameter "${parameter}" then get flag
        flag="$_return_value"
        if [ -n "$flag" ];then
            rcm-yaml find parameter "${parameter}" then get value
            value="$_return_value"
            if [ -n "$value" ];then
                [[ "$value" =~ ' ' ]] && value="'$value'"
                RCM_ARGUMENT_PASS+=("${parameter}=${value}")
                RCM_ARGUMENT_PREVIEW+=("${parameter}=${value}")
                RCM_ARGUMENT_PREVIEW_REAL+=("${parameter}=${value}")
            else
                RCM_ARGUMENT_PASS+=("${parameter}")
                RCM_ARGUMENT_PREVIEW+=("${parameter}")
                RCM_ARGUMENT_PREVIEW_REAL+=("${parameter}")
            fi
        else
            RCM_ARGUMENT_PREVIEW+=("${parameter}-")
        fi

        # Backup to text file for flag or value.
        if [ -n "$flag" ];then
            mkdir -p $(dirname "$backup_storage")
            if [ -n "$value" ];then
                echo "${parameter}=${value}" >> "$backup_storage"
            else
                echo "${parameter}" >> "$backup_storage"
            fi
        fi

        # Save to placeholders.
        if [ -n "$flag" ];then
            if [ -n "$value" ];then
                RCM_ARGUMENT_PLACEHOLDERS+='['"$parameter"']: '"$value"
                RCM_ARGUMENT_PLACEHOLDERS+=$'\n'
                RCM_ARGUMENT_PLACEHOLDERS+='['"$parameter"'^^]: '"${value^^}"
            fi
        fi

    }

    print-increment-dialog() {
        _; _.
        _ 'Argument '; magenta "${parameter}";_, ' is '; _, optional;_, '.'; _.
        if [ -n "$description" ];then
            _; _.
            while read line; do
                echo-wrap "$line"
            done <<< "$description"
        fi
        for each in "${RCM_PREPOPULATE_ARGUMENTS[@]}";do
            if grep -q -- "^${parameter}" <<< "$each";then
                while true; do
                    if [[ "$each" == "${parameter}-" ]];then
                        rcm-yaml find parameter "${parameter}" then set prepopulate bypass 1
                        break
                    fi
                    if [[ "$each" == "${parameter}" ]];then
                        rcm-yaml find parameter "${parameter}" then increase prepopulate count
                        break
                    fi
                    break
                done
            fi
        done
        while true; do
            # Bypass.
            rcm-yaml find parameter "${parameter}" then get conditional bypass
            if [ -n "$_return_value" ];then
                _; _.
                echo-wrap-color "Argument <magenta>${parameter}</magenta> skip by conditional." yellow
                if [ -n "$conditional" ];then
                    _; _.
                    echo-wrap "$conditional"
                fi
                break
            fi
            # Bypass.
            rcm-yaml find parameter "${parameter}" then get prepopulate bypass
            if [ -n "$_return_value" ];then
                _; _.
                __; _, Argument; _, ' '; _, "$parameter"; _, ' ';  _, set to skip by user,' '; _, pass; _, .; _.
                break
            fi
            # Khusus increment, pilih salah satu antara prepopulate
            # atau restore.
            count=0
            while true; do
                # Prepopulate.
                rcm-yaml find parameter "${parameter}" then get prepopulate count
                if [ -n "$_return_value" ];then
                    count="$_return_value"
                    _; _.
                    for ((i = 0 ; i < $count ; i++)); do
                        echo-wrap-color "Argument <magenta>${parameter}</magenta> prepopulated." green
                    done
                    rcm-yaml find parameter "${parameter}" then set count "$count"
                    break
                fi
                # Restore.
                if [ -n "$backup_value" ];then
                    print-backup-flag-dialog
                    if [ -n "$RCM_BOOLEAN" ];then
                        count="$backup_value"
                        _; _.
                        for ((i = 0 ; i < $count ; i++)); do
                            echo-wrap-color "Argument <magenta>${parameter}</magenta> added which is restored." green
                        done
                        rcm-yaml find parameter "${parameter}" then set count "$count"
                        break
                    fi
                fi
                break
            done
            # Todo, how about other options.
            while true; do
                if [ "$count" -eq 0 ];then
                    _; _.
                    __; _, Add this argument?; _.
                    read-false
                    if [ -n "$RCM_BOOLEAN" ];then
                        _; _.
                        echo-wrap-color "Argument <magenta>${parameter}</magenta> added manually." green
                        count=$((count + 1))
                        rcm-yaml find parameter "${parameter}" then set count $count
                    else
                        break
                    fi
                else
                    _; _.
                    __ Add this argument again?
                    read-false
                    if [ -n "$RCM_BOOLEAN" ];then
                        _; _.
                        echo-wrap-color "Argument <magenta>${parameter}</magenta> added again manually." green
                        count=$((count + 1))
                        rcm-yaml find parameter "${parameter}" then set count $count
                    else
                        break
                    fi
                fi
            done
            break
        done

        # Save value.
        rcm-yaml find parameter "${parameter}" then get count
        count="$_return_value"
        if [ -n "$count" ];then
            for ((i = 0 ; i < $count ; i++)); do
                RCM_ARGUMENT_PASS+=("${parameter}")
                RCM_ARGUMENT_PREVIEW+=("${parameter}")
                RCM_ARGUMENT_PREVIEW_REAL+=("${parameter}")
            done
        else
            RCM_ARGUMENT_PREVIEW+=("${parameter}-")
        fi

        # Backup to text file for increment.
        if [ -n "$count" ];then
            mkdir -p $(dirname "$backup_storage")
            echo "${parameter}=${count}" >> "$backup_storage"
        fi

    }

    print-multivalue-dialog() {
        rcm-yaml find parameter "${parameter}" then get validate is_required
        is_required="$_return_value"
        _; _.
        if [ -n "$is_required" ];then
            _ 'Argument '; magenta "${parameter}";_, ' is '; yellow required; _, ' at least a value.'; _.
        else
            _ 'Argument '; magenta "${parameter}";_, ' is '; _, optional;_, ' and may have many value.'; _.
        fi
        if [ -n "$description" ];then
            _; _.
            while read line; do
                echo-wrap "$line"
            done <<< "$description"
        fi
        for each in "${RCM_PREPOPULATE_ARGUMENTS[@]}";do
            if grep -q -- "^${parameter}" <<< "$each";then
                while true; do
                    if [[ "$each" == "${parameter}-" ]];then
                        rcm-yaml find parameter "${parameter}" then set prepopulate bypass 1
                        break
                    fi
                    if [[ "$each" =~ "${parameter}=" ]];then
                        value="${each#$parameter=}"
                        rcm-yaml find parameter "${parameter}" then append prepopulate values "$value"
                        break
                    fi
                    break
                done
            fi
        done
        while true; do
            # Bypass.
            rcm-yaml find parameter "${parameter}" then get conditional bypass
            if [ -n "$_return_value" ];then
                _; _.
                echo-wrap-color "Argument <magenta>${parameter}</magenta> skip by conditional." yellow
                if [ -n "$conditional" ];then
                    _; _.
                    echo-wrap "$conditional"
                fi
                break
            fi
            # Bypass.
            if [ -z "$is_required" ];then
                # Tidak ada prepopulate bypass jika required.
                rcm-yaml find parameter "${parameter}" then get prepopulate bypass
                if [ -n "$_return_value" ];then
                    _; _.
                    __; _, Argument; _, ' '; _, "$parameter"; _, ' ';  _, set to skip by user,' '; _, pass; _, .; _.
                    break
                fi
            fi
            # Prepopulate.
            rcm-yaml find parameter "${parameter}" then get prepopulate values
            values=("${_return_array[@]}")
            if [ "${#values[@]}" -gt 0 ];then
                _; _.
                for value in "${values[@]}"; do
                    echo-wrap-color "Argument <magenta>${parameter}</magenta> prepopulated with value <yellow>$value</yellow>." green
                    rcm-yaml find parameter "${parameter}" then append values "$value"
                done
                # break
                # Note: Tidak ada break seperti flag_value atau value, tapi tetap
                # dilanjutkan karena multivalue.
            fi
            # Restore.
            if [ -n "$backup_values" ];then
                print-backup-flag-dialog
                if [ -n "$RCM_BOOLEAN" ];then
                    rcm-yaml find parameter "${parameter}" then set flag 1
                    until [[ -z "$backup_values" ]];do
                        backup_value=`sed -n 1p <<< "$backup_values"`
                        backup_values=`sed -n '2,$p' <<< "$backup_values"`
                        print-backup-dialog
                        if [ -n "$value" ];then
                            rcm-yaml find parameter "${parameter}" then append values "$value"
                        fi
                    done
                    rcm-yaml find parameter "${parameter}" then get prepopulate values
                    values=("${_return_array[@]}")
                    if [ "${#values[@]}" -eq 0 ];then
                        print-fill-a-value-dialog
                    fi
                    # User may leave blank.
                    if [ -n "$value" ];then
                        rcm-yaml find parameter "${parameter}" then set value "$value"
                    fi
                    # break
                    # Note: Tidak ada break seperti flag_value atau value, tapi tetap
                    # dilanjutkan karena multivalue.
                fi
            fi
            rcm-yaml find parameter "${parameter}" then get prepopulate values
            values=("${_return_array[@]}")
            if [ "${#values[@]}" -eq 0 ];then
                if [ -z "$is_required" ];then
                    print-fill-a-value-dialog
                    if [ -z "$value" ];then
                        break
                    fi
                else
                    _; _.
                    until [[ -n "$value" ]];do
                        __; read -p "Type the value: " value
                        sanitize-value
                    done
                fi
                if [ -n "$value" ];then
                    _; _.
                    echo-wrap-color "Argument <magenta>${parameter}</magenta> filled with value <yellow>$value</yellow> manually." green
                    rcm-yaml find parameter "${parameter}" then append values "$value"
                fi
            fi
            while true;do
                _; _.
                __ Add another value?
                read-false
                if [ -z "$RCM_BOOLEAN" ];then
                    break
                fi
                __; read -p "Type the value or leave blank to skip: " value
                sanitize-value
                if [ -n "$value" ];then
                    _; _.
                    echo-wrap-color "Argument <magenta>${parameter}</magenta> filled again with value <yellow>$value</yellow> manually." green
                    rcm-yaml find parameter "${parameter}" then append values "$value"
                else
                    break
                fi
            done
            break
        done

        rcm-yaml find parameter "${parameter}" then get values
        values=("${_return_array[@]}")
        if [ "${#values[@]}" -gt 0 ];then
            for value in "${values[@]}"; do
                [[ "$value" =~ ' ' ]] && value="'$value'"
                RCM_ARGUMENT_PASS+=("${parameter}=${value}")
                RCM_ARGUMENT_PREVIEW+=("${parameter}=${value}")
                RCM_ARGUMENT_PREVIEW_REAL+=("${parameter}=${value}")
            done
        else
            RCM_ARGUMENT_PREVIEW+=("${parameter}-")
        fi

        # Backup to text file for value.
        if [ "${#values[@]}" -gt 0 ];then
            mkdir -p $(dirname "$backup_storage")
            for value in "${values[@]}"; do
                [[ "$value" =~ ' ' ]] && value="'$value'"
                echo "${parameter}=${value}" >> "$backup_storage"
            done
        fi

        # Placeholder tidak berlaku untuk multivalue.
    }

    print-flag-multivalue-dialog() {
        _; _.
        _ 'Argument '; magenta "${parameter}";_, ' is '; _, optional;_, ' and may have many value.'; _.
        if [ -n "$description" ];then
            _; _.
            while read line; do
                echo-wrap "$line"
            done <<< "$description"
        fi
        for each in "${RCM_PREPOPULATE_ARGUMENTS[@]}";do
            if grep -q -- "^${parameter}" <<< "$each";then
                while true; do
                    if [[ "$each" == "${parameter}-" ]];then
                        rcm-yaml find parameter "${parameter}" then set prepopulate bypass 1
                        break
                    fi
                    if [[ "$each" == "${parameter}" ]];then
                        rcm-yaml find parameter "${parameter}" then set prepopulate flag 1
                        break
                    fi
                    if [[ "$each" =~ "${parameter}=" ]];then
                        value="${each#$parameter=}"
                        rcm-yaml find parameter "${parameter}" then set prepopulate flag 1
                        rcm-yaml find parameter "${parameter}" then append prepopulate values "$value"
                        break
                    fi
                    break
                done
            fi
        done
        while true; do
            # Bypass.
            rcm-yaml find parameter "${parameter}" then get conditional bypass
            if [ -n "$_return_value" ];then
                _; _.
                echo-wrap-color "Argument <magenta>${parameter}</magenta> skip by conditional." yellow
                if [ -n "$conditional" ];then
                    _; _.
                    echo-wrap "$conditional"
                fi
                break
            fi
            # Bypass.
            rcm-yaml find parameter "${parameter}" then get prepopulate bypass
            if [ -n "$_return_value" ];then
                _; _.
                __; _, Argument; _, ' '; _, "$parameter"; _, ' ';  _, set to skip by user,' '; _, pass; _, .; _.
                break
            fi
            # Prepopulate.
            rcm-yaml find parameter "${parameter}" then get prepopulate flag
            flag="$_return_value"
            if [ -n "$flag" ];then
                rcm-yaml find parameter "${parameter}" then set flag 1
                rcm-yaml find parameter "${parameter}" then get prepopulate values
                values=("${_return_array[@]}")
                if [ "${#values[@]}" -gt 0 ];then
                    _; _.
                    for value in "${values[@]}"; do
                        echo-wrap-color "Argument <magenta>${parameter}</magenta> prepopulated with value <yellow>$value</yellow>." green
                        rcm-yaml find parameter "${parameter}" then append values "$value"
                    done
                else
                    _; _.
                    echo-wrap-color "Argument <magenta>${parameter}</magenta> prepopulated." green
                fi
                # break
                # Note: Tidak ada break seperti flag_value atau value, tapi tetap
                # dilanjutkan karena multivalue.
            fi
            # Restore.
            if [ -n "$backup_values" ];then
                backup_flag=1
            fi
            if [ -n "$backup_flag" ];then
                print-backup-flag-dialog
                if [ -n "$RCM_BOOLEAN" ];then
                    rcm-yaml find parameter "${parameter}" then set flag 1
                    flag=1
                    if [ -n "$backup_values" ];then
                        until [[ -z "$backup_values" ]];do
                            backup_value=`sed -n 1p <<< "$backup_values"`
                            backup_values=`sed -n '2,$p' <<< "$backup_values"`
                            print-backup-dialog
                            if [ -n "$value" ];then
                                rcm-yaml find parameter "${parameter}" then append values "$value"
                            fi
                        done
                    else
                        print-fill-a-value-dialog
                        # User may leave blank.
                        if [ -n "$value" ];then
                            rcm-yaml find parameter "${parameter}" then append values "$value"
                        fi
                    fi
                    # break
                    # Note: Tidak ada break seperti flag_value atau value, tapi tetap
                    # dilanjutkan karena multivalue.
                else
                    # Note. Langusng break jika menolak restore, artinya false.
                    break
                fi
            fi

            # Todo, how about other options.
            # Todo, how about prepopulate value from variable.
            if [ -z "$flag" ];then
                _; _.
                __; _, Add this argument?; _.
                read-false
                if [ -n "$RCM_BOOLEAN" ];then
                    _; _.
                    echo-wrap-color "Argument <magenta>${parameter}</magenta> added manually." green
                    rcm-yaml find parameter "${parameter}" then set flag 1
                    if [ -z "$value" ];then
                        print-fill-a-value-dialog
                        if [ -n "$value" ];then
                            _; _.
                            echo-wrap-color "Argument <magenta>${parameter}</magenta> filled with value <yellow>$value</yellow> manually." green
                            rcm-yaml find parameter "${parameter}" then append values "$value"
                        fi
                    fi
                    break
                fi
            fi
            break
        done
        rcm-yaml find parameter "${parameter}" then get values
        values=("${_return_array[@]}")
        if [ "${#values[@]}" -gt 0 ];then
            while true;do
                _; _.
                __ Add another value?
                read-false
                if [ -z "$RCM_BOOLEAN" ];then
                    break
                fi
                __; read -p "Type the value or leave blank to skip: " value
                sanitize-value
                if [ -n "$value" ];then
                    _; _.
                    echo-wrap-color "Argument <magenta>${parameter}</magenta> filled again with value <yellow>$value</yellow> manually." green
                    rcm-yaml find parameter "${parameter}" then append values "$value"
                else
                    break
                fi
            done
        fi

        # Save value.
        rcm-yaml find parameter "${parameter}" then get flag
        flag="$_return_value"
        rcm-yaml find parameter "${parameter}" then get values
        values=("${_return_array[@]}")
        if [ -n "$flag" ];then
            if [ "${#values[@]}" -gt 0 ];then
                for value in "${values[@]}"; do
                    [[ "$value" =~ ' ' ]] && value="'$value'"
                    RCM_ARGUMENT_PASS+=("${parameter}=${value}")
                    RCM_ARGUMENT_PREVIEW+=("${parameter}=${value}")
                    RCM_ARGUMENT_PREVIEW_REAL+=("${parameter}=${value}")
                done
            else
                RCM_ARGUMENT_PASS+=("${parameter}")
                RCM_ARGUMENT_PREVIEW+=("${parameter}")
                RCM_ARGUMENT_PREVIEW_REAL+=("${parameter}")
            fi
        else
            RCM_ARGUMENT_PREVIEW+=("${parameter}-")
        fi

        # Backup to text file for flag.
        if [ -n "$flag" ];then
            mkdir -p $(dirname "$backup_storage")
            if [ "${#values[@]}" -gt 0 ];then
                for value in "${values[@]}"; do
                    [[ "$value" =~ ' ' ]] && value="'$value'"
                    echo "${parameter}=${value}" >> "$backup_storage"
                done
            else
                echo "${parameter}" >> "$backup_storage"
            fi
        fi

        # Placeholder tidak berlaku untuk multivalue.

    }

    parse-parameter

    parse-description

    rcm-yaml find parameter "${parameter}" then get type
    type="$_return_value"

    is_typing=
    is_press=
    is_flagged=

    values=()
    flags=1
    backup_values=
    backup_value=
    backup_flag=
    if [ -f "$backup_storage" ];then
        case "$type" in
            flag*)
                backup_flag=$(grep -q -- "^${parameter}$" "$backup_storage" && echo 1)
                ;;
        esac
        case "$type" in
            *multivalue)
                backup_values=$(grep -- "^${parameter}=.*$" "$backup_storage" | sed -E -e 's|'"^${parameter}=(.*)$"'|\1|' -e "s|^'(.*)'$|\1|" | sort -u)
                ;;
            *)
                backup_value=$(grep -- "^${parameter}=.*$" "$backup_storage" | tail -1 | sed -E 's|'"^${parameter}=(.*)$"'|\1|')
                ;;
        esac
    fi
    if [ -f "$history_storage" ];then
        history_value=$(grep -- "^${parameter}=.*$" "$history_storage" | tail -9 | sed -E 's|'"^${parameter}=(.*)$"'|\1|')
    fi

    while true; do
        find=`echo "$description" | grep -i -o -E 'Conditional: [^\.]+\.'`
        if [ -n "$find" ];then
            parse-conditional "$find"
            break
        fi
        break
    done

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

    case "$type" in
        flag)
            print-flag-dialog
            ;;
        value)
            print-value-dialog
            ;;
        flag_value)
            print-flag-value-dialog
            ;;
        increment)
            print-increment-dialog
            ;;
        multivalue)
            print-multivalue-dialog
            ;;
        flag_multivalue)
            print-flag-multivalue-dialog
            ;;
    esac
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

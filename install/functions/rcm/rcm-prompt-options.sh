#!/bin/bash

rcm-prompt-options() {
    # Required Global variable.
    [ -z "$RCM_OPTIONS" ] && { error "Variable RCM_OPTIONS is required."; x; }

    # Local variable as property.
    local options="$RCM_OPTIONS"
    local other_options="$RCM_OTHER_OPTIONS"
    local load_other_options=
    local bypass_dialog=
    local count below

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

        parameter=`sed -n 1p <<< "$option" | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//'`
        is_required=
        is_flag=
        value_addon=
        is_flagvalue=
        save_history=1
        is_typing=
        is_press=
        is_flagged=
        default_value=
        prepopulate_value=
        if [[ "${parameter:(-1):1}" == '*' ]];then
            is_required=1
            parameter="${parameter::-1}"
            parameter=`echo "$parameter" | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//'`
        elif [[ "${parameter:(-1):1}" == '^' ]];then
            is_flag=1
            parameter="${parameter::-1}"
            parameter=`echo "$parameter" | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//'`
        fi
        if [[ "$parameter" == '--' ]];then
            is_required=
            is_flag=
            value_addon=multivalue
        fi
        description=
        unset count
        declare -i count
        count=2
        placeholders=
        while true; do
            below=`sed -n ${count}p <<< "$option" | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//'`
            if [ -z "$below" ];then
                break
            fi
            if [[ "${below:0:1}" == '[' ]];then
                if [ -n "$placeholders" ];then
                    placeholders+=$'\n'
                fi
                placeholders+="$below"
            else
                description+="$below"
                description+=$'\n'
            fi
            count+=1
        done

        if grep -q -i -E '(^|\.\s)Multivalue\.' <<< "$description";then
            value_addon=multivalue
        fi
        if grep -q -i -E '(^|\.\s)Can have value\.' <<< "$description";then
            value_addon=canhavevalue
        fi
        value=
        values=()
        flags=1
        backup_value=
        backup_flag=
        if [ -f "$backup_storage" ];then
            backup_value=$(grep -- "^${parameter}=.*$" "$backup_storage" | tail -1 | sed -E 's|'"^${parameter}=(.*)$"'|\1|')
            backup_flag=$(grep -q -- "^${parameter}$" "$backup_storage" && echo 1)
        fi
        history_value=
        if [ -f "$history_storage" ];then
            history_value=$(grep -- "^${parameter}=.*$" "$history_storage" | tail -9 | sed -E 's|'"^${parameter}=(.*)$"'|\1|')
        fi
        available_values=()
        _available_values=`echo "$description" | grep -i -o -E 'Available values?:[^\.]+\.'| sed -n -E 's/^Available values?: ([^\.]+)\.$/\1/ip'`
        if [ -n "$_available_values" ];then
            description=`echo "$description" | sed -E 's/ *Available values?: ([^\.]+)\.//i'`
        fi
        _available_values_from_command=`echo "$description" | grep -i -o -E 'Values? available from command:\s*[^\(]+\((\)|[^\)]+\))(\.|, or others?\.)'`
        _available_values_from_command_executed=
        if [ -n "$_available_values_from_command" ];then
            description=`echo "$description" | sed -E 's/ *Values? available from command:\s*[^\(]+\((\)|[^\)]+\))(\.|, or others?\.)//i'`
        fi
        or_other=
        if [ -n "$_available_values" ];then
            if grep -i -q -E 'or others?' <<< "$_available_values";then
                or_other=1
                _available_values=`echo "$_available_values" | sed -E 's/or others?$//'`
            fi
        fi
        if [ -n "$_available_values_from_command" ];then
            if grep -i -q -E 'or others?' <<< "$_available_values_from_command";then
                or_other=1
            fi
        fi
        _default_value=`echo "$description" | grep -i -o -E 'Default value from variable:? [^\.]+\.'| sed -n -E 's/^Default value from variable:? ([^\.]+)\.$/\1/ip'`
        if [ -n "$_default_value" ];then
            description=`echo "$description" | sed -E 's/ *Default value from variable:? ([^\.]+)\.//i'`
            default_value="${!_default_value}"
        fi
        _prepopulate_value=`echo "$description" | grep -i -o -E 'Prepopulate value from variable:? [^\.]+\.'| sed -n -E 's/^Prepopulate value from variable:? ([^\.]+)\.$/\1/ip'`
        if [ -n "$_prepopulate_value" ];then
            description=`echo "$description" | sed -E 's/ *Prepopulate value from variable:? ([^\.]+)\.//i'`
            if [ -n "$RCM_ARGUMENT_PLACEHOLDERS" ];then
                while read line; do
                    find=$(echo ${line} | sed -E 's|^([^:]+):.*|\1|' | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
                    replace=$(echo ${line} | sed -E 's|^[^:]+:(.*)|\1|' | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
                    _prepopulate_value="${_prepopulate_value/"$find"/"$replace"}"
                done <<< "$RCM_ARGUMENT_PLACEHOLDERS"
            fi
            prepopulate_value="${!_prepopulate_value}"
        fi
        if [ -n "$placeholders" ];then
            _available_values=(`echo "$_available_values" | tr ',' ' '`)
            available_values=()
            for each in "${_available_values[@]}"; do
                if grep -q -F "${each}: " <<< "$placeholders";then
                    line=`grep -F "${each}: " <<< "$placeholders"`
                    replace=$(echo ${line} | cut -d: -f2 | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
                    available_values+=("$replace")
                else
                    available_values+=("$each")
                fi
            done
        else
            if [ -n "$_available_values" ];then
                available_values=(`echo "$_available_values" | tr ',' ' '`)
            fi
        fi
        _; _.
        if [ -n "$_available_values_from_command" ];then
            # Tidak ada history jika value dari command.
            history_value=
            save_history=
        fi
        if [ -n "$_available_values_from_command" ];then
            # parsing argument.
            _command_arguments=$(echo "$_available_values_from_command" | sed -n -E 's/^Values? available from command:\s*([^\)]+\))(\.$|, or others?\.$)/\1/p')
            _command=$(echo "$_command_arguments" | sed -n -E 's/^([^\(]+)\(([^\)]*)\)$/\1/p')
            _arguments=$(echo "$_command_arguments" | sed -n -E 's/^([^\(]+)\(([^\)]*)\)$/\2/p')
            if command -v "$_command" > /dev/null;then
                if [ -n "$RCM_ARGUMENT_PLACEHOLDERS" ];then
                    while read line; do
                        find=$(echo ${line} | sed -E 's|^([^:]+):.*|\1|' | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
                        replace=$(echo ${line} | sed -E 's|^[^:]+:(.*)|\1|' | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
                        description="${description/"$find"/"$replace"}"
                        if [ -n "$_arguments" ];then
                            _arguments="${_arguments/"$find"/"$replace"}"
                        fi
                    done <<< "$RCM_ARGUMENT_PLACEHOLDERS"
                fi
            fi
        fi
        if [ -n "$RCM_ARGUMENT_PLACEHOLDERS" ];then
            while read line; do
                find=$(echo ${line} | sed -E 's|^([^:]+):.*|\1|' | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
                replace=$(echo ${line} | sed -E 's|^[^:]+:(.*)|\1|' | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
                description="${description/"$find"/"$replace"}"
            done <<< "$RCM_ARGUMENT_PLACEHOLDERS"
        fi
        if [ -n "$is_flag" ];then
            _ 'Argument '; magenta ${parameter};_, ' is '; _, optional;_, '.'; _.
            if [ -n "$description" ];then
                _; _.
                while read line; do
                    echo-wrap "$line"
                done <<< "$description"
            fi
            _boolean=
            for each in "${RCM_PREPOPULATE_ARGUMENT_OPTIONS[@]}";do
                if grep -q -- "^${parameter}-\$" <<< "$each";then
                    _boolean=0
                    break
                elif grep -q -- "^${parameter}-=" <<< "$each";then
                    # Ada argument lupa dihapus, contoh: --with-roundcube- mail.example.org
                    # maka set sebagai skip.
                    _boolean=0
                    break
                elif grep -q -- "^${parameter}\$" <<< "$each";then
                    _boolean=1
                    if [[ "$value_addon" == 'canhavevalue' ]];then
                        value_addon=
                    fi
                    if [[ "$value_addon" == 'multivalue' ]];then
                        ArrayRemove "$parameter" RCM_PREPOPULATE_ARGUMENT_OPTIONS[@]
                        RCM_PREPOPULATE_ARGUMENT_OPTIONS=("${_return[@]}")
                        unset _return
                    fi
                    break
                elif grep -q -- "^${parameter}=" <<< "$each";then
                    if [[ "$value_addon" == 'canhavevalue' ]];then
                        _boolean=1
                        value=$(echo "$each" | sed -n -E 's|^[^=]+=(.*)|\1|p')
                        break
                    fi
                fi
            done
            # Reset first.
            RCM_BOOLEAN=
            master_boolean=
            if [[ "$_boolean" == 0 ]];then
                _; _.
                __; _, Argument; _, ' '; _, "$parameter"; _, ' ';  _, set to skip by user,' '; _, pass; _, .; _.
                backup_flag=
                master_boolean=' '
            elif [[ "$_boolean" == 1 ]];then
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
                master_boolean=1
            fi

            # Jika $parameter merupakan other option, maka skip semua dialog.
            # jika tidak ada prepopulate value.
            if [ -n "$bypass_dialog" ];then
                if [ -z "$_boolean" ];then
                    backup_flag=
                    master_boolean=' '
                fi
            fi

            if [ -n "$backup_flag" ];then
                printBackupFlagDialog
                master_boolean="$RCM_BOOLEAN"
                if [[ "$value_addon" == 'canhavevalue' ]];then
                    if [ -n "$backup_value" ];then
                        printBackupDialog
                    fi
                fi
            fi
            if [ -z "$master_boolean" ];then
                _; _.
                __; _, Add this argument?; _.
                read-false
                master_boolean="$RCM_BOOLEAN"
                is_press=1
            fi
            if [[ "$master_boolean" == ' ' ]];then
                master_boolean=
            fi
            # Populate placeholders.
            if [ -n "$RCM_ARGUMENT_PLACEHOLDERS" ];then
                RCM_ARGUMENT_PLACEHOLDERS+=$'\n'
            fi
            if [ -n "$master_boolean" ]; then
                is_flagged=1
                if [[ "$value_addon" == 'canhavevalue' ]];then
                    if [ -z "$value" ];then
                        _; _.
                        __; _, Do you want fill with value?; _.
                        read-false
                    fi
                    if [ -n "$value" ];then
                        # fill from prepopulated
                        RCM_BOOLEAN=1
                    fi
                    if [ -n "$RCM_BOOLEAN" ]; then
                        if [ -z "$value" ];then
                            if [ -n "$history_value" ];then
                                printHistoryDialog
                                if [ -n "$value" ];then
                                    _; _.
                                    echo-wrap-color "Argument <magenta>${parameter}</magenta> filled with value <yellow>$value</yellow> which is selected from the list of history." green
                                fi
                            fi
                        fi
                        if [ -z "$value" ];then
                            if [ "${#available_values[@]}" -gt 0 ];then
                                printSelectDialog available_values[@]
                            fi
                        fi
                        until [[ -n "$value" ]];do
                            __; read -p "Type the value: " value
                            is_typing=1
                        done
                        # Sanitize user input
                        # Menghapus karakter aneh karena menekan arrow up/down/right/left di keyboard.
                        # Credit: https://stackoverflow.com/a/47918586
                        value=$(echo "$value" | tr -cd '\11\12\15\40-\176' | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
                        RCM_ARGUMENT_PASS+=("${parameter}=${value}")
                        [[ "$value" =~ ' ' ]] && _value="'$value'" || _value="$value"
                        RCM_ARGUMENT_PREVIEW+=("${parameter}=${_value}")
                        RCM_ARGUMENT_PREVIEW_REAL+=("${parameter}=${_value}")
                    else
                        RCM_ARGUMENT_PASS+=("${parameter}")
                        RCM_ARGUMENT_PREVIEW+=("${parameter}")
                        RCM_ARGUMENT_PREVIEW_REAL+=("${parameter}")
                    fi
                else
                    i=1
                    until [[ $i -gt $flags ]];do
                        RCM_ARGUMENT_PASS+=("${parameter}")
                        RCM_ARGUMENT_PREVIEW+=("${parameter}")
                        RCM_ARGUMENT_PREVIEW_REAL+=("${parameter}")
                        let i++
                    done
                fi
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
            if [ -n "$master_boolean" ];then
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
                    printHistoryDialog
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
            if [ -n "$is_required" ];then
                _ 'Argument '; magenta ${parameter};_, ' is '; yellow required;_, '.'; _.
            else
                _ 'Argument '; magenta ${parameter};_, ' is '; _, optional;_, '.'; _.
            fi
            if [ -n "$description" ];then
                _; _.
                while read line; do
                    echo-wrap "$line"
                done <<< "$description"
            fi
            if [ -n "$default_value" ];then
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
                printBackupDialog
            fi
            if [ -z "$value" ];then
                # History dialog belum mendukung multivalue.
                if [ -n "$history_value" ];then
                    printHistoryDialog
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
                Rcm_get_list_values
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
                [ -z "$default_value" ] && suffix=' manually' || suffix=' automatically'
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
        if [ -n "$master_boolean" ];then
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
                            printHistoryDialog
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
                        Rcm_get_list_values "$value_before"
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

    until [[ -z "$options" ]];do
        RCM_OPTION=`sed -n 1p <<< "$options" | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//'`
        unset count
        declare -i count
        count=2
        while true; do
            below=`sed -n ${count}p <<< "$options" | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//'`
            if grep -q '^--' <<< "$below";then
                break
            fi
            if [ -z "$below" ];then
                break
            fi
            RCM_OPTION+=$'\n'
            RCM_OPTION+="$below"
            count+=1
        done
        rcm-prompt-options-option $bypass_dialog
        options=`sed -n ${count}',$p' <<< "$options"`

        # Other options.
        if [[ -z "$options" && -z "$load_other_options" ]];then
            if [ -n "$other_options" ];then
                options="$other_options"
                load_other_options=1
                if [ -z "$autoyes" ];then
                    _; _.
                    _; _, 'There are '; yellow other ;_, ' arguments available and optional.'; _.
                    _; _.
                    __; _, Prompt other arguments?; _.
                    read-false
                    if [ -z "$RCM_BOOLEAN" ]; then
                        bypass_dialog='--bypass-dialog'
                    fi
                else
                    bypass_dialog='--bypass-dialog'
                fi
            fi
        fi
    done
    ____

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

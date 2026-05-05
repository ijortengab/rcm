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
    local yaml_prepopulate_bypass=
    local yaml_prepopulate_value=
    local yaml_prepopulate_flag=
    local yaml_prepopulate_count=0
    local yaml_prepopulate_values=()
    local yaml_conditional_bypass=
    local yaml_flag=
    local yaml_count=0
    local yaml_values=()
    local yaml_values_backup=()
    local yaml_values_key
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
    local value=
    local prepopulate_boolean=
    local conditional

    parse-parameter() {
        # global is_required
        local type
        local is_multiple
        local first_line_trimmed residue

        # global option
        # global parameter
        # global is_required
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
                    # Cara dibawah ini simple, tapi lambat.
                    # ```
                    #     rcm-yaml find parameter "${parameter}" then set conditional bypass 1
                    # ```
                    # Solusinya dengan direct langsung ke RCM_YAML manual.
                    RCM_YAML+='  conditional:'$'\n'
                    RCM_YAML+='    bypass: 1'$'\n'
                    # Lalu beri set sebagai variable sehingga tidak perlu get lagi.
                    yaml_conditional_bypass=1
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
        # Cara dibawah ini simple, tapi lambat.
        # ```
        #     rcm-yaml find parameter "${parameter}" then get type
        # ```
        # Alternative adalah, langsung populate variable array.
        rcm-yaml find parameter "${parameter}"
        # Lalu ambil property `type` via array function.
        array type; type="$_return_value"
        # Begitu juga dengan property `value`, via array function.
        case "$type" in
            value)
                array value; value="$_return_value"
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
        for each in "${RCM_PREPOPULATE_ARGUMENTS[@]}";do
            if grep -q -- "^${parameter}" <<< "$each";then
                while true; do
                    if [[ "$each" == "${parameter}-" ]];then
                        # Cara dibawah ini simple, tapi lambat.
                        # ```
                        #     rcm-yaml find parameter "${parameter}" then set prepopulate bypass 1
                        # ```
                        # Solusinya dengan direct langsung ke RCM_YAML manual.
                        RCM_YAML+='  prepopulate:'$'\n'
                        RCM_YAML+='    bypass: 1'$'\n'
                        # Lalu beri set sebagai variable sehingga tidak perlu get lagi.
                        yaml_prepopulate_bypass=1
                        break
                    fi
                    if [[ "$each" == "${parameter}" ]];then
                        # Cara dibawah ini simple, tapi lambat.
                        # ```
                        #     rcm-yaml find parameter "${parameter}" then set prepopulate flag 1
                        # ```
                        # Solusinya dengan direct langsung ke RCM_YAML manual.
                        RCM_YAML+='  prepopulate:'$'\n'
                        RCM_YAML+='    flag: 1'$'\n'
                        # Lalu beri set sebagai variable sehingga tidak perlu get lagi.
                        yaml_prepopulate_flag=1
                        break
                    fi
                    break
                done
            fi
        done

        while true; do
            # Bypass.
            if [ -n "$bypass_dialog" ];then
                break
            fi
            # Cara dibawah ini simple, tapi lambat.
            # ```
            #     rcm-yaml find parameter "${parameter}" then get conditional bypass
            #     yaml_conditional_bypass="$_return_value"
            # ```
            # Gunakan saja variable $yaml_conditional_bypass yang sudah kita
            # definisikan diatas.
            if [ -n "$yaml_conditional_bypass" ];then
                _; _.
                echo-wrap-color "Argument <magenta>${parameter}</magenta> skip by conditional." yellow
                if [ -n "$conditional" ];then
                    _; _.
                    echo-wrap "$conditional"
                fi
                break
            fi

            # Bypass.
            # Cara dibawah ini simple, tapi lambat.
            # ```
            #     rcm-yaml find parameter "${parameter}" then get prepopulate bypass
            #     yaml_prepopulate_bypass="$_return_value"
            # ```
            # Gunakan saja variable $yaml_prepopulate_bypass yang sudah kita
            # definisikan diatas.
            if [ -n "$yaml_prepopulate_bypass" ];then
                _; _.
                __; _, Argument; _, ' '; _, "$parameter"; _, ' ';  _, set to skip by user,' '; _, pass; _, .; _.
                break
            fi

            # Prepopulate.
            # Cara dibawah ini simple, tapi lambat.
            # ```
            #     rcm-yaml find parameter "${parameter}" then get prepopulate flag
            #     yaml_prepopulate_flag="$_return_value"
            # ```
            # Gunakan saja variable $yaml_prepopulate_flag yang sudah kita
            # definisikan diatas.
            if [ -n "$yaml_prepopulate_flag" ];then
                _; _.
                echo-wrap-color "Argument <magenta>${parameter}</magenta> prepopulated." green
                # Cara dibawah ini simple, tapi lambat.
                # ```
                #     rcm-yaml find parameter "${parameter}" then set flag 1
                # ```
                # Solusinya dengan direct langsung ke RCM_YAML manual.
                RCM_YAML+='  flag: 1'$'\n'
                # Lalu beri set sebagai variable sehingga tidak perlu get lagi.
                yaml_flag=1
                break
            fi

            # Restore.
            if [ -n "$backup_flag" ];then
                print-backup-flag-dialog
                if [ -n "$RCM_BOOLEAN" ];then
                    # Cara dibawah ini simple, tapi lambat.
                    # ```
                    #     rcm-yaml find parameter "${parameter}" then set flag 1
                    # ```
                    # Solusinya dengan direct langsung ke RCM_YAML manual.
                    RCM_YAML+='  flag: 1'$'\n'
                    # Lalu beri set sebagai variable sehingga tidak perlu get lagi.
                    yaml_flag=1
                fi
                # Note. Langusng break jika menolak restore, artinya false.
                break
            fi

            # Process description.
            while true; do
                find=`echo "$description" | grep -i -o -E 'Conditional: [^\.]+\.'`
                if [ -n "$find" ];then
                    parse-conditional "$find"
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
            if [ -n "$description" ];then
                _; _.
                while read line; do
                    echo-wrap "$line"
                done <<< "$description"
            fi

            _; _.
            __; _, Add this argument?; _.
            read-false
            if [ -n "$RCM_BOOLEAN" ];then
                _; _.
                echo-wrap-color "Argument <magenta>${parameter}</magenta> added manually." green
                # Cara dibawah ini simple, tapi lambat.
                # ```
                #     rcm-yaml find parameter "${parameter}" then set flag 1
                # ```
                # Solusinya dengan direct langsung ke RCM_YAML manual.
                RCM_YAML+='  flag: 1'$'\n'
                # Lalu beri set sebagai variable sehingga tidak perlu get lagi.
                yaml_flag=1
                break
            fi
            break
        done

        # Cara dibawah ini simple, tapi lambat.
        # ```
        #     rcm-yaml find parameter "${parameter}" then get flag
        #     yaml_flag="$_return_value"
        # ```
        # Gunakan saja variable $yaml_flag yang sudah kita
        # definisikan diatas.
        if [ -n "$yaml_flag" ];then
            RCM_ARGUMENT_PASS+=("${parameter}")
            RCM_ARGUMENT_PREVIEW+=("${parameter}")
            RCM_ARGUMENT_PASS_QUOTED+=("${parameter}")
        else
            RCM_ARGUMENT_PREVIEW+=("${parameter}-")
        fi

        # Backup to text file for flag.
        if [ -n "$yaml_flag" ];then
            mkdir -p $(dirname "$backup_storage")
            echo "${parameter}" >> "$backup_storage"
        fi
    }

    print-value-dialog() {
        # Cara dibawah ini simple, tapi lambat.
        # ```
        #     rcm-yaml find parameter "${parameter}" then get validate is_required
        #     is_required="$_return_value"
        # ```
        # Solusinya adalah dengan menyelesaikan semuanya di method
        # parse-parameter() sehingga variable menjadi global.
        # global is_required
        _; _.
        if [ -n "$is_required" ];then
            _ 'Argument '; magenta "${parameter}";_, ' is '; yellow requires;_, ' a value.'; _.
        else
            _ 'Argument '; magenta "${parameter}";_, ' is '; _, optional;_, ' and may have value.'; _.
        fi

        for each in "${RCM_PREPOPULATE_ARGUMENTS[@]}";do
            if grep -q -- "^${parameter}" <<< "$each";then
                while true; do
                    if [[ "$each" == "${parameter}-" ]];then
                        # Cara dibawah ini simple, tapi lambat.
                        # ```
                        #     rcm-yaml find parameter "${parameter}" then set prepopulate bypass 1
                        # ```
                        # Solusinya dengan direct langsung ke RCM_YAML manual.
                        RCM_YAML+='  prepopulate:'$'\n'
                        RCM_YAML+='    bypass: 1'$'\n'
                        # Lalu beri set sebagai variable sehingga tidak perlu get lagi.
                        yaml_prepopulate_bypass=1
                        break
                    fi
                    if [[ "$each" =~ "${parameter}=" ]];then
                        value="${each#$parameter=}"
                        # Cara dibawah ini simple, tapi lambat.
                        # ```
                        #     rcm-yaml find parameter "${parameter}" then set prepopulate value "$value"
                        # ```
                        # Solusinya dengan direct langsung ke RCM_YAML manual.
                        RCM_YAML+='  prepopulate:'$'\n'
                        RCM_YAML+='    value: '"$value"$'\n'
                        # Lalu beri set sebagai variable sehingga tidak perlu get lagi.
                        yaml_prepopulate_value="$value"
                        break
                    fi
                    break
                done
            fi
        done
        while true; do
            # Bypass.
            if [ -n "$bypass_dialog" ];then
                break
            fi
            # Cara dibawah ini simple, tapi lambat.
            # ```
            #     rcm-yaml find parameter "${parameter}" then get conditional bypass
            #     yaml_conditional_bypass="$_return_value"
            # ```
            # Gunakan saja variable $yaml_conditional_bypass yang sudah kita
            # definisikan diatas.
            if [ -n "$yaml_conditional_bypass" ];then
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
                # Cara dibawah ini simple, tapi lambat.
                # ```
                #     rcm-yaml find parameter "${parameter}" then get prepopulate bypass
                #     yaml_prepopulate_bypass="$_return_value"
                # ```
                # Gunakan saja variable $yaml_prepopulate_bypass yang sudah kita
                # definisikan diatas.
                if [ -n "$yaml_prepopulate_bypass" ];then
                    _; _.
                    __; _, Argument; _, ' '; _, "$parameter"; _, ' ';  _, set to skip by user,' '; _, pass; _, .; _.
                    break
                fi
            fi

            # Prepopulate.
            # Cara dibawah ini simple, tapi lambat.
            # ```
            #     rcm-yaml find parameter "${parameter}" then get prepopulate value
            #     yaml_prepopulate_value="$_return_value"
            # ```
            # Gunakan saja variable $yaml_prepopulate_value yang sudah kita
            # definisikan diatas.
            if [ -n "$yaml_prepopulate_value" ];then
                _; _.
                value="$yaml_prepopulate_value"
                echo-wrap-color "Argument <magenta>${parameter}</magenta> prepopulated with value <yellow>${value}</yellow> ." green
                # Cara dibawah ini simple, tapi lambat.
                # ```
                #     rcm-yaml find parameter "${parameter}" then set value "$value"
                # ```
                # Solusinya dengan direct langsung ke RCM_YAML manual.
                RCM_YAML+='  value: '"$value"$'\n'
                break
            fi

            # Restore.
            if [ -n "$backup_value" ];then
                print-backup-dialog
                if [ -n "$value" ];then
                    # Cara dibawah ini simple, tapi lambat.
                    # ```
                    #     rcm-yaml find parameter "${parameter}" then set value "$value"
                    # ```
                    # Solusinya dengan direct langsung ke RCM_YAML manual.
                    RCM_YAML+='  value: '"$value"$'\n'
                    break
                fi
            fi

            # Process description.
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
            if [ -n "$description" ];then
                _; _.
                while read line; do
                    echo-wrap "$line"
                done <<< "$description"
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
                # Cara dibawah ini simple, tapi lambat.
                # ```
                #     rcm-yaml find parameter "${parameter}" then set value "$value"
                # ```
                # Solusinya dengan direct langsung ke RCM_YAML manual.
                RCM_YAML+='  value: '"$value"$'\n'
            fi

            break
        done

        # Save value.
        # Cara dibawah ini simple, tapi lambat.
        # ```
        #     rcm-yaml find parameter "${parameter}" then get value
        #     value="$_return_value"
        # ```
        # Gunakan saja variable $value yang sudah kita
        # definisikan diatas.
        if [ -n "$value" ];then
            RCM_ARGUMENT_PASS+=("${parameter}=${value}")
            [[ "$value" =~ ' ' ]] && value="'$value'"
            RCM_ARGUMENT_PREVIEW+=("${parameter}=${value}")
            RCM_ARGUMENT_PASS_QUOTED+=("${parameter}=${value}")
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
            RCM_ARGUMENT_PLACEHOLDERS+=$'\n'
        fi
    }

    print-flag-value-dialog() {
        _; _.
        _ 'Argument '; magenta "${parameter}";_, ' is '; _, optional; _, ' and may have value.'; _.
        for each in "${RCM_PREPOPULATE_ARGUMENTS[@]}";do
            if grep -q -- "^${parameter}" <<< "$each";then
                while true; do
                    if [[ "$each" == "${parameter}-" ]];then
                        # Cara dibawah ini simple, tapi lambat.
                        # ```
                        #     rcm-yaml find parameter "${parameter}" then set prepopulate bypass 1
                        # ```
                        # Solusinya dengan direct langsung ke RCM_YAML manual.
                        RCM_YAML+='  prepopulate:'$'\n'
                        RCM_YAML+='    bypass: 1'$'\n'
                        # Lalu beri set sebagai variable sehingga tidak perlu get lagi.
                        yaml_prepopulate_bypass=1
                        break
                    fi
                    if [[ "$each" == "${parameter}" ]];then
                        # Cara dibawah ini simple, tapi lambat.
                        # ```
                        #     rcm-yaml find parameter "${parameter}" then set prepopulate flag 1
                        # ```
                        # Solusinya dengan direct langsung ke RCM_YAML manual.
                        RCM_YAML+='  prepopulate:'$'\n'
                        RCM_YAML+='    flag: 1'$'\n'
                        # Lalu beri set sebagai variable sehingga tidak perlu get lagi.
                        yaml_prepopulate_flag=1
                        break
                    fi
                    if [[ "$each" =~ "${parameter}=" ]];then
                        value="${each#$parameter=}"
                        # Cara dibawah ini simple, tapi lambat.
                        # ```
                        #     rcm-yaml find parameter "${parameter}" then set prepopulate flag 1
                        #     rcm-yaml find parameter "${parameter}" then set prepopulate value "$value"
                        # ```
                        # Solusinya dengan direct langsung ke RCM_YAML manual.
                        RCM_YAML+='  prepopulate:'$'\n'
                        RCM_YAML+='    flag: 1'$'\n'
                        RCM_YAML+='    value: '"$value"$'\n'
                        # Lalu beri set sebagai variable sehingga tidak perlu get lagi.
                        yaml_prepopulate_flag=1
                        yaml_prepopulate_value="$value"
                        break
                    fi
                    break
                done
            fi
        done

        while true; do
            # Bypass.
            if [ -n "$bypass_dialog" ];then
                break
            fi
            # Cara dibawah ini simple, tapi lambat.
            # ```
            #     rcm-yaml find parameter "${parameter}" then get conditional bypass
            #     yaml_conditional_bypass="$_return_value"
            # ```
            # Gunakan saja variable $yaml_conditional_bypass yang sudah kita
            # definisikan diatas.
            if [ -n "$yaml_conditional_bypass" ];then
                _; _.
                echo-wrap-color "Argument <magenta>${parameter}</magenta> skip by conditional." yellow
                if [ -n "$conditional" ];then
                    _; _.
                    echo-wrap "$conditional"
                fi
                break
            fi

            # Bypass.
            # Cara dibawah ini simple, tapi lambat.
            # ```
            #     rcm-yaml find parameter "${parameter}" then get prepopulate bypass
            #     yaml_prepopulate_bypass="$_return_value"
            # ```
            # Gunakan saja variable $yaml_prepopulate_bypass yang sudah kita
            # definisikan diatas.
            if [ -n "$yaml_prepopulate_bypass" ];then
                _; _.
                __; _, Argument; _, ' '; _, "$parameter"; _, ' ';  _, set to skip by user,' '; _, pass; _, .; _.
                break
            fi

            # Prepopulate.
            # Cara dibawah ini simple, tapi lambat.
            # ```
            #     rcm-yaml find parameter "${parameter}" then get prepopulate flag
            #     yaml_prepopulate_flag="$_return_value"
            # ```
            # Gunakan saja variable $yaml_prepopulate_flag yang sudah kita
            # definisikan diatas.
            if [ -n "$yaml_prepopulate_flag" ];then
                # Cara dibawah ini simple, tapi lambat.
                # ```
                #     rcm-yaml find parameter "${parameter}" then set flag 1
                # ```
                # Solusinya dengan direct langsung ke RCM_YAML manual.
                RCM_YAML+='  flag: 1'$'\n'
                # Lalu beri set sebagai variable sehingga tidak perlu get lagi.
                yaml_flag=1
                # Cara dibawah ini simple, tapi lambat.
                # ```
                #     rcm-yaml find parameter "${parameter}" then get prepopulate value
                #     yaml_prepopulate_value="$_return_value"
                # ```
                # Gunakan saja variable $yaml_prepopulate_value yang sudah kita
                # definisikan diatas.
                if [ -n "$yaml_prepopulate_value" ];then
                    value="$yaml_prepopulate_value"
                    _; _.
                    echo-wrap-color "Argument <magenta>${parameter}</magenta> prepopulated with value <yellow>${value}</yellow> ." green
                    # Cara dibawah ini simple, tapi lambat.
                    # ```
                    #     rcm-yaml find parameter "${parameter}" then set value "$value"
                    # ```
                    # Solusinya dengan direct langsung ke RCM_YAML manual.
                    RCM_YAML+='  value: '"$value"$'\n'
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
                    # Cara dibawah ini simple, tapi lambat.
                    # ```
                    #     rcm-yaml find parameter "${parameter}" then set flag 1
                    # ```
                    # Solusinya dengan direct langsung ke RCM_YAML manual.
                    RCM_YAML+='  flag: 1'$'\n'
                    # Lalu beri set sebagai variable sehingga tidak perlu get lagi.
                    yaml_flag=1
                    if [ -n "$backup_value" ];then
                        print-backup-dialog
                    fi
                    if [ -z "$value" ];then
                        print-fill-a-value-dialog
                    fi
                    # User may leave blank.
                    if [ -n "$value" ];then
                        # Cara dibawah ini simple, tapi lambat.
                        # ```
                        #     rcm-yaml find parameter "${parameter}" then set value "$value"
                        # ```
                        # Solusinya dengan direct langsung ke RCM_YAML manual.
                        RCM_YAML+='  value: '"$value"$'\n'
                    fi
                fi
                # Note. Langusng break jika menolak restore, artinya false.
                break
            fi

            # Process description.
            while true; do
                find=`echo "$description" | grep -i -o -E 'Conditional: [^\.]+\.'`
                if [ -n "$find" ];then
                    parse-conditional "$find"
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
            if [ -n "$description" ];then
                _; _.
                while read line; do
                    echo-wrap "$line"
                done <<< "$description"
            fi

            # Todo, how about prepopulate value from variable.
            _; _.
            __; _, Add this argument?; _.
            read-false
            if [ -n "$RCM_BOOLEAN" ];then
                _; _.
                echo-wrap-color "Argument <magenta>${parameter}</magenta> added manually." green
                # Cara dibawah ini simple, tapi lambat.
                # ```
                #     rcm-yaml find parameter "${parameter}" then set flag 1
                # ```
                # Solusinya dengan direct langsung ke RCM_YAML manual.
                RCM_YAML+='  flag: 1'$'\n'
                # Lalu beri set sebagai variable sehingga tidak perlu get lagi.
                yaml_flag=1
                print-fill-a-value-dialog
                if [ -n "$value" ];then
                    _; _.
                    echo-wrap-color "Argument <magenta>${parameter}</magenta> filled with value <yellow>$value</yellow> manually." green
                    # Cara dibawah ini simple, tapi lambat.
                    # ```
                    #     rcm-yaml find parameter "${parameter}" then set value "$value"
                    # ```
                    # Solusinya dengan direct langsung ke RCM_YAML manual.
                    RCM_YAML+='  value: '"$value"$'\n'
                fi
                break
            fi
            break
        done

        # Save value.
        # Cara dibawah ini simple, tapi lambat.
        # ```
        #     rcm-yaml find parameter "${parameter}" then get flag
        #     yaml_flag="$_return_value"
        # ```
        # Gunakan saja variable $yaml_flag yang sudah kita
        # definisikan diatas.
        if [ -n "$yaml_flag" ];then
            # Cara dibawah ini simple, tapi lambat.
            # ```
            #     rcm-yaml find parameter "${parameter}" then get value
            #     value="$_return_value"
            # ```
            # Gunakan saja variable $value yang sudah kita
            # definisikan diatas.
            if [ -n "$value" ];then
                RCM_ARGUMENT_PASS+=("${parameter}=${value}")
                [[ "$value" =~ ' ' ]] && value="'$value'"
                RCM_ARGUMENT_PREVIEW+=("${parameter}=${value}")
                RCM_ARGUMENT_PASS_QUOTED+=("${parameter}=${value}")
            else
                RCM_ARGUMENT_PASS+=("${parameter}")
                RCM_ARGUMENT_PREVIEW+=("${parameter}")
                RCM_ARGUMENT_PASS_QUOTED+=("${parameter}")
            fi
        else
            RCM_ARGUMENT_PREVIEW+=("${parameter}-")
        fi

        # Backup to text file for flag or value.
        if [ -n "$yaml_flag" ];then
            mkdir -p $(dirname "$backup_storage")
            if [ -n "$value" ];then
                echo "${parameter}=${value}" >> "$backup_storage"
            else
                echo "${parameter}" >> "$backup_storage"
            fi
        fi

        # Save to placeholders.
        if [ -n "$yaml_flag" ];then
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
        for each in "${RCM_PREPOPULATE_ARGUMENTS[@]}";do
            if grep -q -- "^${parameter}" <<< "$each";then
                while true; do
                    if [[ "$each" == "${parameter}-" ]];then
                        # Cara dibawah ini simple, tapi lambat.
                        # ```
                        #     rcm-yaml find parameter "${parameter}" then set prepopulate bypass 1
                        # ```
                        # Solusinya dengan direct langsung ke RCM_YAML manual.
                        RCM_YAML+='  prepopulate:'$'\n'
                        RCM_YAML+='    bypass: 1'$'\n'
                        # Lalu beri set sebagai variable sehingga tidak perlu get lagi.
                        yaml_prepopulate_bypass=1
                        break
                    fi
                    if [[ "$each" == "${parameter}" ]];then
                        # Cara dibawah ini simple, tapi lambat.
                        # ```
                        #     rcm-yaml find parameter "${parameter}" then increase prepopulate count
                        # ```
                        # Solusinya dengan direct langsung ke RCM_YAML manual.
                        # Tahap pertama: loop and gathered.
                        yaml_prepopulate_count=$((yaml_prepopulate_count+1))
                        break
                    fi
                    break
                done
            fi
        done
        # Cara dibawah ini simple, tapi lambat.
        # ```
        #     rcm-yaml find parameter "${parameter}" then increase prepopulate count
        # ```
        # Solusinya dengan direct langsung ke RCM_YAML manual.
        # Tahap kedua: edit.
        if [ $yaml_prepopulate_count -gt 0 ];then
            RCM_YAML+='  prepopulate:'$'\n'
            RCM_YAML+='    count: '"$yaml_prepopulate_count"$'\n'
        fi

        while true; do
            # Bypass.
            if [ -n "$bypass_dialog" ];then
                break
            fi
            # Cara dibawah ini simple, tapi lambat.
            # ```
            #     rcm-yaml find parameter "${parameter}" then get conditional bypass
            #     yaml_conditional_bypass="$_return_value"
            # ```
            # Gunakan saja variable $yaml_conditional_bypass yang sudah kita
            # definisikan diatas.
            if [ -n "$yaml_conditional_bypass" ];then
                _; _.
                echo-wrap-color "Argument <magenta>${parameter}</magenta> skip by conditional." yellow
                if [ -n "$conditional" ];then
                    _; _.
                    echo-wrap "$conditional"
                fi
                break
            fi

            # Bypass.
            # Cara dibawah ini simple, tapi lambat.
            # ```
            #     rcm-yaml find parameter "${parameter}" then get prepopulate bypass
            #     yaml_prepopulate_bypass="$_return_value"
            # ```
            # Gunakan saja variable $yaml_prepopulate_bypass yang sudah kita
            # definisikan diatas.
            if [ -n "$yaml_prepopulate_bypass" ];then
                _; _.
                __; _, Argument; _, ' '; _, "$parameter"; _, ' ';  _, set to skip by user,' '; _, pass; _, .; _.
                break
            fi
            # Khusus increment, pilih salah satu antara prepopulate
            # atau restore.
            while true; do

                # Prepopulate.
                # Cara dibawah ini simple, tapi lambat.
                # ```
                #     rcm-yaml find parameter "${parameter}" then get prepopulate count
                #     yaml_prepopulate_count="$_return_value"
                # ```
                # Gunakan saja variable $yaml_prepopulate_count yang sudah kita
                # definisikan diatas.

                if [ -n "$yaml_prepopulate_count" ];then
                    yaml_count="$yaml_prepopulate_count"
                    _; _.
                    for ((i = 0 ; i < $yaml_count ; i++)); do
                        echo-wrap-color "Argument <magenta>${parameter}</magenta> prepopulated." green
                    done
                    # Cara dibawah ini simple, tapi lambat.
                    # ```
                    #     rcm-yaml find parameter "${parameter}" then set count $yaml_count
                    # ```
                    # Solusinya dengan direct langsung ke RCM_YAML manual.
                    RCM_YAML+='  count: '"$yaml_count"$'\n'
                    break
                fi
                # Restore.
                if [ -n "$backup_value" ];then
                    print-backup-flag-dialog
                    if [ -n "$RCM_BOOLEAN" ];then
                        yaml_count="$backup_value"
                        _; _.
                        for ((i = 0 ; i < $count ; i++)); do
                            echo-wrap-color "Argument <magenta>${parameter}</magenta> added which is restored." green
                        done
                        # Cara dibawah ini simple, tapi lambat.
                        # ```
                        #     rcm-yaml find parameter "${parameter}" then set count $yaml_count
                        # ```
                        # Solusinya dengan direct langsung ke RCM_YAML manual.
                        RCM_YAML+='  count: '"$yaml_count"$'\n'
                        break
                    fi
                fi
                break
            done

            # Process description.
            while true; do
                find=`echo "$description" | grep -i -o -E 'Conditional: [^\.]+\.'`
                if [ -n "$find" ];then
                    parse-conditional "$find"
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
            if [ -n "$description" ];then
                _; _.
                while read line; do
                    echo-wrap "$line"
                done <<< "$description"
            fi

            while true; do
                if [ "$yaml_count" -eq 0 ];then
                    _; _.
                    __; _, Add this argument?; _.
                    read-false
                    if [ -n "$RCM_BOOLEAN" ];then
                        _; _.
                        echo-wrap-color "Argument <magenta>${parameter}</magenta> added manually." green
                        yaml_count=$((yaml_count + 1))
                        # Cara dibawah ini simple, tapi lambat.
                        # ```
                        #     rcm-yaml find parameter "${parameter}" then set count $yaml_count
                        # ```
                        # Solusinya dengan direct langsung ke RCM_YAML manual.
                        RCM_YAML+='  count: '"$yaml_count"$'\n'
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
                        yaml_count=$((yaml_count + 1))
                        # Cara dibawah ini simple, tapi lambat.
                        # ```
                        #     rcm-yaml find parameter "${parameter}" then set count $yaml_count
                        # ```
                        # Solusinya dengan direct langsung ke RCM_YAML manual.
                        # Hapus dulu value existing.
                        RCM_YAML=$(echo "$RCM_YAML" | head -n -2)$'\n'
                        RCM_YAML+='  count: '"$yaml_count"$'\n'
                    else
                        break
                    fi
                fi
            done
            break
        done

        # Save value.
        # Cara dibawah ini simple, tapi lambat.
        # ```
        #     rcm-yaml find parameter "${parameter}" then get count
        #     yaml_count="$_return_value"
        # ```
        # Gunakan saja variable $yaml_flag yang sudah kita
        # definisikan diatas.
        if [ -n "$yaml_count" ];then
            for ((i = 0 ; i < $yaml_count ; i++)); do
                RCM_ARGUMENT_PASS+=("${parameter}")
                RCM_ARGUMENT_PREVIEW+=("${parameter}")
                RCM_ARGUMENT_PASS_QUOTED+=("${parameter}")
            done
        else
            RCM_ARGUMENT_PREVIEW+=("${parameter}-")
        fi

        # Backup to text file for increment.
        if [ -n "$yaml_count" ];then
            mkdir -p $(dirname "$backup_storage")
            echo "${parameter}=${count}" >> "$backup_storage"
        fi
    }

    print-multivalue-dialog() {
        # Cara dibawah ini simple, tapi lambat.
        # ```
        #     rcm-yaml find parameter "${parameter}" then get validate is_required
        #     is_required="$_return_value"
        # ```
        # Solusinya adalah dengan menyelesaikan semuanya di method
        # parse-parameter() sehingga variable menjadi global.
        # global is_required
        _; _.
        if [ -n "$is_required" ];then
            _ 'Argument '; magenta "${parameter}";_, ' is '; yellow required; _, ' at least a value.'; _.
        else
            _ 'Argument '; magenta "${parameter}";_, ' is '; _, optional;_, ' and may have many value.'; _.
        fi

        for each in "${RCM_PREPOPULATE_ARGUMENTS[@]}";do
            if grep -q -- "^${parameter}" <<< "$each";then
                while true; do
                    if [[ "$each" == "${parameter}-" ]];then
                        # Cara dibawah ini simple, tapi lambat.
                        # ```
                        #     rcm-yaml find parameter "${parameter}" then set prepopulate bypass 1
                        # ```
                        # Solusinya dengan direct langsung ke RCM_YAML manual.
                        RCM_YAML+='  prepopulate:'$'\n'
                        RCM_YAML+='    bypass: 1'$'\n'
                        # Lalu beri set sebagai variable sehingga tidak perlu get lagi.
                        yaml_prepopulate_bypass=1
                        break
                    fi
                    if [[ "$each" =~ "${parameter}=" ]];then
                        value="${each#$parameter=}"
                        # Cara dibawah ini simple, tapi lambat.
                        # ```
                        #     rcm-yaml find parameter "${parameter}" then append prepopulate values "$value"
                        # ```
                        # Solusinya dengan direct langsung ke RCM_YAML manual.
                        # Tahap pertama: loop and gathered.
                        yaml_prepopulate_values+=("$value")
                        break
                    fi
                    break
                done
            fi
        done

        # Cara dibawah ini simple, tapi lambat.
        # ```
        #     rcm-yaml find parameter "${parameter}" then append prepopulate values "$value"
        # ```
        # Solusinya dengan direct langsung ke RCM_YAML manual.
        # Tahap kedua: edit.
        if [ ${#yaml_prepopulate_values[@]} -gt 0 ];then
            RCM_YAML+='  prepopulate:'$'\n'
            RCM_YAML+='    values:'$'\n'
            for each in "${yaml_prepopulate_values[@]}"; do
                RCM_YAML+='      - '"$each"$'\n'
            done
        fi

        while true; do
            # Bypass.
            if [ -n "$bypass_dialog" ];then
                break
            fi
            # Cara dibawah ini simple, tapi lambat.
            # ```
            #     rcm-yaml find parameter "${parameter}" then get conditional bypass
            #     yaml_conditional_bypass="$_return_value"
            # ```
            # Gunakan saja variable $yaml_conditional_bypass yang sudah kita
            # definisikan diatas.
            if [ -n "$yaml_conditional_bypass" ];then
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
                # Cara dibawah ini simple, tapi lambat.
                # ```
                #     rcm-yaml find parameter "${parameter}" then get prepopulate bypass
                #     yaml_prepopulate_bypass="$_return_value"
                # ```
                # Gunakan saja variable $yaml_prepopulate_bypass yang sudah kita
                # definisikan diatas.
                if [ -n "$yaml_prepopulate_bypass" ];then
                    _; _.
                    __; _, Argument; _, ' '; _, "$parameter"; _, ' ';  _, set to skip by user,' '; _, pass; _, .; _.
                    break
                fi
            fi

            # Prepopulate.
            # Cara dibawah ini simple, tapi lambat.
            # ```
            #     rcm-yaml find parameter "${parameter}" then get prepopulate values
            #     yaml_prepopulate_values=("${_return_array[@]}")
            # ```
            # Gunakan saja variable $yaml_prepopulate_values yang sudah kita
            # definisikan diatas.
            if [ "${#yaml_prepopulate_values[@]}" -gt 0 ];then
                _; _.
                for value in "${yaml_prepopulate_values[@]}"; do
                    echo-wrap-color "Argument <magenta>${parameter}</magenta> prepopulated with value <yellow>$value</yellow>." green
                    # Cara dibawah ini simple, tapi lambat.
                    # ```
                    #     rcm-yaml find parameter "${parameter}" then append values "$value"
                    # ```
                    # Solusinya dengan direct langsung ke RCM_YAML manual.
                    # Tahap pertama: loop and gathered.
                    yaml_values+=("$value")
                done
                # Cara dibawah ini simple, tapi lambat.
                # ```
                #     rcm-yaml find parameter "${parameter}" then append values "$value"
                # ```
                # Solusinya dengan direct langsung ke RCM_YAML manual.
                # Tahap kedua: edit.
                if [ ${#yaml_values[@]} -gt 0 ];then
                    RCM_YAML+='  values:'$'\n'
                    yaml_values_key=1
                    for each in "${yaml_prepopulate_values[@]}"; do
                        RCM_YAML+='    - '"$each"$'\n'
                    done
                fi
                # break
                # Note: Tidak ada break seperti flag_value atau value, tapi tetap
                # dilanjutkan karena multivalue.
            fi

            # Restore.
            if [ -n "$backup_values" ];then
                # Backup and reset.
                yaml_values_backup=("${yaml_values[@]}")
                yaml_values=()
                until [[ -z "$backup_values" ]];do
                    backup_value=`sed -n 1p <<< "$backup_values"`
                    backup_values=`sed -n '2,$p' <<< "$backup_values"`
                    print-backup-dialog
                    if [ -n "$value" ];then
                        # Cara dibawah ini simple, tapi lambat.
                        # ```
                        #     rcm-yaml find parameter "${parameter}" then append values "$value"
                        # ```
                        # Solusinya dengan direct langsung ke RCM_YAML manual.
                        # Tahap pertama: loop and gathered.
                        yaml_values+=("$value")
                    fi
                done
                # Cara dibawah ini simple, tapi lambat.
                # ```
                #     rcm-yaml find parameter "${parameter}" then append values "$value"
                # ```
                # Solusinya dengan direct langsung ke RCM_YAML manual.
                # Tahap kedua: edit.
                if [ ${#yaml_values[@]} -gt 0 ];then
                    if [ -z "$yaml_values_key" ];then
                        RCM_YAML+='  values:'$'\n'
                        yaml_values_key=1
                    fi
                    for each in "${yaml_values[@]}"; do
                        RCM_YAML+='    - '"$each"$'\n'
                    done
                fi
                yaml_values=("${yaml_values[@]}" "${yaml_values_backup[@]}")

                # break
                # Note: Tidak ada break seperti flag_value atau value, tapi tetap
                # dilanjutkan karena multivalue.
            fi

            # Process description.
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
            if [ -n "$RCM_ARGUMENT_PLACEHOLDERS" ];then
                while read line; do
                    find=$(echo ${line} | sed -E 's|^([^:]+):.*|\1|' | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
                    replace=$(echo ${line} | sed -E 's|^[^:]+:(.*)|\1|' | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
                    description="${description/"$find"/"$replace"}"
                done <<< "$RCM_ARGUMENT_PLACEHOLDERS"
            fi
            if [ -n "$description" ];then
                _; _.
                while read line; do
                    echo-wrap "$line"
                done <<< "$description"
            fi

            # Cara dibawah ini simple, tapi lambat.
            # ```
            #     rcm-yaml find parameter "${parameter}" then get prepopulate values
            #     values=("${_return_array[@]}")
            # ```
            # Gunakan saja variable $yaml_prepopulate_values yang sudah kita
            # definisikan diatas.
            if [ "${#yaml_prepopulate_values[@]}" -eq 0 ];then
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
                    # Cara dibawah ini simple, tapi lambat.
                    # ```
                    #     rcm-yaml find parameter "${parameter}" then append values "$value"
                    # ```
                    # Solusinya dengan direct langsung ke RCM_YAML manual.
                    if [ -z "$yaml_values_key" ];then
                        RCM_YAML+='  values:'$'\n'
                        yaml_values_key=1
                    fi
                    RCM_YAML+='    - '"$value"$'\n'
                    yaml_values+=("$value")
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
                    # Cara dibawah ini simple, tapi lambat.
                    # ```
                    #     rcm-yaml find parameter "${parameter}" then append values "$value"
                    # ```
                    # Solusinya dengan direct langsung ke RCM_YAML manual.
                    RCM_YAML+='    - '"$value"$'\n'
                    yaml_values+=("$value")
                else
                    break
                fi
            done
            break
        done

        # Cara dibawah ini simple, tapi lambat.
        # ```
        #     rcm-yaml find parameter "${parameter}" then get values
        #     yaml_values=("${_return_array[@]}")
        # ```
        # Gunakan saja variable $yaml_values yang sudah kita
        # definisikan diatas.
        if [ "${#yaml_values[@]}" -gt 0 ];then
            for value in "${yaml_values[@]}"; do
                RCM_ARGUMENT_PASS+=("${parameter}=${value}")
                [[ "$value" =~ ' ' ]] && value="'$value'"
                RCM_ARGUMENT_PREVIEW+=("${parameter}=${value}")
                RCM_ARGUMENT_PASS_QUOTED+=("${parameter}=${value}")
            done
        else
            RCM_ARGUMENT_PREVIEW+=("${parameter}-")
        fi

        # Backup to text file for value.
        if [ "${#yaml_values[@]}" -gt 0 ];then
            mkdir -p $(dirname "$backup_storage")
            for value in "${yaml_values[@]}"; do
                [[ "$value" =~ ' ' ]] && value="'$value'"
                echo "${parameter}=${value}" >> "$backup_storage"
            done
        fi

        # Placeholder tidak berlaku untuk multivalue.
    }

    print-flag-multivalue-dialog() {
        _; _.
        _ 'Argument '; magenta "${parameter}";_, ' is '; _, optional;_, ' and may have many value.'; _.
        for each in "${RCM_PREPOPULATE_ARGUMENTS[@]}";do
            if grep -q -- "^${parameter}" <<< "$each";then
                while true; do
                    if [[ "$each" == "${parameter}-" ]];then
                        # Cara dibawah ini simple, tapi lambat.
                        # ```
                        #     rcm-yaml find parameter "${parameter}" then set prepopulate bypass 1
                        # ```
                        # Solusinya dengan direct langsung ke RCM_YAML manual.
                        RCM_YAML+='  prepopulate:'$'\n'
                        RCM_YAML+='    bypass: 1'$'\n'
                        # Lalu beri set sebagai variable sehingga tidak perlu get lagi.
                        yaml_prepopulate_bypass=1
                        break
                    fi
                    if [[ "$each" == "${parameter}" ]];then
                        # Cara dibawah ini simple, tapi lambat.
                        # ```
                        #     rcm-yaml find parameter "${parameter}" then set prepopulate flag 1
                        # ```
                        # Solusinya dengan direct langsung ke RCM_YAML manual.
                        RCM_YAML+='  prepopulate:'$'\n'
                        RCM_YAML+='    flag: 1'$'\n'
                        # Lalu beri set sebagai variable sehingga tidak perlu get lagi.
                        yaml_prepopulate_flag=1
                        break
                    fi
                    if [[ "$each" =~ "${parameter}=" ]];then
                        value="${each#$parameter=}"
                        # Cara dibawah ini simple, tapi lambat.
                        # ```
                        #     rcm-yaml find parameter "${parameter}" then set prepopulate flag 1
                        # ```
                        # Solusinya dengan direct langsung ke RCM_YAML manual.
                        RCM_YAML+='  prepopulate:'$'\n'
                        RCM_YAML+='    flag: 1'$'\n'
                        # Lalu beri set sebagai variable sehingga tidak perlu get lagi.
                        yaml_prepopulate_flag=1
                        # Cara dibawah ini simple, tapi lambat.
                        # ```
                        #     rcm-yaml find parameter "${parameter}" then append prepopulate values "$value"
                        # ```
                        # Solusinya dengan direct langsung ke RCM_YAML manual.
                        # Tahap pertama: loop and gathered.
                        yaml_prepopulate_values+=("$value")
                        break
                    fi
                    break
                done
            fi
        done

        # Cara dibawah ini simple, tapi lambat.
        # ```
        #     rcm-yaml find parameter "${parameter}" then append prepopulate values "$value"
        # ```
        # Solusinya dengan direct langsung ke RCM_YAML manual.
        # Tahap kedua: edit.
        if [ ${#yaml_prepopulate_values[@]} -gt 0 ];then
            RCM_YAML+='  prepopulate:'$'\n'
            RCM_YAML+='    values:'$'\n'
            for each in "${yaml_prepopulate_values[@]}"; do
                RCM_YAML+='      - '"$each"$'\n'
            done
        fi

        while true; do
            # Bypass.
            if [ -n "$bypass_dialog" ];then
                break
            fi
            # Cara dibawah ini simple, tapi lambat.
            # ```
            #     rcm-yaml find parameter "${parameter}" then get conditional bypass
            #     yaml_conditional_bypass="$_return_value"
            # ```
            # Gunakan saja variable $yaml_conditional_bypass yang sudah kita
            # definisikan diatas.
            if [ -n "$yaml_conditional_bypass" ];then
                _; _.
                echo-wrap-color "Argument <magenta>${parameter}</magenta> skip by conditional." yellow
                if [ -n "$conditional" ];then
                    _; _.
                    echo-wrap "$conditional"
                fi
                break
            fi
            # Bypass.
            # Cara dibawah ini simple, tapi lambat.
            # ```
            #     rcm-yaml find parameter "${parameter}" then get prepopulate bypass
            #     yaml_prepopulate_bypass="$_return_value"
            # ```
            # Gunakan saja variable $yaml_prepopulate_bypass yang sudah kita
            # definisikan diatas.
            if [ -n "$yaml_prepopulate_bypass" ];then
                _; _.
                __; _, Argument; _, ' '; _, "$parameter"; _, ' ';  _, set to skip by user,' '; _, pass; _, .; _.
                break
            fi

            # Prepopulate.
            # Cara dibawah ini simple, tapi lambat.
            # ```
            #     rcm-yaml find parameter "${parameter}" then get prepopulate flag
            #     yaml_prepopulate_flag="$_return_value"
            # ```
            # Gunakan saja variable $yaml_prepopulate_flag yang sudah kita
            # definisikan diatas.
            yaml_flag="$yaml_prepopulate_flag"

            if [ -n "$yaml_flag" ];then
                # Cara dibawah ini simple, tapi lambat.
                # ```
                #     rcm-yaml find parameter "${parameter}" then set flag 1
                # ```
                # Solusinya dengan direct langsung ke RCM_YAML manual.
                RCM_YAML+='  flag: 1'$'\n'
                # Lalu beri set sebagai variable sehingga tidak perlu get lagi.
                yaml_flag=1

                # Cara dibawah ini simple, tapi lambat.
                # ```
                #     rcm-yaml find parameter "${parameter}" then get prepopulate values
                #     yaml_prepopulate_values=("${_return_array[@]}")
                # ```
                # Gunakan saja variable $yaml_prepopulate_values yang sudah kita
                # definisikan diatas.

                if [ "${#yaml_prepopulate_values[@]}" -gt 0 ];then
                    _; _.
                    for value in "${yaml_prepopulate_values[@]}"; do
                        echo-wrap-color "Argument <magenta>${parameter}</magenta> prepopulated with value <yellow>$value</yellow>." green
                        # Cara dibawah ini simple, tapi lambat.
                        # ```
                        #     rcm-yaml find parameter "${parameter}" then append values "$value"
                        # ```
                        # Solusinya dengan direct langsung ke RCM_YAML manual.
                        # Tahap pertama: loop and gathered.
                        yaml_values+=("$value")
                    done
                    # Cara dibawah ini simple, tapi lambat.
                    # ```
                    #     rcm-yaml find parameter "${parameter}" then append values "$value"
                    # ```
                    # Solusinya dengan direct langsung ke RCM_YAML manual.
                    # Tahap kedua: edit.
                    if [ ${#yaml_values[@]} -gt 0 ];then
                        RCM_YAML+='  values:'$'\n'
                        yaml_values_key=1
                        for each in "${yaml_prepopulate_values[@]}"; do
                            RCM_YAML+='    - '"$each"$'\n'
                        done
                    fi
                else
                    _; _.
                    echo-wrap-color "Argument <magenta>${parameter}</magenta> prepopulated." green
                fi
                # break
                # Note: Tidak ada break seperti flag_value atau value, tapi tetap
                # dilanjutkan karena multivalue.
            fi

            # Process description.
            # Restore terdapat dialog, sehingga description berada diatas restore.
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
            if [ -n "$RCM_ARGUMENT_PLACEHOLDERS" ];then
                while read line; do
                    find=$(echo ${line} | sed -E 's|^([^:]+):.*|\1|' | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
                    replace=$(echo ${line} | sed -E 's|^[^:]+:(.*)|\1|' | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
                    description="${description/"$find"/"$replace"}"
                done <<< "$RCM_ARGUMENT_PLACEHOLDERS"
            fi
            if [ -n "$description" ];then
                _; _.
                while read line; do
                    echo-wrap "$line"
                done <<< "$description"
            fi

            # Restore.
            if [ -n "$backup_values" ];then
                backup_flag=1
            fi
            if [ -n "$backup_flag" ];then
                print-backup-flag-dialog
                if [ -n "$RCM_BOOLEAN" ];then
                    # Cara dibawah ini simple, tapi lambat.
                    # ```
                    #     rcm-yaml find parameter "${parameter}" then set flag 1
                    # ```
                    # Solusinya dengan direct langsung ke RCM_YAML manual.
                    RCM_YAML+='  flag: 1'$'\n'
                    # Lalu beri set sebagai variable sehingga tidak perlu get lagi.
                    yaml_flag=1
                    if [ -n "$backup_values" ];then
                        yaml_values_backup=("${yaml_values[@]}")
                        yaml_values=()
                        until [[ -z "$backup_values" ]];do
                            backup_value=`sed -n 1p <<< "$backup_values"`
                            backup_values=`sed -n '2,$p' <<< "$backup_values"`
                            print-backup-dialog
                            if [ -n "$value" ];then
                                # Cara dibawah ini simple, tapi lambat.
                                # ```
                                #     rcm-yaml find parameter "${parameter}" then append values "$value"
                                # ```
                                # Solusinya dengan direct langsung ke RCM_YAML manual.
                                # Tahap pertama: loop and gathered.
                                yaml_values+=("$value")
                            fi
                        done
                        # Cara dibawah ini simple, tapi lambat.
                        # ```
                        #     rcm-yaml find parameter "${parameter}" then append values "$value"
                        # ```
                        # Solusinya dengan direct langsung ke RCM_YAML manual.
                        # Tahap kedua: edit.
                        if [ ${#yaml_values[@]} -gt 0 ];then
                            if [ -z "$yaml_values_key" ];then
                                RCM_YAML+='  values:'$'\n'
                                yaml_values_key=1
                            fi
                            for each in "${yaml_values[@]}"; do
                                RCM_YAML+='    - '"$each"$'\n'
                            done
                        fi
                        yaml_values=("${yaml_values[@]}" "${yaml_values_backup[@]}")
                    else
                        print-fill-a-value-dialog
                        # User may leave blank.
                        if [ -n "$value" ];then
                            _; _.
                            echo-wrap-color "Argument <magenta>${parameter}</magenta> filled with value <yellow>$value</yellow> manually." green
                            # Cara dibawah ini simple, tapi lambat.
                            # ```
                            #     rcm-yaml find parameter "${parameter}" then append values "$value"
                            # ```
                            # Solusinya dengan direct langsung ke RCM_YAML manual.
                            if [ -z "$yaml_values_key" ];then
                                RCM_YAML+='  values:'$'\n'
                                yaml_values_key=1
                            fi
                            RCM_YAML+='    - '"$value"$'\n'
                            yaml_values+=("$value")
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

            # Todo, how about prepopulate value from variable.
            if [ -z "$yaml_flag" ];then
                _; _.
                __; _, Add this argument?; _.
                read-false
                if [ -n "$RCM_BOOLEAN" ];then
                    _; _.
                    echo-wrap-color "Argument <magenta>${parameter}</magenta> added manually." green
                    # Cara dibawah ini simple, tapi lambat.
                    # ```
                    #     rcm-yaml find parameter "${parameter}" then set flag 1
                    # ```
                    # Solusinya dengan direct langsung ke RCM_YAML manual.
                    RCM_YAML+='  flag: 1'$'\n'
                    # Lalu beri set sebagai variable sehingga tidak perlu get lagi.
                    yaml_flag=1
                    if [ -z "$value" ];then
                        print-fill-a-value-dialog
                        if [ -n "$value" ];then
                            _; _.
                            echo-wrap-color "Argument <magenta>${parameter}</magenta> filled with value <yellow>$value</yellow> manually." green
                            # Cara dibawah ini simple, tapi lambat.
                            # ```
                            #     rcm-yaml find parameter "${parameter}" then append values "$value"
                            # ```
                            # Solusinya dengan direct langsung ke RCM_YAML manual.
                            if [ -z "$yaml_values_key" ];then
                                RCM_YAML+='  values:'$'\n'
                                yaml_values_key=1
                            fi
                            RCM_YAML+='    - '"$value"$'\n'
                            yaml_values+=("$value")
                        fi
                    fi
                    break
                fi
            fi
            break
        done

        # Cara dibawah ini simple, tapi lambat.
        # ```
        #     rcm-yaml find parameter "${parameter}" then get values
        #     yaml_values=("${_return_array[@]}")
        # ```
        # Gunakan saja variable $yaml_values yang sudah kita
        # definisikan diatas.
        if [ "${#yaml_values[@]}" -gt 0 ];then
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
                    # Cara dibawah ini simple, tapi lambat.
                    # ```
                    #     rcm-yaml find parameter "${parameter}" then append values "$value"
                    # ```
                    # Solusinya dengan direct langsung ke RCM_YAML manual.
                    if [ -z "$yaml_values_key" ];then
                        RCM_YAML+='  values:'$'\n'
                        yaml_values_key=1
                    fi
                    RCM_YAML+='    - '"$value"$'\n'
                    yaml_values+=("$value")
                else
                    break
                fi
            done
        fi

        # Save value.
        # Cara dibawah ini simple, tapi lambat.
        # ```
        #     rcm-yaml find parameter "${parameter}" then get flag
        #     yaml_flag="$_return_value"
        # ```
        # Gunakan saja variable $yaml_flag yang sudah kita
        # definisikan diatas.
        # Cara dibawah ini simple, tapi lambat.
        # ```
        #     rcm-yaml find parameter "${parameter}" then get values
        #     yaml_values=("${_return_array[@]}")
        # ```
        # Gunakan saja variable $yaml_values yang sudah kita
        # definisikan diatas.
        if [ -n "$yaml_flag" ];then
            if [ "${#yaml_values[@]}" -gt 0 ];then
                for value in "${yaml_values[@]}"; do
                    RCM_ARGUMENT_PASS+=("${parameter}=${value}")
                    [[ "$value" =~ ' ' ]] && value="'$value'"
                    RCM_ARGUMENT_PREVIEW+=("${parameter}=${value}")
                    RCM_ARGUMENT_PASS_QUOTED+=("${parameter}=${value}")
                done
            else
                RCM_ARGUMENT_PASS+=("${parameter}")
                RCM_ARGUMENT_PREVIEW+=("${parameter}")
                RCM_ARGUMENT_PASS_QUOTED+=("${parameter}")
            fi
        else
            RCM_ARGUMENT_PREVIEW+=("${parameter}-")
        fi

        # Backup to text file for flag.
        if [ -n "$yaml_flag" ];then
            mkdir -p $(dirname "$backup_storage")
            if [ "${#yaml_values[@]}" -gt 0 ];then
                for value in "${yaml_values[@]}"; do
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
                backup_value=$(grep -- "^${parameter}=.*$" "$backup_storage" | tail -1 | sed -E -e 's|'"^${parameter}=(.*)$"'|\1|' -e "s|^'(.*)'$|\1|")
                ;;
        esac
    fi
    if [ -f "$history_storage" ];then
        history_value=$(grep -- "^${parameter}=.*$" "$history_storage" | tail -9 | sed -E 's|'"^${parameter}=(.*)$"'|\1|')
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

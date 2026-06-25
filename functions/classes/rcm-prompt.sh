#!/bin/bash

require vendor/ijortengab/rcm/functions/classes/rcm-prompt-options.sh

rcm-prompt() {
    # Local variable as property.
    local contents="$RCM_CONTENTS"
    local mapping_operand
    local first_operand
    local value
    local command="$1"
    local label list_to_execute
    local indent
    local default_indent='  '
    local each
    local usage_string usage_array
    local command_chain

    build-command() {
        local each
        local rcm_options=
        local rcm_options_array=()
        local words_array=()
        [ -n "$interactive" ] && rcm_options_array+=(i)
        [ -n "$autoyes" ] && rcm_options_array+=(y)
        [ -n "$prompt" ] && rcm_options_array+=(p)
        [ -n "$timer" ] && rcm_options_array+=(t)
        [ -z "$fast" ] && rcm_options_array+=(s)
        if [ -n "$verbose" ];then
            for ((i = 0 ; i < "$verbose" ; i++)); do
                rcm_options_array+=(v)
            done
        fi
        for each in "${rcm_options_array[@]}";do
            rcm_options+="$each"
        done
        [ -n "$rcm_options" ] && rcm_options="-${rcm_options}"
        words_array+=(rcm $rcm_options)
        words_array+=("${RCM_EXTENSION_CHAIN[@]}")
        words_array+=("${RCM_ARGUMENT_PREVIEW[@]}")
        echo-wrap-multiline
    }

    trap-sigint() {
        local line
        local tempfile

        if [[ $RCM_MAIN_PID == $$ ]];then
            _.;
            _.;
            error Interrupt by User.
            _.;
            tempfile=/dev/shm/rcm.$RCM_MAIN_PID
            if [ -s "$tempfile" ];then
                RCM_ARGUMENT_PREVIEW+=(--)
                while IFS= read -r line; do
                    if [ -n "$line" ];then
                        RCM_ARGUMENT_PREVIEW+=("$line")
                    fi
                done < "$tempfile"
            fi
            build-command
        else
            tempfile=/dev/shm/rcm.$RCM_MAIN_PID
            if [ "${#RCM_ARGUMENT_PREVIEW[@]}" -gt 0 ];then
                for each in "${RCM_ARGUMENT_PREVIEW[@]}";do
                    echo "$each" >> "$tempfile"
                done
            fi
        fi
        exit 0
    }

    # Mem-parse chapter $label pada contents, yang digunakan untuk list
    # execute command.
    parse-to-include() {
        local label="$1"
        local contents="$2"
        local first_line_trimmed is_valid
        local command arguments
        local line find replace
        [ -z "$label" ] && { error "Argument <label> is required."; x; }
        [ -z "$contents" ] && { error "Argument <contents> is required."; x; }

        build-command
        _.;

        chapter "$label" include.
        ____

        until [[ -z "$contents" ]];do
            first_line_trimmed=`sed -n 1p <<< "$contents" | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//'`
            contents=`sed -n '2,$p' <<< "$contents"`
            is_valid=$(echo "$first_line_trimmed" | sed -n -E 's/\s*([^\)]+\))/\1/p')
            if [ -z "$is_valid" ];then
                error The command format is not valid: '`'"$first_line_trimmed"'`'.; x;
            fi
            command=$(echo "$first_line_trimmed" | sed -n -E 's/^([^\(]+)\(([^\)]*)\)$/\1/p')
            arguments=$(echo "$first_line_trimmed" | sed -n -E 's/^([^\(]+)\(([^\)]*)\)$/\2/p')

            if ! command -v "$command" > /dev/null;then
                error The command is not found.; x;
            fi
            if [ -n "$RCM_ARGUMENT_PLACEHOLDERS" ];then
                while read line; do
                    find=$(echo ${line} | sed -E 's|^([^:]+):.*|\1|' | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
                    replace=$(echo ${line} | sed -E 's|^[^:]+:(.*)|\1|' | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
                    # description="${description/"$find"/"$replace"}"
                    if [ -n "$arguments" ];then
                        arguments="${arguments/"$find"/"$replace"}"
                    fi
                done <<< "$RCM_ARGUMENT_PLACEHOLDERS"
            fi
            [ -n "$arguments" ] && arguments=' '"$arguments"
            # chapter "$label" command.

            INDENT+="$RCM_INDENT"; export INDENT="$INDENT"
            source `${command}${arguments}` \
                ; [ ! $? -eq 0 ] && x
            INDENT="${INDENT::-${#RCM_INDENT}}"

        done
    }

    # Mem-parse chapter $label pada contents, yang digunakan untuk list
    # execute command.
    parse-to-execute() {
        local label="$1"
        local contents="$2"
        local first_line_trimmed is_valid
        local command arguments
        local line find replace
        [ -z "$label" ] && { error "Argument <label> is required."; x; }
        [ -z "$contents" ] && { error "Argument <contents> is required."; x; }

        build-command
        _.;

        chapter "$label" execute.
        ____

        until [[ -z "$contents" ]];do
            first_line_trimmed=`sed -n 1p <<< "$contents" | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//'`
            contents=`sed -n '2,$p' <<< "$contents"`
            is_valid=$(echo "$first_line_trimmed" | sed -n -E 's/\s*([^\)]+\))/\1/p')
            if [ -z "$is_valid" ];then
                error The command format is not valid: '`'"$first_line_trimmed"'`'.; x;
            fi
            command=$(echo "$first_line_trimmed" | sed -n -E 's/^([^\(]+)\(([^\)]*)\)$/\1/p')
            arguments=$(echo "$first_line_trimmed" | sed -n -E 's/^([^\(]+)\(([^\)]*)\)$/\2/p')

            if ! command -v "$command" > /dev/null;then
                error The command is not found.; x;
            fi
            [ -n "$arguments" ] && arguments=' '"$arguments"
            case "$label" in
                Additional\ Options)
                    parse-to-prompt-yaml
                    ;;
            esac
        done
    }

    parse-to-prompt-yaml() {
        local found
        local failed
        local each line
        local arguments_array=()
        local is_flag argument value
        # global command
        # global arguments

        if [ -n "$arguments" ];then
            # Explode by space.
            read -ra arguments_array -d '' <<< "$arguments"
            failed=
            while IFS= read -r line; do
                if [ -n "$line" ];then
                    quoted_string=$(echo "$line" | sed 's/[^a-z-]/\\&/g')
                    found=
                    while IFS= read -r each; do
                        if grep -q -E "^${quoted_string}:" <<< "$each";then
                            found=1
                            replace=$(grep -E "^${quoted_string}:" <<< "$each" | sed -E 's|^[^:]+:(.*)|\1|' | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
                            find=$(grep -E "^${quoted_string}:" <<< "$each" | sed -E 's|^([^:]+):.*|\1|' | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
                        fi
                    done <<< "$RCM_ARGUMENT_PLACEHOLDERS"
                    if [ -n "$found" ];then
                        arguments="${arguments/"$find"/"$replace"}"
                        ArraySearch "$find" arguments_array[@]
                        i=$_return
                        arguments_array[$i]="$replace"
                    else
                        failed=1
                    fi
                fi
            done <<< `grep -o -E '\[--[a-z-]+\]' <<< "$arguments"`
            # Jika placeholder gagal di translate, Maka anggap tidak jadi di eksekusi.
            if [ -n "$failed" ];then
                return 0
            fi
        fi

        if [ "${#RCM_PREPOPULATE_ARGUMENT_NON_OPTIONS[@]}" -gt 0 ];then
            # Build ulang dan kasih quote untuk value dengan spasi.
            set -- "${RCM_PREPOPULATE_ARGUMENT_NON_OPTIONS[@]}"
            RCM_PREPOPULATE_ARGUMENT_NON_OPTIONS=()
            while [ $# -gt 0 ]; do
                arguments_array+=("$1")
                each="$1"
                argument=
                value=
                # Credit: https://devhints.io/bash
                argument="${each%%=*}"
                value="${each#$argument=}"
                [[ "$argument" == "$value" ]] && is_flag=1 ||  is_flag=
                if [ -n "$is_flag" ];then
                    arguments+=" ${each}"
                else
                    [[ "$value" =~ ' ' ]] && value="'$value'"
                    arguments+=" ${argument}=${value}"
                fi
                shift
            done
        fi

        code $command $arguments
        ____

        if [ -z "$tempfile" ];then
            tempfile=$(mktemp -p /dev/shm -t rcm.XXXXXX)
        fi
        INDENT+="$RCM_INDENT" $command "${arguments_array[@]}" > "$tempfile" \
            ; [ ! $? -eq 0 ] && { rm "$tempfile"; x; }
        RCM_PROMPT_YAML+=$(cat < "$tempfile")$'\n'

        array="$RCM_PROMPT_YAML"
        array _preview;

        RCM_ARGUMENT_PREVIEW+=(--)
        if [ "${#_return_array[@]}" -gt 0 ];then
            for each in "${_return_array[@]}";do
                RCM_ARGUMENT_PREVIEW+=("$each")
            done
        fi
        array --unset _preview

        array _prepopulate_argument_non_options;
        if [ "${#_return_array[@]}" -gt 0 ];then
            for each in "${_return_array[@]}";do
                RCM_PREPOPULATE_ARGUMENT_NON_OPTIONS+=("$each")
            done
        fi
        array --unset _prepopulate_argument_non_options
        RCM_PROMPT_YAML="$array"
    }

    trap trap-sigint SIGINT

    # Populate options.
    RCM_OPTIONS=`echo "$contents" | sed -n '/^Options[:\.]$/,$p' | sed -n '1,/^\s*$/p' | sed -n '2,/^\s*$/p'`
    if [ -n "$RCM_OPTIONS" ];then
        RCM_OTHER_OPTIONS=`echo "$contents" | sed -n '/^Other [Oo]ptions.*[:\.]$/,$p' | sed -n '1,/^\s*$/p' | sed -n '2,/^\s*$/p'`
        rcm-prompt-options
    fi

    label='Additional Options'
    list_to_execute=`echo "$contents" | sed -n '/^'"$label"'[:\.]$/,$p' | sed -n '1,/^\s*$/p' | sed -n '2,/^\s*$/p'`
    if [ -n "$list_to_execute" ];then
        RCM_ARGUMENT_PASS_CONFIG=1
        parse-to-execute "$label" "$list_to_execute"
    fi

    usage_string=`echo "$contents" | grep -i -o -E '^ *Usage *?: *(.+) *$' | sed -E 's/^ *Usage *?: *rcm *(.+) *$/\1/i'`
    command_chain=()
    usage_array=()
    if [ -n "$usage_string" ];then
        read -ra usage_array -d '' <<< "$usage_string"
        usage_array_valid=()
        for each in "${usage_array[@]}";do
            if grep -q -E -- '[^-_\[\=0-9\.<]' <<< ${each:0:1};then
                usage_array_valid+=("$each")
            else
                break
            fi
        done
        if [ ${#usage_array_valid[@]} -gt 0 ];then
            command_chain=("${usage_array_valid[@]}")
        fi
    fi
    if [ ${#command_chain[@]} -eq 0 ];then
        command_chain=("${RCM_EXTENSION_CHAIN[@]}")
    fi

    if [ -n "$RCM_YAML" ];then
        indent=''
        for each in "${command_chain[@]}"; do
            RCM_PROMPT_YAML+="${indent}${each}:"$'\n'
            indent+="$default_indent"
        done
        while IFS= read -r line; do
            if [ -n "$line" ];then
                RCM_PROMPT_YAML+="${indent}${line}"$'\n'
            fi
        done <<< "$RCM_YAML"
    fi

    # Append informasi array RCM_ARGUMENT_PREVIEW pada global variable
    # RCM_PROMPT_YAML agar bisa di gabung dengan parent.
    RCM_PROMPT_YAML+=_preview:$'\n'
    if [ "${#RCM_ARGUMENT_PREVIEW[@]}" -gt 0 ];then
        for each in "${RCM_ARGUMENT_PREVIEW[@]}";do
            RCM_PROMPT_YAML+="${default_indent}- ${each}"$'\n'
        done
    fi

    # Append juga informasi array RCM_PREPOPULATE_ARGUMENT_NON_OPTIONS sebagai
    # residu, agar bisa dipakai lagi.
    RCM_PROMPT_YAML+=_prepopulate_argument_non_options:$'\n'
    if [ "${#RCM_PREPOPULATE_ARGUMENT_NON_OPTIONS[@]}" -gt 0 ];then
        for each in "${RCM_PREPOPULATE_ARGUMENT_NON_OPTIONS[@]}";do
            RCM_PROMPT_YAML+="${default_indent}- ${each}"$'\n'
        done
    fi
}

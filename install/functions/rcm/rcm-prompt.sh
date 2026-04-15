#!/bin/bash

source /usr/local/rcm/$RCM_VERSION/functions/rcm/rcm-prompt-options.sh

rcm-prompt() {
    # Required Global variable.
    [ -z "$RCM_CONTENTS" ] && { error "Variable RCM_CONTENTS is required."; x; }

    # Local variable as property.
    local contents="$RCM_CONTENTS"
    local mapping_operand
    local first_operand
    local value
    local command="$1"
    local label list_to_execute

    Rcm_prompt_build_command() {
        local _RCM_PROMPT_CHAIN
        echo-wrap 'Use command below to return to the last dialog.' 0
        local shortoptions
        [ -n "$interactive" ] && shortoptions+='i'
        [ -n "$autoyes" ] && shortoptions+='y'
        [ -n "$timer" ] && shortoptions+='t'
        [ -z "$fast" ] && shortoptions+='s'
        if [ -n "$verbose" ];then
            for ((i = 0 ; i < "$verbose" ; i++)); do
                shortoptions+='v'
            done
        fi
        [ -n "$shortoptions" ] && shortoptions=" -${shortoptions}"
        if [ -z "$RCM_PROMPT_CHAIN" ];then
            _RCM_PROMPT_CHAIN="rcm${shortoptions} ${extension}"
        else
            _RCM_PROMPT_CHAIN="$RCM_PROMPT_CHAIN"
        fi
        for each in "${RCM_ARGUMENT_PREVIEW[@]}"; do _RCM_PROMPT_CHAIN+=" ${each}"; done
        words_array=($_RCM_PROMPT_CHAIN)
        echo-wrap-multiline
    }
    Rcm_prompt_sigint() {
        _.;
        _.;
        error Interrupt by User.
        _.;
        Rcm_prompt_build_command
        exit 0
    }

    # Mem-parse chapter 'Mapping Operand:" pada contents.
    parse-mapping-operand() {
        local contents=$1
        local count
        [ -z "$contents" ] && { error "Argument <contents> is required."; x; }
        chapter Mapping operand as value of options.
        unset count
        declare -i count
        count=1
        while true; do
            below=`sed -n ${count}p <<< "$mapping_operand" | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//'`
            if [ -z "$below" ];then
                break
            fi
            for _value in "${RCM_PREPOPULATE_ARGUMENT_OPERANDS[@]}";do
                ArrayShift RCM_PREPOPULATE_ARGUMENT_OPERANDS[@]
                break
            done
            RCM_PREPOPULATE_ARGUMENT_OPERANDS=("${_return[@]}")
            if [ -n "$_value" ];then
                RCM_PREPOPULATE_ARGUMENT_OPTIONS+=("${below}=${_value}")
                code "${below}=${_value}"
            fi
            unset _return
            unset _value
            count+=1
        done
        ____
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

        Rcm_prompt_build_command
        _.;
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
            chapter "$label" command.
            code ${command}${arguments}
            ____

            if [ -z "$tempfile" ];then
                tempfile=$(mktemp -p /dev/shm -t rcm.XXXXXX)
            fi
            RCM_PROMPT_CHAIN= INDENT+="$RCM_INDENT" ${command}${arguments} \
                > "$tempfile" \
                ; [ ! $? -eq 0 ] && { rm "$tempfile"; x; }

            while IFS= read -r to_export; do
                key=$(cut -d= -f1 <<< "$to_export")
                value=$(cut -d= -f2- <<< "$to_export")
                [ -z "$value" ] && value=-
                code export "$key"="$value"
                export "$key"="$value"
                [ -n "$RCM_ENVIRONMENT_VARIABLES" ] && RCM_ENVIRONMENT_VARIABLES+=" "
                RCM_ENVIRONMENT_VARIABLES+="${key}=${value}"
            done < "$tempfile"
            if [ -s "$tempfile" ];then
                ____
            fi
        done
    }

    mapping_operand=`echo "$contents" | sed -n '/^Mapping Operand[:\.]$/,$p' | sed -n '1,/^\s*$/p' | sed -n '2,/^\s*$/p'`
    if [ -n "$mapping_operand" ];then
        parse-mapping-operand "$mapping_operand"
    fi

    label='Pre Prompt'
    list_to_execute=`echo "$contents" | sed -n '/^'"$label"'[:\.]$/,$p' | sed -n '1,/^\s*$/p' | sed -n '2,/^\s*$/p'`
    if [ -n "$list_to_execute" ];then
        parse-to-execute "$label" "$list_to_execute"
    fi

    trap Rcm_prompt_sigint SIGINT

    # Populate options.
    RCM_OPTIONS=`echo "$contents" | sed -n '/^Options[:\.]$/,$p' | sed -n '1,/^\s*$/p' | sed -n '2,/^\s*$/p'`
    if [ -n "$RCM_OPTIONS" ];then
        RCM_OTHER_OPTIONS=`echo "$contents" | sed -n '/^Other [Oo]ptions.*[:\.]$/,$p' | sed -n '1,/^\s*$/p' | sed -n '2,/^\s*$/p'`
        rcm-prompt-options
    fi

    label='Post Prompt'
    list_to_execute=`echo "$contents" | sed -n '/^'"$label"'[:\.]$/,$p' | sed -n '1,/^\s*$/p' | sed -n '2,/^\s*$/p'`
    if [ -n "$list_to_execute" ];then
        parse-to-execute "$label" "$list_to_execute"
    fi
}

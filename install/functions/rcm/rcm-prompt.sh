#!/bin/bash

source "${RCM_LIB}"/functions/rcm/rcm-prompt-options.sh

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
    local indent
    local default_indent='  '
    local each

    build-command() {
        local each
        local rcm_options=
        local rcm_options_array=()
        local words_array=()
        [ -n "$interactive" ] && rcm_options_array+=(i)
        [ -n "$autoyes" ] && rcm_options_array+=(y)
        [ -n "$timer" ] && rcm_options_array+=(t)
        [ -z "$fast" ] && rcm_options_array+=(s)
        if [ -n "$verbose" ];then
            for ((i = 0 ; i < "$verbose" ; i++)); do
                rcm_options_array+=(v)
            done
        fi
        for each in "${rcm_options_array[@]}";do
            rcm_options="$each"
        done
        [ -n "$rcm_options" ] && rcm_options="-${rcm_options}"
        words_array+=(rcm $rcm_options)
        words_array+=("${RCM_EXTENSION_CHAIN[@]}")
        words_array+=("${RCM_ARGUMENT_PREVIEW[@]}")
        echo-wrap-multiline
    }

    trap-sigint() {
        _.;
        _.;
        error Interrupt by User.
        _.;
        build-command
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

    trap trap-sigint SIGINT

    # Populate options.
    RCM_OPTIONS=`echo "$contents" | sed -n '/^Options[:\.]$/,$p' | sed -n '1,/^\s*$/p' | sed -n '2,/^\s*$/p'`
    if [ -n "$RCM_OPTIONS" ];then
        RCM_OTHER_OPTIONS=`echo "$contents" | sed -n '/^Other [Oo]ptions.*[:\.]$/,$p' | sed -n '1,/^\s*$/p' | sed -n '2,/^\s*$/p'`
        rcm-prompt-options
    fi

    label='Additional Options'
    list_to_include=`echo "$contents" | sed -n '/^'"$label"'[:\.]$/,$p' | sed -n '1,/^\s*$/p' | sed -n '2,/^\s*$/p'`
    if [ -n "$list_to_include" ];then
        parse-to-include "$label" "$list_to_include"
    fi

    indent=''
    for each in "${RCM_EXTENSION_CHAIN[@]}"; do
        RCM_PROMPT_YAML+="${indent}${each}:"$'\n'
        indent+="$default_indent"
    done
    while IFS= read -r line; do
        if [ -n "$line" ];then
            RCM_PROMPT_YAML+="${indent}${line}"$'\n'
        fi
    done <<< "$RCM_YAML"
}

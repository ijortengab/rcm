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

    build-command() {
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

    trap-sigint() {
        _.;
        _.;
        error Interrupt by User.
        _.;
        build-command
        exit 0
    }

    trap trap-sigint SIGINT

    # Populate options.
    RCM_OPTIONS=`echo "$contents" | sed -n '/^Options[:\.]$/,$p' | sed -n '1,/^\s*$/p' | sed -n '2,/^\s*$/p'`
    if [ -n "$RCM_OPTIONS" ];then
        RCM_OTHER_OPTIONS=`echo "$contents" | sed -n '/^Other [Oo]ptions.*[:\.]$/,$p' | sed -n '1,/^\s*$/p' | sed -n '2,/^\s*$/p'`
        rcm-prompt-options
    fi

}

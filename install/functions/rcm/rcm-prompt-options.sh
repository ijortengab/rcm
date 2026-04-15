#!/bin/bash

source /usr/local/rcm/$RCM_VERSION/functions/rcm/rcm-prompt-options-option.sh

rcm-prompt-options() {
    # Required Global variable.
    [ -z "$RCM_OPTIONS" ] && { error "Variable RCM_OPTIONS is required."; x; }

    # Local variable as property.
    local options="$RCM_OPTIONS"
    local other_options="$RCM_OTHER_OPTIONS"
    local load_other_options=
    local bypass_dialog=
    local count below

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

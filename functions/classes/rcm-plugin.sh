#!/bin/bash

use ijortengab/rcm rcm-yaml

rcm-plugin () {

    _set() {
        local plugin_name
        local interface

        INDENT+="$RCM_INDENT"; export INDENT="$INDENT"
        title rcm-plugin set "$@"
        ____

        INDENT="${INDENT::-${#RCM_INDENT}}"

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --interface=*) interface="${1#*=}"; shift ;;
                --interface) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then interface="$2"; shift; fi; shift ;;
                --plugin-name=*) plugin_name="${1#*=}"; shift ;;
                --plugin-name) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then plugin_name="$2"; shift; fi; shift ;;
                *) shift ;;
            esac
        done
        [ -n "$interface" ] || { error "Options --interface is required."; __ "Command: rcm-plugin set --interface=<interface> --plugin-name=<plugin_name>"; x; }
        [ -n "$plugin_name" ] || { error "Options --plugin-name is required."; __ "Command: rcm-plugin set --interface=<interface> --plugin-name=<plugin_name>"; x; }

        RCM_PLUGIN_YAML+='- interface: '"$interface"$'\n'
        RCM_PLUGIN_YAML+='  plugin_name: '"$plugin_name"$'\n'
    }

    _runMethod() {
        local plugin_name
        local interface
        local method

        INDENT+="$RCM_INDENT"; export INDENT="$INDENT"
        title rcm-plugin run-method "$@"
        ____

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --interface=*) interface="${1#*=}"; shift ;;
                --interface) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then interface="$2"; shift; fi; shift ;;
                --method=*) method="${1#*=}"; shift ;;
                --method) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then method="$2"; shift; fi; shift ;;
                *) shift ;;
            esac
        done

        [ -n "$interface" ] || { error "Options --interface is required."; __ "Command: rcm-plugin set --interface=<interface> --method=<method>"; x; }
        [ -n "$method" ] || { error "Options --method is required."; __ "Command: rcm-plugin set --interface=<interface> --method=<method>"; x; }

        # Get the plugin_name from YAML.
        RCM_YAML="$RCM_PLUGIN_YAML"
        rcm-yaml find interface "$interface" then get plugin_name
        plugin_name="$_return_value"; unset _return_value;
        [ -n "$plugin_name" ] || { error "Variable plugin_name failed to populate."; x; }
        path="${RCM_LIB}/interfaces/${interface}/implements/${plugin_name}/methods/${method}/socket.sh"
        if [ ! -f "$path" ];then
            error Socket file is not found.; code path=$; x
        fi
        . "$path" --interface="$interface" --plugin-name="$plugin_name" --method="$method"
        INDENT="${INDENT::-${#RCM_INDENT}}"
    }

    _extends() {
        local plugin_parent_name
        local plugin_name
        local interface
        local method

        INDENT+="$RCM_INDENT"; export INDENT="$INDENT"
        title rcm-plugin extends "$@"
        ____

        INDENT="${INDENT::-${#RCM_INDENT}}"

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --interface=*) interface="${1#*=}"; shift ;;
                --interface) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then interface="$2"; shift; fi; shift ;;
                --plugin-parent-name=*) plugin_parent_name="${1#*=}"; shift ;;
                --plugin-parent-name) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then plugin_parent_name="$2"; shift; fi; shift ;;
                --plugin-name=*) plugin_name="${1#*=}"; shift ;;
                --plugin-name) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then plugin_name="$2"; shift; fi; shift ;;
                --method=*) method="${1#*=}"; shift ;;
                --method) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then method="$2"; shift; fi; shift ;;
                *) shift ;;
            esac
        done

        [ -n "$interface" ] || { error "Options --interface is required."; __ "Command: rcm-plugin extends --interface=<interface> --method=<method>"; x; }
        [ -n "$method" ] || { error "Options --method is required."; __ "Command: rcm-plugin extends --interface=<interface> --method=<method>"; x; }
        [ -n "$plugin_name" ] || { error "Options --plugin-name is required."; __ "Command: rcm-plugin extends --interface=<interface> --plugin-name=<plugin_name>"; x; }
        [ -n "$plugin_parent_name" ] || { error "Options --plugin-parent-name is required."; __ "Command: rcm-plugin extends --interface=<interface> --plugin-name=<plugin_name>"; x; }

        RCM_PLUGIN_YAML+='- fully_qualified_plugin_name: '"${interface}/${plugin_name}"$'\n'
        RCM_PLUGIN_YAML+='  interface: '"$interface"$'\n'
        RCM_PLUGIN_YAML+='  plugin_name: '"${plugin_name}"$'\n'
        RCM_PLUGIN_YAML+='  plugin_parent_name: '"${plugin_parent_name}"$'\n'
    }

    _runParentMethod() {
        local plugin_name
        local interface
        local method

        INDENT+="$RCM_INDENT"; export INDENT="$INDENT"
        title rcm-plugin run-parent-method "$@"
        ____

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --interface=*) interface="${1#*=}"; shift ;;
                --interface) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then interface="$2"; shift; fi; shift ;;
                --plugin-name=*) plugin_name="${1#*=}"; shift ;;
                --plugin-name) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then plugin_name="$2"; shift; fi; shift ;;
                --method=*) method="${1#*=}"; shift ;;
                --method) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then method="$2"; shift; fi; shift ;;
                *) shift ;;
            esac
        done

        [ -n "$interface" ] || { error "Options --interface is required."; __ "Command: rcm-plugin extends --interface=<interface> --method=<method>"; x; }
        [ -n "$method" ] || { error "Options --method is required."; __ "Command: rcm-plugin extends --interface=<interface> --method=<method>"; x; }
        [ -n "$plugin_name" ] || { error "Options --plugin-name is required."; __ "Command: rcm-plugin extends --interface=<interface> --plugin-name=<plugin_name>"; x; }

        # Get the plugin_name from YAML.
        RCM_YAML="$RCM_PLUGIN_YAML"
        rcm-yaml find fully_qualified_plugin_name "${interface}/${plugin_name}" then get plugin_parent_name
        plugin_parent_name="$_return_value"; unset _return_value;
        [ -n "$plugin_parent_name" ] || { error "Variable plugin_parent_name failed to populate."; x; }
        path="${RCM_LIB}/interfaces/${interface}/implements/${plugin_parent_name}/methods/${method}/socket.sh"
        if [ ! -f "$path" ];then
            error Socket file is not found.; code path=$; x
        fi
        . "$path" --interface="$interface" --plugin-name="$plugin_parent_name" --method="$method"
        INDENT="${INDENT::-${#RCM_INDENT}}"
    }

    _runStaticMethod() {
        local plugin_name
        local interface
        local method

        INDENT+="$RCM_INDENT"; export INDENT="$INDENT"
        title rcm-plugin run-static-method "$@"
        ____

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --interface=*) interface="${1#*=}"; shift ;;
                --interface) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then interface="$2"; shift; fi; shift ;;
                --plugin-name=*) plugin_name="${1#*=}"; shift ;;
                --plugin-name) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then plugin_name="$2"; shift; fi; shift ;;
                --method=*) method="${1#*=}"; shift ;;
                --method) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then method="$2"; shift; fi; shift ;;
                *) shift ;;
            esac
        done

        [ -n "$interface" ] || { error "Options --interface is required."; __ "Command: rcm-plugin extends --interface=<interface> --method=<method>"; x; }
        [ -n "$method" ] || { error "Options --method is required."; __ "Command: rcm-plugin extends --interface=<interface> --method=<method>"; x; }
        [ -n "$plugin_name" ] || { error "Options --plugin-name is required."; __ "Command: rcm-plugin extends --interface=<interface> --plugin-name=<plugin_name>"; x; }

        path="${RCM_LIB}/interfaces/${interface}/implements/${plugin_name}/methods/${method}/socket.sh"
        if [ ! -f "$path" ];then
            error Socket file is not found.; code path=$; x
        fi
        . "$path" --interface="$interface" --plugin-name="$plugin_name" --method="$method"
        INDENT="${INDENT::-${#RCM_INDENT}}"
    }

    _useTrait() {
        local plugin_name
        local interface
        local method

        INDENT+="$RCM_INDENT"; export INDENT="$INDENT"
        title plugin use-trait "$@"
        ____

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --interface=*) interface="${1#*=}"; shift ;;
                --interface) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then interface="$2"; shift; fi; shift ;;
                --plugin-name=*) plugin_name="${1#*=}"; shift ;;
                --plugin-name) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then plugin_name="$2"; shift; fi; shift ;;
                --method=*) method="${1#*=}"; shift ;;
                --method) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then method="$2"; shift; fi; shift ;;
                *) shift ;;
            esac
        done

        [ -n "$interface" ] || { error "Options --interface is required."; __ "Command: rcm-plugin extends --interface=<interface> --method=<method>"; x; }
        [ -n "$method" ] || { error "Options --method is required."; __ "Command: rcm-plugin extends --interface=<interface> --method=<method>"; x; }
        [ -n "$plugin_name" ] || { error "Options --plugin-name is required."; __ "Command: rcm-plugin extends --interface=<interface> --plugin-name=<plugin_name>"; x; }

        # Suffix with trait.
        method+=-trait
        path="${RCM_LIB}/interfaces/${interface}/implements/${plugin_name}/methods/${method}/socket.sh"
        if [ ! -f "$path" ];then
            error Socket file is not found.; code path=$; x
        fi
        . "$path" --interface="$interface" --plugin-name="$plugin_name" --method="$method"
        INDENT="${INDENT::-${#RCM_INDENT}}"

    }

    local mode="$1"; shift

    case "$mode" in
        set) _set "$@" ;;
        run-method) _runMethod "$@" ;;
        extends) _extends "$@" ;;
        run-parent-method) _runParentMethod "$@" ;;
        run-static-method) _runStaticMethod "$@" ;;
        use-trait) _useTrait "$@" ;;
    esac
}

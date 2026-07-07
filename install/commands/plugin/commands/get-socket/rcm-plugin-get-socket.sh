#!/bin/bash

RCM_EXTENSION_VERSION=0.19.0-alpha.12

# Usage Functions.
usage() {
    cat << EOF
Usage: rcm plugin get-socket

EOF
}

# Prevent scripts from being executed directly.
[ -f "${RCM_LIB}/require.sh" ] && source "${RCM_LIB}/require.sh" || { usage >&2; exit 1; }

_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --hide-title) hide_title=1; shift ;;
        --) shift
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    *) _new_arguments+=("$1"); shift ;;
                esac
            done
            ;;
        --[^-]*) shift ;;
        *) _new_arguments+=("$1"); shift ;;
    esac
done
set -- "${_new_arguments[@]}"
unset _new_arguments

# Require.
require vendor/ijortengab/rcm/functions/base/print-select-dialog.sh
require vendor/ijortengab/bash/functions/array-search.sh

# ------------------------------------------------------------------------------

# Requirement, validate, and populate value.
prefix="$RCM_LIB"/interfaces
list=()
is_required=1
parameter=interface
parameter_plural=interfaces
is_title_printed=

while IFS= read -r each;do
    find="${prefix}/"; replace=
    each="${each/#$find/$replace}"
    find=/implements; replace=
    each="${each/%$find/$replace}"
    list+=("$each")
done <<< `find "$prefix" -type d -iname implements`

command="rcm plugin get-socket"

if [ -n "$1" ];then
    value="$1"; shift
    if ! ArraySearch "$value" list[@];then
        code "${command} ${value}"
        error The interface of plugin is unknown: '`'"$value"'`'.; x
    fi
    unset _return
    command+=" ${value}"
    interface=$value
    extension_chain+=("$interface")
    value=
else
    title "$command"
    ____

    chapter Prepare argument for command '`'$command'`'.
    is_title_printed=1
    _; _.
    _ Select available interface of plugin.; _.
    print-select-dialog list[@] "$parameter" "$parameter_plural"
    command+=" ${value}"
    _; _.
    _; _, Execute' '; magenta $command; _.
    interface=$value
    extension_chain+=("$interface")
    value=
fi

prefix+=/"$interface"
list=(`ls "$prefix/implements"`)
is_required=1
parameter=plugin
parameter_plural=plugins

if [ -n "$1" ];then
    value="$1"; shift
    if ! ArraySearch "$value" list[@];then
        code "${command} ${value}"
        error The plugin name is not implement $interface interface: '`'"$value"'`'.; x
    fi
    unset _return
    command+=" ${value}"
    plugin_name=$value
    extension_chain+=("$plugin_name")
    value=
else
    _; _.
    _ Select available plugin which implemented that interface.; _.
    print-select-dialog list[@] "$parameter" "$parameter_plural"
    command+=" ${value}"
    _; _.
    _; _, Execute' '; magenta $command; _.
    plugin_name=$value
    extension_chain+=("$plugin_name")
    value=
fi

prefix+=/implements/"$plugin_name"
list=(`ls "$prefix/methods"`)
is_required=1
parameter=method
parameter_plural=methods

if [ -n "$1" ];then
    value="$1"; shift
    if ! ArraySearch "$value" list[@];then
        code "${command} ${value}"
        error The plugin '`'"$plugin_name"'`' that implements '`'"$interface"'`' interface does not have method: '`'"$value"'`'.; x
    fi
    unset _return
    command+=" ${value}"
    method_name=$value
    extension_chain+=("$method_name")
    value=
else
    _; _.
    _ Select method to be executed.; _.
    print-select-dialog list[@] "$parameter" "$parameter_plural"
    command+=" ${value}"
    _; _.
    _; _, Execute' '; magenta $command; _.
    method_name=$value
    extension_chain+=("$method_name")
    value=
fi

prefix+=/methods/$method_name

if [ -z "$is_title_printed" ];then
    if [ -z "$hide_title" ];then
        title "$command"
        ____
    fi
fi

if [ -n "$help" ];then
    if [ -f "$prefix/help.txt" ];then
        cat "$prefix/help.txt"
    fi
else
    echo "$prefix/socket.sh"
fi

exit 0

# parse-options.sh \
# --with-end-options-double-dash \
# --with-end-options-specific-operand \
# --compact \
# --clean \
# --no-hash-bang \
# --no-original-arguments \
# --no-error-invalid-options \
# --no-error-require-arguments << EOF | clip
# FLAG=(
# --version
# --help
# --hide-title
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

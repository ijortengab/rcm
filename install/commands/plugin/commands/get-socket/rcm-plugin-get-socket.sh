#!/bin/bash

RCM_EXTENSION_VERSION=0.19.0-alpha.6

# Usage Functions.
usage() {
    cat << EOF
Usage: rcm plugin get-socket

EOF
}

# Prevent scripts from being executed directly.
[ -f "${RCM_LIB}/require.sh" ] && source "${RCM_LIB}/require.sh" || { usage >&2; exit 1; }

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
is_intro_printed=

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
        error The interface of plugin is unknown: '`'"$value"'`'.; x
    fi
    unset _return
    command+=" ${value}"
    extension=$value
    extension_chain+=("$extension")
    value=
else
    if [ -z "$is_intro_printed" ];then

        title "$command"
        ____

        chapter Prepare argument for command '`'$command'`'.
        is_intro_printed=1
    fi
    _; _.
    _ Select available interface of plugin.; _.
    print-select-dialog list[@] "$parameter" "$parameter_plural"
    command+=" ${value}"
    _; _.
    _; _, Execute' '; magenta $command; _.
    extension=$value
    extension_chain+=("$extension")
    value=
fi

prefix+=/"$extension"
list=(`ls "$prefix/implements"`)
is_required=1
parameter=plugin
parameter_plural=plugins

if [ -n "$1" ];then
    value="$1"; shift
    if ! ArraySearch "$value" list[@];then
        error The plugin name is not implement $extension interface: '`'"$value"'`'.; x
    fi
    unset _return
    command+=" ${value}"
    extension=$value
    extension_chain+=("$extension")
    value=
else
    _; _.
    _ Select available plugin which implemented that interface.; _.
    print-select-dialog list[@] "$parameter" "$parameter_plural"
    command+=" ${value}"
    _; _.
    _; _, Execute' '; magenta $command; _.
    extension=$value
    extension_chain+=("$extension")
    value=
fi

prefix+=/implements/"$extension"
list=(`ls "$prefix/methods"`)
is_required=1
parameter=method
parameter_plural=methods

if [ -n "$1" ];then
    value="$1"; shift
    if ! ArraySearch "$value" list[@];then
        error The method name is unknown: '`'"$value"'`'.; x
    fi
    unset _return
    command+=" ${value}"
    extension=$value
    extension_chain+=("$extension")
    value=
else
    _; _.
    _ Select method to be executed.; _.
    print-select-dialog list[@] "$parameter" "$parameter_plural"
    command+=" ${value}"
    _; _.
    _; _, Execute' '; magenta $command; _.
    extension=$value
    extension_chain+=("$extension")
    value=
fi

prefix+=/methods/$extension

if [ -z "$is_intro_printed" ];then
    title "$command"
    ____
fi

echo "$prefix/socket.sh"

exit 0

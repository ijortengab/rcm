#!/bin/bash

RCM_EXTENSION_VERSION=0.19.0-alpha.5

# Usage Functions.
usage() {
    cat << EOF
Usage: rcm plugin list

EOF
}

# Prevent scripts from being executed directly.
[ -f "${RCM_LIB}/require.sh" ] && source "${RCM_LIB}/require.sh" || { usage >&2; exit 1; }

# Require.
require vendor/ijortengab/rcm/functions/base/print-select-dialog.sh
require vendor/ijortengab/rcm/functions/base/array-search.sh

# ------------------------------------------------------------------------------

# Requirement, validate, and populate value.
prefix="$RCM_LIB"/interfaces
list=()
is_required=1
parameter=interface
parameter_plural=interfaces

while IFS= read -r each;do
    find="${prefix}/"; replace=
    each="${each/#$find/$replace}"
    find=/implements; replace=
    each="${each/%$find/$replace}"
    list+=("$each")
done <<< `find "$prefix" -type d -iname implements`

command="rcm plugin list"
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
prefix+=/$extension
if [ -f "$prefix/list.sh" ];then
    source "$prefix/list.sh"
else
    ls -1 "$prefix/implements"
fi

exit 0

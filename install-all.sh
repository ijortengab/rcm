#!/bin/bash

if [[ "$EUID" -ne 0 ]]; then
    echo This script needs to be run with superuser privileges
    exit 1
fi

# Functions.
resolve_relative_path() {
    if [ -d "$1" ];then
        cd "$1" || return 1
        pwd
    elif [ -e "$1" ];then
        if [ ! "${1%/*}" = "$1" ]; then
            cd "${1%/*}" || return 1
        fi
        echo "$(pwd)/${1##*/}"
    else
        return 1
    fi
}

__FILE__=$(resolve_relative_path "$0")
__DIR__=$(dirname "$__FILE__")
cd "$__DIR__"

RCM_PREFIX=${RCM_PREFIX:=/usr/local/rcm}
RCM_VERSION=`grep -o -P 'RCM_VERSION=\K(\S+)' rcm.sh`
RCM_LIB="${RCM_PREFIX}/lib/${RCM_VERSION}"

source install/require.sh

title install-all
____

code cd "$__DIR__"
____

chapter Mempersiapkan direktori RCM_LIB.
code RCM_LIB=$
code mkdir -p "${RCM_LIB}/commands"
mkdir -p "${RCM_LIB}/commands"
code mkdir -p "${RCM_LIB}/interfaces"
mkdir -p "${RCM_LIB}/interfaces"
code mkdir -p "${RCM_LIB}/vendor"
mkdir -p "${RCM_LIB}/vendor"
____

source="${__DIR__}/rcm.sh"
target="/usr/local/bin/rcm"
code source=$
code target=$
code ln -sf "$source" "$target"
ln -sf "$source" "$target"
____

source="${__DIR__}/install/require.sh"
target="${RCM_LIB}/require.sh"
code source=$
code target=$
code cd "$RCM_LIB"
cd "$RCM_LIB"
code ln -sf "$source" "$target"
ln -sf "$source"
____

source="${__DIR__}/install/rcm-exec.sh"
target="${RCM_LIB}/rcm-exec.sh"
code source=$
code target=$
code cd "$RCM_LIB"
cd "$RCM_LIB"
code ln -sf "$source" "$target"
ln -sf "$source"
____

NAMESPACE=ijortengab/rcm
code cd "$RCM_LIB"
cd "$RCM_LIB"
source="$__DIR__"
target="${PWD}/vendor/${NAMESPACE}"
code source=$
code target=$
target_parent=$(dirname "$target")
code mkdir -p "$target_parent"
mkdir -p "$target_parent"
cd "$target_parent"
code ln -sf "$source" "$target"
ln -sf "$source"
____

NAMESPACE=ijortengab/bash
code cd "$RCM_LIB"
cd "$RCM_LIB"
source="${__DIR__}/vendor/${NAMESPACE}"
target="${PWD}/vendor/${NAMESPACE}"
code source=$
code target=$
target_parent=$(dirname "$target")
code mkdir -p "$target_parent"
mkdir -p "$target_parent"
cd "$target_parent"
code ln -sf "$source" "$target"
ln -sf "$source"
____

require vendor/ijortengab/rcm/functions/classes/rcm-dir.sh
require vendor/ijortengab/rcm/functions/utility/link-symbolic.sh
require vendor/ijortengab/rcm/functions/utility/link-symbolic-dir.sh

chapter Memeriksa direktori commands.
target="${RCM_LIB}/commands"
code target="$target"
rcm-dir terminateIfNotExists "$target"
source="${PWD}/rcm/install/commands"
code source="$source"
rcm-dir isExists "$source"
if [ -n "$found" ];then
    __ Symlink all items inside commands directory.
    ____
    while IFS= read -r line; do
        link-symbolic-dir "${source}/${line}" "${target}/${line}" - absolute
    done <<< `ls -1 "$source"`
else
    ____
fi

chapter Memeriksa direktori interfaces.
target="${RCM_LIB}/interfaces"
code target="$target"
rcm-dir terminateIfNotExists "$target"
source="rcm/install/interfaces"
code source="$source"
rcm-dir isExists "$source"
if [ -n "$found" ];then
    __ Symlink all items inside interfaces directory.
    ____

    while IFS= read -r line; do
        link-symbolic "${PWD}/${line}" "${target}${line/$source/}" - absolute
    done <<< `find "$source" -type f`
else
    ____
fi

exit 0

#!/bin/bash

RCM_EXTENSION_VERSION=0.19.0-alpha.6

# Usage Functions.
usage() {
    cat << EOF
Usage: rcm require <owner>/<repo> [version]

Global Options:
   --version
        Print version of this script.
   --help
        Show this help.
EOF

}

[ -f "${RCM_LIB}/require.sh" ] && source "${RCM_LIB}/require.sh" || { usage >&2; exit 1; }

# ------------------------------------------------------------------------------

# Title.
title rcm require
____

# Dependency.
require rcm install

# Functions.
# Mapping operand to value of options.
chapter Mapping operand as value of options.
if [ -n "$1" ];then
    code --package=$1
    package=$1; shift
fi
if [ -n "$1" ];then
    code --package-version=$1
    package_version=$1; shift
fi
____

# Requirement, validate, and populate value.
chapter Variable dump.
if [ -z "$package" ];then
    error "Argument --package required."; x
fi
if [[ ! "$package" =~ / ]];then
    error "The format of --package is not correct."; x
fi
code 'package="'$package'"'
url="https://github.com/${package}"
code 'url="'$url'"'
____

INDENT+="    " \
rcm install $isfast \
    --root="$root" \
    --url="$url" \
    --extension-version="$package_version" \
    ; [ ! $? -eq 0 ] && x

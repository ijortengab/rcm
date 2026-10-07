#!/bin/bash

# How to use?
# rcm-dir isExists "$path"
# rcm-dir mustExists "$path"
# rcm-dir terminateIfNotExists "$path"
# rcm-dir createIfNotExists "$path"
rcm-dir() {
    [ "$1" == --help ] && {
        e Usage: rcm-dir '<method>' '<path>'; _.;
        e Method available: isExists, mustExists, terminateIfNotExists, createIfNotExists.; _.;
        e Global variable used: \$found, \$notfound.; _.;
        return;
    }
    local method="$1"
    local path="$2"
    [ -z "$method" ] && { error Argument '<method>' is required.; x; }
    [ -z "$path" ] && { error Argument '<path>' is required.; x; }
    shift 2
    local dirname="${path##*/}"

    case "$method" in
        isExists)
            found=
            notfound=
            if [ -d "$path" ];then
                __ Direktori '`'"$dirname"'`' ditemukan.
                found=1
            else
                __ Direktori '`'"$dirname"'`' tidak ditemukan.
                notfound=1
            fi
            ;;
        mustExists)
            if [ -d "$path" ];then
                __; green Direktori '`'"$dirname"'`' ditemukan.; _.
            else
                __; red Direktori '`'"$dirname"'`' tidak ditemukan.; x
            fi
            ;;
        terminateIfNotExists)
            if [ ! -d "$path" ];then
                __; red Direktori '`'"$dirname"'`' tidak ditemukan.; x
            fi
            ;;
        createIfNotExists)
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --label=*) label="${1#*=}"; shift ;;
                    --label) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then label="$2"; shift; fi; shift ;;
                    --owner=*) owner="${1#*=}"; shift ;;
                    --owner) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then owner="$2"; shift; fi; shift ;;
                    --[^-]*) shift ;;
                    *) shift ;;
                esac
            done
            [ -n "$label" ] && label="directory ${label}" || label=directory
            chapter Create "$label" if not exists.
            code path=$
            if [ -d "$path" ];then
                __ Direktori '`'"$dirname"'`' ditemukan.
            else
                __ Direktori '`'"$dirname"'`' tidak ditemukan.
                __ Membuat "$label".
                code mkdir -p '"'$path'"'
                mkdir -p "$path"
                if [ -n "$owner" ];then
                    code chown -R $owner:$owner '"'"$path"'"'
                    chown -R $owner:$owner "$path"
                fi
                if [ -d "$path" ];then
                    __; green Direktori '`'"$dirname"'`' ditemukan.; _.
                else
                    __; red Direktori '`'"$dirname"'`' tidak ditemukan.; x
                fi
            fi
            ____

            ;;
    esac
}

# Class ini menggantikan function isDirExists() dan dirMustExists()
# Legacy:
# `isDirExists "$dir"` digantikan dengan `rcm-dir "$dir" isExists`
# `[ -d "$dir" ] || dirMustExists "$dir"` digantikan dengan `rcm-dir "$dir" terminateIfNotExists`
# `dirMustExists "$dir"` digantikan dengan `rcm-dir "$dir" mustExists`
# ``
# dirMustExists() {
    # local path="$1"
    # global used:
    # global modified:
    # function used: __, success, error, x
    # if [ -d "$path" ];then
        # __; green Direktori '`'"$dirname"'`' ditemukan.; _.
    # else
        # __; red Direktori '`'"$dirname"'`' tidak ditemukan.; x
    # fi
# }
# isDirExists() {
    # local path="$1"
    # global used:
    # global modified: found, notfound
    # function used: __
    # found=
    # notfound=
    # if [ -d "$path" ];then
        # __ Direktori '`'"$dirname"'`' ditemukan.
        # found=1
    # else
        # __ Direktori '`'"$dirname"'`' tidak ditemukan.
        # notfound=1
    # fi
# }

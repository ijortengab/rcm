#!/bin/bash

# How to use?
# rcm-file isExists "$path"
# rcm-file mustExists "$path"
# rcm-file terminateIfNotExists "$path"
rcm-file() {
    [ "$1" == --help ] && {
        e Usage: rcm-file '<method>' '<path>'; _.;
        e Method available: isExists, mustExists, terminateIfNotExists.; _.;
        e Global variable used: \$found, \$notfound.; _.;
        return;
    }
    local method="$1"
    local path="$2"
    [ -z "$method" ] && { error Argument '<method>' is required.; x; }
    [ -z "$path" ] && { error Argument '<path>' is required.; x; }
    shift 2
    local filename="${path##*/}"

    case "$method" in
        isExists)
            found=
            notfound=
            if [ -f "$path" ];then
                __ File '`'"$filename"'`' ditemukan.
                found=1
            else
                __ File '`'"$filename"'`' tidak ditemukan.
                notfound=1
            fi
            ;;
        mustExists)
            if [ -f "$path" ];then
                __; green File '`'"$filename"'`' ditemukan.; _.
            else
                __; red File '`'"$filename"'`' tidak ditemukan.; x
            fi
            ;;
        terminateIfNotExists)
            if [ ! -f "$path" ];then
                __; red File '`'"$filename"'`' tidak ditemukan.; x
            fi
            ;;
    esac
}

# Class ini menggantikan function isFileExists() dan fileMustExists()
# Legacy:
# `isFileExists "$file"` digantikan dengan `rcm-file isExists` "$file"
# `[ -f "$file" ] || fileMustExists "$file"` digantikan dengan `rcm-file terminateIfNotExists` "$file"
# `fileMustExists "$file"` digantikan dengan `rcm-file mustExists` "$file"
# ``
# fileMustExists() {
    # local path="$1"
    # global used:
    # global modified:
    # function used: __, success, error, x
    # if [ -f "$path" ];then
        # __; green File '`'"$filename"'`' ditemukan.; _.
    # else
        # __; red File '`'"$filename"'`' tidak ditemukan.; x
    # fi
# }
# isFileExists() {
    # local path="$1"
    # global used:
    # global modified: found, notfound
    # function used: __
    # found=
    # notfound=
    # if [ -f "$path" ];then
        # __ File '`'"$filename"'`' ditemukan.
        # found=1
    # else
        # __ File '`'"$filename"'`' tidak ditemukan.
        # notfound=1
    # fi
# }

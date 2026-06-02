#!/bin/bash

# How to use?
# rcm-file "$path" isExists
# rcm-file "$path" mustExists
# rcm-file "$path" terminateIfNotExists
rcm-file() {
    local path="$1"
    local method="$2"
    shift 2

    case "$method" in
        isExists)
            found=
            notfound=
            if [ -f "$path" ];then
                __ File '`'$(basename "$path")'`' ditemukan.
                found=1
            else
                __ File '`'$(basename "$path")'`' tidak ditemukan.
                notfound=1
            fi
            ;;
        mustExists)
            if [ -f "$path" ];then
                __; green File '`'$(basename "$path")'`' ditemukan.; _.
            else
                __; red File '`'$(basename "$path")'`' tidak ditemukan.; x
            fi
            ;;
        terminateIfNotExists)
            if [ ! -f "$path" ];then
                __; red File '`'$(basename "$path")'`' tidak ditemukan.; x
            fi
            ;;
    esac
}

# Class ini menggantikan function isFileExists() dan fileMustExists()
# Legacy:
# `isFileExists "$file"` digantikan dengan `rcm-file "$file" isExists`
# `[ -f "$file" ] || fileMustExists "$file"` digantikan dengan `rcm-file "$file" terminateIfNotExists`
# `fileMustExists "$file"` digantikan dengan `rcm-file "$file" mustExists`
# ``
# fileMustExists() {
    # global used:
    # global modified:
    # function used: __, success, error, x
    # if [ -f "$1" ];then
        # __; green File '`'$(basename "$1")'`' ditemukan.; _.
    # else
        # __; red File '`'$(basename "$1")'`' tidak ditemukan.; x
    # fi
# }
# isFileExists() {
    # global used:
    # global modified: found, notfound
    # function used: __
    # found=
    # notfound=
    # if [ -f "$1" ];then
        # __ File '`'$(basename "$1")'`' ditemukan.
        # found=1
    # else
        # __ File '`'$(basename "$1")'`' tidak ditemukan.
        # notfound=1
    # fi
# }

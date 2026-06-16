#!/bin/bash

# How to use?
# rcm-dir "$path" isExists
# rcm-dir "$path" mustExists
# rcm-dir "$path" terminateIfNotExists
rcm-dir() {
    local path="$1"
    local method="$2"
    shift 2

    case "$method" in
        isExists)
            found=
            notfound=
            if [ -d "$path" ];then
                __ Direktori '`'$(basename "$path")'`' ditemukan.
                found=1
            else
                __ Direktori '`'$(basename "$path")'`' tidak ditemukan.
                notfound=1
            fi
            ;;
        mustExists)
            if [ -d "$path" ];then
                __; green Direktori '`'$(basename "$path")'`' ditemukan.; _.
            else
                __; red Direktori '`'$(basename "$path")'`' tidak ditemukan.; x
            fi
            ;;
        terminateIfNotExists)
            if [ ! -d "$path" ];then
                __; red Direktori '`'$(basename "$path")'`' tidak ditemukan.; x
            fi
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
    # global used:
    # global modified:
    # function used: __, success, error, x
    # if [ -d "$1" ];then
        # __; green Direktori '`'$(basename "$1")'`' ditemukan.; _.
    # else
        # __; red Direktori '`'$(basename "$1")'`' tidak ditemukan.; x
    # fi
# }
# isDirExists() {
    # global used:
    # global modified: found, notfound
    # function used: __
    # found=
    # notfound=
    # if [ -d "$1" ];then
        # __ Direktori '`'$(basename "$1")'`' ditemukan.
        # found=1
    # else
        # __ Direktori '`'$(basename "$1")'`' tidak ditemukan.
        # notfound=1
    # fi
# }

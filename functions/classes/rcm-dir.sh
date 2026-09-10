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
                __ Direktori '`'"${path##*/}"'`' ditemukan.
                found=1
            else
                __ Direktori '`'"${path##*/}"'`' tidak ditemukan.
                notfound=1
            fi
            ;;
        mustExists)
            if [ -d "$path" ];then
                __; green Direktori '`'"${path##*/}"'`' ditemukan.; _.
            else
                __; red Direktori '`'"${path##*/}"'`' tidak ditemukan.; x
            fi
            ;;
        terminateIfNotExists)
            if [ ! -d "$path" ];then
                __; red Direktori '`'"${path##*/}"'`' tidak ditemukan.; x
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
    # local path="$1"
    # global used:
    # global modified:
    # function used: __, success, error, x
    # if [ -d "$path" ];then
        # __; green Direktori '`'"${path##*/}"'`' ditemukan.; _.
    # else
        # __; red Direktori '`'"${path##*/}"'`' tidak ditemukan.; x
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
        # __ Direktori '`'"${path##*/}"'`' ditemukan.
        # found=1
    # else
        # __ Direktori '`'"${path##*/}"'`' tidak ditemukan.
        # notfound=1
    # fi
# }

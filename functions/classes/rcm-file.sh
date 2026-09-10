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
                __ File '`'"${path##*/}"'`' ditemukan.
                found=1
            else
                __ File '`'"${path##*/}"'`' tidak ditemukan.
                notfound=1
            fi
            ;;
        mustExists)
            if [ -f "$path" ];then
                __; green File '`'"${path##*/}"'`' ditemukan.; _.
            else
                __; red File '`'"${path##*/}"'`' tidak ditemukan.; x
            fi
            ;;
        terminateIfNotExists)
            if [ ! -f "$path" ];then
                __; red File '`'"${path##*/}"'`' tidak ditemukan.; x
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
    # local path="$1"
    # global used:
    # global modified:
    # function used: __, success, error, x
    # if [ -f "$path" ];then
        # __; green File '`'"${path##*/}"'`' ditemukan.; _.
    # else
        # __; red File '`'"${path##*/}"'`' tidak ditemukan.; x
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
        # __ File '`'"${path##*/}"'`' ditemukan.
        # found=1
    # else
        # __ File '`'"${path##*/}"'`' tidak ditemukan.
        # notfound=1
    # fi
# }

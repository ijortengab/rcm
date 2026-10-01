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
                __ Direktori '`'"${path##*/}"'`' ditemukan.
            else
                __ Direktori '`'"${path##*/}"'`' tidak ditemukan.
                __ Membuat "$label" '`'$nginx_config_dir'`'.
                code mkdir -p '"'$path'"'
                mkdir -p "$path"
                if [ -n "$owner" ];then
                    code chown -R $owner:$owner '"'"$path"'"'
                    chown -R $owner:$owner "$path"
                fi
                if [ -d "$path" ];then
                    __; green Direktori '`'"${path##*/}"'`' ditemukan.; _.
                else
                    __; red Direktori '`'"${path##*/}"'`' tidak ditemukan.; x
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

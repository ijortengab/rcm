#!/bin/bash

link-symbolic-dir() {
    local source="$1"
    local target="$2"
    local sudo="$3"
    local source_mode="$4"
    local create
    # Trim trailing slash.
    source=$(echo "$source" | sed -E 's|/+$||g')
    target=$(echo "$target" | sed -E 's|/+$||g')
    [ "$sudo" == - ] && sudo=
    [ "$source_mode" == absolute ] || source_mode=
    [ -e "$source" ] || { error Source not exist: $source.; x; }
    [ -d "$source" ] || { error Source exists but not directory: $source.; x; }
    [ -n "$target" ] || { error Target not defined.; x; }
    [[ $(type -t backup-file) == function ]] || { error Function backup-file not found.; x; }
    [[ $(type -t backup-dir) == function ]] || { error Function backup-dir not found.; x; }
    chapter Membuat symbolic link directory.
    __ source: '`'$source'`'
    __ target: '`'$target'`'
    if [ -d "$target" ];then
        if [ -h "$target" ];then
            __ Path target saat ini sudah merupakan directory symbolic link: '`'$target'`'
            local _readlink=$(readlink "$target")
            __; magenta readlink "$target"; _.
            _ $_readlink; _.
            if [[ "$_readlink" =~ ^[^/\.] ]];then
                local target_parent="${target%/*}"
                local _dereference="${target_parent}/${_readlink}"
            elif [[ "$_readlink" =~ ^[\.] ]];then
                local target_parent="${target%/*}"
                local _dereference="${target_parent}/${_readlink}"
                _dereference=$(realpath -s "$_dereference")
            else
                _dereference="$_readlink"
            fi
            __; _, Mengecek apakah link merujuk ke '`'$source'`':' '
            if [[ "$source" == "$_dereference" ]];then
                _, merujuk.; _.
            else
                _, tidak merujuk.; _.
                __ Melakukan backup.
                backup-file move "$target"
                create=1
            fi
        else
            __ Melakukan backup regular direktori: '`'"$target"'`'.
            backup-dir "$target"
            create=1
        fi
    elif [ -f "$target" ];then
        __ Melakukan backup file: '`'"$target"'`'.
        backup-file move "$target"
        create=1
    else
        create=1
    fi
    if [ -n "$create" ];then
        __ Membuat symbolic link: '`'$target'`'.
        local target_parent="${target%/*}"
        if [ -n "$sudo" ];then
            code sudo -u '"'$sudo'"' mkdir -p '"'$target_parent'"'
            sudo -u "$sudo" mkdir -p "$target_parent"
        else
            code mkdir -p "$target_parent"
            mkdir -p "$target_parent"
        fi
        if [ -z "$source_mode" ];then
            source=$(realpath -s --relative-to="$target_parent" "$source")
        fi
        if [ -n "$sudo" ];then
            code sudo -u '"'$sudo'"' ln -s '"'$source'"' '"'$target'"'
            sudo -u "$sudo" ln -s "$source" "$target"
        else
            code ln -s '"'$source'"' '"'$target'"'
            ln -s "$source" "$target"
        fi
        if [ $? -eq 0 ];then
            __; green Symbolic link berhasil dibuat.; _.
        else
            __; red Symbolic link gagal dibuat.; x
        fi
    fi
    ____
}
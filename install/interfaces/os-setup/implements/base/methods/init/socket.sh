#!/bin/bash

chapter Mengecek shell default
is_dash=
if [[ $(realpath /bin/sh) =~ dash$ ]];then
    __ '`'sh'`' command is linked to dash.
    is_dash=1
else
    __ '`'sh'`' command is linked to $(realpath /bin/sh).
fi
____

if [[ -n "$is_dash" ]];then
    chapter Disable dash
    __ '`sh` command link to dash. Disable now.'
    echo "dash dash/sh boolean false" | debconf-set-selections
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash
    if [[ $(realpath /bin/sh) =~ dash$ ]];then
        __ '`'sh'`' command link to dash.
    else
        __; green '`'sh'`' command link to $(realpath /bin/sh).; _.
        is_dash=
    fi
    ____
fi

if [[ -n "$is_dash" ]];then
    chapter Disable dash again.
    __ '`sh` command link to dash. Override now.'
    path=$(command -v sh)
    cd $(dirname $path)
    ln -sf bash sh
    if [[ $(realpath /bin/sh) =~ dash$ ]];then
        __; red '`'sh'`' command link to dash.; x
    else
        __; green '`'sh'`' command link to $(realpath /bin/sh).; _.
    fi
    ____
fi

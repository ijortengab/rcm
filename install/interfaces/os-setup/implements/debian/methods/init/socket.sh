#!/bin/bash

include `rcm plugin run-parent-method os-setup base init`

chapter Mengecek timezone.
timezone="$RCM_OS_TIMEZONE"
if [ -n "$timezone" ];then
    if [ ! -f /usr/share/zoneinfo/$timezone ];then
        __ Timezone is not valid.
        timezone=
        code 'timezone="'$timezone'"'
    fi
fi
adjust=
if [ -n "$timezone" ];then
    current_timezone=$(realpath /etc/localtime | cut -d/ -f5,6)
    if [[ "$current_timezone" == "$timezone" ]];then
        __ Timezone is match: ${current_timezone}
    else
        __ Timezone is different: ${current_timezone}
        adjust=1
    fi
fi
____

if [[ -n "$adjust" ]];then
    chapter Adjust timezone.
    __ Backup file '`'/etc/localtime'`'
    backup-file move /etc/localtime
    __; magenta ln -s /usr/share/zoneinfo/$timezone /etc/localtime; _.
    ln -s /usr/share/zoneinfo/$timezone /etc/localtime
    current_timezone=$(realpath /etc/localtime | cut -d/ -f5,6)
    if [[ "$current_timezone" == "$timezone" ]];then
        __; green Timezone is match: ${current_timezone}; _.
    else
        __; red Timezone is different: ${current_timezone}; x
    fi
    ____
fi

#!/bin/bash

sleep-extended() {
    # Menggunakan global variable countdown agar sleep ini dapat di-interupsi.
    # Contoh:
    # ```
    # immediately() {
    #     countdown=0
    # }
    # trap immediately SIGINT
    # sleepExtended 30
    # trap x SIGINT
    # ```
    local timer=$1
    local width=$2
    local dikali10 countdown _dotLength dotLength
    if [ -z "$width" ];then
        width=80
    fi
    if [ "$timer" -gt 0 ];then
        dikali10=$((timer*10))
        countdown=$dikali10
        _dotLength=$(( ( width * countdown ) / dikali10 ))
        printf "\r\033[K" >&2
        e; printf %"$_dotLength"s | tr " " "." >&2
        printf "\r"
        while [ "$countdown" -ge 0 ]; do
            dotLength=$(( ( width * countdown ) / dikali10 ))
            if [[ ! "$dotLength" == "$_dotLength" ]];then
                _dotLength="$dotLength"
                printf "\r\033[K" >&2
                e; printf %"$dotLength"s | tr " " "." >&2
                printf "\r"
            fi
            countdown=$((countdown - 1))
            sleep .1
        done
    fi
}

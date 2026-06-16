#!/bin/bash

read-false() {
    _; _.
    __;  _, '['; yellow Enter; _, ']'; _, ' '; yellow N; _, 'o and skip.'; _.
    __;  _, '['; yellow Y; _, ']'; _, ' '; yellow Y; _, 'es and continue.'; _.
    RCM_BOOLEAN=
    _; _.
    __ Press the yellow key to select.
    while true; do
        __; read -rsn 1 -p "Select: " char
        if [ -z "$char" ];then
            char=n
        fi
        case $char in
            y|Y) echo "$char" >&2; RCM_BOOLEAN=1; break;;
            n|N) echo "$char" >&2; break ;;
            *) echo >&2
        esac
    done
}

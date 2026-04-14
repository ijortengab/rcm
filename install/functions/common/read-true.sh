#!/bin/bash

read-true() {
    _; _.
    __;  _, '['; yellow Enter; _, ']'; _, ' '; yellow Y; _, 'es and continue.'; _.
    __;  _, '['; yellow Esc; _, ']'; _, ' '; yellow N; _, 'o and skip.'; _.
    RCM_BOOLEAN=
    _; _.
    __ Press the yellow key to select.
    while true; do
        __; read -rsn 1 -p "Select: " char
        if [ -z "$char" ];then
            char=y
        fi
        case $char in
            y|Y) echo "$char" >&2; RCM_BOOLEAN=1; break;;
            n|N) echo "$char" >&2; break ;;
            $'\33') echo "n" >&2; break ;;
            *) echo >&2
        esac
    done
}

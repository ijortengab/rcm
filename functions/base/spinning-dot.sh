#!/bin/bash

spinning-dot() {
    spin=('\b\b\b\033[K' . . .)
    i=0
    __; _, "$1"
    while true; do
        i=$(( (i+1) %4 ))
        printf "${spin[$i]}" >&2;
        sleep .1
    done
}

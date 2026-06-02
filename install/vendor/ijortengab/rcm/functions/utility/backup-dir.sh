#!/bin/bash

backup-dir() {
    local oldpath="$1" i newpath
    # Trim trailing slash.
    oldpath=$(echo "$oldpath" | sed -E 's|/+$||g')
    i=1
    newpath="${oldpath}.${i}"
    if [ -e "$newpath" ]; then
        let i++
        newpath="${oldpath}.${i}"
        while [ -e "$newpath" ] ; do
            let i++
            newpath="${oldpath}.${i}"
        done
    fi
    mv "$oldpath" "$newpath"
}

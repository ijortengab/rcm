#!/bin/bash

include `rcm plugin get-socket os-setup ubuntu init`

# Dependency.
require command find-string

chapter Update Repository
update_system="$RCM_DO_UPDATE_SYSTEM"
upgrade_system="$RCM_DO_UPGRADE_SYSTEM"

repository_required=$(cat <<EOF
deb http://archive.ubuntu.com/ubuntu/ jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ jammy-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ jammy-backports main restricted universe multiverse
deb http://archive.canonical.com/ubuntu/ jammy partner
EOF
)
path=/etc/apt/sources.list
code path='"'$path'"'
while IFS= read -r string; do
    array=($string)
    deb="${array[0]}"
    uri="${array[1]}"
    suite="${array[2]}"
    if ! find-string "${deb} ${uri}/? ${suite} " "$path"; then
        CONTENT+="$string"$'\n'
        update_now=1
    fi
done <<< "$repository_required"
[ -z "$CONTENT" ] || {
    CONTENT=$'\n'"# Customize. ${NOW}"$'\n'"$CONTENT"
    echo "$CONTENT" >> /etc/apt/sources.list
}
if [ -n "$update_now" ];then
    code apt -y update
    apt -y update
else
    if [ -n "$update_system" ];then
        code apt -y update
        apt -y update
    fi
    if [ -n "$upgrade_system" ];then
        code apt -y upgrade
        apt -y upgrade
    fi
fi
____

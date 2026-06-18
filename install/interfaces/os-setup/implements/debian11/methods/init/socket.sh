#!/bin/bash

include `rcm plugin run-parent-method os-setup debian init`

# Dependency.
require command find-string

chapter Update Repository
update_system="$RCM_DO_UPDATE_SYSTEM"
upgrade_system="$RCM_DO_UPGRADE_SYSTEM"
repository_required=$(cat <<EOF
deb http://deb.debian.org/debian bullseye main
deb-src http://deb.debian.org/debian bullseye main
deb http://security.debian.org/debian-security bullseye-security main
deb-src http://security.debian.org/debian-security bullseye-security main
deb http://deb.debian.org/debian bullseye-updates main
deb-src http://deb.debian.org/debian bullseye-updates main
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

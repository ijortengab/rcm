#!/bin/bash

# apache2-utils dibutuhkan untuk htpasswd.
apt-install apache2-utils

INDENT+="$RCM_INDENT" \
rcm nginx init \
    ; [ ! $? -eq 0 ] && x

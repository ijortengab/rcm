#!/bin/bash

INDENT+="$RCM_INDENT" \
rcm mariadb init \
    ; [ ! $? -eq 0 ] && x

# Wajib return atau exit 0 jika success.
return 0

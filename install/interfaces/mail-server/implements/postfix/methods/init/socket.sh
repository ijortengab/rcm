#!/bin/bash

INDENT+="$RCM_INDENT" \
rcm postfix init \
    ; [ ! $? -eq 0 ] && x

# Wajib return atau exit 0 jika success.
return 0

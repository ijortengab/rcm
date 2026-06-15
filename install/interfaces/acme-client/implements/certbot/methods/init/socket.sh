#!/bin/bash

INDENT+="$RCM_INDENT" \
rcm certbot init \
    ; [ ! $? -eq 0 ] && x

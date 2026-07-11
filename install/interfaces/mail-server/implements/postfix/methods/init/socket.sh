#!/bin/bash

INDENT+="$RCM_INDENT" \
rcm postfix init \
    ; [ ! $? -eq 0 ] && x

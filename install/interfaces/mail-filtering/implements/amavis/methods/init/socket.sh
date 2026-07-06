#!/bin/bash

INDENT+="$RCM_INDENT" \
rcm amavis init \
    ; [ ! $? -eq 0 ] && x

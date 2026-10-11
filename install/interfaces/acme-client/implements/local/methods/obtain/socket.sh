#!/bin/bash

# Dependency.
[ -n "$RCM_FQDN" ] || { red "Unable to proceed, variable \$RCM_FQDN is empty."; x; }

domain_name="$RCM_FQDN"

run rcm openssl create certificate \
    --domain="$domain_name" \
    ; [ $? -eq 0 ] || x

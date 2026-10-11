#!/bin/bash

# Dependency.
[ -n "$RCM_FQDN" ] || { red "Unable to proceed, variable \$RCM_FQDN is empty."; x; }

domain_name="$RCM_FQDN"

# Sementara pakai cara ini dulu.
RCM_TLS_CERTIFICATE="/usr/local/share/certificates/${domain_name}/${domain_name}.crt"
RCM_TLS_CERTIFICATE_KEY="/usr/local/share/certificates/${domain_name}/${domain_name}.key"

#!/bin/bash

# Dependency.
require vendor/ijortengab/bash/functions/array-search.sh
require vendor/ijortengab/rcm/functions/base/array.sh

chapter Populate variables.
code RCM_WEB_SERVER_VHOST_TAGS=@
code RCM_WEB_SERVER_VHOST_METADATA_YAML=+
nginx_template_candidate=static-default
language=html
if array-search php RCM_WEB_SERVER_VHOST_TAGS[@];then
    nginx_template_candidate=php-default
    language=php
fi
if array-search subdirectory-safe RCM_WEB_SERVER_VHOST_TAGS[@];then
    case "$language" in
        php)
            nginx_template_candidate=php-multiple-root
            ;;
    esac
fi

code nginx_template_candidate=$
array="$RCM_WEB_SERVER_VHOST_METADATA_YAML"
array url; url="$_return_value"; unset _return_value
array fastcgi_pass; fastcgi_pass="$_return_value"; unset _return_value
array root; root="$_return_value"; unset _return_value
array tls_certificate; tls_certificate="$_return_value"; unset _return_value
array tls_certificate_key; tls_certificate_key="$_return_value"; unset _return_value
code url=$
code fastcgi_pass=$
code root=$
code tls_certificate=$
code tls_certificate_key=$
____

require rcm nginx add vhost $nginx_template_candidate

run rcm nginx add vhost $nginx_template_candidate \
    --url="$url" \
    --fastcgi-pass="$fastcgi_pass" \
    --root="$root" \
    --tls-certificate="$tls_certificate" \
    --tls-certificate-key="$tls_certificate_key" \

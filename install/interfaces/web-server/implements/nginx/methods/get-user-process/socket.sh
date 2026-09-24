#!/bin/bash

# Must populate variable $RCM_WEB_SERVER_USER with value:
# Validate if empty string should inspect in parent.
# Reset first.
RCM_WEB_SERVER_USER=

nginx_user=
conf_nginx=`command -v nginx > /dev/null && nginx -V 2>&1 | grep -o -P -- '--conf-path=\K(\S+)'`
if [ -f "$conf_nginx" ];then
    nginx_user=`grep -o -P '^user\s+\K([^;]+)' "$conf_nginx"`
fi
RCM_WEB_SERVER_USER="$nginx_user"

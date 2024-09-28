#!/bin/bash

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --fast) fast=1; shift ;;
        --root-sure) root_sure=1; shift ;;
        --[^-]*) shift ;;
        *) _new_arguments+=("$1"); shift ;;
    esac
done
set -- "${_new_arguments[@]}"
unset _new_arguments

# Common Functions.
red() { echo -ne "\e[91m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
green() { echo -ne "\e[92m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
yellow() { echo -ne "\e[93m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
blue() { echo -ne "\e[94m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
magenta() { echo -ne "\e[95m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
error() { echo -n "$INDENT" >&2; red '#' "$@" >&2; echo >&2; }
success() { echo -n "$INDENT" >&2; green '#' "$@" >&2; echo >&2; }
chapter() { echo -n "$INDENT" >&2; yellow '#' "$@" >&2; echo >&2; }
title() { echo -n "$INDENT" >&2; blue '#' "$@" >&2; echo >&2; }
code() { echo -n "$INDENT" >&2; magenta "$@" >&2; echo >&2; }
x() { echo >&2; exit 1; }
e() { echo -n "$INDENT" >&2; echo "#" "$@" >&2; }
_() { echo -n "$INDENT" >&2; echo -n "#" "$@" >&2; }
_,() { echo -n "$@" >&2; }
_.() { echo >&2; }
__() { echo -n "$INDENT" >&2; echo -n "#" '    ' >&2; [ -n "$1" ] && echo "$@" >&2 || echo -n  >&2; }
____() { echo >&2; [ -n "$delay" ] && sleep "$delay"; }

# Functions.
printVersion() {
    echo '0.16.0'
}
printHelp() {
    title RCM Composer Auto-Installer
    _ 'Variation '; yellow Default; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-composer-autoinstaller [options]

Global Options.
   --fast
        No delay every subtask.
   --version
        Print version of this script.
   --help
        Show this help.
   --root-sure
        Bypass root checking.
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Dependency.
command -v "php" >/dev/null || { echo -e "\e[91m" "Unable to proceed, php command not found." "\e[39m"; exit 1; }

# Functions.

# Title.
title rcm-composer-autoinstaller
____

# Require, validate, and populate value.
chapter Dump variable.
delay=.5; [ -n "$fast" ] && unset delay
____

if [ -z "$root_sure" ];then
    chapter Mengecek akses root.
    if [[ "$EUID" -ne 0 ]]; then
        error This script needs to be run with superuser privileges.; x
    else
        __ Privileges.
    fi
    ____
fi

# Credit:
# https://www.google.com/search?q=php+http+proxy+environment+variable
# https://stackoverflow.com/a/40771206
# https://gist.github.com/ebuildy/381f116e9cd18216a69188ce0230708d
php=$(cat <<-'EOF'
$proxy = getenv('http_proxy');
if (!empty($proxy)) {
    $proxy = str_replace('http://', 'tcp://', $proxy);
    $context = array(
        'http' => array(
            'proxy' => $proxy,
            'request_fulluri' => true,
            'verify_peer'      => false,
            'verify_peer_name' => false,
        ),
        "ssl"=>array(
            "verify_peer"=>false,
            "verify_peer_name"=>false
        )
    );
    stream_context_set_default($context);
}
$mode = $_SERVER['argv'][1];
switch ($mode) {
    case 'get_expected_checksum':
        copy("https://composer.github.io/installer.sig", "php://stdout");
        break;

    case 'download':
        copy('https://getcomposer.org/installer', 'composer-setup.php');
        break;

    case 'get_actual_checksum':
        echo hash_file('sha384', 'composer-setup.php');
        break;
}

EOF
)

chapter Memastikan command '`'composer'`'
notfound=
if command -v composer >/dev/null;then
    __ Command composer ditemukan.
else
    __ Command composer tidak ditemukan.
    notfound=1
fi
____

if [ -n "$notfound" ];then
    chapter Mendownload Installer
    __ Mengecek Checksum.
    EXPECTED_CHECKSUM=$(php -r "$php" get_expected_checksum)
    __; magenta EXPECTED_CHECKSUM="$EXPECTED_CHECKSUM"; _.
    cd /tmp
    __ Mendownload File '`'getcomposer.org/installer'`' sebagai file '`'composer-setup.php'`'
    php -r "$php" download
    ACTUAL_CHECKSUM="$(php -r "$php" get_actual_checksum)"
    __; magenta ACTUAL_CHECKSUM="$ACTUAL_CHECKSUM"; _.
    if [[ ! "$EXPECTED_CHECKSUM" == "$ACTUAL_CHECKSUM" ]];then
        rm composer-setup.php
        error 'ERROR: Invalid installer checksum'; x
    fi
    ____

    chapter Menginstall Composer
    code php composer-setup.php --install-dir=/usr/local/bin --filename=composer
    if php composer-setup.php --install-dir=/usr/local/bin --filename=composer;then
        __; green Berhasil install Composer.; _.
    else
        __; red Failed install Composer.; x
    fi
    rm composer-setup.php
    cd - >/dev/null
    ____

    chapter Verifikasi command '`'composer'`'
    if command -v composer >/dev/null;then
        __; green Command composer ditemukan.; _.
    else
        __; red Command composer tidak ditemukan.; x
    fi
    ____
fi

exit 0

# parse-options.sh \
# --without-end-options-double-dash \
# --compact \
# --clean \
# --no-hash-bang \
# --no-original-arguments \
# --no-error-invalid-options \
# --no-error-require-arguments << EOF | clip
# FLAG=(
# --fast
# --version
# --help
# --root-sure
# )
# VALUE=(
# )
# MULTIVALUE=(
# )
# FLAG_VALUE=(
# )
# EOF
# clear

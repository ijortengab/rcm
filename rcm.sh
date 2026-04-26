#!/bin/bash

# Rapid Construct Massive
#
# (c) IjorTengab <ijortengab@systemix.id> <ijortengab@gmail.com>
#
# https://github.com/ijortengab/rcm
#
# Command to install: `wget -qO- git.io/rcm | sh`
#

RCM_PREFIX=${RCM_PREFIX:=/usr/local/rcm}
RCM_VERSION='0.18.0-alpha.6'
RCM_LIB="${RCM_PREFIX}/lib/${RCM_VERSION}"

if ! command -v rcm > /dev/null;then
    echo -n "\e[95m"rcm; echo -n "\e[39m" command is; echo -n "\e[91m" not found; echo "\e[39m".
    if ! command -v wget > /dev/null;then
        echo -n "\e[95m"wget; echo "\e[39m" command is not found.
        echo Please install wget first.; exit 1
    fi
    echo -n Downloading...
    tempdir=$(mktemp -d)
    cd "$tempdir"
    owner=ijortengab
    repository=rcm
    tag_name=$RCM_VERSION
    url_tarball="https://api.github.com/repos/${owner}/${repository}/tarball/${tag_name}"
    wget -q -O "${tag_name}.tar.gz" "$url_tarball"
    printf "\r\033[K" >&2
    if [ ! -s "${tag_name}.tar.gz" ];then
        echo Failed to download file: "${tag_name}.tar.gz".;
        cd - >/dev/null; rm -rf "$tempdir"; exit 1
    else
        echo Downloaded.
    fi
    echo -n Extracting...
    tar xfz "${tag_name}.tar.gz"
    printf "\r\033[K" >&2
    found_directory_extracted=$(find -maxdepth 1 -mindepth 1 -type d)
    if [ ! -d "$found_directory_extracted" ];then
        echo Failed to extract archieve: "${tag_name}.tar.gz".;
        cd - >/dev/null; rm -rf "$tempdir"; exit 1
    else
        echo Extracted.
    fi
    echo -n Installing...
    mkdir -p "$RCM_LIB"
    mv "$found_directory_extracted/install" -T "$RCM_LIB"
    chmod a+x "$found_directory_extracted/rcm.sh"
    mv "$found_directory_extracted/rcm.sh" /usr/local/bin/rcm
    printf "\r\033[K" >&2
    if ! command -v rcm > /dev/null;then
        echo Failed to install.;
        cd - >/dev/null; rm -rf "$tempdir"; exit 1
    else
        echo Installed.
    fi
    echo -n "\e[95m"rcm; echo -n "\e[39m" command is; echo -n "\e[92m" found; echo "\e[39m".
fi

source "${RCM_LIB}"/rcm-exec.sh

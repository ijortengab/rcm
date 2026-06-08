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
RCM_VERSION='0.19.0-alpha.7'
RCM_LIB="${RCM_PREFIX}/lib/${RCM_VERSION}"
GITHUB_OWNER=ijortengab
GITHUB_REPOSITORY=rcm

if ! command -v rcm > /dev/null;then
    # Compatible with: bash and dash.
    # Credit: https://stackoverflow.com/a/37351799
    printf '%b' "\033[95;1m"rcm"\033[0m"' command is '"\033[91;1m"'not found'"\033[0m"."\n" >&2

    if ! command -v wget > /dev/null;then
        printf '%b' "\033[95;1m"wget"\033[0m"' command is '"\033[91;1m"'not found'"\033[0m"."\n" >&2
        echo Please install wget first. >&2; exit 1
    fi
    echo -n Downloading... >&2
    tempdir=$(mktemp -d)
    cd "$tempdir"
    owner=$GITHUB_OWNER
    repository=$GITHUB_REPOSITORY
    tag_name=$RCM_VERSION
    url_tarball="https://api.github.com/repos/${owner}/${repository}/tarball/${tag_name}"
    wget -q -O "${tag_name}.tar.gz" "$url_tarball"
    printf "\r\033[K" >&2
    if [ ! -s "${tag_name}.tar.gz" ];then
        echo Failed to download file: "${tag_name}.tar.gz". >&2
        cd - >/dev/null; rm -rf "$tempdir"; exit 1
    else
        echo Downloaded. >&2
    fi
    echo -n Extracting... >&2
    tar xfz "${tag_name}.tar.gz"
    printf "\r\033[K" >&2
    found_directory_extracted=$(find -maxdepth 1 -mindepth 1 -type d)
    if [ ! -d "$found_directory_extracted" ];then
        echo Failed to extract archieve: "${tag_name}.tar.gz". >&2
        cd - >/dev/null; rm -rf "$tempdir"; exit 1
    else
        echo Extracted. >&2
    fi
    echo -n Installing... >&2
    mkdir -p "$RCM_LIB"
    mv "$found_directory_extracted/install" -T "$RCM_LIB"
    chmod a+x "$found_directory_extracted/rcm.sh"
    mv "$found_directory_extracted/rcm.sh" /usr/local/bin/rcm
    printf "\r\033[K" >&2
    if ! command -v rcm > /dev/null;then
        echo Failed to install. >&2
        cd - >/dev/null; rm -rf "$tempdir"; exit 1
    else
        echo Installed. >&2
    fi
    printf '%b' "\033[95;1m"rcm"\033[0m"' command is '"\033[92;1m"'found'"\033[0m"."\n" >&2
    echo -n Initialize... >&2
    mkdir -p "${RCM_LIB}/interfaces"
    rcm init
    printf "\r\033[K" >&2
    echo Initialized. >&2
else
    [ -f "${RCM_LIB}/rcm-exec.sh" ] || { echo File is not found: rcm-exec.sh. >&2; exit 1; }
    source "${RCM_LIB}"/rcm-exec.sh
fi

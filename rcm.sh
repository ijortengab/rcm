#!/bin/bash

# Prerequisite.
[ -f "$0" ] || { echo -e "\e[91m" "Cannot run as dot command. Hit Control+c now." "\e[39m"; read; exit 1; }

# Parse arguments. Generated by parse-options.sh
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --fast) fast=1; shift ;;
        --root-sure) root_sure=1; shift ;;
        --) shift
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    *) _new_arguments+=("$1"); shift ;;
                esac
            done
            ;;
        --[^-]*) shift ;;
        *) _new_arguments+=("$1"); shift ;;
    esac
done
set -- "${_new_arguments[@]}"
unset _new_arguments

# Command.
command="$1"; shift
if [ -n "$command" ];then
    case "$command" in
        dependency-downloader) ;;
        rcm-*.sh) ;;
        *) echo -e "\e[91m""Command ${command} is unknown.""\e[39m"; exit 1
    esac
else
    command=list
fi

# Functions.
[[ $(type -t Rcm_printVersion) == function ]] || Rcm_printVersion() {
    echo '0.1.5'
}
[[ $(type -t Rcm_printHelp) == function ]] || Rcm_printHelp() {
    cat << EOF
RCM Wrapper
Variation Default
Version `Rcm_printVersion`

EOF
    cat << 'EOF'
Usage: rcm.sh [file]
       rcm.sh [command]

Available commands: dependency-downloader.

Options:

Global Options:
   --fast
        No delay every subtask.
   --version
        Print version of this script.
   --help
        Show this help.
   --root-sure
        Bypass root checking.

Environment Variables:
   BINARY_DIRECTORY
        Default to $__DIR__
EOF
}

# Help and Version.
[ -n "$help" ] && { Rcm_printHelp; exit 1; }
[ -n "$version" ] && { Rcm_printVersion; exit 1; }

# Common Functions.
[[ $(type -t red) == function ]] || red() { echo -ne "\e[91m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
[[ $(type -t green) == function ]] || green() { echo -ne "\e[92m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
[[ $(type -t yellow) == function ]] || yellow() { echo -ne "\e[93m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
[[ $(type -t blue) == function ]] || blue() { echo -ne "\e[94m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
[[ $(type -t magenta) == function ]] || magenta() { echo -ne "\e[95m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
[[ $(type -t error) == function ]] || error() { echo -n "$INDENT" >&2; red "$@" >&2; echo >&2; }
[[ $(type -t success) == function ]] || success() { echo -n "$INDENT" >&2; green "$@" >&2; echo >&2; }
[[ $(type -t chapter) == function ]] || chapter() { echo -n "$INDENT" >&2; yellow "$@" >&2; echo >&2; }
[[ $(type -t title) == function ]] || title() { echo -n "$INDENT" >&2; blue "$@" >&2; echo >&2; }
[[ $(type -t code) == function ]] || code() { echo -n "$INDENT" >&2; magenta "$@" >&2; echo >&2; }
[[ $(type -t x) == function ]] || x() { echo >&2; exit 1; }
[[ $(type -t e) == function ]] || e() { echo -n "$INDENT" >&2; echo "$@" >&2; }
[[ $(type -t _) == function ]] || _() { echo -n "$INDENT" >&2; echo -n "$@" >&2; }
[[ $(type -t _,) == function ]] || _,() { echo -n "$@" >&2; }
[[ $(type -t _.) == function ]] || _.() { echo >&2; }
[[ $(type -t __) == function ]] || __() { echo -n "$INDENT" >&2; echo -n '    ' >&2; [ -n "$1" ] && echo "$@" >&2 || echo -n  >&2; }
[[ $(type -t ____) == function ]] || ____() { echo >&2; [ -n "$delay" ] && sleep "$delay"; }

# Functions.
[[ $(type -t resolve_relative_path) == function ]] || resolve_relative_path() (
    # Credit: https://www.baeldung.com/linux/bash-expand-relative-path
    # Info: https://github.com/ijortengab/bash/blob/master/commands/resolve-relative-path.sh
    if [ -d "$1" ]; then
        cd "$1" || return 1
        pwd
    elif [ -e "$1" ]; then
        if [ ! "${1%/*}" = "$1" ]; then
            cd "${1%/*}" || return 1
        fi
        echo "$(pwd)/${1##*/}"
    else
        return 1
    fi
)
[[ $(type -t fileMustExists) == function ]] || fileMustExists() {
    # global used:
    # global modified:
    # function used: __, success, error, x
    if [ -f "$1" ];then
        __; green File '`'$(basename "$1")'`' ditemukan.; _.
    else
        __; red File '`'$(basename "$1")'`' tidak ditemukan.; x
    fi
}
[[ $(type -t Rcm_download) == function ]] || Rcm_download() {
    each="$1"
    inside_directory="$2"
    chapter Requires command: "$each".
    if [[ -f "$BINARY_DIRECTORY/$each" && ! -s "$BINARY_DIRECTORY/$each" ]];then
        __ Empty file detected.
        __; magenta rm "$BINARY_DIRECTORY/$each"; _.
        rm "$BINARY_DIRECTORY/$each"
    fi
    if [ ! -f "$BINARY_DIRECTORY/$each" ];then
        __ Memulai download.
        if [ -z "$inside_directory" ];then
            __; magenta wget https://github.com/ijortengab/rcm/raw/master/"$each" -O "$BINARY_DIRECTORY/$each"; _.
            wget -q https://github.com/ijortengab/rcm/raw/master/"$each" -O "$BINARY_DIRECTORY/$each"
        else
            __; magenta wget https://github.com/ijortengab/rcm/raw/master/$(cut -d- -f2 <<< "$each")/"$each" -O "$BINARY_DIRECTORY/$each"; _.
            wget -q https://github.com/ijortengab/rcm/raw/master/$(cut -d- -f2 <<< "$each")/"$each" -O "$BINARY_DIRECTORY/$each"
        fi
        if [ ! -s "$BINARY_DIRECTORY/$each" ];then
            __; magenta rm "$BINARY_DIRECTORY/$each"; _.
            rm "$BINARY_DIRECTORY/$each"
            __; red HTTP Response: 404 Not Found; x
        fi
        __; magenta chmod a+x "$BINARY_DIRECTORY/$each"; _.
        chmod a+x "$BINARY_DIRECTORY/$each"
    elif [[ ! -x "$BINARY_DIRECTORY/$each" ]];then
        __; magenta chmod a+x "$BINARY_DIRECTORY/$each"; _.
        chmod a+x "$BINARY_DIRECTORY/$each"
    fi
    fileMustExists "$BINARY_DIRECTORY/$each"
    ____
}
[[ $(type -t userInputBooleanDefaultNo) == function ]] || userInputBooleanDefaultNo() {
    __;  _, '['; yellow Enter; _, ']'; _, ' '; yellow N; _, 'o and skip.'; _.
    __;  _, '['; yellow Y; _, ']'; _, ' '; yellow Y; _, 'es and continue.'; _.
    boolean=
    while true; do
        __; read -rsn 1 -p "Select: " char
        if [ -z "$char" ];then
            char=n
        fi
        case $char in
            y|Y) echo "$char"; boolean=1; break;;
            n|N) echo "$char"; break ;;
            *) echo
        esac
    done
}
[[ $(type -t userInputBooleanDefaultYes) == function ]] || userInputBooleanDefaultYes() {
    __;  _, '['; yellow Enter; _, ']'; _, ' '; yellow Y; _, 'es and continue.'; _.
    __;  _, '['; yellow Esc; _, ']'; _, ' '; yellow N; _, 'o and skip.'; _.
    boolean=
    while true; do
        __; read -rsn 1 -p "Select: " char
        if [ -z "$char" ];then
            char=y
        fi
        case $char in
            y|Y) echo "$char"; boolean=1; break;;
            n|N) echo "$char"; break ;;
            $'\33') echo "n"; break ;;
            *) echo
        esac
    done
}
[[ $(type -t printBackupDialog) == function ]] || printBackupDialog() {
    __; _, Restore the value:' '; yellow "${backup_value}"; _, '. '; _, Would you like to use that value?; _.
    userInputBooleanDefaultYes
    if [ -n "$boolean" ];then
        __; _, Value; _, ' '; yellow "$backup_value"; _, ' ';  _, used.; _.
        value="$backup_value";
    fi
}
[[ $(type -t printHistoryDialog) == function ]] || printHistoryDialog() {
    count_max=$(wc -l <<< "$history_value")
    unset count
    declare -i count
    count=0
    __ There are values available from history. Press the yellow key to select.
    while read opt; do
        count+=1
        __; _, '['; yellow $count; _, ']'; _, ' '; _, "$opt"; _.
    done <<< "$history_value"
    __;  _, '['; yellow Esc; _, ']'; _, ' '; yellow N; _, 'o and type new value.'; _.
    while true; do
        __; read -rsn 1 -p "Select: " char;
        case $char in
            $'\33') echo "n"; break ;;
            n|N) echo "$char"; break ;;
            [1-$count_max])
                echo "$char"
                value=$(sed -n ${char}p <<< "$history_value")
                __; _, Value; _, ' '; yellow "$value"; _, ' ';  _, selected.; _.
                save_history=
                break ;;
            *) echo
        esac
    done

}
[[ $(type -t Rcm_prompt) == function ]] || Rcm_prompt() {
    command="$1"
    argument_pass=()
    options=`$command --help | sed -n '/^Options[:\.]$/,$p' | sed -n '2,/^$/p'`
    if [ -n "$options" ];then
        chapter Prepare argument for command '`'$command'`'.
        until [[ -z "$options" ]];do
            parameter=`sed -n 1p <<< "$options" | xargs`
            is_required=
            is_flag=
            value_addon=
            is_flagvalue=
            save_history=1
            if [[ "${parameter:(-1):1}" == '*' ]];then
                is_required=1
                parameter="${parameter::-1}"
                parameter=`xargs <<< "$parameter"`
            elif [[ "${parameter:(-1):1}" == '^' ]];then
                is_flag=1
                parameter="${parameter::-1}"
                parameter=`xargs <<< "$parameter"`
            fi
            if [[ "$parameter" == '--' ]];then
                is_required=
                is_flag=
                value_addon=multivalue
            fi
            label=`sed -n 2p <<< "$options" | xargs`
            if grep -q -i -E '(^|\.\s)Multivalue\.' <<< "$label";then
                value_addon=multivalue
            fi
            if grep -q -i -E '(^|\.\s)Can have value\.' <<< "$label";then
                value_addon=canhavevalue
            fi
            options=`sed -n '3,$p' <<< "$options"`
            value=
            backup_value=$(grep -- "^${parameter}=.*$" "$backup_storage" | tail -1 | sed -E 's|'"^${parameter}=(.*)$"'|\1|')
            history_value=$(grep -- "^${parameter}=.*$" "$history_storage" | tail -9 | sed -E 's|'"^${parameter}=(.*)$"'|\1|')
            if [ -n "$is_required" ];then
                _ 'Argument '; magenta ${parameter};_, ' is '; yellow required; _, ". ${label}"; _.
                if [ -n "$backup_value" ];then
                    printBackupDialog
                fi
                if [ -z "$value" ];then
                    if [ -n "$history_value" ];then
                        printHistoryDialog
                    fi
                fi
                until [[ -n "$value" ]];do
                    __; read -p "Type the value: " value
                done
                argument_pass+=("${parameter}=${value}")
            elif [ -n "$is_flag" ];then
                _ 'Argument '; magenta ${parameter};_, ' is '; _, optional; _, ". ${label}"; _.
                __; _, Add this argument?; _.
                userInputBooleanDefaultNo
                if [ -n "$boolean" ]; then
                    if [[ "$value_addon" == 'canhavevalue' ]];then
                        __; _, Do you want fill with value?; _.
                        userInputBooleanDefaultNo
                        if [ -n "$boolean" ]; then
                            if [ -n "$backup_value" ];then
                                printBackupDialog
                            fi
                            if [ -z "$value" ];then
                                if [ -n "$history_value" ];then
                                    printHistoryDialog
                                fi
                            fi
                            until [[ -n "$value" ]];do
                                __; read -p "Type the value: " value
                            done
                            argument_pass+=("${parameter}=${value}")
                        else
                            argument_pass+=("${parameter}")
                        fi
                    else
                        argument_pass+=("${parameter}")
                    fi
                fi
            elif [[ "$parameter" == '--' ]];then
                _ 'Argument '; magenta ${parameter};_, ' is '; _, optional; _, ". ${label}"; _.
                __; read -p "Type the value: " value
                if [ -n "$value" ];then
                    argument_pass+=("${parameter} ${value}")
                fi
            else
                _ 'Argument '; magenta ${parameter};_, ' is '; _, optional; _, ". ${label}"; _.
                if [ -n "$backup_value" ];then
                    printBackupDialog
                fi
                if [ -z "$value" ];then
                    if [ -n "$history_value" ];then
                        printHistoryDialog
                    fi
                fi
                if [ -z "$value" ];then
                    __; read -p "Type the value: " value
                fi
                if [ -n "$value" ];then
                    argument_pass+=("${parameter}=${value}")
                fi
            fi
            if [[ "$value_addon" == 'multivalue' ]];then
                again=1
                until [ -z "$again" ]; do
                    if [ -n "$is_flag" ];then
                        read -p "Add this argument again [yN]? " value
                    else
                        read -p "Add other value [yN]? " value
                    fi
                    until [[ "$value" =~ ^[yYnN]*$ ]]; do
                        echo "$value: invalid selection."
                        if [ -n "$is_flag" ];then
                            read -p "Add this argument again [yN]? " value
                        else
                            read -p "Add other value [yN]? " value
                        fi
                    done
                    if [[ "$value" =~ ^[yY]$ ]]; then
                        if [ -n "$is_flag" ];then
                            argument_pass+=("${parameter}")
                        elif [[ "$parameter" == '--' ]];then
                            __; read -p "Type the value: " value
                            [ -n "$value" ] && argument_pass+=("${value}")
                        else
                            __; read -p "Type the value: " value
                            [ -n "$value" ] && argument_pass+=("${parameter}=${value}")
                        fi
                    else
                        again=
                    fi
                done
            fi
            # Backup to text file.
            if [ -n "$value" ];then
                echo "${parameter}=${value}" >> "$backup_storage"
                if [ -n "$save_history" ];then
                    echo "${parameter}=${value}" >> "$history_storage"
                fi
            fi
        done
        ____
    fi
}

# Execute command.
# git ls-files | grep '\.sh$' | grep -v rcm\.sh | grep -v rcm-dependency-downloader\.sh | cut -d/ -f2
if [ $command == list ];then
    cat << 'EOF'
rcm-amavis-setup-ispconfig.sh
rcm-certbot-autoinstaller.sh
rcm-certbot-digitalocean-autoinstaller.sh
rcm-certbot-setup-nginx.sh
rcm-composer-autoinstaller.sh
rcm-cygwin-setup-cron-wsl-autorun-sshd.sh
rcm-debian-11-setup-basic.sh
rcm-digitalocean-api-manage-domain-record.sh
rcm-digitalocean-api-manage-domain.sh
rcm-drupal-autoinstaller-nginx-php-fpm.sh
rcm-drupal-setup-drush-alias.sh
rcm-drupal-setup-dump-variables.sh
rcm-drupal-setup-variation1.sh
rcm-drupal-setup-variation2.sh
rcm-drupal-setup-variation3.sh
rcm-drupal-setup-wrapper-nginx-setup-drupal.sh
rcm-ispconfig-autoinstaller-nginx-php-fpm.sh
rcm-ispconfig-control-manage-domain.sh
rcm-ispconfig-control-manage-email-alias.sh
rcm-ispconfig-control-manage-email-mailbox.sh
rcm-ispconfig-setup-dump-variables.sh
rcm-ispconfig-setup-internal-command.sh
rcm-ispconfig-setup-variation1.sh
rcm-ispconfig-setup-variation2.sh
rcm-ispconfig-setup-wrapper-certbot-setup-nginx.sh
rcm-ispconfig-setup-wrapper-digitalocean.sh
rcm-ispconfig-setup-wrapper-nginx-setup-php-fpm.sh
rcm-mariadb-autoinstaller.sh
rcm-mariadb-setup-database.sh
rcm-mariadb-setup-ispconfig.sh
rcm-nginx-autoinstaller.sh
rcm-nginx-setup-drupal.sh
rcm-nginx-setup-hello-world-static.sh
rcm-nginx-setup-ispconfig.sh
rcm-nginx-setup-php-fpm.sh
rcm-nginx-setup-static.sh
rcm-php-autoinstaller.sh
rcm-php-setup-adjust-cli-version.sh
rcm-php-setup-drupal.sh
rcm-php-setup-ispconfig.sh
rcm-phpmyadmin-autoinstaller-nginx-php-fpm.sh
rcm-postfix-autoinstaller.sh
rcm-postfix-setup-ispconfig.sh
rcm-roundcube-autoinstaller-nginx-php-fpm.sh
rcm-roundcube-setup-ispconfig-integration.sh
rcm-ssh-setup-sshd-listen-port.sh
rcm-ubuntu-22.04-setup-basic.sh
rcm-wsl-setup-lemp-stack.sh
EOF
    ____

    read -p "Type the command to execute (or blank to skip): " command
    ____

    if [ -z "$command" ];then
        exit
    fi

fi

# Prompt.
if [ -z "$fast" ];then
    yellow It is highly recommended that you use; _, ' ' ; magenta --fast; _, ' ' ; yellow option.; _.
    countdown=2
    while [ "$countdown" -ge 0 ]; do
        printf "\r\033[K" >&2
        printf %"$countdown"s | tr " " "." >&2
        printf "\r"
        countdown=$((countdown - 1))
        sleep .8
    done
    ____
fi

# Title.
title Rapid Construct Massive
_ 'Variation '; yellow Default; _.
_ 'Version '; yellow `Rcm_printVersion`; _.
____

# Requirement, validate, and populate value.
chapter Dump variable.
delay=.5; [ -n "$fast" ] && unset delay
__FILE__=$(resolve_relative_path "$0")
__DIR__=$(dirname "$__FILE__")
BINARY_DIRECTORY=${BINARY_DIRECTORY:=$__DIR__}
code 'BINARY_DIRECTORY="'$BINARY_DIRECTORY'"'
declare -i countdown
____

if [ -z "$root_sure" ];then
    chapter Mengecek akses root.
    if [[ "$EUID" -ne 0 ]]; then
        error This script needs to be run with superuser privileges.; x
    else
        __ Privileges.; root_sure=1
    fi
    ____
fi

if [ -z "$binary_directory_exists_sure" ];then
    chapter Mempersiapkan directory binary.
    __; magenta BINARY_DIRECTORY=$BINARY_DIRECTORY; _.
    notfound=
    if [ -d "$BINARY_DIRECTORY" ];then
        __ Direktori '`'$BINARY_DIRECTORY'`' ditemukan.
        binary_directory_exists_sure=1
    else
        __ Direktori '`'$BINARY_DIRECTORY'`' tidak ditemukan.
        notfound=1
    fi
    ____

    if [ -n "$notfound" ];then
        chapter Membuat directory.
        mkdir -p "$BINARY_DIRECTORY"
        if [ -d "$BINARY_DIRECTORY" ];then
            __; green Direktori '`'$BINARY_DIRECTORY'`' ditemukan.; _.
            binary_directory_exists_sure=1
        else
            __; red Direktori '`'$BINARY_DIRECTORY'`' tidak ditemukan.; x
        fi
        ____
    fi
fi

if [ $command == dependency-downloader ];then
    PATH="${BINARY_DIRECTORY}:${PATH}"
    Rcm_download rcm-dependency-downloader.sh
    exit
fi

PATH="${BINARY_DIRECTORY}:${PATH}"
Rcm_download rcm-dependency-downloader.sh

Rcm_download $command true

if [ $# -eq 0 ];then
    backup_storage=$HOME'/.rcm.'$command'.bak'
    history_storage=$HOME'/.rcm.'$command'.history'
    touch "$backup_storage"
    touch "$history_storage"
    Rcm_prompt $command
    if [[ "${#argument_pass[@]}" -gt 0 ]];then
        set -- "${argument_pass[@]}"
        unset argument_pass
    fi
    rm "$backup_storage"
fi

chapter Execute:
[ -n "$fast" ] && isfast='--fast ' || isfast=''
code rcm-dependency-downloader.sh ${isfast}${command}
code ${command} ${isfast}"$@"
____

if [ -z "$fast" ];then
    yellow It is highly recommended that you use; _, ' ' ; magenta --fast; _, ' ' ; yellow option.; _.
    countdown=5
    while [ "$countdown" -ge 0 ]; do
        printf "\r\033[K" >&2
        printf %"$countdown"s | tr " " "." >&2
        printf "\r"
        countdown=$((countdown - 1))
        sleep .8
    done
    ____
fi

chapter Timer Start.
e Begin: $(date +%Y%m%d-%H%M%S)
Rcm_BEGIN=$SECONDS
____

_ _______________________________________________________________________;_.;_.;

INDENT+="    "
command -v "rcm-dependency-downloader.sh" >/dev/null || { red "Unable to proceed, rcm-dependency-downloader.sh command not found." "\e[39m"; x; }
INDENT="$INDENT" BINARY_DIRECTORY="$BINARY_DIRECTORY" rcm-dependency-downloader.sh $command $isfast --root-sure --binary-directory-exists-sure
command -v "$command" >/dev/null || { red "Unable to proceed, $command command not found."; x; }
INDENT="$INDENT" BINARY_DIRECTORY="$BINARY_DIRECTORY" $command $isfast --root-sure "$@"
INDENT=${INDENT::-4}
_ _______________________________________________________________________;_.;_.;

chapter Timer Finish.
e End: $(date +%Y%m%d-%H%M%S)
Rcm_END=$SECONDS
duration=$(( Rcm_END - Rcm_BEGIN ))
hours=$((duration / 3600)); minutes=$(( (duration % 3600) / 60 )); seconds=$(( (duration % 3600) % 60 ));
runtime=`printf "%02d:%02d:%02d" $hours $minutes $seconds`
_ Duration: $runtime; if [ $duration -gt 60 ];then _, " (${duration} seconds)"; fi; _, '.'; _.
____

exit 0

# parse-options.sh \
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
# CSV=(
# )
# EOF
# clear

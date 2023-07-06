#!/bin/bash

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
        rcm-*.sh) ;;
        *) echo -e "\e[91m""Command ${command} is unknown.""\e[39m"; exit 1
    esac
else
    command=list # internal only.
fi

# Functions.
printVersion() {
    echo '0.2.1'
}
printHelp() {
    cat << EOF
Rapid Construct Massive
Variation Default
Version `printVersion`

EOF
    cat << 'EOF'
Usage: rcm.sh
       rcm.sh [command]

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
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Common Functions.
red() { echo -ne "\e[91m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
green() { echo -ne "\e[92m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
yellow() { echo -ne "\e[93m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
blue() { echo -ne "\e[94m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
magenta() { echo -ne "\e[95m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
error() { echo -n "$INDENT" >&2; red "$@" >&2; echo >&2; }
success() { echo -n "$INDENT" >&2; green "$@" >&2; echo >&2; }
chapter() { echo -n "$INDENT" >&2; yellow "$@" >&2; echo >&2; }
title() { echo -n "$INDENT" >&2; blue "$@" >&2; echo >&2; }
code() { echo -n "$INDENT" >&2; magenta "$@" >&2; echo >&2; }
x() { echo >&2; exit 1; }
e() { echo -n "$INDENT" >&2; echo "$@" >&2; }
_() { echo -n "$INDENT" >&2; echo -n "$@" >&2; }
_,() { echo -n "$@" >&2; }
_.() { echo >&2; }
__() { echo -n "$INDENT" >&2; echo -n '    ' >&2; [ -n "$1" ] && echo "$@" >&2 || echo -n  >&2; }
____() { echo >&2; [ -n "$delay" ] && sleep "$delay"; }

# Functions.
resolve_relative_path() (
    if [ -d "$1" ];then
        cd "$1" || return 1
        pwd
    elif [ -e "$1" ];then
        if [ ! "${1%/*}" = "$1" ]; then
            cd "${1%/*}" || return 1
        fi
        echo "$(pwd)/${1##*/}"
    else
        return 1
    fi
)
fileMustExists() {
    # global used:
    # global modified:
    # function used: __, success, error, x
    if [ -f "$1" ];then
        __; green File '`'$(basename "$1")'`' ditemukan.; _.
    else
        __; red File '`'$(basename "$1")'`' tidak ditemukan.; x
    fi
}
userInputBooleanDefaultNo() {
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
userInputBooleanDefaultYes() {
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
printBackupDialog() {
    __; _, Restore the value:' '; yellow "${backup_value}"; _, '. '; _, Would you like to use that value?; _.
    userInputBooleanDefaultYes
    if [ -n "$boolean" ];then
        __; _, Value; _, ' '; yellow "$backup_value"; _, ' ';  _, used.; _.
        value="$backup_value";
    fi
}
printHistoryDialog() {
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
ArrayDiff() {
    # Computes the difference of arrays.
    #
    # Globals:
    #   Modified: _return
    #
    # Arguments:
    #   1 = Parameter of the array to compare from.
    #   2 = Parameter of the array to compare against.
    #
    # Returns:
    #   None
    #
    # Example:
    #   ```
    #   my=("cherry" "manggo" "blackberry" "manggo" "blackberry")
    #   yours=("cherry" "blackberry")
    #   ArrayDiff my[@] yours[@]
    #   # Get result in variable `$_return`.
    #   # _return=("manggo" "manggo")
    #   ```
    local e
    local source=("${!1}")
    local reference=("${!2}")
    _return=()
    # inArray is alternative of ArraySearch.
    inArray () {
        local e match="$1"
        shift
        for e; do [[ "$e" == "$match" ]] && return 0; done
        return 1
    }
    if [[ "${#reference[@]}" -gt 0 ]];then
        for e in "${source[@]}";do
            if ! inArray "$e" "${reference[@]}";then
                _return+=("$e")
            fi
        done
    else
        _return=("${source[@]}")
    fi
}
ArrayUnique() {
    # Removes duplicate values from an array.
    #
    # Globals:
    #   Modified: _return
    #
    # Arguments:
    #   1 = Parameter of the input array.
    #
    # Returns:
    #   None
    #
    # Example:
    #   ```
    #   my=("cherry" "manggo" "blackberry" "manggo" "blackberry")
    #   ArrayUnique my[@]
    #   # Get result in variable `$_return`.
    #   # _return=("cherry" "manggo" "blackberry")
    #   ```
    local e source=("${!1}")
    # inArray is alternative of ArraySearch.
    inArray () {
        local e match="$1"
        shift
        for e; do [[ "$e" == "$match" ]] && return 0; done
        return 1
    }
    _return=()
    for e in "${source[@]}";do
        if ! inArray "$e" "${_return[@]}";then
            _return+=("$e")
        fi
    done
}
Rcm_download() {
    commands_required=("$1")
    PATH="${BINARY_DIRECTORY}:${PATH}"
    commands_exists=()
    commands_downloaded=()
    table_downloads=
    until [[ ${#commands_required[@]} -eq 0 ]];do
        _commands_required=()
        chapter Requires command.
        for each in "${commands_required[@]}"; do
            _ Requires command: "$each"
            if command -v "$each" > /dev/null;then
                _, ' [FOUND].'; _.
                # __ Command "$each" ditemukan.
            else
                _, ' [NOTFOUND].'; _.
                if [[ -f "$BINARY_DIRECTORY/$each" && ! -s "$BINARY_DIRECTORY/$each" ]];then
                    __ Empty file detected.
                    __; magenta rm "$BINARY_DIRECTORY/$each"; _.
                    rm "$BINARY_DIRECTORY/$each"
                fi
                if [ ! -f "$BINARY_DIRECTORY/$each" ];then
                    url=
                    # Command dengan prefix rcm, kita anggap dari repository `ijortengab/rcm`.
                    if [[ "$each" =~ ^rcm- ]];then
                        url=https://github.com/ijortengab/rcm/raw/master/$(cut -d- -f2 <<< "$each")/"$each"
                    elif [[ "$each" =~ \.sh$ ]];then
                        url=$(grep -F '['$each']' <<< "$table_downloads" | tail -1 | sed -E 's/.*\((.*)\).*/\1/')
                    fi
                    if [ -n "$url" ];then
                        __ Memulai download.
                        __; magenta wget "$url"; _.
                        wget -q "$url" -O "$BINARY_DIRECTORY/$each"
                        fileMustExists "$BINARY_DIRECTORY/$each"
                        if [ ! -s "$BINARY_DIRECTORY/$each" ];then
                            __; magenta rm "$BINARY_DIRECTORY/$each"; _.
                            rm "$BINARY_DIRECTORY/$each"
                            __; red HTTP Response: 404 Not Found; x
                        fi
                        __; magenta chmod a+x "$BINARY_DIRECTORY/$each"; _.
                        chmod a+x "$BINARY_DIRECTORY/$each"
                        commands_downloaded+=("$each")
                    fi
                elif [[ ! -x "$BINARY_DIRECTORY/$each" ]];then
                    __; magenta chmod a+x "$BINARY_DIRECTORY/$each"; _.
                    chmod a+x "$BINARY_DIRECTORY/$each"
                fi
            fi
            commands_exists+=("$each")
            _help=$("$each" --help 2>/dev/null)
            # Hanya mendownload dependency dengan akhiran .sh (shell script).
            _dependency=$(echo "$_help" | sed -n '/^Dependency:/,$p' | sed -n '2,/^$/p' | sed 's/^ *//g' | grep \.sh$)
            _download=$(echo "$_help" | sed -n '/^Download:/,$p' | sed -n '2,/^$/p' | sed 's/^ *//g')
            if [ -n "$_dependency" ];then
                [ -n "$table_downloads" ] && table_downloads+=$'\n'
                table_downloads+="$_download"
            fi
            unset _download
            unset _help
            if [ -n "$_dependency" ];then
                _dependency=($_dependency)
                ArrayDiff _dependency[@] commands_exists[@]
                if [[ ${#_return[@]} -gt 0 ]];then
                    _commands_required+=("${_return[@]}")
                    unset _return
                fi
                unset _dependency
            fi
        done
        ____

        chapter Dump variable.
        ArrayUnique _commands_required[@]
        commands_required=("${_return[@]}")
        unset _return
        unset _commands_required
        code 'commands_required=('"${commands_required[@]}"')'
        ____
    done
}
Rcm_prompt() {
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

# Prompt.
if [ -z "$fast" ];then
    yellow It is highly recommended that you use; _, ' ' ; magenta --fast; _, ' ' ; yellow option.; _.
    if [[ $command =~ ^rcm ]];then
        countdown=1
        while [ "$countdown" -ge 0 ]; do
            printf "\r\033[K" >&2
            printf %"$countdown"s | tr " " "." >&2
            printf "\r"
            countdown=$((countdown - 1))
            sleep .8
        done
    fi
    ____
fi

# Execute command.
# git ls-files | grep '\.sh$' | grep -v rcm\.sh | cut -d/ -f2
if [ $command == list ];then
    command_list=$(cat << 'EOF'
rcm-amavis-setup-ispconfig.sh
rcm-certbot-autoinstaller.sh
rcm-certbot-digitalocean-autoinstaller.sh
rcm-certbot-setup-nginx.sh
rcm-composer-autoinstaller.sh
rcm-cron-setup-wsl-autorun-crond.sh
rcm-cron-setup-wsl-autorun-sshd.sh
rcm-cron-setup-wsl-port-forwarding.sh
rcm-debian-11-setup-basic.sh
rcm-digitalocean-api-manage-domain-record.sh
rcm-digitalocean-api-manage-domain.sh
rcm-drupal-autoinstaller-nginx-php-fpm.sh
rcm-drupal-setup-drush-alias.sh
rcm-drupal-setup-dump-variables.sh
rcm-drupal-setup-variation1.sh
rcm-drupal-setup-variation2.sh
rcm-drupal-setup-variation3.sh
rcm-drupal-setup-variation4.sh
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
rcm-ssh-setup-open-ssh-tunnel.sh
rcm-ssh-setup-sshd-listen-port.sh
rcm-ubuntu-22.04-setup-basic.sh
rcm-wsl-setup-lemp-stack.sh
EOF
    )
    e Press the yellow key to select.;
    history_storage=$HOME'/.rcm.history'
    save_history=1
    if [ -f "$history_storage" ];then
        history_value=$(tail -9 "$history_storage")
        count_max=$(wc -l <<< "$history_value")
        unset count
        declare -i count
        count=0
        while read opt; do
            count+=1
            _ '['; yellow $count; _, ']'; _, ' '; _, "$opt"; _.
        done <<< "$history_value"

    fi
    _ '['; yellow Esc; _, ']'; _, ' '; yellow Q; _, 'uit.'; _.
    _ '['; yellow Enter; _, ']'; _, ' Show all commands. (Tips navigate: press space key for next page, press q to quit.)'; _.
    while true; do
        read -rsn 1 -p "Select: " char
        if [ -z "$char" ];then
            printf "\r\033[K" >&2
            echo "$command_list" | less -N -X
            break
        fi
        case $char in
            $'\33') echo "q"; exit ;;
            q|Q) echo "$char"; exit ;;
            [1-$count_max])
                echo "$char"
                command_selected=$(sed -n ${char}p <<< "$history_value")
                save_history=
                break
                ;;
            *) echo
        esac
    done
    printDialogSecondary=
    until [ -n "$command_selected" ];do
        if [ -n "$printDialogSecondary" ];then
            printDialogSecondary=
            e Press the yellow key to select.;
            _ '['; yellow Esc; _, ']'; _, ' '; yellow Q; _, 'uit.'; _.
            _ '['; yellow Backspace; _, ']'; _, ' Show all commands.'; _.
            _ '['; yellow Enter; _, ']'; _, ' Type the number of command to select.'; _.
            while true; do
                read -rsn 1 -p "Select: " char
                if [ -z "$char" ];then
                    printf "\r\033[K" >&2
                    break
                fi
                case $char in
                    $'\33') echo "q"; exit ;;
                    q|Q) echo "$char"; exit ;;
                    $'\177')
                        printf "\r\033[K" >&2
                        echo "$command_list" | less -N -X
                        break
                        ;;
                    *) echo
                esac
            done
        fi
        read -p "Number of command to select: " number
        if [ -z "$number" ];then
            error The number is required.; _.
        elif [[ "$number" =~ ^[0-9]+$ ]];then
            command_selected=$(sed -n ${number}p <<< "$command_list")
            if [ -z "$command_selected" ];then
                error The number is out of range.; _.
            fi
        else
            error Input is not valid.; _.
        fi
        printDialogSecondary=1
    done
    _ Command' '; magenta $command_selected; _, ' 'selected.; _.
    command=$command_selected
    ____

    if [ -n "$save_history" ];then
        echo "$command_selected" >> "$history_storage"
    fi
fi

# Title.
title Rapid Construct Massive
_ 'Variation '; yellow Default; _.
_ 'Version '; yellow `printVersion`; _.
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
        __ Privileges.
    fi
    ____
fi

if [ -z "$binary_directory_exists_sure" ];then
    chapter Mempersiapkan directory binary.
    __; magenta BINARY_DIRECTORY=$BINARY_DIRECTORY; _.
    notfound=
    if [ -d "$BINARY_DIRECTORY" ];then
        __ Direktori '`'$BINARY_DIRECTORY'`' ditemukan.
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
            else
            __; red Direktori '`'$BINARY_DIRECTORY'`' tidak ditemukan.; x
        fi
        ____
    fi
fi

PATH="${BINARY_DIRECTORY}:${PATH}"

Rcm_download $command

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
code ${command} ${isfast}"$@"
____

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

chapter Timer Start.
e Begin: $(date +%Y%m%d-%H%M%S)
Rcm_BEGIN=$SECONDS
____
_ _______________________________________________________________________;_.;_.;

INDENT+="    "
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

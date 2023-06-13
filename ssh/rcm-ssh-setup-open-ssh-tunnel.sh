#!/bin/bash

# Prerequisite.
[ -f "$0" ] || { echo -e "\e[91m" "Cannot run as dot command. Hit Control+c now." "\e[39m"; read; exit 1; }

# Parse arguments. Generated by parse-options.sh_new_arguments=()
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --autorun=*) autorun="${1#*=}"; shift ;;
        --autorun) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then autorun="$2"; shift; fi; shift ;;
        --fast) fast=1; shift ;;
        --pattern=*) pattern="${1#*=}"; shift ;;
        --pattern) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then pattern="$2"; shift; fi; shift ;;
        --root-sure) root_sure=1; shift ;;
        --timeout-trigger-command=*) timeout_trigger_command="${1#*=}"; shift ;;
        --timeout-trigger-command) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then timeout_trigger_command="$2"; shift; fi; shift ;;
        --[^-]*) shift ;;
        *) _new_arguments+=("$1"); shift ;;
    esac
done
set -- "${_new_arguments[@]}"
unset _new_arguments

# Functions.
[[ $(type -t RcmSshSetupOpenSshTunnel_printVersion) == function ]] || RcmSshSetupOpenSshTunnel_printVersion() {
    echo '0.1.0'
}
[[ $(type -t RcmSshSetupOpenSshTunnel_printHelp) == function ]] || RcmSshSetupOpenSshTunnel_printHelp() {
    cat << EOF
RCM Wrapper
Variation Default
Version `RcmSshSetupOpenSshTunnel_printVersion`

EOF
    cat << 'EOF'
Usage: rcm-ssh-setup-open-ssh-tunnel.sh [options]

Available commands: dependency-downloader.

Options:
   --pattern *
        Argument that will be pass to `ssh-command-generator.sh` command.
   --timeout-trigger-command
        Argument that will be pass to `command-keep-alive.sh` command.
  --autorun
        Available value: cron, systemd.

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
   PREFIX_DIRECTORY
        Default to /usr/local

Dependency:
   ssh-keep-alive-symlink-reference.sh
EOF
}

# Help and Version.
[ -n "$help" ] && { RcmSshSetupOpenSshTunnel_printHelp; exit 1; }
[ -n "$version" ] && { RcmSshSetupOpenSshTunnel_printVersion; exit 1; }

# Dependency.
while IFS= read -r line; do
    command -v "${line}" >/dev/null || { echo -e "\e[91m""Unable to proceed, ${line} command not found." "\e[39m"; exit 1; }
done <<< `RcmSshSetupOpenSshTunnel_printHelp | sed -n '/^Dependency:/,$p' | sed -n '2,/^$/p' | sed 's/^ *//g'`

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
[[ $(type -t backupFile) == function ]] || backupFile() {
    local mode="$1"
    local oldpath="$2" i newpath
    i=1
    newpath="${oldpath}.${i}"
    if [ -f "$newpath" ]; then
        let i++
        newpath="${oldpath}.${i}"
        while [ -f "$newpath" ] ; do
            let i++
            newpath="${oldpath}.${i}"
        done
    fi
    case $mode in
        move)
            mv "$oldpath" "$newpath" ;;
        copy)
            local user=$(stat -c "%U" "$oldpath")
            local group=$(stat -c "%G" "$oldpath")
            cp "$oldpath" "$newpath"
            chown ${user}:${group} "$newpath"
    esac
}
[[ $(type -t isFileExists) == function ]] || isFileExists() {
    # global used:
    # global modified: found, notfound
    # function used: __
    found=
    notfound=
    if [ -f "$1" ];then
        __ File '`'$(basename "$1")'`' ditemukan.
        found=1
    else
        __ File '`'$(basename "$1")'`' tidak ditemukan.
        notfound=1
    fi
}
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

# Functions.
[[ $(type -t isFileExists) == function ]] || isFileExists() {
    # global used:
    # global modified: found, notfound
    # function used: __
    found=
    notfound=
    if [ -f "$1" ];then
        __ File '`'$(basename "$1")'`' ditemukan.
        found=1
    else
        __ File '`'$(basename "$1")'`' tidak ditemukan.
        notfound=1
    fi
}
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

# Title.
title RCM SSH Setup
_ 'Variation '; yellow Open SSH Tunnel; _.
_ 'Version '; yellow `RcmSshSetupOpenSshTunnel_printVersion`; _.
____

# Requirement, validate, and populate value.
chapter Dump variable.
delay=.5; [ -n "$fast" ] && unset delay
PREFIX_DIRECTORY=${PREFIX_DIRECTORY:=/usr/local}
code 'PREFIX_DIRECTORY="'$PREFIX_DIRECTORY'"'
prefix_directory=${PREFIX_DIRECTORY%/} # remove suffix.
code 'prefix_directory="'$prefix_directory'"'
until [[ -n "$pattern" ]];do
    read -p "Argument --pattern required: " pattern
done
code 'pattern="'$pattern'"'
code 'timeout_trigger_command="'$timeout_trigger_command'"'
if [ -n "$autorun" ];then
    case "$autorun" in
        cron|systemd) ;;
        *) autorun=
    esac
    until [[ -n "$autorun" ]];do
        _ Available value:' '; yellow cron, systemd.; _.
        read -p "Argument --autorun required: " autorun
        case "$autorun" in
            cron|systemd) ;;
            *) autorun=
        esac
    done

fi
code 'autorun="'$autorun'"'
case `uname` in
    CYGWIN*) is_cygwin=1 ;;
    *) is_cygwin= ;;
esac
code 'is_cygwin="'$is_cygwin'"'
____

if [ -z "$root_sure" ];then
    chapter Mengecek '`'Run as Administrator'`'.
    admin=$(/usr/bin/id -G | /usr/bin/grep -Eq '\<544\>' && echo yes || echo no)
    if [[ "$admin" == 'yes' ]]; then
        __ Run as admin.;
    else
        __ Run as Standard user.
    fi
    ____
fi

chapter Memeriksa full path dari command '`'ssh-keep-alive-symlink-reference.sh'`'.
full_path=$(command -v ssh-keep-alive-symlink-reference.sh)
code 'full_path="'$full_path'"'
____

filename_string="${prefix_directory}/${pattern}.sh"
shell_script="$filename_string"
chapter Memeriksa file '`'$filename_string'`'
isFileExists "$filename_string"
if [ -n "$notfound" ];then
    create=1
else
    if [ -h "$filename_string" ];then
        __; _, Mengecek apakah file merujuk ke '`'ssh-keep-alive-symlink-reference.sh'`':
        _dereference=$(stat --cached=never "$filename_string" -c %N)
        match="'$filename_string' -> '$full_path'"
        if [[ "$_dereference" == "$match" ]];then
            _, ' 'Merujuk.; _.
        else
            _, ' 'Tidak Merujuk.; _.
            __ Melakukan backup.
            backupFile move "$filename_string"
            create=1
        fi
    else
        __ File bukan merupakan symbolic link.
        __ Melakukan backup.
        backupFile move "$filename_string"
        create=1
    fi
fi
____

if [ -n "$create" ];then
    chapter Membuat symbolic link '`'$filename_string'`'.
    code ln -s \"$full_path\" \"$filename_string\"
    ln -s "$full_path" "$filename_string"
    __ Verifikasi
    if [ -h "$filename_string" ];then
        _dereference=$(stat --cached=never "$filename_string" -c %N)
        match="'$filename_string' -> '$full_path'"
        if [[ "$_dereference" == "$match" ]];then
            __; green Symbolic link berhasil dibuat.; _.
        else
            __; red Symbolic link gagal dibuat.; x
        fi
    fi
    ____
fi

if [[ "$autorun" == cron && -n "$is_cygwin" ]];then
    ## Cron pada Cygwin hanya memberikan informasi PATH sbb:
    # /bin:/cygdrive/c/Windows/system32:# /cygdrive/c/Windows:
    # /cygdrive/c/Windows/System32/Wbem:
    # /cygdrive/c/Windows/System32/WindowsPowerShell/v1.0:
    # /cygdrive/c/Windows/System32/OpenSSH:
    # /cygdrive/c/Windows/system32/config/systemprofile/AppData/Local/Microsoft/WindowsApps
    # Sehingga perlu kita edit sedikit.
    # Agar PATH juga terdapat /usr/local/bin:/usr/bin atau
    # /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    chapter Mengecek '$PATH' pada crontab.
    line='PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:$PATH'
    code '"'"$line"'"'
    crontab=$(crontab -l | sed '/^#.*$/d')
    notfound=
    if grep -q -F "$line" <<< "$crontab"; then
        __ '$PATH' pada crontab ditemukan.
    else
        __ '$PATH' pada crontab tidak ditemukan.
        notfound=1
    fi
    ____

    if [ -n "$notfound" ];then
        chapter Menambah '$PATH' pada crontab.
        if [ -n "$is_cygwin" ];then
            crontab=$(crontab -l | sed '/^# DO NOT EDIT THIS FILE/,+2d')
        else
            crontab=$(crontab -l)
        fi
        (echo "$line"; echo "$crontab" ) | crontab -
        crontab=$(crontab -l | sed '/^#.*$/d')
        if grep -q -F "$line" <<< "$crontab"; then
            __; green '$PATH' pada crontab ditemukan.; _.
        else
            __; red '$PATH' pada crontab tidak ditemukan.; x
        fi
        ____
    fi
fi
if [[ "$autorun" == cron ]];then
    if [[ "$PREFIX_DIRECTORY" == '/usr/local' ]];then
        filename_string="/var/log/${pattern}.log"
    else
        filename_string="${prefix_directory}/${pattern}.log"
    fi
    chapter Mengecek file log '`'$filename_string'`'
    isFileExists "$filename_string"
    if [ -n "$notfound" ];then
        __ Membuat file.
        touch "$filename_string"
        fileMustExists "$filename_string"
    fi
    ____

    chapter Mengecek cronjob.
    [ -n "$timeout_trigger_command" ] && is_timeout_trigger_command=' '"\"$timeout_trigger_command\"" || is_timeout_trigger_command=''
    line='@reboot '"${shell_script}${is_timeout_trigger_command}"' --daemon --tunnel >> '"${filename_string}"
    code '"'"$line"'"'
    crontab=$(crontab -l | sed '/^#.*$/d')
    notfound=
    if grep -q -F "$line" <<< "$crontab"; then
        __ Cronjob ditemukan
    else
        __ Cronjob tidak ditemukan
        notfound=1
    fi
    ____

    if [ -n "$notfound" ];then
        chapter Menambah cronjob.
        if [ -n "$is_cygwin" ];then
            crontab=$(crontab -l | sed '/^# DO NOT EDIT THIS FILE/,+2d')
        else
            crontab=$(crontab -l)
        fi
        (echo "$crontab"; echo "$line") | crontab -
        crontab=$(crontab -l | sed '/^#.*$/d')
        if grep -q -F "$line" <<< "$crontab"; then
            __; green Cronjob ditemukan; _.
        else
            __; red Cronjob tidak ditemukan; x
        fi
        ____
    fi

    chapter Dump crontab.
    code crontab -l
    e $'\n'; crontab -l
    ____
fi

if [[ "$autorun" == systemd ]];then
    service_name="custom-${pattern}"
    service_name="${service_name//,/-}"
    service_name="${service_name//./--}"
    filename_string="/etc/systemd/system/${service_name}.service"
    chapter Mengecek file service '`'$filename_string'`'
    isFileExists "$filename_string"
    if [ -n "$notfound" ];then
        __ Membuat file.
        string=$(cat << 'EOF'
[Unit]
After = network.service

[Service]
ExecStart= __SHELL_SCRIPT__ --tunnel

[Install]
WantedBy = default.target
EOF
        )
        string=$(sed "s|__SHELL_SCRIPT__|$shell_script|" <<< "$string")
        echo "$string" > "$filename_string"
        fileMustExists "$filename_string"
    fi
    ____

    chapter Mengecek ActiveState service '`'$service_name'`'.
    msg=$(systemctl show "$service_name" --no-page | grep ActiveState | grep -o -P "^ActiveState=\K(\S+)")
    restart=
    if [[ -z "$msg" ]];then
        __; red Service '`'$service_name'`' tidak ditemukan.; x
    elif [[ "$msg"  == 'active' ]];then
        __ Service '`'$service_name'`' active.
    else
        __ Service ActiveState '`'$service_name'`': $msg.
        restart=1
    fi
    ____

    if [ -n "$restart" ];then
        chapter Menjalankan service '`'$service_name'`'.
        code systemctl enable --now $service_name
        systemctl enable --now $service_name
        msg=$(systemctl show "$service_name" --no-page | grep ActiveState | grep -o -P "ActiveState=\K(\S+)")
        if [[ $msg == 'active' ]];then
            __; green Berhasil activated.; _.
        else
            __; red Gagal activated.; _.
            __ ActiveState state: $msg.
            exit
        fi
        ____
    fi

    chapter Dump service.
    code systemctl status $service_name --no-pager
    systemctl status $service_name --no-pager
    ____
fi

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
# --pattern
# --timeout-trigger-command
# --autorun
# )
# MULTIVALUE=(
# )
# FLAG_VALUE=(
# )
# CSV=(
# )
# EOF
# clear
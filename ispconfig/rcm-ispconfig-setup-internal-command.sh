#!/bin/bash

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --fast) fast=1; shift ;;
        --ispconfig-version=*) ispconfig_version="${1#*=}"; shift ;;
        --ispconfig-version) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then ispconfig_version="$2"; shift; fi; shift ;;
        --phpmyadmin-version=*) phpmyadmin_version="${1#*=}"; shift ;;
        --phpmyadmin-version) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then phpmyadmin_version="$2"; shift; fi; shift ;;
        --root-sure) root_sure=1; shift ;;
        --roundcube-version=*) roundcube_version="${1#*=}"; shift ;;
        --roundcube-version) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then roundcube_version="$2"; shift; fi; shift ;;
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
    echo '0.11.1'
}
printHelp() {
    title RCM ISPConfig Setup
    _ 'Variation '; yellow Internal Command; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-ispconfig-setup-internal-command [options]

Options:
   --phpmyadmin-version
        Set the version of PHPMyAdmin
   --roundcube-version
        Set the version of RoundCube
   --ispconfig-version
        Set the version of ISPConfig.

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
   ISPCONFIG_INSTALL_DIR
        Default to /usr/local/ispconfig
   ISPCONFIG_DB_USER_HOST
        Default to localhost
   ISPCONFIG_REMOTE_USER_ROOT
        Default to root
   ISPCONFIG_FQDN_LOCALHOST
        Default to ispconfig.localhost

Dependency:
   mysql
   pwgen
   php
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Dependency.
while IFS= read -r line; do
    [[ -z "$line" ]] || command -v "${line}" >/dev/null || { echo -e "\e[91m""Unable to proceed, "'`'"${line}"'`'" command not found." "\e[39m"; exit 1; }
done <<< `printHelp 2>/dev/null | sed -n '/^Dependency:/,$p' | sed -n '2,/^\s*$/p' | sed 's/^ *//g'`

# Functions.
databaseCredentialIspconfig() {
    if [ -f /usr/local/share/ispconfig/credential/database ];then
        local ISPCONFIG_DB_NAME ISPCONFIG_DB_USER ISPCONFIG_DB_USER_PASSWORD
        . /usr/local/share/ispconfig/credential/database
        ispconfig_db_name=$ISPCONFIG_DB_NAME
        ispconfig_db_user=$ISPCONFIG_DB_USER
        ispconfig_db_user_password=$ISPCONFIG_DB_USER_PASSWORD
    else
        ispconfig_db_user_password=$(pwgen -s 32 -1)
        mkdir -p /usr/local/share/ispconfig/credential
        cat << EOF > /usr/local/share/ispconfig/credential/database
ISPCONFIG_DB_USER_PASSWORD=$ispconfig_db_user_password
EOF
        chmod 0500 /usr/local/share/ispconfig/credential
        chmod 0400 /usr/local/share/ispconfig/credential/database
    fi
}
backupFile() {
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
isFileExists() {
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
getRemoteUserIdIspconfigByRemoteUsername() {
    # Get the remote_userid from table remote_user in ispconfig database.
    #
    # Globals:
    #   ispconfig_db_user, ispconfig_db_user_password,
    #   ispconfig_db_user_host, ispconfig_db_name
    #
    # Arguments:
    #   $1: Filter by remote_username.
    #
    # Output:
    #   Write remote_userid to stdout.
    local remote_username="$1"
    local sql="SELECT remote_userid FROM remote_user WHERE remote_username = '$remote_username';"
    local u="$ispconfig_db_user"
    local p="$ispconfig_db_user_password"
    local remote_userid=$(mysql \
        --defaults-extra-file=<(printf "[client]\nuser = %s\npassword = %s" "$u" "$p") \
        -h "$ispconfig_db_user_host" "$ispconfig_db_name" -r -N -s -e "$sql"
    )
    echo "$remote_userid"
}
insertRemoteUsernameIspconfig() {
    local remote_username="$1"
    local _remote_password="$2"
    local _remote_functions="$3"
    CONTENT=$(cat <<- EOF
require '${ispconfig_install_dir}/interface/lib/classes/auth.inc.php';
echo (new auth)->crypt_password('$_remote_password');
EOF
    )
    local remote_password=$(php -r "$CONTENT")
    local remote_functions=$(tr '\n' ';' <<< "$_remote_functions")
    local sql="INSERT INTO remote_user
(sys_userid, sys_groupid, sys_perm_user, sys_perm_group, sys_perm_other, remote_username, remote_password, remote_access, remote_ips, remote_functions)
VALUES
(1, 1, 'riud', 'riud', '', '$remote_username', '$remote_password', 'y', '127.0.0.1', '$remote_functions');"
    local u="$ispconfig_db_user"
    local p="$ispconfig_db_user_password"
    mysql --defaults-extra-file=<(printf "[client]\nuser = %s\npassword = %s" "$u" "$p") \
        -h "$ispconfig_db_user_host" "$ispconfig_db_name" -e "$sql"
    remote_userid=$(getRemoteUserIdIspconfigByRemoteUsername "$remote_username")
    if [ -n "$remote_userid" ];then
        return 0
    fi
    return 1
}
isRemoteUsernameIspconfigExist() {
    # Insert the remote_username to table remote_user in ispconfig database.
    #
    # Globals:
    #   Used: ispconfig_install_dir
    #         ispconfig_db_user_host
    #         ispconfig_db_user
    #         ispconfig_db_name
    #         ispconfig_db_user_password
    #   Modified: remote_userid
    #
    # Arguments:
    #   $1: remote_username
    #   $2: remote_password
    #   $3: remote_functions
    #
    # Return:
    #   0 if exists.
    #   1 if not exists.
    local remote_username="$1"
    remote_userid=$(getRemoteUserIdIspconfigByRemoteUsername "$remote_username")
    if [ -n "$remote_userid" ];then
        return 0
    fi
    return 1
}
remoteUserCredentialIspconfig() {
    # Check if the remote_username from table remote_user exists in ispconfig database.
    #
    # Globals:
    #   Modified: remote_userid
    #
    # Arguments:
    #   $1: remote_username to be checked.
    #
    # Return:
    #   0 if exists.
    #   1 if not exists.
    local user="$1"
    if [ -f /usr/local/share/ispconfig/credential/remote/$user ];then
        local ISPCONFIG_REMOTE_USER_PASSWORD
        . /usr/local/share/ispconfig/credential/remote/$user
        ispconfig_remote_user_password=$ISPCONFIG_REMOTE_USER_PASSWORD
    else
        ispconfig_remote_user_password=$(pwgen -s 32 -1)
        mkdir -p /usr/local/share/ispconfig/credential/remote
        cat << EOF > /usr/local/share/ispconfig/credential/remote/$user
ISPCONFIG_REMOTE_USER_PASSWORD=$ispconfig_remote_user_password
EOF
        chmod 0500 /usr/local/share/ispconfig/credential
        chmod 0500 /usr/local/share/ispconfig/credential/remote
        chmod 0400 /usr/local/share/ispconfig/credential/remote/$user
    fi
}

# Title.
title rcm-ispconfig-setup-internal-command
____

# Requirement, validate, and populate value.
chapter Dump variable.
ISPCONFIG_INSTALL_DIR=${ISPCONFIG_INSTALL_DIR:=/usr/local/ispconfig}
code 'ISPCONFIG_INSTALL_DIR="'$ISPCONFIG_INSTALL_DIR'"'
ISPCONFIG_DB_USER_HOST=${ISPCONFIG_DB_USER_HOST:=localhost}
code 'ISPCONFIG_DB_USER_HOST="'$ISPCONFIG_DB_USER_HOST'"'
ISPCONFIG_REMOTE_USER_ROOT=${ISPCONFIG_REMOTE_USER_ROOT:=root}
code 'ISPCONFIG_REMOTE_USER_ROOT="'$ISPCONFIG_REMOTE_USER_ROOT'"'
ISPCONFIG_FQDN_LOCALHOST=${ISPCONFIG_FQDN_LOCALHOST:=ispconfig.localhost}
code 'ISPCONFIG_FQDN_LOCALHOST="'$ISPCONFIG_FQDN_LOCALHOST'"'
if [ -z "$phpmyadmin_version" ];then
    error "Argument --phpmyadmin-version required."; x
fi
code 'phpmyadmin_version="'$phpmyadmin_version'"'
if [ -z "$roundcube_version" ];then
    error "Argument --roundcube-version required."; x
fi
code 'roundcube_version="'$roundcube_version'"'
if [ -z "$ispconfig_version" ];then
    error "Argument --ispconfig-version required."; x
fi
code 'ispconfig_version="'$ispconfig_version'"'
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

chapter Dump variable of ISPConfig Credential
databaseCredentialIspconfig
ispconfig_db_user_host="$ISPCONFIG_DB_USER_HOST"
code ispconfig_db_user="$ispconfig_db_user"
code ispconfig_db_user_host="$ispconfig_db_user_host"
code ispconfig_db_user_password="$ispconfig_db_user_password"
code ispconfig_db_name="$ispconfig_db_name"
_ispconfig_db_user=$(php -r "include '$ISPCONFIG_INSTALL_DIR/interface/lib/config.inc.php';echo DB_USER;")
_ispconfig_db_user_password=$(php -r "include '$ISPCONFIG_INSTALL_DIR/interface/lib/config.inc.php';echo DB_PASSWORD;")
_ispconfig_db_user_host=$(php -r "include '$ISPCONFIG_INSTALL_DIR/interface/lib/config.inc.php';echo DB_HOST;")
_ispconfig_db_name=$(php -r "include '$ISPCONFIG_INSTALL_DIR/interface/lib/config.inc.php';echo DB_DATABASE;")
has_different=
for string in ispconfig_db_name ispconfig_db_user ispconfig_db_user_host ispconfig_db_user_password
do
    parameter=$string
    parameter_from_shell=${!string}
    string="_${string}"
    parameter_from_php=${!string}
    if [[ ! "$parameter_from_shell" == "$parameter_from_php" ]];then
        __ Different from PHP Scripts found.
        __; echo -n Value of '`'"$parameter"'`' from shell:' '
        echo "$parameter_from_shell"
        __; echo -n Value of '`'"$parameter"'`' from PHP script:' '
        echo "$parameter_from_php"
        has_different=1
    fi
done
if [ -n "$has_different" ];then
    __; red Terdapat perbedaan value.; x
fi
____

chapter Mengecek ISPConfig PHP scripts.
isFileExists /usr/local/share/ispconfig/scripts/soap_config.php
____

if [ -n "$notfound" ];then
    chapter Copy ISPConfig PHP scripts.
    if [ ! -d /tmp/ispconfig3_install/remoting_client/examples ];then
        __ Mendownload ISPConfig
        cd /tmp
        if [ ! -f /tmp/ISPConfig-$ispconfig_version.tar.gz ];then
            wget https://www.ispconfig.org/downloads/ISPConfig-$ispconfig_version.tar.gz
        fi
        fileMustExists /tmp/ISPConfig-$ispconfig_version.tar.gz
        if [ ! -f /tmp/ispconfig3_install/install/install.php ];then
            tar xfz ISPConfig-$ispconfig_version.tar.gz
        fi
        fileMustExists /tmp/ispconfig3_install/install/install.php
    fi
    mkdir -p /usr/local/share/ispconfig/scripts
    cp -f /tmp/ispconfig3_install/remoting_client/examples/* /usr/local/share/ispconfig/scripts
    fileMustExists /usr/local/share/ispconfig/scripts/soap_config.php
     __ Memodifikasi scripts.
    cd /usr/local/share/ispconfig/scripts
    find * -maxdepth 1 -type f \
    -not -path 'soap_config.php' \
    -not -path 'rest_example.php' \
    -not -path 'ispc-import-csv-email.php' | while read line; do
    sed -i -e 's,^?>$,echo PHP_EOL;,' \
           -e "s,'<br />',PHP_EOL," \
           -e 's,"<br>",PHP_EOL,' \
           -e "s,<br />','.PHP_EOL," \
           -e "s,die('SOAP Error: '.\$e->getMessage());,die('SOAP Error: '.\$e->getMessage().PHP_EOL);," \
           -e "s,\$client_id = 1;,\$client_id = 0;," \
    ${line}
    done
    ____
fi

chapter Populate variable.
phpmyadmin_install_dir=/usr/local/share/phpmyadmin/"$phpmyadmin_version"
[ -d "$phpmyadmin_install_dir" ] || { red Directory not found: "$phpmyadmin_install_dir"; x; }
roundcube_install_dir=/usr/local/share/roundcube/"$roundcube_version"
[ -d "$roundcube_install_dir" ] || { red Directory not found: "$roundcube_install_dir"; x; }
scripts_dir=/usr/local/share/ispconfig/scripts
[ -d "$scripts_dir" ] || { red Directory not found: "$scripts_dir"; x; }
code phpmyadmin_install_dir="$phpmyadmin_install_dir"
code roundcube_install_dir="$roundcube_install_dir"
code scripts_dir="$scripts_dir"
____

chapter Mengecek '`'ispconfig.sh'`' command.
isFileExists /usr/local/share/ispconfig/bin/ispconfig.sh
if command -v "ispconfig.sh" >/dev/null;then
    __ Command found.
else
    __ Command not found.
    notfound=1
fi
____

if [ -n "$notfound" ];then
    chapter Create ISPConfig Command '`'ispconfig.sh'`'.
    mkdir -p /usr/local/share/ispconfig/bin
    cat << 'EOF' > /usr/local/share/ispconfig/bin/ispconfig.sh
#!/bin/bash
s=__SCRIPTS_DIR__
Usage() {
    echo -e "Usage: ispconfig.sh \e[33m<command>\e[0m [<args>]" >&2
    echo >&2
    echo "Available commands: " >&2
    echo -e '   \e[33mls\e[0m       \e[35m[<prefix>]\e[0m   List PHP Script. Filter by prefix.' >&2
    echo -e '   \e[33mmktemp\e[0m   \e[35m<script>\e[0m     Create a temporary file based on Script.' >&2
    echo -e '   \e[33meditor\e[0m   \e[35m<script>\e[0m     Edit PHP Script.' >&2
    echo -e '   \e[33mphp\e[0m      \e[35m<script>\e[0m     Execute PHP Script.' >&2
    echo -e '   \e[33mcat\e[0m      \e[35m<script>\e[0m     Get the contents of PHP Script.' >&2
    echo -e '   \e[33mrealpath\e[0m \e[35m<script>\e[0m     Return the real path of PHP Script.' >&2
    echo -e '   \e[33mexport\e[0m                Export some variables.' >&2
    echo >&2
    echo -e 'Command for switch editor: \e[35mupdate-alternatives --config editor\e[0m' >&2
}
if [ -z "$1" ];then
    Usage
else
    case "$1" in
        -h|--help)
            Usage
            ;;
        ls)
            if [ -z "$2" ];then
                ls "$s"
            else
                cd "$s"
                ls "$2"*
            fi
            ;;
        mktemp)
            if [ -f "$s/$2" ];then
                filename="${2%.*}"
                temp=$(mktemp -p "$s" \
                    -t "$filename"_temp_XXXXX.php)
                cd "$s"
                cp "$2" "$temp"
                echo $(basename $temp)
            fi
            ;;
        editor)
            if [ -f "$s/$2" ];then
                editor "$s/$2"
            fi
            ;;
        php)
            if [ -f "$s/$2" ];then
                php "$s/$2"
            fi
            ;;
        cat)
            if [ -f "$s/$2" ];then
                cat "$s/$2"
            fi
            ;;
        realpath)
            if [ -f "$s/$2" ];then
                echo "$s/$2"
            fi
            ;;
        export)
            echo phpmyadmin_install_dir=__PHPMYADMIN_INSTALL_DIR__
            echo roundcube_install_dir=__ROUNDCUBE_INSTALL_DIR__
            echo ispconfig_install_dir=__ISPCONFIG_INSTALL_DIR__
            echo scripts_dir=__SCRIPTS_DIR__
            phpmyadmin_install_dir=__PHPMYADMIN_INSTALL_DIR__
            roundcube_install_dir=__ROUNDCUBE_INSTALL_DIR__
            ispconfig_install_dir=__ISPCONFIG_INSTALL_DIR__
            scripts_dir=__SCRIPTS_DIR__
    esac
fi
EOF
    chmod a+x /usr/local/share/ispconfig/bin/ispconfig.sh
    sed -i 's,__PHPMYADMIN_INSTALL_DIR__,'"${phpmyadmin_install_dir}"',' /usr/local/share/ispconfig/bin/ispconfig.sh
    sed -i 's,__ROUNDCUBE_INSTALL_DIR__,'"${roundcube_install_dir}"',' /usr/local/share/ispconfig/bin/ispconfig.sh
    sed -i 's,__ISPCONFIG_INSTALL_DIR__,'"${ISPCONFIG_INSTALL_DIR}"',' /usr/local/share/ispconfig/bin/ispconfig.sh
    sed -i 's,__SCRIPTS_DIR__,'"${scripts_dir}"',' /usr/local/share/ispconfig/bin/ispconfig.sh
    ln -sf /usr/local/share/ispconfig/bin/ispconfig.sh /usr/local/bin/ispconfig.sh
    if command -v "ispconfig.sh" >/dev/null;then
        __; green Command found.; _.
    else
        __; red Command not found.; x
    fi
    ____
fi

chapter Mengecek '`'ispconfig.sh'`' autocompletion.
isFileExists /etc/profile.d/ispconfig-completion.sh
____

if [ -n "$notfound" ];then
    chapter Create ISPConfig Command '`'ispconfig.sh'`' Autocompletion.
    cat << 'EOF' > /etc/profile.d/ispconfig-completion.sh
#!/bin/bash
_ispconfig_sh() {
    local scripts_dir=|scripts_dir|
    local cur
    cur=${COMP_WORDS[COMP_CWORD]}
    prev=${COMP_WORDS[COMP_CWORD-1]}
    case ${COMP_CWORD} in
        1)
            COMPREPLY=($(compgen -W "ls php editor mktemp cat realpath export" -- ${cur}))
            ;;
        2)
            if [[ "${prev}" == 'export' ]];then
                COMPREPLY=()
            elif [ -z ${cur} ];then
                COMPREPLY=($(ls "$scripts_dir" | awk -F '_' '!x[$1]++{print $1}'))
            else
                words_merge=$(ls "$scripts_dir" | xargs)
                COMPREPLY=($(compgen -W "$words_merge" -- ${cur}))
            fi
            ;;
        *)
            COMPREPLY=()
            ;;
    esac
}
complete -F _ispconfig_sh ispconfig.sh
EOF
    chmod a+x /etc/profile.d/ispconfig-completion.sh
    sed -i 's,|scripts_dir|,'"${scripts_dir}"',' /etc/profile.d/ispconfig-completion.sh
    fileMustExists /etc/profile.d/ispconfig-completion.sh
    ____
fi

chapter Mengecek Remote User ISPConfig '"'$ISPCONFIG_REMOTE_USER_ROOT'"'
notfound=
if isRemoteUsernameIspconfigExist "$ISPCONFIG_REMOTE_USER_ROOT" ;then
    __ Found '(remote_userid:'$remote_userid')'.
else
    __ Not Found.
    notfound=1
fi
____

if [ -n "$notfound" ];then
    chapter Insert Remote User ISPConfig '"'$ISPCONFIG_REMOTE_USER_ROOT'"'
    functions='server_get,server_config_set,get_function_list,client_templates_get_all,server_get_serverid_by_ip,server_ip_get,server_ip_add,server_ip_update,server_ip_delete,system_config_set,system_config_get,config_value_get,config_value_add,config_value_update,config_value_replace,config_value_delete
admin_record_permissions
client_get_id,login,logout,mail_alias_get,mail_fetchmail_add,mail_fetchmail_delete,mail_fetchmail_get,mail_fetchmail_update,mail_policy_get,mail_spamfilter_blacklist_add,mail_spamfilter_blacklist_delete,mail_spamfilter_blacklist_get,mail_spamfilter_blacklist_update,mail_spamfilter_user_add,mail_spamfilter_user_get,mail_spamfilter_user_update,mail_spamfilter_whitelist_add,mail_spamfilter_whitelist_delete,mail_spamfilter_whitelist_get,mail_spamfilter_whitelist_update,mail_user_filter_add,mail_user_filter_delete,mail_user_filter_get,mail_user_filter_update,mail_user_get,mail_user_update,server_get,server_get_app_version
client_get_all,client_get,client_add,client_update,client_delete,client_get_sites_by_user,client_get_by_username,client_get_by_customer_no,client_change_password,client_get_id,client_delete_everything,client_get_emailcontact
domains_domain_get,domains_domain_add,domains_domain_update,domains_domain_delete,domains_get_all_by_user
quota_get_by_user,trafficquota_get_by_user,mailquota_get_by_user,databasequota_get_by_user
mail_domain_get,mail_domain_add,mail_domain_update,mail_domain_delete,mail_domain_set_status,mail_domain_get_by_domain
mail_aliasdomain_get,mail_aliasdomain_add,mail_aliasdomain_update,mail_aliasdomain_delete
mail_mailinglist_get,mail_mailinglist_add,mail_mailinglist_update,mail_mailinglist_delete
mail_user_get,mail_user_add,mail_user_update,mail_user_delete
mail_alias_get,mail_alias_add,mail_alias_update,mail_alias_delete
mail_forward_get,mail_forward_add,mail_forward_update,mail_forward_delete
mail_catchall_get,mail_catchall_add,mail_catchall_update,mail_catchall_delete
mail_transport_get,mail_transport_add,mail_transport_update,mail_transport_delete
mail_relay_get,mail_relay_add,mail_relay_update,mail_relay_delete
mail_whitelist_get,mail_whitelist_add,mail_whitelist_update,mail_whitelist_delete
mail_blacklist_get,mail_blacklist_add,mail_blacklist_update,mail_blacklist_delete
mail_spamfilter_user_get,mail_spamfilter_user_add,mail_spamfilter_user_update,mail_spamfilter_user_delete
mail_policy_get,mail_policy_add,mail_policy_update,mail_policy_delete
mail_fetchmail_get,mail_fetchmail_add,mail_fetchmail_update,mail_fetchmail_delete
mail_spamfilter_whitelist_get,mail_spamfilter_whitelist_add,mail_spamfilter_whitelist_update,mail_spamfilter_whitelist_delete
mail_spamfilter_blacklist_get,mail_spamfilter_blacklist_add,mail_spamfilter_blacklist_update,mail_spamfilter_blacklist_delete
mail_user_filter_get,mail_user_filter_add,mail_user_filter_update,mail_user_filter_delete
mail_user_backup
mail_filter_get,mail_filter_add,mail_filter_update,mail_filter_delete
monitor_jobqueue_count
sites_cron_get,sites_cron_add,sites_cron_update,sites_cron_delete
sites_database_get,sites_database_add,sites_database_update,sites_database_delete, sites_database_get_all_by_user,sites_database_user_get,sites_database_user_add,sites_database_user_update,sites_database_user_delete, sites_database_user_get_all_by_user
sites_web_folder_get,sites_web_folder_add,sites_web_folder_update,sites_web_folder_delete,sites_web_folder_user_get,sites_web_folder_user_add,sites_web_folder_user_update,sites_web_folder_user_delete
sites_ftp_user_get,sites_ftp_user_server_get,sites_ftp_user_add,sites_ftp_user_update,sites_ftp_user_delete
sites_shell_user_get,sites_shell_user_add,sites_shell_user_update,sites_shell_user_delete
sites_web_domain_get,sites_web_domain_add,sites_web_domain_update,sites_web_domain_delete,sites_web_domain_set_status
sites_web_domain_backup
sites_web_aliasdomain_get,sites_web_aliasdomain_add,sites_web_aliasdomain_update,sites_web_aliasdomain_delete
sites_web_subdomain_get,sites_web_subdomain_add,sites_web_subdomain_update,sites_web_subdomain_delete
sites_aps_update_package_list,sites_aps_available_packages_list,sites_aps_change_package_status,sites_aps_install_package,sites_aps_get_package_details,sites_aps_get_package_file,sites_aps_get_package_settings,sites_aps_instance_get,sites_aps_instance_delete
sites_webdav_user_get,sites_webdav_user_add,sites_webdav_user_update,sites_webdav_user_delete
dns_zone_get,dns_zone_get_id,dns_zone_add,dns_zone_update,dns_zone_delete,dns_zone_set_status,dns_templatezone_add
dns_a_get,dns_a_add,dns_a_update,dns_a_delete
dns_aaaa_get,dns_aaaa_add,dns_aaaa_update,dns_aaaa_delete
dns_alias_get,dns_alias_add,dns_alias_update,dns_alias_delete
dns_caa_get,dns_caa_add,dns_caa_update,dns_caa_delete
dns_cname_get,dns_cname_add,dns_cname_update,dns_cname_delete
dns_dname_get,dns_dname_add,dns_dname_update,dns_dname_delete
dns_ds_get,dns_ds_add,dns_ds_update,dns_ds_delete
dns_hinfo_get,dns_hinfo_add,dns_hinfo_update,dns_hinfo_delete
dns_loc_get,dns_loc_add,dns_loc_update,dns_loc_delete
dns_mx_get,dns_mx_add,dns_mx_update,dns_mx_delete
dns_naptr_get,dns_naptr_add,dns_naptr_update,dns_naptr_delete
dns_ns_get,dns_ns_add,dns_ns_update,dns_ns_delete
dns_ptr_get,dns_ptr_add,dns_ptr_update,dns_ptr_delete
dns_rp_get,dns_rp_add,dns_rp_update,dns_rp_delete
dns_srv_get,dns_srv_add,dns_srv_update,dns_srv_delete
dns_sshfp_get,dns_sshfp_add,dns_sshfp_update,dns_sshfp_delete
dns_tlsa_get,dns_tlsa_add,dns_tlsa_update,dns_tlsa_delete
dns_txt_get,dns_txt_add,dns_txt_update,dns_txt_delete
vm_openvz'
    remoteUserCredentialIspconfig $ISPCONFIG_REMOTE_USER_ROOT
    if [[ -z "$ispconfig_remote_user_password" ]];then
        __; red Informasi credentials tidak lengkap: '`'/usr/local/share/ispconfig/credential/remote/$ISPCONFIG_REMOTE_USER_ROOT'`'.; x
    else
        code ispconfig_remote_user_password="$ispconfig_remote_user_password"
    fi
    # Populate Variable.
    . ispconfig.sh export >/dev/null
    code ispconfig_install_dir="$ispconfig_install_dir"
    if insertRemoteUsernameIspconfig  "$ISPCONFIG_REMOTE_USER_ROOT" "$ispconfig_remote_user_password" "$functions" ;then
        __; green Remote username "$ISPCONFIG_REMOTE_USER_ROOT" created '(remote_userid:'$remote_userid')'.; _.
    else
        __; red Remote username "$ISPCONFIG_REMOTE_USER_ROOT" failed to create.; x
    fi
    ____
fi

chapter Mengecek file '`'soap_config.php'`'.
remoteUserCredentialIspconfig $ISPCONFIG_REMOTE_USER_ROOT
if [[ -z "$ispconfig_remote_user_password" ]];then
    __; red Informasi credentials tidak lengkap: '`'/usr/local/share/ispconfig/credential/remote/$ISPCONFIG_REMOTE_USER_ROOT'`'.; x
else
    code ispconfig_remote_user_password="$ispconfig_remote_user_password"
fi
. ispconfig.sh export >/dev/null
code scripts_dir="$scripts_dir"
soap_config="${scripts_dir}/soap_config.php"
php=$(cat <<'EOF'
$args = $_SERVER['argv'];
$mode = $args[1];
$file = $args[2];
$arg_username = $args[3];
$arg_password = $args[4];
$arg_subdomain_localhost = $args[5];
$arg_soap_location = 'http://'.$arg_subdomain_localhost.'/remote/index.php';
$arg_soap_uri = 'http://'.$arg_subdomain_localhost.'/remote/';
// var_dump($mode);
// var_dump($file);
// var_dump($arg_username);
// var_dump($arg_password);
// var_dump($arg_soap_location);
// var_dump($arg_soap_uri);
$append = array();
include($file);
$username = isset($username) ? $username : NULL;
$password = isset($password) ? $password : NULL;
$soap_location = isset($soap_location) ? $soap_location : NULL;
$soap_uri = isset($soap_uri) ? $soap_uri : NULL;
// var_dump('---');
// var_dump($username);
// var_dump($password);
// var_dump($soap_location);
// var_dump($soap_uri);
$is_different = false;
if ($username != $arg_username) {
    $is_different = true;
}
if ($password != $arg_password) {
    $is_different = true;
}
if ($password != $arg_password) {
    $is_different = true;
}
if ($soap_location != $arg_soap_location) {
    $is_different = true;
}
if ($soap_uri != $arg_soap_uri) {
    $is_different = true;
}
switch ($mode) {
    case 'is_different':
        $is_different ? exit(0) : exit(1);
        break;
}
EOF
)
is_different=
if php -r "$php" is_different \
    "$soap_config" \
    $ISPCONFIG_REMOTE_USER_ROOT \
    $ispconfig_remote_user_password \
    $ISPCONFIG_FQDN_LOCALHOST;then
    is_different=1
    __ Diperlukan modifikasi file '`'soap_config.php'`'.
else
    __ File '`'soap_config.php'`' tidak ada perubahan.
fi
____

if [ -n "$is_different" ];then
    chapter Memodifikasi file '`'soap_config.php'`'.
    __ Backup file "$soap_config"
    backupFile move "$soap_config"
    cat <<EOF > "$soap_config"
<?php

\$username = '$ISPCONFIG_REMOTE_USER_ROOT';
\$password = '$ispconfig_remote_user_password';
\$soap_location = 'http://$ISPCONFIG_FQDN_LOCALHOST/remote/index.php';
\$soap_uri = 'http://$ISPCONFIG_FQDN_LOCALHOST/remote/';
EOF
    if php -r "$php" is_different \
        "$soap_config" \
        $ISPCONFIG_REMOTE_USER_ROOT \
        $ispconfig_remote_user_password \
        $ISPCONFIG_FQDN_LOCALHOST;then
        __; red Modifikasi file '`'soap_config.php'`' gagal.; x
    else
        __; green Modifikasi file '`'soap_config.php'`' berhasil.; _.
    fi
    ____
fi

chapter Test Command
code 'ispconfig.sh php login.php'
ispconfig.sh php login.php
____

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
# --phpmyadmin-version
# --roundcube-version
# --ispconfig-version
# )
# FLAG_VALUE=(
# )
# EOF
# clear

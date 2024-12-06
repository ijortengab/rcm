#!/bin/bash

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --fast) fast=1; shift ;;
        --php-version=*) php_version="${1#*=}"; shift ;;
        --php-version) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then php_version="$2"; shift; fi; shift ;;
        --phpmyadmin-version=*) phpmyadmin_version="${1#*=}"; shift ;;
        --phpmyadmin-version) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then phpmyadmin_version="$2"; shift; fi; shift ;;
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
e() { echo -n "$INDENT" >&2; echo -n "$@" >&2; }
_() { echo -n "$INDENT" >&2; echo -n "#" "$@" >&2; }
_,() { echo -n "$@" >&2; }
_.() { echo >&2; }
__() { echo -n "$INDENT" >&2; echo -n "#" '    ' >&2; [ -n "$1" ] && echo "$@" >&2 || echo -n  >&2; }
____() { echo >&2; [ -n "$delay" ] && sleep "$delay"; }

# Functions.
printVersion() {
    echo '0.16.7'
}
printHelp() {
    title RCM PHPMyAdmin Auto-Installer
    _ 'Variation '; yellow Nginx; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << EOF
Usage: rcm-phpmyadmin-autoinstaller-nginx [options]

Options:
   --php-version *
        Set the version of PHP FPM.
   --phpmyadmin-version *
        Set the version of PHPMyAdmin.

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
   PHPMYADMIN_FQDN_LOCALHOST
        Default to phpmyadmin.localhost
   PHPMYADMIN_NGINX_CONFIG_FILE
        Default to phpmyadmin
   MARIADB_PREFIX_MASTER
        Default to /usr/local/share/mariadb
   MARIADB_USERS_CONTAINER_MASTER
        Default to users

Dependency:
   php
   curl
   rcm-nginx-virtual-host-autocreate-php
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Title.
title rcm-phpmyadmin-autoinstaller-nginx
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

# Dependency.
while IFS= read -r line; do
    [[ -z "$line" ]] || command -v `cut -d: -f1 <<< "${line}"` >/dev/null || { error Unable to proceed, command not found: '`'$line'`'.; x; }
done <<< `printHelp 2>/dev/null | sed -n '/^Dependency:/,$p' | sed -n '2,/^\s*$/p' | sed 's/^ *//g'`

# Functions.
databaseCredentialPhpmyadmin() {
    local DB_USER DB_USER_PASSWORD
    __ Memerlukan file '`'"${MARIADB_PREFIX_MASTER}/${MARIADB_USERS_CONTAINER_MASTER}/${db_user}"'`'
    isFileExists "${MARIADB_PREFIX_MASTER}/${MARIADB_USERS_CONTAINER_MASTER}/${db_user}"
    [ -n "$notfound" ] && fileMustExists "${MARIADB_PREFIX_MASTER}/${MARIADB_USERS_CONTAINER_MASTER}/${db_user}"
    # Populate.
    . "${MARIADB_PREFIX_MASTER}/${MARIADB_USERS_CONTAINER_MASTER}/${db_user}"
    db_user=$DB_USER
    db_user_password=$DB_USER_PASSWORD
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
backupDir() {
    local oldpath="$1" i newpath
    i=1
    newpath="${oldpath}.${i}"
    if [ -e "$newpath" ]; then
        let i++
        newpath="${oldpath}.${i}"
        while [ -e "$newpath" ] ; do
            let i++
            newpath="${oldpath}.${i}"
        done
    fi
    mv "$oldpath" "$newpath"
}
dirMustExists() {
    # global used:
    # global modified:
    # function used: __, success, error, x
    if [ -d "$1" ];then
        __; green Direktori '`'$(basename "$1")'`' ditemukan.; _.
    else
        __; red Direktori '`'$(basename "$1")'`' tidak ditemukan.; x
    fi
}
isDirExists() {
    # global used:
    # global modified: found, notfound
    # function used: __
    found=
    notfound=
    if [ -d "$1" ];then
        __ Direktori '`'$(basename "$1")'`' ditemukan.
        found=1
    else
        __ Direktori '`'$(basename "$1")'`' tidak ditemukan.
        notfound=1
    fi
}
link_symbolic() {
    local source="$1"
    local target="$2"
    local sudo="$3"
    local source_mode="$4"
    local create
    [ "$sudo" == - ] && sudo=
    [ "$source_mode" == absolute ] || source_mode=
    [ -e "$source" ] || { error Source not exist: $source.; x; }
    [ -f "$source" ] || { error Source exists but not file: $source.; x; }
    [ -n "$target" ] || { error Target not defined.; x; }
    [[ $(type -t backupFile) == function ]] || { error Function backupFile not found.; x; }
    [[ $(type -t backupDir) == function ]] || { error Function backupDir not found.; x; }
    chapter Membuat symbolic link.
    __ source: '`'$source'`'
    __ target: '`'$target'`'
    if [ -f "$target" ];then
        if [ -h "$target" ];then
            __ Path target saat ini sudah merupakan file symbolic link: '`'$target'`'
            local _readlink=$(readlink "$target")
            __; magenta readlink "$target"; _.
            _ $_readlink; _.
            if [[ "$_readlink" =~ ^[^/\.] ]];then
                local target_parent=$(dirname "$target")
                local _dereference="${target_parent}/${_readlink}"
            elif [[ "$_readlink" =~ ^[\.] ]];then
                local target_parent=$(dirname "$target")
                local _dereference="${target_parent}/${_readlink}"
                _dereference=$(realpath -s "$_dereference")
            else
                _dereference="$_readlink"
            fi
            __; _, Mengecek apakah link merujuk ke '`'$source'`':' '
            if [[ "$source" == "$_dereference" ]];then
                _, merujuk.; _.
            else
                _, tidak merujuk.; _.
                __ Melakukan backup.
                backupFile move "$target"
                create=1
            fi
        else
            __ Melakukan backup regular file: '`'"$target"'`'.
            backupFile move "$target"
            create=1
        fi
    elif [ -d "$target" ];then
        __ Melakukan backup direktori: '`'"$target"'`'.
        backupDir "$target"
        create=1
    else
        create=1
    fi
    if [ -n "$create" ];then
        __ Membuat symbolic link: '`'$target'`'.
        local target_parent=$(dirname "$target")
        code mkdir -p "$target_parent"
        mkdir -p "$target_parent"
        if [ -z "$source_mode" ];then
            source=$(realpath -s --relative-to="$target_parent" "$source")
        fi
        if [ -n "$sudo" ];then
            code sudo -u '"'$sudo'"' ln -s '"'$source'"' '"'$target'"'
            sudo -u "$sudo" ln -s "$source" "$target"
        else
            code ln -s '"'$source'"' '"'$target'"'
            ln -s "$source" "$target"
        fi
        if [ $? -eq 0 ];then
            __; green Symbolic link berhasil dibuat.; _.
        else
            __; red Symbolic link gagal dibuat.; x
        fi
    fi
    ____
}
link_symbolic_dir() {
    local source="$1"
    local target="$2"
    local sudo="$3"
    local source_mode="$4"
    local create
    [ "$sudo" == - ] && sudo=
    [ "$source_mode" == absolute ] || source_mode=
    [ -e "$source" ] || { error Source not exist: $source.; x; }
    [ -d "$source" ] || { error Source exists but not directory: $source.; x; }
    [ -n "$target" ] || { error Target not defined.; x; }
    [[ $(type -t backupFile) == function ]] || { error Function backupFile not found.; x; }
    [[ $(type -t backupDir) == function ]] || { error Function backupDir not found.; x; }
    chapter Membuat symbolic link directory.
    __ source: '`'$source'`'
    __ target: '`'$target'`'
    if [ -d "$target" ];then
        if [ -h "$target" ];then
            __ Path target saat ini sudah merupakan directory symbolic link: '`'$target'`'
            local _readlink=$(readlink "$target")
            __; magenta readlink "$target"; _.
            _ $_readlink; _.
            if [[ "$_readlink" =~ ^[^/\.] ]];then
                local target_parent=$(dirname "$target")
                local _dereference="${target_parent}/${_readlink}"
            elif [[ "$_readlink" =~ ^[\.] ]];then
                local target_parent=$(dirname "$target")
                local _dereference="${target_parent}/${_readlink}"
                _dereference=$(realpath -s "$_dereference")
            else
                _dereference="$_readlink"
            fi
            __; _, Mengecek apakah link merujuk ke '`'$source'`':' '
            if [[ "$source" == "$_dereference" ]];then
                _, merujuk.; _.
            else
                _, tidak merujuk.; _.
                __ Melakukan backup.
                backupFile move "$target"
                create=1
            fi
        else
            __ Melakukan backup regular direktori: '`'"$target"'`'.
            backupDir "$target"
            create=1
        fi
    elif [ -f "$target" ];then
        __ Melakukan backup file: '`'"$target"'`'.
        backupFile move "$target"
        create=1
    else
        create=1
    fi
    if [ -n "$create" ];then
        __ Membuat symbolic link: '`'$target'`'.
        local target_parent=$(dirname "$target")
        code mkdir -p "$target_parent"
        mkdir -p "$target_parent"
        if [ -z "$source_mode" ];then
            source=$(realpath -s --relative-to="$target_parent" "$source")
        fi
        if [ -n "$sudo" ];then
            code sudo -u '"'$sudo'"' ln -s '"'$source'"' '"'$target'"'
            sudo -u "$sudo" ln -s "$source" "$target"
        else
            code ln -s '"'$source'"' '"'$target'"'
            ln -s "$source" "$target"
        fi
        if [ $? -eq 0 ];then
            __; green Symbolic link berhasil dibuat.; _.
        else
            __; red Symbolic link gagal dibuat.; x
        fi
    fi
    ____
}

# Requirement, validate, and populate value.
chapter Dump variable.
[ -n "$fast" ] && isfast=' --fast' || isfast=''
PHPMYADMIN_FQDN_LOCALHOST=${PHPMYADMIN_FQDN_LOCALHOST:=phpmyadmin.localhost}
code 'PHPMYADMIN_FQDN_LOCALHOST="'$PHPMYADMIN_FQDN_LOCALHOST'"'
PHPMYADMIN_NGINX_CONFIG_FILE=${PHPMYADMIN_NGINX_CONFIG_FILE:=phpmyadmin}
code 'PHPMYADMIN_NGINX_CONFIG_FILE="'$PHPMYADMIN_NGINX_CONFIG_FILE'"'
MARIADB_PREFIX_MASTER=${MARIADB_PREFIX_MASTER:=/usr/local/share/mariadb}
code 'MARIADB_PREFIX_MASTER="'$MARIADB_PREFIX_MASTER'"'
MARIADB_USERS_CONTAINER_MASTER=${MARIADB_USERS_CONTAINER_MASTER:=users}
code 'MARIADB_USERS_CONTAINER_MASTER="'$MARIADB_USERS_CONTAINER_MASTER'"'
delay=.5; [ -n "$fast" ] && unset delay
if [ -z "$phpmyadmin_version" ];then
    error "Argument --phpmyadmin-version required."; x
fi
code 'phpmyadmin_version="'$phpmyadmin_version'"'
if [ -z "$php_version" ];then
    error "Argument --php-version required."; x
fi
code 'php_version="'$php_version'"'
nginx_user=
conf_nginx=`command -v nginx > /dev/null && command -v nginx > /dev/null && nginx -V 2>&1 | grep -o -P -- '--conf-path=\K(\S+)'`
if [ -f "$conf_nginx" ];then
    nginx_user=`grep -o -P '^user\s+\K([^;]+)' "$conf_nginx"`
fi
code 'nginx_user="'$nginx_user'"'
if [ -z "$nginx_user" ];then
    error "Variable \$nginx_user failed to populate."; x
fi
php_fpm_user="$nginx_user"
code 'php_fpm_user="'$php_fpm_user'"'
prefix=$(getent passwd "$php_fpm_user" | cut -d: -f6 )
code 'prefix="'$prefix'"'
project_container="$PHPMYADMIN_FQDN_LOCALHOST"
code 'project_container="'$project_container'"'
php_project_name=www
code 'php_project_name="'$php_project_name'"'
mariadb_project_name=phpmyadmin
code 'mariadb_project_name="'$mariadb_project_name'"'
root="$prefix/${project_container}/web"
code 'root="'$root'"'
root_source="$prefix/${project_container}/${phpmyadmin_version}"
code 'root_source="'$root_source'"'
____

target_project_container="${prefix}/${project_container}"
chapter Mengecek direktori project container '`'$target_project_container'`'.
isDirExists "$target_project_container"
____

if [ -n "$notfound" ];then
    chapter Membuat direktori project container.
    code mkdir -p '"'$target_project_container'"'
    code chown $php_fpm_user:$php_fpm_user '"'$target_project_container'"'
    mkdir -p "$target_project_container"
    chown $php_fpm_user:$php_fpm_user "$target_project_container"
    dirMustExists "$target_project_container"
    ____
fi

chapter Prepare arguments.
____; socket_filename=$(INDENT+="    " rcm-php-fpm-setup-project-config $isfast --root-sure --php-version="$php_version" --php-fpm-user="$php_fpm_user" --project-name="$php_project_name" get listen)
if [ -z "$socket_filename" ];then
    __; red Socket Filename of PHP-FPM not found.; x
fi
code socket_filename="$socket_filename"
code root="$root"
filename="$PHPMYADMIN_NGINX_CONFIG_FILE"
code filename="$filename"
url_scheme=http
url_port=80
url_host="$PHPMYADMIN_FQDN_LOCALHOST"
code 'url_scheme="'$url_scheme'"'
code 'url_host="'$url_host'"'
code 'url_port="'$url_port'"'
____

INDENT+="    " \
rcm-nginx-virtual-host-autocreate-php $isfast --root-sure \
    --root="$root" \
    --filename="$filename" \
    --fastcgi-pass="unix:${socket_filename}" \
    --url-host="$url_host" \
    --url-scheme="$url_scheme" \
    --url-port="$url_port" \
    ; [ ! $? -eq 0 ] && x

chapter Mengecek address host local '`'$PHPMYADMIN_FQDN_LOCALHOST'`'.
notfound=
string="$PHPMYADMIN_FQDN_LOCALHOST"
string_quoted=$(sed "s/\./\\\./g" <<< "$string")
if grep -q -E "^\s*127\.0\.0\.1\s+${string_quoted}" /etc/hosts;then
    __ Address Host local terdapat pada local DNS resolver '`'/etc/hosts'`'.
else
    __ Address Host local tidak terdapat pada local DNS resolver '`'/etc/hosts'`'.
    notfound=1
fi
____

if [ -n "$notfound" ];then
    chapter Menambahkan host '`'$PHPMYADMIN_FQDN_LOCALHOST'`'.
    echo "127.0.0.1"$'\t'"${PHPMYADMIN_FQDN_LOCALHOST}" >> /etc/hosts
    if grep -q -E "^\s*127\.0\.0\.1\s+${string_quoted}" /etc/hosts;then
        __; green Address Host local terdapat pada local DNS resolver '`'/etc/hosts'`'.; _.
    else
        __; red Address Host local tidak terdapat pada local DNS resolver '`'/etc/hosts'`'.; x
    fi
    ____
fi

chapter Mengecek file '`'composer.json'`' untuk project '`'phpmyadmin/phpmyadmin'`'
path="${root_source}/composer.json"
isFileExists "$path"
____

if [ -n "$notfound" ];then
    chapter Mendownload PHPMyAdmin
    code sudo -u $php_fpm_user mkdir -p '"'$root_source'"'
    sudo -u $php_fpm_user mkdir -p "$root_source"
    cd $root_source
    __ Mendownload PHPMyAdmin
    path="${root_source}/phpMyAdmin-${phpmyadmin_version}-all-languages.tar.gz"
    isFileExists "$path"
    if [ -n "$notfound" ];then
        sudo -u $php_fpm_user wget "https://files.phpmyadmin.net/phpMyAdmin/${phpmyadmin_version}/phpMyAdmin-${phpmyadmin_version}-all-languages.tar.gz"
        fileMustExists "$path"
    fi
    [ -f "$path" ] || fileMustExists "$path"
    __ Extract File.
    path_tar_gz="$path"
    path="${root_source}/phpMyAdmin-${phpmyadmin_version}-all-languages/composer.json"
    isFileExists "$path"
    if [ -n "$notfound" ];then
        code sudo -u $php_fpm_user tar xfz "$path_tar_gz"
        sudo -u $php_fpm_user tar xfz "$path_tar_gz"
        fileMustExists "$path"
        __ Memindahkan hasil download ke parent.
        code sudo -u $php_fpm_user mv "$path_tar_gz" -t ..
        sudo -u $php_fpm_user mv "$path_tar_gz" -t ..
    fi
    [ -f "$path" ] || fileMustExists "$path"
    __ Memindahkan codebase.
    code mv "${root_source}/phpMyAdmin-${phpmyadmin_version}-all-languages/"'*' -t '"'$root_source'"'
    code mv "${root_source}/phpMyAdmin-${phpmyadmin_version}-all-languages/"'.[!.]*' -t '"'$root_source'"'
    code rmdir "${root_source}/phpMyAdmin-${phpmyadmin_version}-all-languages"
    mv "${root_source}/phpMyAdmin-${phpmyadmin_version}-all-languages/"* -t "$root_source"
    mv "${root_source}/phpMyAdmin-${phpmyadmin_version}-all-languages/".[!.]* -t "$root_source"
    rmdir "${root_source}/phpMyAdmin-${phpmyadmin_version}-all-languages"
    path="${root_source}/composer.json"
    fileMustExists "$path"
    cd - >/dev/null
    ____
fi
[ -f "$path" ] || fileMustExists "$path"

source="$root_source"
target="$root"
link_symbolic_dir "$source" "$target" "$php_fpm_user"

chapter Mengecek file konfigurasi PHPMyAdmin.
path="${root_source}/config.inc.php"
isFileExists "$path"
if [ -n "$notfound" ];then
    source="${root_source}/config.sample.inc.php"
    fileMustExists "$source"
    code sudo -u $php_fpm_user cp "$source" "$path"
    sudo -u $php_fpm_user cp "$source" "$path"
    fileMustExists "$path"
fi
[ -f "$path" ] || fileMustExists "$path"
____

INDENT+="    " \
rcm-mariadb-setup-project-database $isfast --root-sure \
    --project-name="$mariadb_project_name" \
    ; [ ! $? -eq 0 ] && x

chapter Prepare arguments.
db_name="$mariadb_project_name"
db_user="$mariadb_project_name"
code 'db_name="'$db_name'"'
code 'db_user="'$db_user'"'
databaseCredentialPhpmyadmin
code 'db_user_password="'$db_user_password'"'
db_user_host=localhost
code 'db_user_host="'$db_user_host'"'
____

chapter Mengecek apakah PHPMyAdmin sudah imported SQL.
notfound=
msg=$(mysql \
    --defaults-extra-file=<(printf "[client]\nuser = %s\npassword = %s" "${db_user}" "${db_user_password}") \
    --silent --skip-column-names \
    $db_name -e "show tables;" | wc -l)
if [[ $msg -gt 0 ]];then
    __ PHPMyAdmin sudah imported SQL.
else
    __ PHPMyAdmin belum imported SQL.
    notfound=1
fi
____

if [ -n "$notfound" ];then
    chapter PHPMyAdmin Import SQL
    isFileExists "${root_source}/sql/create_tables.sql"
    [ -n "$notfound" ] && fileMustExists "${root_source}/sql/create_tables.sql"
    mysql \
        --defaults-extra-file=<(printf "[client]\nuser = %s\npassword = %s" "${db_user}" "${db_user_password}") \
        $db_name < "${root_source}/sql/create_tables.sql"
    msg=$(mysql \
        --defaults-extra-file=<(printf "[client]\nuser = %s\npassword = %s" "${db_user}" "${db_user_password}") \
        --silent --skip-column-names \
        $db_name -e "show tables;" | wc -l)
    if [[ $msg -gt 0 ]];then
        __; green PHPMyAdmin sudah imported SQL.; _.
    else
        __; red PHPMyAdmin belum imported SQL.; x
    fi
    ____
fi

chapter Mengecek informasi file konfigurasi PHPMyAdmin.
php=$(cat <<'EOF'
$mode = $_SERVER['argv'][1];
switch ($mode) {
    case 'is_empty' :
        $path = $_SERVER['argv'][2];
        $key = $_SERVER['argv'][3];
        include($path);
        $cfg = isset($cfg) ? $cfg : [];
        if (array_key_exists($key, $cfg)) {
            if (is_string($cfg[$key]) && strlen($cfg[$key]) === 0) {
                exit(0);
            }
        }
        exit(1);
        break;
    case 'generate_sodium':
        $key = sodium_crypto_secretbox_keygen();
        echo sodium_bin2hex($key);
        break;
    case 'is_different':
    case 'save':
        # Populate variable $is_different.
        $file = $_SERVER['argv'][2];
        $reference = unserialize($_SERVER['argv'][3]);
        include($file);
        $cfg = isset($cfg) ? $cfg : [];
        $cfg['Servers']['1'] = isset($cfg['Servers']['1']) ? $cfg['Servers']['1'] : [];
        // Tidak menggunakan array_map serialize seperti rcm-roundcube-autoinstaller-nginx karena dipastikan seluruh value non array.
        $is_different = !empty(array_diff_assoc($reference['Servers']['1'], $cfg['Servers']['1']));
        break;
}
switch ($mode) {
    case 'is_different':
        $is_different ? exit(0) : exit(1);
        break;
    case 'save':
        if (!$is_different) {
            exit(0);
        }
        $contents = file_get_contents($file);
        $need_edit = array_diff_assoc($reference['Servers']['1'], $cfg['Servers']['1']);
        $new_lines = [];
        foreach ($need_edit as $key => $value) {
            $new_line = "__PARAMETER__[__KEY__] = __VALUE__; # managed by RCM";
            // Jika indexed array dan hanya satu , maka buat one line.
            if (is_array($value) && array_key_exists(0, $value) && count($value) === 1) {
                $new_line = str_replace(['__PARAMETER__','__KEY__','__VALUE__'],['$cfg'."['Servers'][1]", var_export($key, true), "['".$value[0]."']"], $new_line);
            }
            else {
                $new_line = str_replace(['__PARAMETER__','__KEY__','__VALUE__'],['$cfg'."['Servers'][1]", var_export($key, true), var_export($value, true)], $new_line);
            }
            $is_one_line = preg_match('/\n/', $new_line) ? false : true;
            $find_existing = "__PARAMETER__[__KEY__] = __VALUE__; # managed by RCM";
            $find_existing = str_replace(['__PARAMETER__','__KEY__'],['$cfg'."['Servers'][1]", var_export($key, true)], $find_existing);
            $find_existing = preg_quote($find_existing);
            $find_existing = str_replace('__VALUE__', '.*', $find_existing);
            $find_existing = '/\s*'.$find_existing.'/';
            if ($is_one_line && preg_match_all($find_existing, $contents, $matches, PREG_PATTERN_ORDER)) {
                $contents = str_replace($matches[0], '', $contents);
            }
            $new_lines[] = $new_line;
        }
        if (substr($contents, -1) != "\n") {
            $contents .= "\n";
        }
        $contents .= implode("\n", $new_lines);
        $contents .= "\n";
        file_put_contents($file, $contents);
        break;
}
EOF
)

path="${root_source}/config.inc.php"
if php -r "$php" is_empty "$path" blowfish_secret;then
    __ Key '`'blowfish_secret'`' belum berisi nilai. Diperlukan modifikasi file '`'config.inc.php'`'.
    blowfish_secret=`php -r "$php" generate_sodium`
    sed -i "s,\$cfg\['blowfish_secret'\] = '';.*,\$cfg['blowfish_secret'] = \\\sodium_hex2bin('$blowfish_secret');," "$path"
    if php -r "$php" is_empty "$path" blowfish_secret;then
        __; red Key '`'blowfish_secret'`' belum berisi nilai. Gagal modifikasi file '`'config.inc.php'`'.
    else
        __; green Key '`'blowfish_secret'`' sudah terisi nilai. Berhasil modifikasi file '`'config.inc.php'`'.; _.
    fi
else
    __ Key '`'blowfish_secret'`' sudah terisi nilai. Tidak diperlukan modifikasi file '`'config.inc.php'`'.
fi

reference="$(php -r "echo serialize([
    'Servers' => [
        '1' => [
            'controlhost' => '$db_user_host',
            'controluser' => '$db_user',
            'controlpass' => '$db_user_password',
            'pmadb' => '$db_name',
            'bookmarktable' => 'pma__bookmark',
            'relation' => 'pma__relation',
            'table_info' => 'pma__table_info',
            'table_coords' => 'pma__table_coords',
            'pdf_pages' => 'pma__pdf_pages',
            'column_info' => 'pma__column_info',
            'history' => 'pma__history',
            'table_uiprefs' => 'pma__table_uiprefs',
            'tracking' => 'pma__tracking',
            'userconfig' => 'pma__userconfig',
            'recent' => 'pma__recent',
            'favorite' => 'pma__favorite',
            'users' => 'pma__users',
            'usergroups' => 'pma__usergroups',
            'navigationhiding' => 'pma__navigationhiding',
            'savedsearches' => 'pma__savedsearches',
            'central_columns' => 'pma__central_columns',
            'designer_settings' => 'pma__designer_settings',
            'export_templates' => 'pma__export_templates',
        ],
    ],
]);")"
is_different=
if php -r "$php" is_different "$path" "$reference";then
    is_different=1
    __ Diperlukan modifikasi file '`'config.inc.php'`'.
else
    __ File '`'config.inc.php'`' tidak ada perubahan.
fi
____

if [ -n "$is_different" ];then
    chapter Memodifikasi file '`'config.inc.php'`'.
    __ Backup file "$path"
    backupFile copy "$path"
    php -r "$php" save "$path" "$reference"
    if php -r "$php" is_different "$path" "$reference";then
        __; red Modifikasi file '`'config.inc.php'`' gagal.; x
    else
        __; green Modifikasi file '`'config.inc.php'`' berhasil.; _.
    fi
    ____
fi
____

chapter Mengecek HTTP Response Code.
code curl http://127.0.0.1 -H '"'Host: ${PHPMYADMIN_FQDN_LOCALHOST}'"'
code=$(curl -L \
    -o /dev/null -s -w "%{http_code}\n" \
    http://127.0.0.1 -H "Host: ${PHPMYADMIN_FQDN_LOCALHOST}")
[[ $code =~ ^[2,3] ]] && {
    __ HTTP Response code '`'$code'`' '('Required')'.
} || {
    __; red Terjadi kesalahan. HTTP Response code '`'$code'`'.; x
}
code curl http://${PHPMYADMIN_FQDN_LOCALHOST}
code=$(curl -L \
    -o /dev/null -s -w "%{http_code}\n" \
    http://127.0.0.1 -H "Host: ${PHPMYADMIN_FQDN_LOCALHOST}")
__ HTTP Response code '`'$code'`'.
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
# --php-version
# )
# FLAG_VALUE=(
# )
# EOF
# clear

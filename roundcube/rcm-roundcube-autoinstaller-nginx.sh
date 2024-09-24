#!/bin/bash

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --fast) fast=1; shift ;;
        --php-version=*) php_version="${1#*=}"; shift ;;
        --php-version) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then php_version="$2"; shift; fi; shift ;;
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
    echo '0.13.0'
}
printHelp() {
    title RCM RoundCube Auto-Installer
    _ 'Variation '; yellow Nginx; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-roundcube-autoinstaller-nginx [options]

Options:
   --php-version
        Set the version of PHP FPM.
   --roundcube-version *
        Set the version of RoundCube.

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
   ROUNDCUBE_FQDN_LOCALHOST
        Default to roundcube.localhost
   ROUNDCUBE_DB_NAME
        Default to roundcubemail
   ROUNDCUBE_DB_USER
        Default to roundcube
   ROUNDCUBE_DB_USER_HOST
        Default to localhost
   ROUNDCUBE_NGINX_CONFIG_FILE
        Default to roundcube

Dependency:
   mysql
   pwgen
   php
   curl
   rcm-nginx-setup-php
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Dependency.
while IFS= read -r line; do
    [[ -z "$line" ]] || command -v `cut -d: -f1 <<< "${line}"` >/dev/null || { echo -e "\e[91m""Unable to proceed, "'`'"${line}"'`'" command not found." "\e[39m"; exit 1; }
done <<< `printHelp 2>/dev/null | sed -n '/^Dependency:/,$p' | sed -n '2,/^\s*$/p' | sed 's/^ *//g'`

# Functions.
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
databaseCredentialRoundcube() {
    if [ -f /usr/local/share/roundcube/credential/database ];then
        local ROUNDCUBE_DB_USER ROUNDCUBE_DB_USER_PASSWORD ROUNDCUBE_BLOWFISH
        . /usr/local/share/roundcube/credential/database
        roundcube_db_user=$ROUNDCUBE_DB_USER
        roundcube_db_user_password=$ROUNDCUBE_DB_USER_PASSWORD
        roundcube_blowfish=$ROUNDCUBE_BLOWFISH
    else
        roundcube_db_user=$ROUNDCUBE_DB_USER # global variable
        roundcube_db_user_password=$(pwgen -s 32 -1)
        roundcube_blowfish=$(pwgen -s 32 -1)
        mkdir -p /usr/local/share/roundcube/credential
        cat << EOF > /usr/local/share/roundcube/credential/database
ROUNDCUBE_DB_USER=$roundcube_db_user
ROUNDCUBE_DB_USER_PASSWORD=$roundcube_db_user_password
ROUNDCUBE_BLOWFISH=$roundcube_blowfish
EOF
        chmod 0500 /usr/local/share/roundcube/credential
        chmod 0400 /usr/local/share/roundcube/credential/database
    fi
}

# Title.
title rcm-roundcube-autoinstaller-nginx
____

# Requirement, validate, and populate value.
chapter Dump variable.
[ -n "$fast" ] && isfast=' --fast' || isfast=''
ROUNDCUBE_FQDN_LOCALHOST=${ROUNDCUBE_FQDN_LOCALHOST:=roundcube.localhost}
code 'ROUNDCUBE_FQDN_LOCALHOST="'$ROUNDCUBE_FQDN_LOCALHOST'"'
ROUNDCUBE_DB_NAME=${ROUNDCUBE_DB_NAME:=roundcubemail}
code 'ROUNDCUBE_DB_NAME="'$ROUNDCUBE_DB_NAME'"'
ROUNDCUBE_DB_USER=${ROUNDCUBE_DB_USER:=roundcube}
code 'ROUNDCUBE_DB_USER="'$ROUNDCUBE_DB_USER'"'
ROUNDCUBE_DB_USER_HOST=${ROUNDCUBE_DB_USER_HOST:=localhost}
code 'ROUNDCUBE_DB_USER_HOST="'$ROUNDCUBE_DB_USER_HOST'"'
ROUNDCUBE_NGINX_CONFIG_FILE=${ROUNDCUBE_NGINX_CONFIG_FILE:=roundcube}
code 'ROUNDCUBE_NGINX_CONFIG_FILE="'$ROUNDCUBE_NGINX_CONFIG_FILE'"'
delay=.5; [ -n "$fast" ] && unset delay
if [ -z "$roundcube_version" ];then
    error "Argument --roundcube-version required."; x
fi
code 'roundcube_version="'$roundcube_version'"'
code 'php_version="'$php_version'"'
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

chapter Mengecek database '`'$ROUNDCUBE_DB_NAME'`'.
msg=$(mysql --silent --skip-column-names -e "select schema_name from information_schema.schemata where schema_name = '$ROUNDCUBE_DB_NAME'")
notfound=
if [[ $msg == $ROUNDCUBE_DB_NAME ]];then
    __ Database ditemukan.
else
    __ Database tidak ditemukan
    notfound=1
fi
____

if [ -n "$notfound" ];then
    chapter Membuat database.
    mysql -e "create database $ROUNDCUBE_DB_NAME character set utf8 collate utf8_general_ci;"
    msg=$(mysql --silent --skip-column-names -e "select schema_name from information_schema.schemata where schema_name = '$ROUNDCUBE_DB_NAME'")
    if [[ $msg == $ROUNDCUBE_DB_NAME ]];then
        __; green Database ditemukan.; _.
    else
        __; red Database tidak ditemukan; x
    fi
    ____
fi

chapter Mengecek database credentials RoundCube.
databaseCredentialRoundcube
if [[ -z "$roundcube_db_user" || -z "$roundcube_db_user_password" || -z "$roundcube_blowfish" ]];then
    __; red Informasi credentials tidak lengkap: '`'/usr/local/share/roundcube/credential/database'`'.; x
else
    code roundcube_db_user="$roundcube_db_user"
    code roundcube_db_user_password="$roundcube_db_user_password"
    code roundcube_blowfish="$roundcube_blowfish"
fi
____

chapter Mengecek user database '`'$roundcube_db_user'`'.
msg=$(mysql --silent --skip-column-names -e "select COUNT(*) FROM mysql.user WHERE user = '$roundcube_db_user';")
notfound=
if [ $msg -gt 0 ];then
    __ User database ditemukan.
else
    __ User database tidak ditemukan.
    notfound=1
fi
____

if [ -n "$notfound" ];then
    chapter Membuat user database '`'$roundcube_db_user'`'.
    mysql -e "create user '${roundcube_db_user}'@'${ROUNDCUBE_DB_USER_HOST}' identified by '${roundcube_db_user_password}';"
    msg=$(mysql --silent --skip-column-names -e "select COUNT(*) FROM mysql.user WHERE user = '$roundcube_db_user';")
    if [ $msg -gt 0 ];then
        __; green User database ditemukan.; _.
    else
        __; red User database tidak ditemukan; x
    fi
    ____
fi

chapter Mengecek grants user '`'$roundcube_db_user'`' ke database '`'$ROUNDCUBE_DB_NAME'`'.
notfound=
msg=$(mysql "$ROUNDCUBE_DB_NAME" --silent --skip-column-names -e "show grants for ${roundcube_db_user}@${ROUNDCUBE_DB_USER_HOST}")
if grep -q "GRANT.*ON.*${ROUNDCUBE_DB_NAME}.*TO.*${roundcube_db_user}.*@.*${ROUNDCUBE_DB_USER_HOST}.*" <<< "$msg";then
    __ Granted.
else
    __ Not granted.
    notfound=1
fi
____

if [ -n "$notfound" ];then
    chapter Memberi grants user '`'$roundcube_db_user'`' ke database '`'$ROUNDCUBE_DB_NAME'`'.
    mysql -e "grant all privileges on \`${ROUNDCUBE_DB_NAME}\`.* TO '${roundcube_db_user}'@'${ROUNDCUBE_DB_USER_HOST}';"
    msg=$(mysql "$ROUNDCUBE_DB_NAME" --silent --skip-column-names -e "show grants for ${roundcube_db_user}@${ROUNDCUBE_DB_USER_HOST}")
    if grep -q "GRANT.*ON.*${ROUNDCUBE_DB_NAME}.*TO.*${roundcube_db_user}.*@.*${ROUNDCUBE_DB_USER_HOST}.*" <<< "$msg";then
        __; green Granted.; _.
    else
        __; red Not granted.; x
    fi
    ____
fi

chapter Prepare arguments.
root="/usr/local/share/roundcube/${roundcube_version}"
code root="$root"
filename="$ROUNDCUBE_NGINX_CONFIG_FILE"
code filename="$filename"
server_name="$ROUNDCUBE_FQDN_LOCALHOST"
code server_name="$server_name"
____

INDENT+="    " \
rcm-nginx-setup-php $isfast --root-sure \
    --root="$root" \
    --php-version="$php_version" \
    --filename="$filename" \
    --server-name="$server_name" \
    ; [ ! $? -eq 0 ] && x

chapter Mengecek subdomain '`'$ROUNDCUBE_FQDN_LOCALHOST'`'.
notfound=
string="$ROUNDCUBE_FQDN_LOCALHOST"
string_quoted=$(sed "s/\./\\\./g" <<< "$string")
if grep -q -E "^\s*127\.0\.0\.1\s+${string_quoted}" /etc/hosts;then
    __ Subdomain terdapat pada local DNS resolver '`'/etc/hosts'`'.
else
    __ Subdomain tidak terdapat pada local DNS resolver '`'/etc/hosts'`'.
    notfound=1
fi
____

if [ -n "$notfound" ];then
    chapter Menambahkan subdomain '`'$ROUNDCUBE_FQDN_LOCALHOST'`'.
    echo "127.0.0.1"$'\t'"${ROUNDCUBE_FQDN_LOCALHOST}" >> /etc/hosts
    if grep -q -E "^\s*127\.0\.0\.1\s+${string_quoted}" /etc/hosts;then
        __; green Subdomain terdapat pada local DNS resolver '`'/etc/hosts'`'.; _.
    else
        __; red Subdomain tidak terdapat pada local DNS resolver '`'/etc/hosts'`'.; x
    fi
    ____
fi

chapter Mencari informasi PHP-FPM User.
__ Membuat file "${root}/.well-known/__getuser.php"
mkdir -p "${root}/.well-known"
cat << 'EOF' > "${root}/.well-known/__getuser.php"
<?php
echo $_SERVER['USER'];
EOF
__ Eksekusi file script.
__; magenta curl http://127.0.0.1/.well-known/__getuser.php -H "Host: ${ROUNDCUBE_FQDN_LOCALHOST}"; _.
user_nginx=$(curl -Ss http://127.0.0.1/.well-known/__getuser.php -H "Host: ${ROUNDCUBE_FQDN_LOCALHOST}")
__; magenta user_nginx="$user_nginx"; _.
if [ -z "$user_nginx" ];then
    error PHP-FPM User tidak ditemukan; x
fi
__ Menghapus file "${root}/.well-known/__getuser.php"
rm "${root}/.well-known/__getuser.php"
rmdir "${root}/.well-known" --ignore-fail-on-non-empty
____

chapter Mengecek file '`'composer.json'`' untuk project '`'roundcube/roundcubemail'`'
notfound=
if [ -f /usr/local/share/roundcube/${roundcube_version}/composer.json ];then
    __ File '`'composer.json'`' ditemukan.
else
    __ File '`'composer.json'`' tidak ditemukan.
    notfound=1
fi
____

if [ -n "$notfound" ];then
    chapter Mendownload RoundCube
    cd          /tmp
    wget        https://github.com/roundcube/roundcubemail/releases/download/${roundcube_version}/roundcubemail-${roundcube_version}-complete.tar.gz
    tar xfz     roundcubemail-${roundcube_version}-complete.tar.gz
    mkdir -p    /usr/local/share/roundcube/${roundcube_version}
    mv          roundcubemail-${roundcube_version}/* -t /usr/local/share/roundcube/${roundcube_version}/
    mv          roundcubemail-${roundcube_version}/.[!.]* -t /usr/local/share/roundcube/${roundcube_version}/
    rmdir       roundcubemail-${roundcube_version}
    chown -R $user_nginx:$user_nginx /usr/local/share/roundcube/${roundcube_version}
    if [ -f /usr/local/share/roundcube/${roundcube_version}/composer.json ];then
        __; green File '`'composer.json'`' ditemukan.; _.
    else
        __; red File '`'composer.json'`' tidak ditemukan.; x
    fi
    ____
fi

chapter Mengecek apakah RoundCube sudah imported SQL.
notfound=
msg=$(mysql \
    --defaults-extra-file=<(printf "[client]\nuser = %s\npassword = %s" "${roundcube_db_user}" "${roundcube_db_user_password}") \
    --silent --skip-column-names \
    $ROUNDCUBE_DB_NAME -e "show tables;" | wc -l)
if [[ $msg -gt 0 ]];then
    __ RoundCube sudah imported SQL.
else
    __ RoundCube belum imported SQL.
    notfound=1
fi
____

if [ -n "$notfound" ];then
    chapter RoundCube Import SQL
    mysql \
        --defaults-extra-file=<(printf "[client]\nuser = %s\npassword = %s" "${roundcube_db_user}" "${roundcube_db_user_password}") \
        $ROUNDCUBE_DB_NAME < /usr/local/share/roundcube/${roundcube_version}/SQL/mysql.initial.sql
    msg=$(mysql \
        --defaults-extra-file=<(printf "[client]\nuser = %s\npassword = %s" "${roundcube_db_user}" "${roundcube_db_user_password}") \
        --silent --skip-column-names \
        $ROUNDCUBE_DB_NAME -e "show tables;" | wc -l)
    if [[ $msg -gt 0 ]];then
        __; green RoundCube sudah imported SQL.; _.
    else
        __; red RoundCube belum imported SQL.; x
    fi
    ____
fi

chapter Mengecek file konfigurasi RoundCube.
notfound=
if [ -f /usr/local/share/roundcube/${roundcube_version}/config/config.inc.php ];then
    __ File '`'config.inc.php'`' ditemukan.
else
    __ File '`'config.inc.php'`' tidak ditemukan.
    notfound=1
fi
____

if [ -n "$notfound" ];then
    chapter Membuat file konfigurasi RoundCube.
    cp /usr/local/share/roundcube/${roundcube_version}/config/config.inc.php.sample \
        /usr/local/share/roundcube/${roundcube_version}/config/config.inc.php
    if [ -f /usr/local/share/roundcube/${roundcube_version}/config/config.inc.php ];then
        __; green File '`'config.inc.php'`' ditemukan.; _.
        chown $user_nginx:$user_nginx /usr/local/share/roundcube/${roundcube_version}/config/config.inc.php
        chmod a-w /usr/local/share/roundcube/${roundcube_version}/config/config.inc.php
    else
        __; red File '`'config.inc.php'`' tidak ditemukan.; x
    fi
    ____
fi

chapter Mengecek informasi file konfigurasi RoundCube.
php=$(cat <<'EOF'
$mode = $_SERVER['argv'][1];
$file = $_SERVER['argv'][2];
$array = unserialize($_SERVER['argv'][3]);
include($file);
$config = isset($config) ? $config : [];
$is_different = !empty(array_diff_assoc($array, $config));
switch ($mode) {
    case 'is_different':
        $is_different ? exit(0) : exit(1);
        break;
    case 'save':
        if ($is_different) {
            $config = array_replace_recursive($config, $array);
            $content = '$config = '.var_export($config, true).';'.PHP_EOL;
            $content = <<< EOF
<?php
$content
EOF;
            file_put_contents($file, $content);
        }
        break;
}
EOF
)
reference="$(php -r "echo serialize([
    'des_key' => '$roundcube_blowfish',
    'db_dsnw' => 'mysql://${roundcube_db_user}:${roundcube_db_user_password}@${ROUNDCUBE_DB_USER_HOST}/${ROUNDCUBE_DB_NAME}',
    'smtp_host' => 'localhost:25',
    'smtp_user' => '',
    'smtp_pass' => '',
    'identities_level' => '3',
    'username_domain' => '%t',
    'default_list_mode' => 'threads',
]);")"
is_different=
if php -r "$php" is_different \
    /usr/local/share/roundcube/${roundcube_version}/config/config.inc.php \
    "$reference";then
    is_different=1
    __ Diperlukan modifikasi file '`'config.inc.php'`'.
else
    __ File '`'config.inc.php'`' tidak ada perubahan.
fi
____

if [ -n "$is_different" ];then
    chapter Memodifikasi file '`'config.inc.php'`'.
    __ Backup file /usr/local/share/roundcube/${roundcube_version}/config/config.inc.php
    backupFile copy /usr/local/share/roundcube/${roundcube_version}/config/config.inc.php
    php -r "$php" save \
        /usr/local/share/roundcube/${roundcube_version}/config/config.inc.php \
        "$reference"
    if php -r "$php" is_different \
        /usr/local/share/roundcube/${roundcube_version}/config/config.inc.php \
        "$reference";then
        __; red Modifikasi file '`'config.inc.php'`' gagal.; x
    else
        __; green Modifikasi file '`'config.inc.php'`' berhasil.; _.
    fi
    ____
fi

chapter Mengecek HTTP Response Code.
code curl http://127.0.0.1 -H '"'Host: ${ROUNDCUBE_FQDN_LOCALHOST}'"'
code=$(curl -L \
    -o /dev/null -s -w "%{http_code}\n" \
    http://127.0.0.1 -H "Host: ${ROUNDCUBE_FQDN_LOCALHOST}")
[[ $code =~ ^[2,3] ]] && {
    __ HTTP Response code '`'$code'`' '('Required')'.
} || {
    __; red Terjadi kesalahan. HTTP Response code '`'$code'`'.; x
}
code curl http://${ROUNDCUBE_FQDN_LOCALHOST}
code=$(curl -L \
    -o /dev/null -s -w "%{http_code}\n" \
    http://127.0.0.1 -H "Host: ${ROUNDCUBE_FQDN_LOCALHOST}")
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
# --roundcube-version
# --php-version
# )
# FLAG_VALUE=(
# )
# EOF
# clear

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
        --phpmyadmin-version=*) phpmyadmin_version="${1#*=}"; shift ;;
        --phpmyadmin-version) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then phpmyadmin_version="$2"; shift; fi; shift ;;
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
    echo '0.6.0'
}
printHelp() {
    title RCM PHPMyAdmin Auto-Installer
    _ 'Variation '; yellow Nginx; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-phpmyadmin-autoinstaller-nginx [options]

Options:
   --php-version
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
   PHPMYADMIN_DB_NAME
        Default to phpmyadmin
   PHPMYADMIN_DB_USER
        Default to pma
   PHPMYADMIN_DB_USER_HOST
        Default to localhost
   PHPMYADMIN_NGINX_CONFIG_FILE
        Default to phpmyadmin

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
    [[ -z "$line" ]] || command -v "${line}" >/dev/null || { echo -e "\e[91m""Unable to proceed, ${line} command not found." "\e[39m"; exit 1; }
done <<< `printHelp 2>/dev/null | sed -n '/^Dependency:/,$p' | sed -n '2,/^$/p' | sed 's/^ *//g'`

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
databaseCredentialPhpmyadmin() {
    if [ -f /usr/local/share/phpmyadmin/credential/database ];then
        local PHPMYADMIN_DB_USER PHPMYADMIN_DB_USER_PASSWORD PHPMYADMIN_BLOWFISH
        . /usr/local/share/phpmyadmin/credential/database
        phpmyadmin_db_user=$PHPMYADMIN_DB_USER
        phpmyadmin_db_user_password=$PHPMYADMIN_DB_USER_PASSWORD
        phpmyadmin_blowfish=$PHPMYADMIN_BLOWFISH
    else
        phpmyadmin_db_user=$PHPMYADMIN_DB_USER # global variable
        phpmyadmin_db_user_password=$(pwgen -s 32 -1)
        phpmyadmin_blowfish=$(pwgen -s 32 -1)
        mkdir -p /usr/local/share/phpmyadmin/credential
        cat << EOF > /usr/local/share/phpmyadmin/credential/database
PHPMYADMIN_DB_USER=$phpmyadmin_db_user
PHPMYADMIN_DB_USER_PASSWORD=$phpmyadmin_db_user_password
PHPMYADMIN_BLOWFISH=$phpmyadmin_blowfish
EOF
        chmod 0500 /usr/local/share/phpmyadmin/credential
        chmod 0400 /usr/local/share/phpmyadmin/credential/database
    fi
}

# Title.
title rcm-phpmyadmin-autoinstaller-nginx
____

# Requirement, validate, and populate value.
chapter Dump variable.
[ -n "$fast" ] && isfast=' --fast' || isfast=''
PHPMYADMIN_FQDN_LOCALHOST=${PHPMYADMIN_FQDN_LOCALHOST:=phpmyadmin.localhost}
code 'PHPMYADMIN_FQDN_LOCALHOST="'$PHPMYADMIN_FQDN_LOCALHOST'"'
PHPMYADMIN_DB_NAME=${PHPMYADMIN_DB_NAME:=phpmyadmin}
code 'PHPMYADMIN_DB_NAME="'$PHPMYADMIN_DB_NAME'"'
PHPMYADMIN_DB_USER=${PHPMYADMIN_DB_USER:=pma}
code 'PHPMYADMIN_DB_USER="'$PHPMYADMIN_DB_USER'"'
PHPMYADMIN_DB_USER_HOST=${PHPMYADMIN_DB_USER_HOST:=localhost}
code 'PHPMYADMIN_DB_USER_HOST="'$PHPMYADMIN_DB_USER_HOST'"'
PHPMYADMIN_NGINX_CONFIG_FILE=${PHPMYADMIN_NGINX_CONFIG_FILE:=phpmyadmin}
code 'PHPMYADMIN_NGINX_CONFIG_FILE="'$PHPMYADMIN_NGINX_CONFIG_FILE'"'
delay=.5; [ -n "$fast" ] && unset delay
if [ -z "$phpmyadmin_version" ];then
    error "Argument --phpmyadmin-version required."; x
fi
code 'phpmyadmin_version="'$phpmyadmin_version'"'
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

chapter Mengecek database '`'$PHPMYADMIN_DB_NAME'`'.
msg=$(mysql --silent --skip-column-names -e "select schema_name from information_schema.schemata where schema_name = '$PHPMYADMIN_DB_NAME'")
notfound=
if [[ $msg == $PHPMYADMIN_DB_NAME ]];then
    __ Database ditemukan.
else
    __ Database tidak ditemukan
    notfound=1
fi
____

if [ -n "$notfound" ];then
    chapter Membuat database.
    mysql -e "create database $PHPMYADMIN_DB_NAME character set utf8 collate utf8_general_ci;"
    msg=$(mysql --silent --skip-column-names -e "select schema_name from information_schema.schemata where schema_name = '$PHPMYADMIN_DB_NAME'")
    if [[ $msg == $PHPMYADMIN_DB_NAME ]];then
        __; green Database ditemukan.; _.
    else
        __; red Database tidak ditemukan; x
    fi
    ____
fi

chapter Mengecek database credentials PHPMyAdmin.
databaseCredentialPhpmyadmin
if [[ -z "$phpmyadmin_db_user" || -z "$phpmyadmin_db_user_password" || -z "$phpmyadmin_blowfish" ]];then
    __; red Informasi credentials tidak lengkap: '`'/usr/local/share/phpmyadmin/credential/database'`'.; x
else
    code phpmyadmin_db_user="$phpmyadmin_db_user"
    code phpmyadmin_db_user_password="$phpmyadmin_db_user_password"
    code phpmyadmin_blowfish="$phpmyadmin_blowfish"
fi
____

chapter Mengecek user database '`'$phpmyadmin_db_user'`'.
msg=$(mysql --silent --skip-column-names -e "select COUNT(*) FROM mysql.user WHERE user = '$phpmyadmin_db_user';")
notfound=
if [ $msg -gt 0 ];then
    __ User database ditemukan.
else
    __ User database tidak ditemukan.
    notfound=1
fi
____

if [ -n "$notfound" ];then
    chapter Membuat user database '`'$phpmyadmin_db_user'`'.
    mysql -e "create user '${phpmyadmin_db_user}'@'${PHPMYADMIN_DB_USER_HOST}' identified by '${phpmyadmin_db_user_password}';"
    msg=$(mysql --silent --skip-column-names -e "select COUNT(*) FROM mysql.user WHERE user = '$phpmyadmin_db_user';")
    if [ $msg -gt 0 ];then
        __; green User database ditemukan.; _.
    else
        __; red User database tidak ditemukan; x
    fi
    ____
fi

chapter Mengecek grants user '`'$phpmyadmin_db_user'`' ke database '`'$PHPMYADMIN_DB_NAME'`'.
notfound=
msg=$(mysql "$PHPMYADMIN_DB_NAME" --silent --skip-column-names -e "show grants for ${phpmyadmin_db_user}@${PHPMYADMIN_DB_USER_HOST}")
if grep -q "GRANT.*ON.*${PHPMYADMIN_DB_NAME}.*TO.*${phpmyadmin_db_user}.*@.*${PHPMYADMIN_DB_USER_HOST}.*" <<< "$msg";then
    __ Granted.
else
    __ Not granted.
    notfound=1
fi
____

if [ -n "$notfound" ];then
    chapter Memberi grants user '`'$phpmyadmin_db_user'`' ke database '`'$PHPMYADMIN_DB_NAME'`'.
    mysql -e "grant all privileges on \`${PHPMYADMIN_DB_NAME}\`.* TO '${phpmyadmin_db_user}'@'${PHPMYADMIN_DB_USER_HOST}';"
    msg=$(mysql "$PHPMYADMIN_DB_NAME" --silent --skip-column-names -e "show grants for ${phpmyadmin_db_user}@${PHPMYADMIN_DB_USER_HOST}")
    if grep -q "GRANT.*ON.*${PHPMYADMIN_DB_NAME}.*TO.*${phpmyadmin_db_user}.*@.*${PHPMYADMIN_DB_USER_HOST}.*" <<< "$msg";then
        __; green Granted.; _.
    else
        __; red Not granted.; x
    fi
    ____
fi

chapter Prepare arguments.
root="/usr/local/share/phpmyadmin/${phpmyadmin_version}"
code root="$root"
filename="$PHPMYADMIN_NGINX_CONFIG_FILE"
code filename="$filename"
server_name="$PHPMYADMIN_FQDN_LOCALHOST"
code server_name="$server_name"
____

INDENT+="    " \
rcm-nginx-setup-php $isfast --root-sure \
    --root="$root" \
    --php-version="$php_version" \
    --filename="$filename" \
    --server-name="$server_name" \
    ; [ ! $? -eq 0 ] && x

chapter Mengecek subdomain '`'$PHPMYADMIN_FQDN_LOCALHOST'`'.
notfound=
string="$PHPMYADMIN_FQDN_LOCALHOST"
string_quoted=$(sed "s/\./\\\./g" <<< "$string")
if grep -q -E "^\s*127\.0\.0\.1\s+${string_quoted}" /etc/hosts;then
    __ Subdomain terdapat pada local DNS resolver '`'/etc/hosts'`'.
else
    __ Subdomain tidak terdapat pada local DNS resolver '`'/etc/hosts'`'.
    notfound=1
fi
____

if [ -n "$notfound" ];then
    chapter Menambahkan subdomain '`'$PHPMYADMIN_FQDN_LOCALHOST'`'.
    echo "127.0.0.1"$'\t'"${PHPMYADMIN_FQDN_LOCALHOST}" >> /etc/hosts
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
__; magenta curl http://127.0.0.1/.well-known/__getuser.php -H "Host: ${PHPMYADMIN_FQDN_LOCALHOST}"; _.
user_nginx=$(curl -Ss http://127.0.0.1/.well-known/__getuser.php -H "Host: ${PHPMYADMIN_FQDN_LOCALHOST}")
__; magenta user_nginx="$user_nginx"; _.
if [ -z "$user_nginx" ];then
    error PHP-FPM User tidak ditemukan; x
fi
__ Menghapus file "${root}/.well-known/__getuser.php"
rm "${root}/.well-known/__getuser.php"
rmdir "${root}/.well-known" --ignore-fail-on-non-empty
____

chapter Mengecek file '`'composer.json'`' untuk project '`'phpmyadmin/phpmyadmin'`'
notfound=
if [ -f /usr/local/share/phpmyadmin/${phpmyadmin_version}/composer.json ];then
    __ File '`'composer.json'`' ditemukan.
else
    __ File '`'composer.json'`' tidak ditemukan.
    notfound=1
fi
____

if [ -n "$notfound" ];then
    chapter Mendownload PHPMyAdmin
    cd          /tmp
    wget        https://files.phpmyadmin.net/phpMyAdmin/${phpmyadmin_version}/phpMyAdmin-${phpmyadmin_version}-all-languages.tar.gz
    tar xfz     phpMyAdmin-${phpmyadmin_version}-all-languages.tar.gz
    mkdir -p    /usr/local/share/phpmyadmin/${phpmyadmin_version}
    mv          phpMyAdmin-${phpmyadmin_version}-all-languages/* -t /usr/local/share/phpmyadmin/${phpmyadmin_version}
    mv          phpMyAdmin-${phpmyadmin_version}-all-languages/.[!.]* -t /usr/local/share/phpmyadmin/${phpmyadmin_version}
    rmdir       phpMyAdmin-${phpmyadmin_version}-all-languages
    chown -R $user_nginx:$user_nginx /usr/local/share/phpmyadmin/${phpmyadmin_version}
    if [ -f /usr/local/share/phpmyadmin/${phpmyadmin_version}/composer.json ];then
        __; green File '`'composer.json'`' ditemukan.; _.
    else
        __; red File '`'composer.json'`' tidak ditemukan.; x
    fi
    ____
fi

chapter Mengecek apakah PHPMyAdmin sudah imported SQL.
notfound=
msg=$(mysql \
    --defaults-extra-file=<(printf "[client]\nuser = %s\npassword = %s" "${phpmyadmin_db_user}" "${phpmyadmin_db_user_password}") \
    --silent --skip-column-names \
    $PHPMYADMIN_DB_NAME -e "show tables;" | wc -l)
if [[ $msg -gt 0 ]];then
    __ PHPMyAdmin sudah imported SQL.
else
    __ PHPMyAdmin belum imported SQL.
    notfound=1
fi
____

if [ -n "$notfound" ];then
    chapter PHPMyAdmin Import SQL
    mysql \
        --defaults-extra-file=<(printf "[client]\nuser = %s\npassword = %s" "${phpmyadmin_db_user}" "${phpmyadmin_db_user_password}") \
        $PHPMYADMIN_DB_NAME < /usr/local/share/phpmyadmin/${phpmyadmin_version}/sql/create_tables.sql
    msg=$(mysql \
        --defaults-extra-file=<(printf "[client]\nuser = %s\npassword = %s" "${phpmyadmin_db_user}" "${phpmyadmin_db_user_password}") \
        --silent --skip-column-names \
        $PHPMYADMIN_DB_NAME -e "show tables;" | wc -l)
    if [[ $msg -gt 0 ]];then
        __; green PHPMyAdmin sudah imported SQL.; _.
    else
        __; red PHPMyAdmin belum imported SQL.; x
    fi
    ____
fi

chapter Mengecek file konfigurasi PHPMyAdmin.
notfound=
if [ -f /usr/local/share/phpmyadmin/${phpmyadmin_version}/config.inc.php ];then
    __ File '`'config.inc.php'`' ditemukan.
else
    __ File '`'config.inc.php'`' tidak ditemukan.
    notfound=1
fi
____

if [ -n "$notfound" ];then
    chapter Membuat file konfigurasi PHPMyAdmin.
    cp /usr/local/share/phpmyadmin/${phpmyadmin_version}/config.sample.inc.php \
        /usr/local/share/phpmyadmin/${phpmyadmin_version}/config.inc.php
    if [ -f /usr/local/share/phpmyadmin/${phpmyadmin_version}/config.inc.php ];then
        __; green File '`'config.inc.php'`' ditemukan.; _.
        chown $user_nginx:$user_nginx /usr/local/share/phpmyadmin/${phpmyadmin_version}/config.inc.php
        chmod a-w /usr/local/share/phpmyadmin/${phpmyadmin_version}/config.inc.php
    else
        __; red File '`'config.inc.php'`' tidak ditemukan.; x
    fi
    ____
fi

chapter Mengecek informasi file konfigurasi PHPMyAdmin pada server index 1.
php=$(cat <<'EOF'
$mode = $_SERVER['argv'][1];
$file = $_SERVER['argv'][2];
$array = unserialize($_SERVER['argv'][3]);
include($file);
$cfg = isset($cfg) ? $cfg : [];
$cfg['blowfish_secret'] = isset($cfg['blowfish_secret']) ? $cfg['blowfish_secret'] : NULL;
$cfg['Servers']['1'] = isset($cfg['Servers']['1']) ? $cfg['Servers']['1'] : [];
$is_different = false;
if ($cfg['blowfish_secret'] != $array['blowfish_secret']) {
    $is_different = true;
}
$result = array_diff_assoc($array['Servers']['1'], $cfg['Servers']['1']);
if (!empty($result)) {
    $is_different = true;
}
switch ($mode) {
    case 'is_different':
        $is_different ? exit(0) : exit(1);
        break;
    case 'save':
        if ($is_different) {
            $cfg = array_replace_recursive($cfg, $array);
            $content = '$cfg = '.var_export($cfg, true).';'.PHP_EOL;
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
    'blowfish_secret' => '$phpmyadmin_blowfish',
    'Servers' => [
        '1' => [
            'controlhost' => '$PHPMYADMIN_DB_USER_HOST',
            'controluser' => '$phpmyadmin_db_user',
            'controlpass' => '$phpmyadmin_db_user_password',
        ],
    ],
]);")"
is_different=
if php -r "$php" is_different \
    /usr/local/share/phpmyadmin/${phpmyadmin_version}/config.inc.php \
    "$reference";then
    is_different=1
    __ Diperlukan modifikasi file '`'config.inc.php'`'.
else
    __ File '`'config.inc.php'`' tidak ada perubahan.
fi
____

if [ -n "$is_different" ];then
    chapter Memodifikasi file '`'config.inc.php'`'.
    __ Backup file /usr/local/share/phpmyadmin/${phpmyadmin_version}/config.inc.php
    backupFile copy /usr/local/share/phpmyadmin/${phpmyadmin_version}/config.inc.php
    php -r "$php" save \
        /usr/local/share/phpmyadmin/${phpmyadmin_version}/config.inc.php \
        "$reference"
    if php -r "$php" is_different \
        /usr/local/share/phpmyadmin/${phpmyadmin_version}/config.inc.php \
        "$reference";then
        __; red Modifikasi file '`'config.inc.php'`' gagal.; x
    else
        __; green Modifikasi file '`'config.inc.php'`' berhasil.; _.
    fi
    ____
fi

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

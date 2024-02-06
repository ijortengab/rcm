#!/bin/bash

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --digitalocean) dns_authenticator=digitalocean; shift ;;
        --dns-authenticator=*) dns_authenticator="${1#*=}"; shift ;;
        --dns-authenticator) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then dns_authenticator="$2"; shift; fi; shift ;;
        --domain=*) domain="${1#*=}"; shift ;;
        --domain) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then domain="$2"; shift; fi; shift ;;
        --fast) fast=1; shift ;;
        --hostname=*) hostname="${1#*=}"; shift ;;
        --hostname) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then hostname="$2"; shift; fi; shift ;;
        --ispconfig-version=*) ispconfig_version="${1#*=}"; shift ;;
        --ispconfig-version) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then ispconfig_version="$2"; shift; fi; shift ;;
        --php-version=*) php_version="${1#*=}"; shift ;;
        --php-version) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then php_version="$2"; shift; fi; shift ;;
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
e() { echo -n "$INDENT" >&2; echo "$@" >&2; }
_() { echo -n "$INDENT" >&2; echo -n "$@" >&2; }
_,() { echo -n "$@" >&2; }
_.() { echo >&2; }
__() { echo -n "$INDENT" >&2; echo -n '    ' >&2; [ -n "$1" ] && echo "$@" >&2 || echo -n  >&2; }
____() { echo >&2; [ -n "$delay" ] && sleep "$delay"; }

# Functions.
printVersion() {
    echo '0.3.2'
}
printHelp() {
    title RCM ISPConfig Auto-Installer
    _ 'Variation '; yellow Nginx PHP-FPM; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-ispconfig-autoinstaller-nginx-php-fpm.sh [options]

Options:
   --hostname
        Hostname of the server.
   --domain
        Domain name of the server.
   --php-version
        Set the version of PHP FPM.
   --ispconfig-version *
        Set the version of ISPConfig.
   --roundcube-version *
        Set the version of RoundCube.
   --phpmyadmin-version *
        Set the version of PHPMyAdmin.
   --dns-authenticator
        Available value: digitalocean.

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
   ISPCONFIG_FQDN_LOCALHOST
        Default to ispconfig.localhost
   MYSQL_ROOT_PASSWD
        Default to $HOME/.mysql-root-passwd.txt
   MYSQL_ROOT_PASSWD_INI
        Default to $HOME/.mysql-root-passwd.ini
   ISPCONFIG_DB_USER_HOST
        Default to localhost
   ISPCONFIG_NGINX_CONFIG_FILE
        Default to ispconfig
   ISPCONFIG_INSTALL_DIR
        Default to /usr/local/ispconfig

Dependency:
   mysql
   pwgen
   php
   curl
   nginx
   rcm-mariadb-setup-ispconfig.sh
   rcm-nginx-setup-ispconfig.sh
   rcm-php-setup-ispconfig.sh
   rcm-postfix-setup-ispconfig.sh
   rcm-ispconfig-setup-smtpd-certificate.sh
   rcm-phpmyadmin-autoinstaller-nginx-php-fpm.sh
   rcm-roundcube-autoinstaller-nginx-php-fpm.sh
   rcm-nginx-setup-php-fpm.sh
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
websiteCredentialIspconfig() {
    if [ -f /usr/local/share/ispconfig/credential/website ];then
        local ISPCONFIG_WEB_USER_PASSWORD
        . /usr/local/share/ispconfig/credential/website
        ispconfig_web_user_password=$ISPCONFIG_WEB_USER_PASSWORD
    else
        ispconfig_web_user_password=$(pwgen 6 -1vA0B)
        mkdir -p /usr/local/share/ispconfig/credential
        cat << EOF > /usr/local/share/ispconfig/credential/website
ISPCONFIG_WEB_USER_PASSWORD=$ispconfig_web_user_password
EOF
        chmod 0500 /usr/local/share/ispconfig/credential
        chmod 0400 /usr/local/share/ispconfig/credential/website
    fi
}
toggleMysqlRootPassword() {
    # global used MYSQL_ROOT_PASSWD_INI
    # global used mysql_root_passwd
    local switch=$1
    local is_password=
    # mysql \
        # --defaults-extra-file="$MYSQL_ROOT_PASSWD_INI" \
        # -e "show variables like 'version';" ; echo $?
    # mysql \
        # -e "show variables like 'version';" ; echo $?
    if mysql \
        --defaults-extra-file="$MYSQL_ROOT_PASSWD_INI" \
        -e "show variables like 'version';" > /dev/null 2>&1;then
        is_password=yes
    fi
    if mysql \
        -e "show variables like 'version';" > /dev/null 2>&1;then
        is_password=no
    fi
    [ -n "$switch" ] || {
        case "$is_password" in
            yes) switch=no ;;
            no) switch=yes ;;
        esac
    }
    case "$switch" in
        yes) [[ "$is_password" == yes ]] && return 0 || {
            __; _, Password MySQL untuk root sedang dipasang:' '
            if mysql \
                -e "set password for root@localhost=PASSWORD('$mysql_root_passwd');" > /dev/null 2>&1;then
                green Password berhasil dipasang; _.
            else
                error Password gagal dipasang; x
            fi
        } ;;
        no) [[ "$is_password" == no ]] && return 0 || {
            __; _, Password MySQL untuk root sedang dicopot:' '
            if mysql \
                --defaults-extra-file="$MYSQL_ROOT_PASSWD_INI" \
                -e "set password for root@localhost=PASSWORD('');" > /dev/null 2>&1;then
                green Password berhasil dicopot.; _.
            else
                error Password gagal dicopot.; x
            fi
        } ;;
    esac
}
createFileDebian12() {
    if [ ! -f /tmp/ispconfig3_install/install/dist/conf/debian120.conf.php ];then
        fileMustExists /tmp/ispconfig3_install/install/dist/conf/debian110.conf.php
        __ Membuat file '`'debian120.conf.php'`'.
        cp /tmp/ispconfig3_install/install/dist/conf/debian110.conf.php \
           /tmp/ispconfig3_install/install/dist/conf/debian120.conf.php
        sed -i \
            -e 's,Debian 11,Debian 12,g' \
            -e 's,debian110,debian120,g' \
            -e 's,"7\.4","'$php_version'",g' \
            -e 's,/7\.4/,/'$php_version'/,g' \
            -e 's,php7\.4,php'$php_version',g' \
            /tmp/ispconfig3_install/install/dist/conf/debian120.conf.php
        # Edit informasi cron yang terlewat.
        file=/tmp/ispconfig3_install/install/dist/conf/debian120.conf.php
        string="//* cron"
        number_1=$(grep -n -F "$string" "$file" | head -1 | cut -d: -f1)
        number_1plus=$((number_1 - 1))
        number_1plus2=$((number_1 + 1))
        part1=$(sed -n '1,'$number_1plus'p' "$file")
        part2=$(sed -n $number_1plus2',$p' "$file")
        additional=$(cat << 'EOF'

//* ufw
$conf['ufw']['installed'] = false;

//* cron
$conf['cron']['installed'] = false;
EOF
        )
        echo "$part1"$'\n'"$additional"$'\n'"$part2" > "$file"
    fi
    fileMustExists /tmp/ispconfig3_install/install/dist/conf/debian120.conf.php
}
editInstallLibDebian12() {
    file=/tmp/ispconfig3_install/install/lib/install.lib.php
    string="elseif(substr(trim(file_get_contents('/etc/debian_version')),0,2) == '12')"
    edit=1
    if grep -q -F "$string" "$file";then
        __ File sudah diedit agar terdapat informasi Debian 12: $(basename "$file").
        edit=
    fi
    if [ -n "$edit" ];then
        __ Mengedit file: $(basename "$file").
        string="elseif(substr(trim(file_get_contents('/etc/debian_version')),0,2) == '11')"
        number_1=$(grep -n -F "$string" "$file" | head -1 | cut -d: -f1)
        number_1plus=$((number_1 + 6))
        number_1plus2=$((number_1 + 7))
        part1=$(sed -n '1,'$number_1plus'p' "$file")
        part2=$(sed -n $number_1plus2',$p' "$file")
        additional=$(cat << 'EOF'
            } elseif(substr(trim(file_get_contents('/etc/debian_version')),0,2) == '12') {
                $distname = 'Debian';
                $distver = 'Bookworm';
                $distconfid = 'debian120';
                $distid = 'debian60';
                $distbaseid = 'debian';
                swriteln("Operating System: Debian 12.0 (Bookworm) or compatible\n");
EOF
        )
        echo "$part1"$'\n'"$additional"$'\n'"$part2" > "$file"
        __ Verifikasi.
        if grep -q -F "$string" "$file";then
            __; green File berhasil diedit agar terdapat informasi Debian 12: $(basename "$file").; _.
        else
            __; red File gagal diedit: $(basename "$file"); _.
        fi
    fi
}

# Title.
title rcm-ispconfig-autoinstaller-nginx-php-fpm.sh
____

# Requirement, validate, and populate value.
chapter Dump variable.
[ -n "$fast" ] && isfast=' --fast' || isfast=''
ISPCONFIG_FQDN_LOCALHOST=${ISPCONFIG_FQDN_LOCALHOST:=ispconfig.localhost}
code 'ISPCONFIG_FQDN_LOCALHOST="'$ISPCONFIG_FQDN_LOCALHOST'"'
MYSQL_ROOT_PASSWD=${MYSQL_ROOT_PASSWD:=$HOME/.mysql-root-passwd.txt}
code 'MYSQL_ROOT_PASSWD="'$MYSQL_ROOT_PASSWD'"'
MYSQL_ROOT_PASSWD_INI=${MYSQL_ROOT_PASSWD_INI:=$HOME/.mysql-root-passwd.ini}
code 'MYSQL_ROOT_PASSWD_INI="'$MYSQL_ROOT_PASSWD_INI'"'
ISPCONFIG_DB_USER_HOST=${ISPCONFIG_DB_USER_HOST:=localhost}
code 'ISPCONFIG_DB_USER_HOST="'$ISPCONFIG_DB_USER_HOST'"'
ISPCONFIG_NGINX_CONFIG_FILE=${ISPCONFIG_NGINX_CONFIG_FILE:=ispconfig}
code 'ISPCONFIG_NGINX_CONFIG_FILE="'$ISPCONFIG_NGINX_CONFIG_FILE'"'
ISPCONFIG_INSTALL_DIR=${ISPCONFIG_INSTALL_DIR:=/usr/local/ispconfig}
code 'ISPCONFIG_INSTALL_DIR="'$ISPCONFIG_INSTALL_DIR'"'
delay=.5; [ -n "$fast" ] && unset delay
until [[ -n "$ispconfig_version" ]];do
    _; read -p "# Argument --ispconfig-version required: " ispconfig_version
done
code 'ispconfig_version="'$ispconfig_version'"'
until [[ -n "$roundcube_version" ]];do
    _; read -p "# Argument --roundcube-version required: " roundcube_version
done
code 'roundcube_version="'$roundcube_version'"'
until [[ -n "$phpmyadmin_version" ]];do
    _; read -p "# Argument --phpmyadmin-version required: " phpmyadmin_version
done
code 'phpmyadmin_version="'$phpmyadmin_version'"'
code 'php_version="'$php_version'"'
until [[ -n "$domain" ]];do
    _; read -p "# Argument --domain required: " domain
done
code 'domain="'$domain'"'
until [[ -n "$hostname" ]];do
    _; read -p "# Argument --hostname required: " hostname
done
code 'hostname="'$hostname'"'
fqdn_project="${hostname}.${domain}"
code fqdn_project="$fqdn_project"
case "$dns_authenticator" in
    digitalocean) ;;
    *) dns_authenticator=
esac
until [[ -n "$dns_authenticator" ]];do
    _ Available value:' '; yellow digitalocean.; _.
    _; read -p "# Argument --dns-authenticator required: " dns_authenticator
    case "$dns_authenticator" in
        digitalocean) ;;
        *) dns_authenticator=
    esac
done
code 'dns_authenticator="'$dns_authenticator'"'
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
_ _______________________________________________________________________;_.;_.;

INDENT+="    " \
rcm-mariadb-setup-ispconfig.sh $isfast --root-sure \
    && INDENT+="    " \
rcm-nginx-setup-ispconfig.sh $isfast --root-sure \
    && INDENT+="    " \
rcm-php-setup-ispconfig.sh $isfast --root-sure \
    --php-version="$php_version" \
    && INDENT+="    " \
rcm-postfix-setup-ispconfig.sh $isfast --root-sure \
    && INDENT+="    " \
rcm-ispconfig-setup-smtpd-certificate.sh $isfast --root-sure \
    --dns-authenticator="$dns_authenticator" \
    --domain="$domain" \
    && INDENT+="    " \
rcm-phpmyadmin-autoinstaller-nginx-php-fpm.sh $isfast --root-sure \
    --phpmyadmin-version="$phpmyadmin_version" \
    --php-version="$php_version" \
    && INDENT+="    " \
rcm-roundcube-autoinstaller-nginx-php-fpm.sh $isfast --root-sure \
    --roundcube-version="$roundcube_version" \
    --php-version="$php_version" \
    ; [ ! $? -eq 0 ] && x
_ _______________________________________________________________________;_.;_.;

chapter Mengecek credentials ISPConfig.
databaseCredentialIspconfig
if [[ -z "$ispconfig_db_user_password" ]];then
    __; red Informasi credentials tidak lengkap: '`'/usr/local/share/ispconfig/credential/database'`'.; x
else
    code ispconfig_db_user_password="$ispconfig_db_user_password"
fi
websiteCredentialIspconfig
if [[ -z "$ispconfig_web_user_password" ]];then
    __; red Informasi credentials tidak lengkap: '`'/usr/local/share/ispconfig/credential/website'`'.; x
else
    code ispconfig_web_user_password="$ispconfig_web_user_password"
fi
____

chapter Prepare arguments.
root="$ISPCONFIG_INSTALL_DIR/interface/web"
code root="$root"
filename="$ISPCONFIG_NGINX_CONFIG_FILE"
code filename="$filename"
server_name="$ISPCONFIG_FQDN_LOCALHOST"
code server_name="$server_name"
____
_ _______________________________________________________________________;_.;_.;

INDENT+="    " \
rcm-nginx-setup-php-fpm.sh $isfast --root-sure \
    --root="$root" \
    --filename="$filename" \
    --server-name="$server_name" \
    --php-version="$php_version" \
    ; [ ! $? -eq 0 ] && x
_ _______________________________________________________________________;_.;_.;

chapter Mengecek subdomain '`'$ISPCONFIG_FQDN_LOCALHOST'`'.
notfound=
string="$ISPCONFIG_FQDN_LOCALHOST"
string_quoted=$(sed "s/\./\\\./g" <<< "$string")
if grep -q -E "^\s*127\.0\.0\.1\s+${string_quoted}" /etc/hosts;then
    __ Subdomain terdapat pada local DNS resolver '`'/etc/hosts'`'.
else
    __ Subdomain tidak terdapat pada local DNS resolver '`'/etc/hosts'`'.
    notfound=1
fi
____

if [ -n "$notfound" ];then
    chapter Menambahkan subdomain '`'$ISPCONFIG_FQDN_LOCALHOST'`'.
    echo "127.0.0.1"$'\t'"${ISPCONFIG_FQDN_LOCALHOST}" >> /etc/hosts
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
__; magenta curl http://127.0.0.1/.well-known/__getuser.php -H "Host: ${ISPCONFIG_FQDN_LOCALHOST}"; _.
user_nginx=$(curl -Ss http://127.0.0.1/.well-known/__getuser.php -H "Host: ${ISPCONFIG_FQDN_LOCALHOST}")
__; magenta user_nginx="$user_nginx"; _.
if [ -z "$user_nginx" ];then
    error PHP-FPM User tidak ditemukan; x
fi
__ Menghapus file "${root}/.well-known/__getuser.php"
rm "${root}/.well-known/__getuser.php"
rmdir "${root}/.well-known" --ignore-fail-on-non-empty
____

php=$(cat <<'EOF'
$args = $_SERVER['argv'];
$mode = $_SERVER['argv'][1];
$file = $_SERVER['argv'][2];
$array = unserialize($_SERVER['argv'][3]);
$autoinstall = parse_ini_file($file);
if (!isset($autoinstall)) {
    exit(255);
}
$is_different = !empty(array_diff_assoc($array, $autoinstall));
switch ($mode) {
    case 'is_different':
        $is_different ? exit(0) : exit(1);
        break;
}
EOF
)

filename_path="$ISPCONFIG_INSTALL_DIR/interface/web/index.php"
filename=$(basename "$filename_path")
chapter Mengecek existing '`'$filename'`'
__; magenta filename_path=$filename_path; _.
isFileExists "$filename_path"
do_install=
do_postinstall=
if [ -n "$notfound" ];then
    do_install=1
fi
____

if [ -n "$do_install" ];then
    chapter Mengecek apakah database ISPConfig siap digunakan.
    db_found=
    # Variable di populate oleh `databaseCredentialIspconfig()`.
    if [[ -n "$ispconfig_db_name" ]];then
        __ Mengecek database '`'$ispconfig_db_name'`'.
        msg=$(mysql --silent --skip-column-names -e "select schema_name from information_schema.schemata where schema_name = '$ispconfig_db_name'")
        if [[ $msg == $ispconfig_db_name ]];then
            __ Database ditemukan.
            db_found=1
        else
            __ Database tidak ditemukan
        fi
    fi
    if [[ -n "$db_found" ]];then
        msg=$(mysql \
            --silent --skip-column-names \
            $ispconfig_db_name -e "show tables;" | wc -l)
        if [[ $msg -gt 0 ]];then
            __; red Database sudah terdapat table sejumlah '`'$msg'`'.; x
        fi
    fi
    __ Database siap digunakan.
    ____

    chapter Menginstall ISPConfig
    __ Mendownload ISPConfig
    cd /tmp
    if [ ! -f /tmp/ISPConfig-$ispconfig_version.tar.gz ];then
        wget https://www.ispconfig.org/downloads/ISPConfig-$ispconfig_version.tar.gz
    fi
    fileMustExists /tmp/ISPConfig-$ispconfig_version.tar.gz
    if [ ! -f /tmp/ispconfig3_install/install/install.php ];then
        tar xfz ISPConfig-$ispconfig_version.tar.gz
    fi
    cd - >/dev/null
    fileMustExists /tmp/ispconfig3_install/install/install.php

    if [ -f /etc/os-release ];then
        . /etc/os-release
    fi
    code 'ID="'$ID'"'
    code 'VERSION_ID="'$VERSION_ID'"'
    code 'ispconfig_version="'$ispconfig_version'"'
    eligible=0
    case $ID in
        debian)
            case "$VERSION_ID" in
                11)
                    case "$ispconfig_version" in
                        3.2.7) eligible=1 ;;
                        *) error ISPConfig Version "$ispconfig_version" not supported; x;
                    esac
                    ;;
                12)
                    case "$ispconfig_version" in
                        3.2.9) eligible=1; createFileDebian12; editInstallLibDebian12 ;;
                        3.2.10) eligible=1; createFileDebian12; editInstallLibDebian12 ;;
                        *) error ISPConfig Version "$ispconfig_version" not supported; x;
                    esac
                    ;;
                *)
                    error OS "$ID" Version "$VERSION_ID" not supported; x;
            esac
            ;;
        ubuntu)
            case "$VERSION_ID" in
                22.04)
                    case "$ispconfig_version" in
                        3.2.7) eligible=1;;
                        *) error ISPConfig Version "$ispconfig_version" not supported; x;
                    esac
                    ;;
                *)
                    error OS "$ID" Version "$VERSION_ID" not supported; x;
            esac
            ;;
        *) error OS "$ID" not supported; x;
    esac

    if [ ! -f /tmp/ispconfig3_install/install/autoinstall.ini ];then
        __ Membuat file '`'autoinstall.ini'`'.
        cp /tmp/ispconfig3_install/docs/autoinstall_samples/autoinstall.ini.sample \
           /tmp/ispconfig3_install/install/autoinstall.ini
        sed -i -E \
            -e ':a;N;$!ba;s|\[expert\]|[expert]\nconfigure_webserver=n|g' \
            /tmp/ispconfig3_install/install/autoinstall.ini
    fi
    fileMustExists /tmp/ispconfig3_install/install/autoinstall.ini
    __; _, Verifikasi file '`'autoinstall.ini'`':' '

    mysql_root_passwd="$(<$MYSQL_ROOT_PASSWD)"
    reference="$(php -r "echo serialize([
        'install_mode' => 'expert',
        'configure_webserver' => 'n',
        'hostname' => '$fqdn_project',
        'mysql_root_password' => '$mysql_root_passwd',
        'http_server' => 'nginx',
        'ispconfig_use_ssl' => 'n',
        'mysql_ispconfig_password' => '$ispconfig_db_user_password',
        'ispconfig_admin_password' => '$ispconfig_web_user_password',
    ]);")"
    is_different=
    if php -r "$php" is_different \
        /tmp/ispconfig3_install/install/autoinstall.ini \
        "$reference";then
        is_different=1
        _, Diperlukan modifikasi file '`'autoinstall.ini'`'.;_.
    else
        if [ $? -eq 255 ];then
            error Terjadi kesalahan dalam parsing file '`'autoinstall.ini'`'.; x
        fi
        _, File '`'autoinstall.ini'`' tidak ada perubahan.; _.
    fi
    if [ -n "$is_different" ];then
        __; _, Memodifikasi file '`'autoinstall.ini'`':' '
        backupFile copy /tmp/ispconfig3_install/install/autoinstall.ini
        sed -e "s,^install_mode=.*$,install_mode=expert," \
            -e "s,^configure_webserver=.*$,configure_webserver=n," \
            -e "s,^hostname=.*$,hostname=${fqdn_project}," \
            -e "s,^mysql_root_password=.*$,mysql_root_password=${mysql_root_passwd}," \
            -e "s,^http_server=.*$,http_server=nginx," \
            -e "s,^ispconfig_use_ssl=.*$,ispconfig_use_ssl=n," \
            -e "s,^ispconfig_admin_password=.*$,ispconfig_admin_password=${ispconfig_web_user_password}," \
            -e "s,^mysql_ispconfig_password=.*$,mysql_ispconfig_password=${ispconfig_db_user_password}," \
            -i /tmp/ispconfig3_install/install//autoinstall.ini
        if php -r "$php" is_different \
            /tmp/ispconfig3_install/install/autoinstall.ini \
            "$reference";then
            error Modifikasi file '`'autoinstall.ini'`' gagal.; x
        else
            green Modifikasi file '`'autoinstall.ini'`' berhasil.; _.
        fi
    fi

    __ Memasang password MySQL untuk root
    toggleMysqlRootPassword yes

    __ Mulai autoinstall.
    rmdir $ISPCONFIG_INSTALL_DIR/interface/web/
    rmdir $ISPCONFIG_INSTALL_DIR/interface/
    rmdir $ISPCONFIG_INSTALL_DIR/
    if grep -q -F '$inst->configure_postfix();' /tmp/ispconfig3_install/install/install.php;then
        sed 's|$inst->configure_postfix();|$inst->configure_postfix("dont-create-certs");|' \
            -i /tmp/ispconfig3_install/install/install.php
    fi
    sleep 2
    php /tmp/ispconfig3_install/install/install.php \
         --autoinstall=/tmp/ispconfig3_install/install/autoinstall.ini
    ____
    __ Mengecek existing '`'$filename'`'
    fileMustExists "$filename_path"
    do_postinstall=1
fi
if [ -n "$do_postinstall" ];then
    chapter Post Install
    __ Mencopot password MySQL untuk root
    toggleMysqlRootPassword no

    __ Menyimpan informasi database.
    ISPCONFIG_DB_USER=$(php -r "include '/usr/local/ispconfig/interface/lib/config.inc.php';echo DB_USER;")
    ISPCONFIG_DB_NAME=$(php -r "include '/usr/local/ispconfig/interface/lib/config.inc.php'; echo DB_DATABASE;")
    databaseCredentialIspconfig
    if [[ -z "$ispconfig_db_name" ]];then
            cat << EOF >> /usr/local/share/ispconfig/credential/database
ISPCONFIG_DB_NAME=$ISPCONFIG_DB_NAME
EOF
    fi
    if [[ -z "$ispconfig_db_user" ]];then
            cat << EOF >> /usr/local/share/ispconfig/credential/database
ISPCONFIG_DB_USER=$ISPCONFIG_DB_USER
EOF
    fi
    ____

    __ Mengubah kepemilikan directory '`'ISPConfig'`'.
    __; magenta chown -R $user_nginx:$user_nginx /usr/local/ispconfig; _.
    chown -R $user_nginx:$user_nginx /usr/local/ispconfig
fi

chapter Mengecek credentials ISPConfig.
databaseCredentialIspconfig
if [[ -z "$ispconfig_db_name" || -z "$ispconfig_db_user" ]];then
    __; red Informasi credentials tidak lengkap: '`'/usr/local/share/ispconfig/credential/database'`'.; x
else
    code ispconfig_db_name="$ispconfig_db_name"
    code ispconfig_db_user="$ispconfig_db_user"
fi
____

chapter Mengecek HTTP Response Code.
code curl http://127.0.0.1 -H '"'Host: ${ISPCONFIG_FQDN_LOCALHOST}'"'
code=$(curl -L \
    -o /dev/null -s -w "%{http_code}\n" \
    http://127.0.0.1 -H "Host: ${ISPCONFIG_FQDN_LOCALHOST}")
[[ $code =~ ^[2,3] ]] && {
    __ HTTP Response code '`'$code'`' '('Required')'.
} || {
    __; red Terjadi kesalahan. HTTP Response code '`'$code'`'.; x
}
code curl http://${ISPCONFIG_FQDN_LOCALHOST}
code=$(curl -L \
    -o /dev/null -s -w "%{http_code}\n" \
    http://127.0.0.1 -H "Host: ${ISPCONFIG_FQDN_LOCALHOST}")
__ HTTP Response code '`'$code'`'.
____

chapter Menghapus port 8080 buatan ISPConfig
isFileExists /etc/nginx/sites-enabled/000-ispconfig.vhost
reload=
if [ -L /etc/nginx/sites-enabled/000-ispconfig.vhost ];then
    __ Menghapus symlink /etc/nginx/sites-enabled/000-ispconfig.vhost
    rm /etc/nginx/sites-enabled/000-ispconfig.vhost
    reload=1
fi
____

if [ -n "$reload" ];then
    chapter Reload nginx configuration.
    __ Cleaning broken symbolic link.
    code find /etc/nginx/sites-enabled -xtype l -delete -print
    find /etc/nginx/sites-enabled -xtype l -delete -print
    if nginx -t 2> /dev/null;then
        code nginx -s reload
        nginx -s reload; sleep .5
    else
        error Terjadi kesalahan konfigurasi nginx. Gagal reload nginx.; x
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
# --hostname
# --domain
# --ispconfig-version
# --php-version
# --dns-authenticator
# --phpmyadmin-version
# --roundcube-version
# )
# FLAG_VALUE=(
# )
# CSV=(
    # long:--digitalocean,parameter:dns_authenticator,type:flag,flag_option:true=digitalocean
# )
# EOF
# clear

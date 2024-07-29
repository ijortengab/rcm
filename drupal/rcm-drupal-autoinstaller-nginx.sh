#!/bin/bash

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --domain-strict) domain_strict=1; shift ;;
        --drupal-version=*) drupal_version="${1#*=}"; shift ;;
        --drupal-version) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then drupal_version="$2"; shift; fi; shift ;;
        --drush-version=*) drush_version="${1#*=}"; shift ;;
        --drush-version) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then drush_version="$2"; shift; fi; shift ;;
        --fast) fast=1; shift ;;
        --php-version=*) php_version="${1#*=}"; shift ;;
        --php-version) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then php_version="$2"; shift; fi; shift ;;
        --prefix=*) prefix="${1#*=}"; shift ;;
        --prefix) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then prefix="$2"; shift; fi; shift ;;
        --project-name=*) project_name="${1#*=}"; shift ;;
        --project-name) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then project_name="$2"; shift; fi; shift ;;
        --project-parent-name=*) project_parent_name="${1#*=}"; shift ;;
        --project-parent-name) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then project_parent_name="$2"; shift; fi; shift ;;
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
    echo '0.3.0'
}
printHelp() {
    title RCM Drupal Auto-Installer
    _ 'Variation '; yellow Nginx PHP-FPM; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    cat << 'EOF'
Usage: rcm-drupal-autoinstaller-nginx.sh [options]

Options:
   --project-name *
        Set the project name. This should be in machine name format.
   --project-parent-name
        Set the project parent name. The parent is not have to installed before.
   --php-version *
        Set the version of PHP FPM.
   --drush-version *
        Set the version of Drush.
   --drupal-version *
        Set the version of Drupal.
   --prefix
        Set prefix directory for project.

Global Options.
   --fast
        No delay every subtask.
   --version
        Print version of this script.
   --help
        Show this help.
   --root-sure
        Bypass root checking.

Environment Variables.
   DRUPAL_DB_USER_HOST
        Default to localhost

Dependency:
   sudo
   composer
   pwgen
   curl
   rcm-nginx-setup-drupal.sh
   rcm-mariadb-setup-database.sh
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
validateMachineName() {
    local value="$1" _value
    local parameter="$2"
    if [[ $value = *" "* ]];then
        [ -n "$parameter" ]  && error "Variable $parameter can not contain space."
        return 1;
    fi
    _value=$(sed -E 's|[^a-zA-Z0-9]|_|g' <<< "$value" | sed -E 's|_+|_|g' )
    if [[ ! "$value" == "$_value" ]];then
        error "Variable $parameter can only contain alphanumeric and underscores."
        _ 'Suggest: '; yellow "$_value"; _.
        return 1
    fi
}
vercomp() {
    # https://www.google.com/search?q=bash+compare+version
    # https://stackoverflow.com/a/4025065
    if [[ $1 == $2 ]]; then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++)); do
        if [[ -z ${ver2[i]} ]];then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 2
        fi
    done
    return 0
}
databaseCredentialDrupal() {
    if [ -f "$prefix"/drupal-project/$project_dir/credential/database ];then
        local DRUPAL_DB_USER DRUPAL_DB_USER_PASSWORD
        . "$prefix"/drupal-project/$project_dir/credential/database
        drupal_db_user=$DRUPAL_DB_USER
        drupal_db_user_password=$DRUPAL_DB_USER_PASSWORD
    else
        drupal_db_user="$project_name"
        [ -n "$project_parent_name" ] && {
            drupal_db_user=$project_parent_name
        }
        drupal_db_user_password=$(pwgen -s 32 -1)
        mkdir -p "$prefix"/drupal-project/$project_dir/credential
        cat << EOF > "$prefix"/drupal-project/$project_dir/credential/database
DRUPAL_DB_USER=$drupal_db_user
DRUPAL_DB_USER_PASSWORD=$drupal_db_user_password
EOF
        chmod 0500 "$prefix"/drupal-project/$project_dir/credential
        chmod 0400 "$prefix"/drupal-project/$project_dir/credential/database
    fi
}
websiteCredentialDrupal() {
    local file="$prefix"/drupal-project/$project_dir/credential/drupal/$drupal_fqdn_localhost
    if [ -f "$file" ];then
        local ACCOUNT_NAME ACCOUNT_PASS
        . "$file"
        account_name=$ACCOUNT_NAME
        account_pass=$ACCOUNT_PASS
    else
        account_name=system
        account_pass=$(pwgen -s 32 -1)
        mkdir -p "$prefix"/drupal-project/$project_dir/credential/drupal
        cat << EOF > "$file"
ACCOUNT_NAME=$account_name
ACCOUNT_PASS=$account_pass
EOF
        chmod 0500 "$prefix"/drupal-project/$project_dir/credential
        chmod 0500 "$prefix"/drupal-project/$project_dir/credential/drupal
        chmod 0400 "$prefix"/drupal-project/$project_dir/credential/drupal/$drupal_fqdn_localhost
    fi
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

# Title.
title rcm-drupal-autoinstaller-nginx.sh
____

# Requirement, validate, and populate value.
chapter Dump variable.
DRUPAL_DB_USER_HOST=${DRUPAL_DB_USER_HOST:=localhost}
code 'DRUPAL_DB_USER_HOST="'$DRUPAL_DB_USER_HOST'"'
if [ -z "$project_name" ];then
    error "Argument --project-name required."; x
fi
code 'project_name="'$project_name'"'
if ! validateMachineName "$project_name" project_name;then x; fi
code 'project_parent_name="'$project_parent_name'"'
if [ -n "$project_parent_name" ];then
    if ! validateMachineName "$project_parent_name" project_parent_name;then x; fi
fi
code 'domain_strict="'$domain_strict'"'

delay=.5; [ -n "$fast" ] && unset delay
if [ -z "$drupal_version" ];then
    error "Argument --drupal-version required."; x
fi
code 'drupal_version="'$drupal_version'"'
vercomp 8 "$drupal_version"
if [[ $? -lt 2 ]];then
    red Hanya mendukung Drupal versi '>=' 8.; x
fi
code 'drush_version="'$drush_version'"'
code 'php_version="'$php_version'"'
project_dir="$project_name"
drupal_nginx_config_file=drupal_"$project_name"
drupal_fqdn_localhost="$project_name".drupal.localhost
drupal_db_name="drupal_${project_name}"
sites_subdir=$project_name
[ -n "$project_parent_name" ] && {
    project_dir="$project_parent_name"
    drupal_nginx_config_file=drupal_"$project_parent_name"__"$project_name"
    drupal_fqdn_localhost="$project_name"."$project_parent_name".drupal.localhost
    drupal_db_name="drupal_${project_parent_name}__${project_name}"
    sites_subdir="${project_parent_name}__${project_name}"
}
sites_subdir=$(tr _ - <<< "$sites_subdir")
code 'project_dir="'$project_dir'"'
code 'drupal_nginx_config_file="'$drupal_nginx_config_file'"'
code 'drupal_fqdn_localhost="'$drupal_fqdn_localhost'"'
code 'drupal_db_name="'$drupal_db_name'"'
code 'sites_subdir="'$sites_subdir'"'
if [ -z "$prefix" ];then
    prefix=/var/www
fi
code 'prefix="'$prefix'"'
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

chapter Mengecek direktori project '`'"$prefix"/drupal-project/$project_dir/drupal/web'`'.
notfound=
if [ -d "$prefix"/drupal-project/$project_dir/drupal/web ] ;then
    __ Direktori ditemukan.
else
    __ Direktori tidak ditemukan.
    notfound=1
fi
____

if [ -n "$notfound" ];then
    chapter Membuat direktori project.
    code mkdir -p "$prefix"/drupal-project/$project_dir/drupal/web
    mkdir -p "$prefix"/drupal-project/$project_dir/drupal/web
    if [ -d "$prefix"/drupal-project/$project_dir/drupal/web ] ;then
        __; green Direktori berhasil dibuat.; _.
    else
        __; red Direktori gagal dibuat.; x
    fi
    ____
fi

chapter Prepare arguments.
root="$prefix/drupal-project/$project_dir/drupal/web"
code root="$root"
filename="$drupal_nginx_config_file"
code filename="$filename"
server_name="$drupal_fqdn_localhost"
code server_name="$server_name"
____

INDENT+="    " \
rcm-nginx-setup-drupal.sh \
    --root="$root" \
    --filename="$filename" \
    --server-name="$server_name" \
    --fastcgi-pass="unix:/run/php/php${php_version}-fpm.sock" \
    ; [ ! $? -eq 0 ] && x

chapter Mengecek subdomain '`'$drupal_fqdn_localhost'`'.
notfound=
string="$drupal_fqdn_localhost"
string_quoted=$(sed "s/\./\\\./g" <<< "$string")
if grep -q -E "^\s*127\.0\.0\.1\s+${string_quoted}" /etc/hosts;then
    __ Subdomain terdapat pada local DNS resolver '`'/etc/hosts'`'.
else
    __ Subdomain tidak terdapat pada local DNS resolver '`'/etc/hosts'`'.
    notfound=1
fi
____

if [ -n "$notfound" ];then
    chapter Menambahkan subdomain '`'$drupal_fqdn_localhost'`'.
    echo "127.0.0.1"$'\t'"${drupal_fqdn_localhost}" >> /etc/hosts
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
__; magenta curl http://127.0.0.1/.well-known/__getuser.php -H "Host: ${drupal_fqdn_localhost}"; _.
user_nginx=$(curl -Ss http://127.0.0.1/.well-known/__getuser.php -H "Host: ${drupal_fqdn_localhost}")
__; magenta user_nginx="$user_nginx"; _.
if [ -z "$user_nginx" ];then
    error PHP-FPM User tidak ditemukan; x
fi
__ Menghapus file "${root}/.well-known/__getuser.php"
rm "${root}/.well-known/__getuser.php"
rmdir "${root}/.well-known" --ignore-fail-on-non-empty
rmdir "$prefix/drupal-project/$project_dir/drupal/web" --ignore-fail-on-non-empty
____

chapter Mengecek file '`'composer.json'`' untuk project '`'drupal/recommended-project'`'
notfound=
if [ -f "$prefix"/drupal-project/$project_dir/drupal/composer.json ];then
    __ File '`'composer.json'`' ditemukan.
else
    __ File '`'composer.json'`' tidak ditemukan.
    notfound=1
fi
____

if [ -n "$notfound" ];then
    chapter Mendownload composer.json untuk project '`'drupal/recommended-project'`'.
    mkdir -p "$prefix"/drupal-project/$project_dir/drupal
    chown $user_nginx:$user_nginx "$prefix"/drupal-project/$project_dir/drupal
    cd "$prefix"/drupal-project/$project_dir/drupal
    # Jika version hanya angka 9 atau 10, maka ubah menjadi ^9 atau ^10.
    if [[ "$drupal_version" =~ ^[0-9]+$ ]];then
        _drupal_version="$drupal_version"
        drupal_version="^${drupal_version}"
    fi
    # https://www.drupal.org/docs/develop/using-composer/manage-dependencies
    code composer create-project --no-install drupal/recommended-project . $drupal_version
    # Code dibawah ini tidak mendetect environment variable terutama http_proxy,
    # sehingga composer gagal mendownload.
    # sudo -u $user_nginx HOME='/tmp' -s composer create-project --no-install drupal/recommended-project . $drupal_version
    # Alternative menggunakan code dibawah ini.
    # Credit: https://stackoverflow.com/a/8633575
    sudo -u $user_nginx HOME='/tmp' -E bash -c "composer create-project --no-install drupal/recommended-project . $drupal_version"
    drupal_version="$_drupal_version"
    cd - >/dev/null
    fileMustExists "$prefix/drupal-project/$project_dir/drupal/composer.json"
    ____
fi

chapter Mengecek dependencies menggunakan Composer.
notfound=
cd "$prefix"/drupal-project/$project_dir/drupal
msg=$(sudo -u $user_nginx HOME='/tmp' -s composer show 2>&1)
if ! grep -q '^No dependencies installed.' <<< "$msg";then
    __ Dependencies installed.
else
    __ Dependencies not installed.
    notfound=1
fi
cd - >/dev/null
____

if [ -n "$notfound" ];then
    chapter Mendownload dependencies menggunakan Composer.
    cd "$prefix"/drupal-project/$project_dir/drupal
    code composer -v install
    # sudo -u $user_nginx HOME='/tmp' -s composer -v install
    sudo -u $user_nginx HOME='/tmp' -E bash -c 'composer -v install'
    cd - >/dev/null
    ____
fi

chapter Mengecek drush.
notfound=
cd "$prefix"/drupal-project/$project_dir/drupal
if sudo -u $user_nginx HOME='/tmp' -s composer show | grep -q '^drush/drush';then
    __ Drush exists.
else
    __ Drush is not exists.
    notfound=1
fi
cd - >/dev/null
____

if [ -n "$notfound" ];then
    chapter Memasang '`'Drush'`' menggunakan Composer.
    cd "$prefix"/drupal-project/$project_dir/drupal
    # Jika version hanya angka 9 atau 10, maka ubah menjadi ^9 atau ^10.
    if [[ "$drush_version" =~ ^[0-9]+$ ]];then
        _drush_version="$drush_version"
        drush_version="^${drush_version}"
    fi
    code composer -v require drush/drush "$drush_version"
    # sudo -u $user_nginx HOME='/tmp' -s composer -v require drush/drush
    sudo -u $user_nginx HOME='/tmp' -E bash -c 'composer -v require drush/drush '"$drush_version"
    if [ -f "$prefix"/drupal-project/$project_dir/drupal/vendor/bin/drush ];then
        __; green Binary Drush is exists.
    else
        __; red Binary Drush is not exists.; x
    fi
    drush_version="$_drush_version"
    cd - >/dev/null
    ____
fi

PATH="$prefix"/drupal-project/$project_dir/drupal/vendor/bin:$PATH

chapter Mengecek domain-strict.
if [ -n "$domain_strict" ];then
    __ Instalasi Drupal tidak menggunakan '`'default'`'.
else
    __ Instalasi Drupal menggunakan '`'default'`'.
fi
____

chapter Mengecek apakah Drupal sudah terinstall sebagai singlesite '`'default'`'.
cd "$prefix"/drupal-project/$project_dir/drupal
default_installed=
if drush status --field=db-status | grep -q '^Connected$';then
    __ Drupal site default installed.
    default_installed=1
else
    __ Drupal site default not installed.
fi
cd - >/dev/null
____

install_type=singlesite
chapter Mengecek Drupal multisite
if [ -n "$project_parent_name" ];then
    __ Project parent didefinisikan. Menggunakan Drupal multisite.
    if [ -f "$prefix"/drupal-project/$project_dir/drupal/web/sites/sites.php ];then
        __ Files '`'sites.php'`' ditemukan.
    else
        __ Files '`'sites.php'`' belum ditemukan.
    fi
    install_type=multisite
else
    __ Project parent tidak didefinisikan.
fi
if [[ -n "$domain_strict"  && -z "$default_installed" ]];then
    __ Domain strict didefinisikan. Menggunakan Drupal multisite.
    install_type=multisite
else
    __ Domain strict tidak didefinisikan.
fi
____

# allsite=("${domain[@]}")
# allsite+=("${drupal_fqdn_localhost}")
allsite=("${drupal_fqdn_localhost}")
multisite_installed=
for eachsite in "${allsite[@]}" ;do
    chapter Mengecek apakah Drupal sudah terinstall sebagai multisite '`'$eachsite'`'.
    if [[ "sites/${sites_subdir}" == $(drush status --uri=$eachsite --field=site) ]];then
        __ Site direktori dari domain '`'$eachsite'`' sesuai, yakni: '`'sites/$sites_subdir'`'.
        if drush status --uri=$eachsite --field=db-status | grep -q '^Connected$';then
            __ Drupal site '`'$eachsite'`' installed.
            multisite_installed=1
        else
            __ Drupal site '`'$eachsite'`' not installed yet.
        fi
    else
        __ Site direktori dari domain '`'$eachsite'`' tidak sesuai.
    fi
    ____
done

chapter Dump variable installed.
code install_type="$install_type"
code domain_strict="$domain_strict"
code default_installed="$default_installed"
code multisite_installed="$multisite_installed"
____

if [[ "$install_type" == singlesite && -z "$domain_strict" && -z "$default_installed" && -n "$multisite_installed" ]];then
    chapter Drupal multisite sudah terinstall.
    __ Sebelumnya sudah di-install dengan option --domain-strict.
    __ Agar proses dapat dilanjutkan, perlu kerja manual dengan memperhatikan sbb:
    __ - Move file '`'settings.php'`' dari '`'sites/'<'sites_subdir'>''`' menjadi '`'sites/default'`'.
    __ - Move file-file script PHP yang di-include oleh '`'settings.php'`'.
    __ - Mengubah informasi public files pada config. Biasanya berada di '`'sites/'<'sites_subdir'>'/files'`'.
    __ - Menghapus informasi site di '`'sites/sites.php'`'.
    __; red Process terminated; x
fi

if [[ -n "$domain_strict" && -n "$default_installed" ]];then
    chapter Drupal singlesite default sudah terinstall.
    __ Option --domain-strict tidak bisa digunakan.
    __ Agar proses dapat dilanjutkan, perlu kerja manual dengan memperhatikan sbb:
    __ - Move file '`'settings.php'`' dari '`'sites/default'`' menjadi '`'sites/'<'sites_subdir'>''`'.
    __ - Move file-file script PHP yang di-include oleh '`'settings.php'`'.
    __ - Mengubah informasi public files pada config. Biasanya berada di '`'sites/default/files'`'.
    __ - Menghapus informasi site di '`'sites/sites.php'`'.
    __; red Process terminated; x
fi

chapter Mengecek database credentials: '`'$prefix/drupal-project/$project_dir/credential/database'`'.
databaseCredentialDrupal
if [[ -z "$drupal_db_user" || -z "$drupal_db_user_password" ]];then
    __; red Informasi credentials tidak lengkap: '`'$prefix/drupal-project/$project_dir/credential/database'`'.; x
else
    code drupal_db_user="$drupal_db_user"
    code drupal_db_user_password="$drupal_db_user_password"
fi
____

chapter Prepare arguments.
db_name="$drupal_db_name"
code db_name="$db_name"
db_user="$drupal_db_user"
code db_user="$db_user"
db_user_password="$drupal_db_user_password"
code db_user_password="$db_user_password"
db_user_host="$DRUPAL_DB_USER_HOST"
code db_user_host="$db_user_host"
____

INDENT+="    " \
rcm-mariadb-setup-database.sh \
    --db-name="$db_name" \
    --db-user="$db_user" \
    --db-user-host="$db_user_host" \
    --db-user-password="$db_user_password" \
    ; [ ! $? -eq 0 ] && x

chapter Mengecek website credentials: '`'$prefix/drupal-project/$project_dir/credential/drupal/$drupal_fqdn_localhost'`'.
websiteCredentialDrupal
if [[ -z "$account_name" || -z "$account_pass" ]];then
    __; red Informasi credentials tidak lengkap: '`'$prefix/drupal-project/$project_dir/credential/drupal/$drupal_fqdn_localhost'`'.; x
else
    code account_name="$account_name"
    code account_pass="$account_pass"
fi
____

if [[ $install_type == 'singlesite' && -z "$default_installed" ]];then
    chapter Install Drupal site default.
    code drush site:install --yes \
        --account-name="$account_name" --account-pass="$account_pass" \
        --db-url=mysql://${drupal_db_user}:${drupal_db_user_password}@${DRUPAL_DB_USER_HOST}/${drupal_db_name}
    sudo -u $user_nginx HOME='/tmp' PATH="$prefix"/drupal-project/$project_dir/drupal/vendor/bin:$PATH -s \
        drush site:install --yes \
            --account-name="$account_name" --account-pass="$account_pass" \
            --db-url=mysql://${drupal_db_user}:${drupal_db_user_password}@${DRUPAL_DB_USER_HOST}/${drupal_db_name}
    if drush status --field=db-status | grep -q '^Connected$';then
        __; green Drupal site default installed.
    else
        __; red Drupal site default not installed.; x
    fi
    ____
fi

if [[ $install_type == 'multisite' && -z "$multisite_installed" ]];then
    chapter Install Drupal multisite.
    code drush site:install --yes \
        --account-name="$account_name" --account-pass="$account_pass" \
        --db-url=mysql://${drupal_db_user}:${drupal_db_user_password}@${DRUPAL_DB_USER_HOST}/${drupal_db_name} \
        --sites-subdir=${sites_subdir}
    sudo -u $user_nginx HOME='/tmp' PATH="$prefix"/drupal-project/$project_dir/drupal/vendor/bin:$PATH -s \
        drush site:install --yes \
            --account-name="$account_name" --account-pass="$account_pass" \
            --db-url=mysql://${drupal_db_user}:${drupal_db_user_password}@${DRUPAL_DB_USER_HOST}/${drupal_db_name} \
            --sites-subdir=${sites_subdir}
    if [ -f "$prefix"/drupal-project/$project_dir/drupal/web/sites/sites.php ];then
        __; green Files '`'sites.php'`' ditemukan.; _.
    else
        __; red Files '`'sites.php'`' tidak ditemukan.; x
    fi
    php=$(cat <<'EOF'
$args = $_SERVER['argv'];
array_shift($args);
$file = $args[0];
array_shift($args);
$sites_subdir = $args[0];
array_shift($args);
include($file);
if (!isset($sites)) {
    $sites = [];
}
while ($site = array_shift($args)) {
    $sites[$site] = $sites_subdir;
}
$content = '$sites = '.var_export($sites, true).';'.PHP_EOL;
$content = <<< EOF
<?php
$content
EOF;
file_put_contents($file, $content);
EOF
)
    sudo -u $user_nginx \
        php -r "$php" \
            "$prefix"/drupal-project/$project_dir/drupal/web/sites/sites.php \
            "$sites_subdir" \
            "${allsite[@]}"
    error=
    for eachsite in "${allsite[@]}" ;do
        if [[ "sites/${sites_subdir}" == $(drush status --uri=$eachsite --field=site) ]];then
            __; green Site direktori dari domain '`'$eachsite'`' sesuai, yakni: '`'sites/$sites_subdir'`'.; _.
        else
            __; red Site direktori dari domain '`'$eachsite'`' tidak sesuai.
            error=1
        fi
        if drush status --uri=$eachsite --field=db-status | grep -q '^Connected$';then
            __; green Drupal site '`'$eachsite'`' installed.; _.
        else
            __; red Drupal site '`'$eachsite'`' not installed yet.
            error=1
        fi
    done
    if [ -n "$error" ];then
        x
    fi
    ____
fi

chapter Mengecek HTTP Response Code.
code curl http://127.0.0.1 -H '"'Host: ${drupal_fqdn_localhost}'"'
code=$(curl -L \
    -o /dev/null -s -w "%{http_code}\n" \
    http://127.0.0.1 -H "Host: ${drupal_fqdn_localhost}")
[[ $code =~ ^[2,3] ]] && {
    __ HTTP Response code '`'$code'`' '('Required')'.
} || {
    __; red Terjadi kesalahan. HTTP Response code '`'$code'`'.; x
}
code curl http://${drupal_fqdn_localhost}
code=$(curl -L \
    -o /dev/null -s -w "%{http_code}\n" \
    http://127.0.0.1 -H "Host: ${drupal_fqdn_localhost}")
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
# --domain-strict
# )
# VALUE=(
# --drupal-version
# --drush-version
# --php-version
# --project-name
# --project-parent-name
# --prefix
# )
# FLAG_VALUE=(
# )
# EOF
# clear

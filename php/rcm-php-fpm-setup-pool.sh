#!/bin/bash

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --fast) fast=1; shift ;;
        --php-fpm-user=*) php_fpm_user="${1#*=}"; shift ;;
        --php-fpm-user) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then php_fpm_user="$2"; shift; fi; shift ;;
        --php-version=*) php_version="${1#*=}"; shift ;;
        --php-version) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then php_version="$2"; shift; fi; shift ;;
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

# Command.
command="$1"; shift
if [ -n "$command" ];then
    case "$command" in
        get) ;;
        *) echo -e "\e[91m""Command ${command} is unknown.""\e[39m"; exit 1
    esac
fi

# Functions.
printVersion() {
    echo '0.15.1'
}
printHelp() {
    title RCM PHP Setup
    _ 'Variation '; yellow ISPConfig; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    nginx_user=
    conf_nginx=`command -v nginx > /dev/null && command -v nginx > /dev/null && nginx -V 2>&1 | grep -o -P -- '--conf-path=\K(\S+)'`
    if [ -f "$conf_nginx" ];then
        nginx_user=`grep -o -P '^user\s+\K([^;]+)' "$conf_nginx"`
    fi
    [ -n "$nginx_user" ] && { nginx_user="${nginx_user},"; }
    cat << EOF
Usage: rcm-php-fpm-setup-pool [options]

Available commands: get.

Options:
   --php-version *
        Set the version of PHP. Available values: [a], [b], or other.
        [a]: 8.2
        [b]: 8.3
   --php-fpm-user
        Set the system user of PHP FPM. Available values: `echo $nginx_user``cut -d: -f1 /etc/passwd | while read line; do [ -d /home/$line ] && echo " ${line}"; done | tr $'\n' ','` or other.

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
   PHP_FPM_POOL_DIRECTORY
        Default to /etc/php/[php-version]/fpm/pool.d
   PHP_FPM_FILENAME_PATTERN
        Default to [php-fpm-user]
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

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

# Title.
title rcm-php-fpm-setup-pool
____

# Requirement, validate, and populate value.
chapter Dump variable.
delay=.5; [ -n "$fast" ] && unset delay
code 'command="'$command'"'
if [ -z "$php_version" ];then
    error "Argument --php-version required."; x
fi
if [ -z "$php_fpm_user" ];then
    error "Argument --php-fpm-user required."; x
fi
code 'php_version="'$php_version'"'
code 'php_fpm_user="'$php_fpm_user'"'
PHP_FPM_POOL_DIRECTORY=${PHP_FPM_POOL_DIRECTORY:=/etc/php/[php-version]/fpm/pool.d}
find='[php-version]'
replace="$php_version"
PHP_FPM_POOL_DIRECTORY="${PHP_FPM_POOL_DIRECTORY/"$find"/"$replace"}"
code 'PHP_FPM_POOL_DIRECTORY="'$PHP_FPM_POOL_DIRECTORY'"'
PHP_FPM_FILENAME_PATTERN=${PHP_FPM_FILENAME_PATTERN:=[php-fpm-user]}
find='[php-fpm-user]'
replace="$php_fpm_user"
PHP_FPM_FILENAME_PATTERN="${PHP_FPM_FILENAME_PATTERN/"$find"/"$replace"}"
code 'PHP_FPM_FILENAME_PATTERN="'$PHP_FPM_FILENAME_PATTERN'"'
nginx_user=
conf_nginx=`command -v nginx > /dev/null && command -v nginx > /dev/null && nginx -V 2>&1 | grep -o -P -- '--conf-path=\K(\S+)'`
if [ -f "$conf_nginx" ];then
    nginx_user=`grep -o -P '^user\s+\K([^;]+)' "$conf_nginx"`
fi
code 'nginx_user="'$nginx_user'"'
if [ -z "$nginx_user" ];then
    error "Variable \$nginx_user failed to populate."; x
fi
____

php=$(cat <<'EOF'
// https://stackoverflow.com/questions/17316873/convert-array-to-an-ini-file
// https://stackoverflow.com/a/17317168
function arr2ini(array $a, array $parent = array())
{
    $out = '';
    foreach ($a as $k => $v)
    {
        if (is_array($v))
        {
            //subsection case
            //merge all the sections into one array...
            $sec = array_merge((array) $parent, (array) $k);
            //add section information to the output
            $out .= '[' . join('.', $sec) . ']' . PHP_EOL;
            //recursively traverse deeper
            $out .= arr2ini($v, $sec);
        }
        else
        {
            //plain key->value case
            $out .= "$k=$v" . PHP_EOL;
        }
    }
    return $out;
}
$mode = $_SERVER['argv'][1];
$file = $_SERVER['argv'][2];
switch ($mode) {
    case 'is_exists':
        $php_fpm_user = $_SERVER['argv'][3];
        $array = parse_ini_file($file, true);
        while($pool = array_shift($array)) {
            if (array_key_exists('user', $pool) && $pool['user'] == $php_fpm_user) {
                exit(0);
            }
        }
        exit(1);
        break;
    case 'create':
        $array = unserialize($_SERVER['argv'][3]);
        $content = arr2ini($array);
        file_put_contents($file, $content);
        break;
    case 'get':
        $php_fpm_user = $_SERVER['argv'][3];
        $what = $_SERVER['argv'][4];
        $array = parse_ini_file($file, true);
        while($pool = array_shift($array)) {
            if (array_key_exists('user', $pool) && $pool['user'] == $php_fpm_user && array_key_exists('listen', $pool)) {
                echo $pool['listen'];
                break 2;
            }
        }
        break;
}

EOF
)

chapter Mengecek file '*.conf' yang mengandung user '`'$php_fpm_user'`'
found=
found_file=
while read file; do
    if php -r "$php" is_exists "$file" "$php_fpm_user";then
        found=1
        found_file="$file"
        break;
    fi
done <<< `ls "$PHP_FPM_POOL_DIRECTORY"/*.conf`

if [ -n "$found" ];then
    __ Ditemukan PHP-FPM user '`'"$php_fpm_user"'`' pada file "$found_file"
else
    __ Tidak ditemukan PHP-FPM user '`'"$php_fpm_user"'`'.
fi
____

restart=
if [ -z "$found" ];then
    reference="$(php -r "echo serialize([
        '$php_fpm_user' => [
            'user' => '$php_fpm_user',
            'group' => '$php_fpm_user',
            'listen' => '/run/php/php${php_version}-fpm-${php_fpm_user}.sock',
            'listen.owner' => '$nginx_user',
            'listen.group' => '$nginx_user',
            'pm' => 'dynamic',
            'pm.max_children' => '5',
            'pm.start_servers' => '2',
            'pm.min_spare_servers' => '1',
            'pm.max_spare_servers' => '3',
        ]
    ]);")"

    chapter Membuat file PHP-FPM config.
    code 'file_config="'${PHP_FPM_POOL_DIRECTORY}/${PHP_FPM_FILENAME_PATTERN}.conf'"'
    file_config="${PHP_FPM_POOL_DIRECTORY}/${PHP_FPM_FILENAME_PATTERN}.conf"
    if [ -f "$file_config" ];then
        __ Backup file "$file_config".
        backupFile move "$file_config"
    fi
    __ Membuat file '`'"$file_config"'`'.
    php -r "$php" create "$file_config" "$reference"
    fileMustExists "$file_config"
    restart=1
    ____
fi

if [ -n "$restart" ];then
    chapter Restart PHP-FPM configuration.
    code /etc/init.d/php${php_version}-fpm restart
    /etc/init.d/php${php_version}-fpm restart
    ____
fi

if [[ "$command" == get ]];then
    what="$1"; shift
    php -r "$php" get "$found_file" "$php_fpm_user" "$what"
fi

exit 0

# parse-options.sh \
# --without-end-options-double-dash \
# --compact \
# --clean \
# --no-hash-bang \
# --no-original-arguments \
# --no-error-invalid-options \
# --no-error-require-arguments << EOF
# FLAG=(
# --fast
# --version
# --help
# --root-sure
# )
# VALUE=(
# --php-version
# --php-fpm-user
# )
# FLAG_VALUE=(
# )
# EOF

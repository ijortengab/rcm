#!/bin/bash

# Parse arguments. Generated by parse-options.sh.
_new_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) help=1; shift ;;
        --version) version=1; shift ;;
        --config-suffix-name=*) config_suffix_name="${1#*=}"; shift ;;
        --config-suffix-name) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then config_suffix_name="$2"; shift; fi; shift ;;
        --fast) fast=1; shift ;;
        --php-fpm-user=*) php_fpm_user="${1#*=}"; shift ;;
        --php-fpm-user) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then php_fpm_user="$2"; shift; fi; shift ;;
        --php-version=*) php_version="${1#*=}"; shift ;;
        --php-version) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then php_version="$2"; shift; fi; shift ;;
        --project-name=*) project_name="${1#*=}"; shift ;;
        --project-name) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then project_name="$2"; shift; fi; shift ;;
        --project-parent-name=*) project_parent_name="${1#*=}"; shift ;;
        --project-parent-name) if [[ ! $2 == "" && ! $2 =~ (^--$|^-[^-]|^--[^-]) ]]; then project_parent_name="$2"; shift; fi; shift ;;
        --root-sure) root_sure=1; shift ;;
        --with-autocreate-user) autocreate_user=1; shift ;;
        --without-autocreate-user) autocreate_user=0; shift ;;
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
    echo '0.16.14'
}
printHelp() {
    title RCM PHP-FPM Setup Project Config
    _ 'Variation '; yellow Default; _.
    _ 'Version '; yellow `printVersion`; _.
    _.
    nginx_user=
    conf_nginx=`command -v nginx > /dev/null && command -v nginx > /dev/null && nginx -V 2>&1 | grep -o -P -- '--conf-path=\K(\S+)'`
    if [ -f "$conf_nginx" ];then
        nginx_user=`grep -o -P '^user\s+\K([^;]+)' "$conf_nginx"`
    fi
    [ -n "$nginx_user" ] && { nginx_user=" ${nginx_user},"; }
    cat << EOF
Usage: rcm-php-fpm-setup-project-config [options]

Available commands: get.

Options:
   --php-version *
        Set the version of PHP. Available values: [a], [b], or other.
        [a]: 8.2
        [b]: 8.3
   --php-fpm-user
        Set the Unix user that used by PHP FPM. Default value is the user that used by web server. Available values:${nginx_user}`cut -d: -f1 /etc/passwd | while read line; do [ -d /home/$line ] && echo " ${line}"; done | tr $'\n' ','` or other. If the user does not exists, it will be autocreate as reguler user.
   --project-name *
        Set the project name. This should be in machine name format.
   --project-parent-name
        Set the project parent name. The parent is not have to exists before.
   --config-suffix-name
        The config suffix name.
   --without-autocreate-user ^
        Skip autocreate Unix user while config is created. Default to --with-autocreate-user.

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

Dependency:
   nginx
EOF
}

# Help and Version.
[ -n "$help" ] && { printHelp; exit 1; }
[ -n "$version" ] && { printVersion; exit 1; }

# Title.
title rcm-php-fpm-setup-project-config
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
backupFile() {
    local mode="$1"
    local oldpath="$2" i newpath
    local target_dir="$3"
    i=1
    dirname=$(dirname "$oldpath")
    basename=$(basename "$oldpath")
    if [ -n "$target_dir" ];then
        case "$target_dir" in
            parent) dirname=$(dirname "$dirname") ;;
            *) dirname="$target_dir"
        esac
    fi
    [ -d "$dirname" ] || { echo 'Directory is not exists.' >&2; return 1; }
    newpath="${dirname}/${basename}.${i}"
    if [ -f "$newpath" ]; then
        let i++
        newpath="${dirname}/${basename}.${i}"
        while [ -f "$newpath" ] ; do
            let i++
            newpath="${dirname}/${basename}.${i}"
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

# Requirement, validate, and populate value.
chapter Dump variable.
delay=.5; [ -n "$fast" ] && unset delay
code 'command="'$command'"'
nginx_user=
conf_nginx=`command -v nginx > /dev/null && command -v nginx > /dev/null && nginx -V 2>&1 | grep -o -P -- '--conf-path=\K(\S+)'`
if [ -f "$conf_nginx" ];then
    nginx_user=`grep -o -P '^user\s+\K([^;]+)' "$conf_nginx"`
fi
code 'nginx_user="'$nginx_user'"'
if [ -z "$nginx_user" ];then
    error "Variable \$nginx_user failed to populate."; x
fi
if [ -z "$php_version" ];then
    error "Argument --php-version required."; x
fi
code 'php_version="'$php_version'"'
if [ -z "$php_fpm_user" ];then
    error "Argument --php-fpm-user required."; x
fi
code 'php_fpm_user="'$php_fpm_user'"'
if [ -z "$project_name" ];then
    error "Argument --project-name required."; x
fi
code 'project_name="'$project_name'"'
code 'project_parent_name="'$project_parent_name'"'
section_name="$project_name"
[ -n "$project_parent_name" ] && {
    section_name="${project_parent_name}__${project_name}"
}
config_file="$project_name"
[ -n "$project_parent_name" ] && {
    config_file="${project_parent_name}__${project_name}"
}
[ -n "$config_suffix_name" ] && {
    section_name="${section_name}__${config_suffix_name}"
    config_file="${config_file}__${config_suffix_name}"
}
config_file+=".conf"
code 'section_name="'$section_name'"'
code 'config_file="'$config_file'"'
PHP_FPM_POOL_DIRECTORY=${PHP_FPM_POOL_DIRECTORY:=/etc/php/[php-version]/fpm/pool.d}
find='[php-version]'
replace="$php_version"
PHP_FPM_POOL_DIRECTORY="${PHP_FPM_POOL_DIRECTORY/"$find"/"$replace"}"
code 'PHP_FPM_POOL_DIRECTORY="'$PHP_FPM_POOL_DIRECTORY'"'
[ -z "$autocreate_user" ] && autocreate_user=1
[ "$autocreate_user" == 0 ] && autocreate_user=
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
        $section_name = $_SERVER['argv'][3];
        if (file_exists($file)) {
            $array = parse_ini_file($file, true);
            if (array_key_exists($section_name, $array)) {
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
        $section_name = $_SERVER['argv'][3];
        $what = $_SERVER['argv'][4];
        if (file_exists($file)) {
            $array = parse_ini_file($file, true);
            if (array_key_exists($section_name, $array)) {
                if (array_key_exists($what, $array[$section_name])) {
                    echo $array[$section_name][$what];
                    exit(0);
                }
            }
        }
        exit(1);
        break;
}

EOF
)

chapter Mengecek file '*.conf' yang mengandung section '`'$section_name'`'
found=
found_file=
while read file; do
    # if php -r "$php" is_exists "$file" "$section_name";then
        # found=1
        # found_file="$file"
        # break;
    # fi
    if grep -q -F "[$section_name]" "$file";then
        found=1
        found_file="$file"
        break;
    fi
done <<< `ls "$PHP_FPM_POOL_DIRECTORY"/*.conf`

if [ -n "$found" ];then
    __ Ditemukan section '`'"$section_name"'`' pada file "$found_file"
else
    __ Tidak ditemukan section '`'"$section_name"'`'.
fi
____

restart=
if [ -z "$found" ];then
    reference="$(php -r "echo serialize([
        '$section_name' => [
            'user' => '$php_fpm_user',
            'group' => '$php_fpm_user',
            'listen' => '/run/php/php${php_version}-fpm-${section_name}.sock',
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
    config_file="${PHP_FPM_POOL_DIRECTORY}/${config_file}"
    code 'config_file="'$config_file'"'
    if [ -f "$config_file" ];then
        __ Backup file "$config_file".
        backupFile move "$config_file"
    fi
    __ Membuat file '`'"$config_file"'`'.
    php -r "$php" create "$config_file" "$reference"
    fileMustExists "$config_file"
    found_file="$config_file"
    restart=1
    ____
fi

found=1
if [ -n "$restart" ];then
    chapter Mengecek PHP-FPM User.
    code id -u '"'$php_fpm_user'"'
    if id "$php_fpm_user" >/dev/null 2>&1; then
        __ User '`'$php_fpm_user'`' found.
    else
        __ User '`'$php_fpm_user'`' not found.;
        found=
    fi
    ____
fi
if [ -z "$found" ];then
    chapter Membuat Unix user.
    if [ -n "$autocreate_user" ];then
        code adduser $php_fpm_user --disabled-password --gecos "''"
        adduser "$php_fpm_user" --disabled-password --gecos ''
    else
        __ Flag --without-autocreate-user ditemukan.
        error User tidak dapat dibuat; x
    fi
    ____
fi

if [ -n "$restart" ];then
    chapter Restart PHP-FPM configuration.
    code /etc/init.d/php${php_version}-fpm restart
    /etc/init.d/php${php_version}-fpm restart 2>&1 &>/dev/null
    ____
fi

if [[ "$command" == get ]];then
    what="$1"; shift
    php -r "$php" get "$found_file" "$section_name" "$what"
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
# --php-version
# --php-fpm-user
# --project-name
# --project-parent-name
# --config-suffix-name
# )
# MULTIVALUE=(
# )
# FLAG_VALUE=(
# )
# CSV=(
    # 'long:--with-autocreate-user,parameter:autocreate_user'
    # 'long:--without-autocreate-user,parameter:autocreate_user,flag_option:reverse'
# )
# EOF
# clear

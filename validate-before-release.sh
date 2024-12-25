#!/bin/bash

# Common Functions.
red() { echo -ne "\e[91m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
green() { echo -ne "\e[92m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
yellow() { echo -ne "\e[93m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
blue() { echo -ne "\e[94m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
magenta() { echo -ne "\e[95m" >&2; echo -n "$@" >&2; echo -ne "\e[39m" >&2; }
_,() { echo -n "$@" >&2; }
_.() { echo >&2; }
x() { echo >&2; exit 1; }

# Functions.
resolve_relative_path() {
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
}
__FILE__=$(resolve_relative_path "$0")
__DIR__=$(dirname "$__FILE__")
cd "$__DIR__"

blue Validate before release.; _.
file='rcm.sh'
cp "$file" "${file}.txt"
string="cat << 'RCM_LIST_INTERNAL'"
part_1_line_start=1
part_1_line_end=$(grep -n -F "$string" "$file" | head -1 | cut -d: -f1)
part_1_string=$(sed -n $part_1_line_start','$part_1_line_end'p' "$file")

string="^RCM_LIST_INTERNAL$"
part_3_line_start=$(grep -n "$string" "$file" | head -1 | cut -d: -f1)
part_3_line_end='$'
part_3_string=$(sed -n $part_3_line_start','$part_3_line_end'p' "$file")

part_2_string=$(git ls-files | grep -E '^.+/rcm.+\.sh$' | cut -d/ -f2 | sed -e 's,^rcm-,,' -e 's,\.sh$,,')

yellow 'Dont forget to Update Rcm_list_internal()'; _.
magenta 'git diff --no-index "'$file'" "'${file}.txt'"'; _.
echo "$part_1_string"$'\n'"$part_2_string"$'\n'"$part_3_string" > "${file}.txt"
git diff --no-index "$file" "${file}.txt"
if [ $? -eq 0 ];then
    rm "${file}.txt"
    green There no changes.; _.
else
    rm "${file}.txt"
    red Need update;_.
fi
_.
yellow 'Set chmod a+x'; _.
magenta "find * -mindepth 1 -type f \( ! -perm -g+x -or  ! -perm -u+x -or ! -perm -o+x \) -and \( -name '*.sh' -or  -name '*.php' \)"; _.
find * -mindepth 1 -type f \( ! -perm -g+x -or  ! -perm -u+x -or ! -perm -o+x \) -and \( -name '*.sh' -or  -name '*.php' \)
if [[ $( find * -mindepth 1 -type f \( ! -perm -g+x -or  ! -perm -u+x -or ! -perm -o+x \) -and \( -name '*.sh' -or  -name '*.php' \)|wc -l) -eq 0 ]];then
    green There no changes.; _.
else
    red Need update;_.
fi

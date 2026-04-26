#!/bin/bash

array() {

    [[ $(type -t array-pop) == function ]] || { echo The array-pop function is required. >&2; exit 1; }
    [[ $(type -t array-shift) == function ]] || { echo The array-shift function is required. >&2; exit 1; }

    # global array
    local args=()
    local default_indent='  '
    while [ $# -gt 0 ]; do
        args+=("$1"); shift
    done

    comparison-equal() {
        # global array
        local array_local="$array"
        local array_local_child
        local args=()
        local count find found below each
        local value expected_value

        while [ $# -gt 0 ]; do
            args+=("$1"); shift
        done

        array-pop args[@]; args=("${_return_array[@]}")
        expected_value="$_return_value"

        until [ ${#args[@]} -eq 0 ];do
            array-shift args[@]; args=("${_return_array[@]}")
            each="$_return_value"

            find='^'"${each}:"
            found=$(grep -n -- "$find" <<< "$array_local" | tail -1)
            if [ -z "$found" ];then
                return 1
            fi

            line_number_found=$(cut -d: -f1 <<< "$found")
            line_string_found=$(cut -d: -f2- <<< "$found")
            find='^'"${each}:\s+(.*)"
            value=$(grep -E -- "${find}" <<< "$line_string_found" | sed -E 's|'"${find}"'|\1|')

            array_local_child=
            unset count; declare -i count; count=$line_number_found
            while true; do
                count+=1
                below=`sed -n ${count}p <<< "$array_local"`
                find='^'"${default_indent}"
                if grep -q -- "$find" <<< "$below";then
                    below_ltrim=$(grep -E -- "${find}" <<< "$below" | sed -E 's|'"${find}(.+)"'|\1|')
                    array_local_child+="$below_ltrim"$'\n'
                else
                    break
                fi
            done
            array_local="$array_local_child"
        done

        if [[ "$expected_value" == "$value" ]];then
            return 0
        else
            return 1
        fi
    }

    get-value() {
        # global array
        # global _return_value
        # global _return_array
        local array_local="$array"
        local array_local_child
        local args=()
        local count find found below each
        local value

        while [ $# -gt 0 ]; do
            args+=("$1"); shift
        done

        until [ ${#args[@]} -eq 0 ];do
            array-shift args[@]; args=("${_return_array[@]}")
            each="$_return_value"

            find='^'"${each}:"
            found=$(grep -n -- "$find" <<< "$array_local" | tail -1)

            if [ -z "$found" ];then
                break
            fi

            line_number_found=$(cut -d: -f1 <<< "$found")
            line_string_found=$(cut -d: -f2- <<< "$found")
            find='^'"${each}:\s+(.*)"
            value=$(grep -E -- "${find}" <<< "$line_string_found" | sed -E 's|'"${find}"'|\1|')

            array_local_child=
            unset count; declare -i count; count=$line_number_found
            while true; do
                count+=1
                below=`sed -n ${count}p <<< "$array_local"`
                find='^'"${default_indent}"
                if grep -q -- "$find" <<< "$below";then
                    below_ltrim=$(grep -E -- "${find}" <<< "$below" | sed -E 's|'"${find}(.+)"'|\1|')
                    array_local_child+="$below_ltrim"$'\n'
                else
                    break
                fi
            done
            array_local="$array_local_child"
        done

        # Reset first.
        _return_value=
        _return_array=()
        _return_value="$value"
        if [ -n "$array_local_child" ];then
            array_local="$array_local_child"
            until [[ -z "$array_local" ]];do
                found=`sed -n 1p <<< "$array_local"`
                each=
                if grep -q -- '^- ' <<< "$found";then
                    each+="$found"
                fi
                unset count; declare -i count; count=2
                while true;do
                    below=`sed -n ${count}p <<< "$array_local"`
                    if grep -q -- '^- ' <<< "$below";then
                        break
                    fi
                    if [ -z "$below" ];then
                        break
                    fi
                    if grep -q -- '^'"$default_indent" <<< "$below";then
                        each+=$'\n'
                        each+="$below"
                    else
                        break
                    fi
                    count+=1
                done
                if [ -n "$each" ];then
                    each=$(sed -E 's,^[ -][ ],,' <<< "$each")
                    _return_array+=("$each")
                fi
                array_local=`sed -n ${count}',$p' <<< "$array_local"`
            done
        fi
    }

    set-value() {
        # global array
        local array_local="$array"
        local array_local_child
        local args=()
        local count find found below each
        local set_value
        local line_1
        local line_2
        local line_3
        local part_1
        local part_2
        local part_3
        local part_4
        local indent
        local parent

        while [ $# -gt 0 ]; do
            args+=("$1"); shift
        done

        array-pop args[@]; args=("${_return_array[@]}")
        set_value="$_return_value"

        until [ ${#args[@]} -eq 0 ];do
            array-shift args[@]; args=("${_return_array[@]}")
            each="$_return_value"

            find='^'"${each}:"
            found=$(grep -n -- "$find" <<< "$array_local" | tail -1)
            if [ -z "$found" ];then
                if [ -n "$parent" ];then
                    # Jika ada value, maka hapus dulu dari array.
                    array=`sed -E $line_1's|:\s+.*|:|g' <<< "$array"`
                fi
                args=("$each" "${args[@]}")
                break
            fi

            line_number_found=$(cut -d: -f1 <<< "$found")
            line_string_found=$(cut -d: -f2- <<< "$found")
            find='^'"${each}:\s+(.*)"
            value=$(grep -E -- "${find}" <<< "$line_string_found" | sed -E 's|'"${find}"'|\1|')

            if [ -z "$line_1" ];then
                line_1=$line_number_found
            else
                line_1=$(( line_1 + line_number_found))
                line_2=$line_1
            fi

            array_local_child=
            unset count; declare -i count; count=$line_number_found
            while true; do
                count+=1
                below=`sed -n ${count}p <<< "$array_local"`
                find='^'"${default_indent}"
                if grep -q -- "$find" <<< "$below";then
                    below_ltrim=$(grep -E -- "${find}" <<< "$below" | sed -E 's|'"${find}(.+)"'|\1|')
                    array_local_child+="$below_ltrim"$'\n'
                    line_2=$(( line_2 + 1))
                else
                    break
                fi
            done
            # Tambah indent hanya jika belum key terakhir.
            if [ ${#args[@]} -gt 0 ];then
                indent+="${default_indent}"
            fi
            array_local="$array_local_child"

            # Save parent key.
            parent="$each"
        done

        if [ ${#args[@]} -gt 0 ];then
            if [ -n "$line_1" ];then
                if [[ "$line_1" -eq 1 ]];then
                    part_1=
                else
                    part_1=$(sed -n '1,'$line_1'p' <<< "$array")
                fi
                line_3=$((line_1+1))
                part_3=$(sed -n $line_3',$p' <<< "$array")
            else
                part_1="$array"
                part_3=
            fi
            part_2=
            until [ ${#args[@]} -eq 0 ];do
                array-shift args[@]; args=("${_return_array[@]}")
                each="$_return_value"
                if [ -n "$part_2" ];then
                    part_2+=$'\n'
                fi
                if [ ${#args[@]} -gt 0 ];then
                    part_2+="${indent}${each}:"
                    indent+="${default_indent}"
                else
                    # The last.
                    part_2+="${indent}${each}: ${set_value}"
                fi
            done
        else
            if [ -n "$line_1" ];then
                if [[ "$line_1" -eq 1 ]];then
                    part_1=
                else
                    part_1=$(sed -n '1,'$((line_1 - 1))'p' <<< "$array")
                fi
                if [[ "$line_2" -gt "$line_1" ]];then
                    part_2=$(sed -n $((line_1 + 1))','$line_2'p' <<< "$array")
                    # Debug jika diperlukan, lalu clear.
                    part_2=
                    line_3=$((line_2+1))
                else
                    part_2=
                    line_3=$((line_1+1))
                fi
                part_3="${indent}${each}: ${set_value}"
                part_4=$(sed -n $line_3',$p' <<< "$array")
            fi
        fi

        if [ -n "$part_1" ];then
            if [[ ! "${part_1:(-1)}" == $'\n' ]];then
                part_1+=$'\n'
            fi
        fi
        if [ -n "$part_2" ];then
            if [[ ! "${part_2:(-1)}" == $'\n' ]];then
                part_2+=$'\n'
            fi
        fi
        if [ -n "$part_3" ];then
            if [[ ! "${part_3:(-1)}" == $'\n' ]];then
                part_3+=$'\n'
            fi
        fi
        if [ -n "$part_4" ];then
            if [[ ! "${part_4:(-1)}" == $'\n' ]];then
                part_4+=$'\n'
            fi
        fi

        # Reset.
        array=
        [ -n "${part_1}" ] && array+="${part_1}"
        [ -n "${part_2}" ] && array+="${part_2}"
        [ -n "${part_3}" ] && array+="${part_3}"
        [ -n "${part_4}" ] && array+="${part_4}"
    }

    append-value() {
        # global array
        local array_local="$array"
        local args=()
        local count find found below each
        local append_value
        local line_1
        local line_2
        local line_3
        local line_4
        local part_1
        local part_2
        local part_3
        local part_4
        local indent
        local parent

        while [ $# -gt 0 ]; do
            args+=("$1"); shift
        done

        array-pop args[@]; args=("${_return_array[@]}")
        append_value="$_return_value"

        until [ ${#args[@]} -eq 0 ];do

            array-shift args[@]; args=("${_return_array[@]}")
            each="$_return_value"

            find='^'"${each}:"
            found=$(grep -n -- "$find" <<< "$array_local" | tail -1)
            if [ -z "$found" ];then
                if [ -n "$parent" ];then
                    # Jika ada value, maka hapus dulu dari array.
                    array=`sed -E $line_1's|:\s+.*|:|g' <<< "$array"`
                fi
                args=("$each" "${args[@]}")
                break
            fi

            line_number_found=$(cut -d: -f1 <<< "$found")
            line_string_found=$(cut -d: -f2- <<< "$found")
            find='^'"${each}:\s+(.*)"
            value=$(grep -E -- "${find}" <<< "$line_string_found" | sed -E 's|'"${find}"'|\1|')
            if [ -z "$line_1" ];then
                line_1=$line_number_found
            else
                line_1=$(( line_1 + line_number_found))
            fi
            line_2=$line_1

            if [ -n "$found" ];then
                if [ -n "$value" ];then
                    # Jika ada value, maka hapus dulu dari array.
                    array=`sed -E $line_1's|:\s+.*|:|g' <<< "$array"`
                fi
            fi

            array_local_child=
            unset count; declare -i count; count=$line_number_found
            while true; do
                count+=1
                below=`sed -n ${count}p <<< "$array_local"`
                find='^'"${default_indent}"
                if grep -q -- "$find" <<< "$below";then
                    below_ltrim=$(grep -E -- "${find}" <<< "$below" | sed -E 's|'"${find}(.+)"'|\1|')
                    array_local_child+="$below_ltrim"$'\n'
                    line_2=$(( line_2 + 1))
                else
                    break
                fi
            done
            # Tambah indent selalu.
            indent+="${default_indent}"

            array_local="$array_local_child"

            # Save parent key.
            parent="$each"
        done

        if [ ${#args[@]} -gt 0 ];then
            if [ -n "$line_1" ];then
                if [[ "$line_1" -eq 1 ]];then
                    part_1=
                else
                    part_1=$(sed -n '1,'$line_1'p' <<< "$array")
                fi
                line_3=$((line_1+1))
                part_3=$(sed -n $line_3',$p' <<< "$array")
            else
                part_1="$array"
                part_3=
            fi

            part_2=
            until [ ${#args[@]} -eq 0 ];do
                array-shift args[@]; args=("${_return_array[@]}")
                each="$_return_value"
                if [ -n "$part_2" ];then
                    part_2+=$'\n'
                fi
                part_2+="${indent}${each}:"
                indent+="${default_indent}"
            done
            part_2+=$'\n'
            part_2+="${indent}- ${append_value}"

        else
            if [ -n "$line_1" ];then
                if [[ "$line_1" -eq 1 ]];then
                    part_1=
                else
                    part_1=$(sed -n '1,'$line_1'p' <<< "$array")
                fi
                if [[ "$line_2" -gt "$line_1" ]];then
                    part_2=$(sed -n $((line_1 + 1))','$line_2'p' <<< "$array")
                    line_3=$((line_2+1))
                else
                    part_2=
                    line_3=$((line_1+1))
                fi
            fi
            part_3="${indent}- ${append_value}"
            part_4=$(sed -n $line_3',$p' <<< "$array")
        fi

        if [ -n "$part_1" ];then
            if [[ ! "${part_1:(-1)}" == $'\n' ]];then
                part_1+=$'\n'
            fi
        fi
        if [ -n "$part_2" ];then
            if [[ ! "${part_2:(-1)}" == $'\n' ]];then
                part_2+=$'\n'
            fi
        fi
        if [ -n "$part_3" ];then
            if [[ ! "${part_3:(-1)}" == $'\n' ]];then
                part_3+=$'\n'
            fi
        fi
        if [ -n "$part_4" ];then
            if [[ ! "${part_4:(-1)}" == $'\n' ]];then
                part_4+=$'\n'
            fi
        fi

        # Reset.
        array=
        [ -n "${part_1}" ] && array+="${part_1}"
        [ -n "${part_2}" ] && array+="${part_2}"
        [ -n "${part_3}" ] && array+="${part_3}"
        [ -n "${part_4}" ] && array+="${part_4}"
    }
    if [ ${#args[@]} -gt 2 ];then
        array-pop args[@]; args=("${_return_array[@]}")
        last_one="$_return_value"

        array-pop args[@]; args=("${_return_array[@]}")
        last_two="$_return_value"
        # Ref: https://www.php.net/manual/en/language.operators.comparison.php
        case "$last_two" in
            ==)
                comparison-equal "${args[@]}" "$last_one"
                ;;
            =)
                set-value "${args[@]}" "$last_one"
                ;;
            [])
                append-value "${args[@]}" "$last_one"
                ;;
            *)
                get-value "${args[@]}" "$last_two" "$last_one"
        esac
    else
        get-value "${args[@]}"
    fi
}

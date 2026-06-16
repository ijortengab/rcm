#!/bin/bash

# Reference: https://github.com/parsecsv/parsecsv-for-php/blob/main/src/Csv.php#L1055
rcm-resolve-condition() {
    local condition=$1; shift;
    local token_list=$1; shift;
    local string=$1; shift;
    local i
    i=0
    binary="$condition"
    conditionToBinary() {
        local condition=$1; shift;
        [ -z "$condition" ] && { error 'Argument <condition> is empty. '; x; }
        local token_list=$1; shift;
        local string=$1; shift;
        local each array
        local or=
        local and=
        conditionToBinaryOr () {
            local condition=$1; shift;
            [ -z "$condition" ] && { error 'Argument <condition> is empty. '; x; }
            local token_list=$1; shift;
            local string=$1; shift;
            local each array
            local or=
            IFS='|' read -ra array <<< "$condition"
            for each in "${array[@]}"; do
                if [ -n "$token_list" ];then
                    or+=$(conditionToBinaryAnd "$each" "$token_list" "$string")
                else
                    or+=$(conditionToBinaryAnd "$each")
                fi
            done
            [[ "$or" =~ 1 ]] && echo 1 || echo 0
        }
        conditionToBinaryAnd () {
            local condition=$1; shift;
            [ -z "$condition" ] && { error 'Argument <condition> is empty. '; x; }
            local token_list=$1; shift;
            local string=$1; shift;
            local each array
            local and=
            IFS='&' read -ra array <<< "$condition"
            for each in "${array[@]}"; do
                if [ -n "$token_list" ];then
                    and+=$(tokenToBinary "$each" "$token_list" "$string")
                else
                    and+="$each"
                fi
            done
            [[ "$and" =~ 0 ]] && echo 0 || echo 1
        }
        conditionToBinaryOr "$condition" "$token_list" "$string"
    }
    # Karakter operator yang berlaku adalah: = != < > <= >= ~ !~
    tokenToBinary () {
        local token=$1; shift;
        [ -z "$token" ] && { error 'Argument <token> is empty. '; x; }
        local token_list=$1; shift;
        [ -z "$token_list" ] && { error 'Argument <token_list> is empty. '; x; }
        local string=$1; shift;
        [ -z "$string" ] && { error 'Argument <string> is empty. '; x; }
        [[ $(type -t array-search) == function ]] || { error Function array-search not found.; x; }
        local array
        # Jika terjadi pengulangan, contoh:
        # a contains 80  a contains 8080
        # Maka kita ambil yang paling akhir.
        local token_list_last=$(echo "$token_list" | grep "^[$token]\s" | tail -1)
        local operator=$(echo "$token_list_last" | cut -d' ' -f2 )
        local value=$(echo "$token_list_last" | cut -d' ' -f3- )
        case "$operator" in
            =)
                if [[ "$string" == "$value" ]];then echo 1; else echo 0; fi
                ;;
            '<>')
                if [[ "$string" == "$value" ]];then echo 0; else echo 1; fi
                ;;
            '<')
                if [[ "$string" -lt "$value" ]];then echo 1; else echo 0; fi
                ;;
            '>')
                if [[ "$string" -gt "$value" ]];then echo 1; else echo 0; fi
                ;;
            '<=')
                if [[ "$string" -le "$value" ]];then echo 1; else echo 0; fi
                ;;
            '>=')
                if [[ "$string" -ge "$value" ]];then echo 1; else echo 0; fi
                ;;
            '[]')
                read -ra array -d '' <<< "$string"
                if array-search "$value" array[@];then echo 1; else echo 0; fi
                ;;
            '![]')
                read -ra array -d '' <<< "$string"
                if array-search "$value" array[@];then echo 0; else echo 1; fi
                ;;
            '~')
                if grep -q -E "$value" <<< "$string";then echo 1; else echo 0; fi
                ;;
            '!~')
                if grep -q -E "$value" <<< "$string";then echo 0; else echo 1; fi
                ;;
            *)
                echo 0
                error Operator is not valid: '`'$operator'`'; x
        esac
    }
    until [[ "$binary" =~ ^(0|1)$ ]];do
        i=$(( i + 1 ))
        # e 'Looping ke-' "$i" ; _.
        # e '< "$binary"' "$binary" ; _.
        if [[ $(echo "$binary" | grep -i -o -E '\([^\(\)]+\)' | grep -o -E '[^\(\)]+' | wc -l) -eq 0 ]];then
            if [[ "$binary" =~ ^[a-z]$ ]];then
                # e '< "$binary"' "$binary"; _.
                binary=$(conditionToBinary "$binary" "$token_list" "$string")
                # e '> "$binary"' "$binary"; _.
            else
                # error Token tidak valid: '`'$token'`'; x
                # e '< "$binary"' "$binary"; _.
                binary=$(conditionToBinary "$binary")
                # e '> "$binary"' "$binary"; _.
            fi
        else
            while IFS= read insideBraces; do
                find="(${insideBraces})"
                # e '"$find"' "$find" ; _.
                replace=$(conditionToBinary "$insideBraces" "$token_list" "$string")
                # e '"$replace"' "$replace" ; _.
                # _ Jangan gunakan replace all, karena bisa jadi ada tanda kurung yang sama.
                # _ Contoh: binary='(a&b)|c|(a&c)|((m&r|(a&b)))'
                # e '< "$binary"' "$binary" ; _.
                binary="${binary/"$find"/"$replace"}"
                # e '> "$binary"' "$binary" ; _.
            done <<< `echo "$binary" | grep -o -E '\([^\(\)]+\)' | grep -o -E   '[^\(\)]+'`
        fi
        # e '> "$binary"' "$binary"; _.
        # __ Limit adalah 100 ya gaes.
        # __ 100 lopping belum ketemu juga, artinya set error dan kembalikan false
        if [[ $i == 100 ]];then
            error Kesalahan Logic.
            binary=0
        fi
    done
    echo "$binary"
}

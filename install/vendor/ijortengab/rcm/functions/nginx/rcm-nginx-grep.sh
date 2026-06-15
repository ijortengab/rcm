#!/bin/bash

# Required function: rcm-resolve-condition.
rcm-nginx-grep(){
    validateToken() {
        # global token
        if [[ ! "$token" =~ ^[a-z]$ ]];then
            error Token tidak valid: '`'$token'`'; x
        fi
    }
    # Mengubah operator dari text string menjadi simbol, sekaligus validasi.
    # Karakter operator yang berlaku adalah: = != < > <= >= ~ !~
    validateOperator() {
        # global operator
        case "$operator" in
            is|equals|=)
                operator='=' ;;
            '!='|'is not'|'<>')
                operator='<>' ;;
            '<'|'is less than')
                operator='<' ;;
            '>'|'is greater than')
                operator='>' ;;
            '<='|'is less than or equals')
                operator='<=' ;;
            '>='|'is greater than or equals')
                operator='>=' ;;
            '[]'|'contains')
                operator='[]' ;;
            '![]'|'does not contain')
                operator='![]' ;;
            '~'|'match')
                operator='~' ;;
            '!~'|'does not match')
                operator='!~' ;;
            *)
                error Operator is not valid: '`'$operator'`'; x
        esac
    }
    [[ $(type -t rcm-resolve-condition) == function ]] || { error Function rcm-resolve-condition not found.; x; }
    local i token operator
    local directive=$1; shift
    # Jika total argument setelah directive adalah 7, 10, 13, dst.,
    # maka berarti conditional complex. Contohnya.
    # rcm-nginx-grep listen '(a&b)' a contains 8080 b contains ssl < a.txt
    # rcm-nginx-grep listen '(a&b)|c' a contain6s 8080 b contains ssl c contains ipv6only=on < a.txt
    token_list=
    if [[ $# -gt 6 && $(( $# % 3 )) == 1 ]];then
        condition=$1; shift
        while [ $# -gt 0 ];do
            token=$1
            validateToken
            operator=$2
            validateOperator
            token_list+="${token} ${operator} $3"
            token_list+=$'\n'
            shift 3;
        done
    # Jika total argument setelah directive adalah 1, maka mencari fix value.
    # Contohnya:
    # rcm-nginx-grep listen 8080
    elif [[ $# -eq 1 ]];then
        condition=a
        token_list+="a = $1"
        token_list+=$'\n'
    # Jika total argument setelah directive adalah 2, maka berarti conditional
    # sederhana. Contohnya.
    # rcm-nginx-grep listen contains ssl
    # rcm-nginx-grep listen 'is not contain' ssl
    elif [[ $# -eq 2 ]];then
        condition=a
        operator=$1
        validateOperator
        token_list+="a ${operator} $2"
        token_list+=$'\n'
    fi
    lines_directive=()
    if [ ! -t 0 ]; then
        i=0
        _ Mencari directive: '`'${directive}'`'; _.
        [ -n "$debug" ] && { _; magenta grep -E "^\s*${directive}\s+[^;]+;\s*\$"; _.; }
        while IFS= read line; do
            i=$(( i + 1 ))
            if [ "${#line}" -eq 0 ];then
                [ -n "$debug" ] && { __; }
            else
                [ -n "$debug" ] && { _; yellow "$line"; _, ' # Line:' $i; }
            fi
            if grep -q -E "^\s*${directive}\s+[^;]+;\s*\$" <<< "$line";then
                [ -n "$debug" ] && { _, ' '; green Baris ditemukan.; }
                lines_directive+=("$line")
            fi
            [ -n "$debug" ] && { _.; }
        done </dev/stdin
    fi
    if [ "${#lines_directive[@]}" -eq 0 ];then
        return 1
    fi
    [ -n "$debug" ] && { _; _.; }
    [ -n "$debug" ] && { _ Variable dump '`'\$condition'`'.; _.; }
    [ -n "$debug" ] && { e; magenta $condition; _.; }
    [ -n "$debug" ] && { _; _.; }
    [ -n "$debug" ] && { _ Variable dump '`'\$token_list'`'.; _.; }
    [ -n "$debug" ] && { while IFS= read line; do [ -n "$line" ] || continue; e; magenta "$line"; _. ; done <<< "$token_list"; }
    # _; _.
    # Directive bisa berulang.
    # Contoh: directive listen bisa berulang sebanyak dua kali.
    # Jadi jika satu saja sudah solve, maka langsung break saja.
    local resolved
    for line in "${lines_directive[@]}"; do
        # e '"$line"' "$line" ; _.
        directive_reverse=$(echo "$line" | sed -E -e "s;\s*${directive}\s+(.*);\1;" -e 's|;\s*$||')
        # e '"$directive_reverse"' "$directive_reverse" ; _.
        resolved=$(rcm-resolve-condition "$condition" "$token_list" "$directive_reverse")
        # e '"$resolved"' "$resolved" ; _.
        if [ "$resolved" == 1 ];then
            [ -n "$debug" ] && { _; _.; }
            _ Condition solved pada baris:' '; yellow  "$line"; _.
            [ -n "$debug" ] && { _; _.; }
            return 0
        fi
    done
    return 1
}

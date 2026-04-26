#!/bin/bash

array-pop() {
    # global _return_value
    # global _return_array
    local index
    local source=("${!1}")
    unset _return_value
    unset _return_array
    _return_value=
    _return_array=()
    for (( index=0; index < $((${#source[@]} - 1)) ; index++ )); do
        _return_array+=("${source[$index]}")
    done
    _return_value="${source[$((${#source[@]} - 1))]}"
}

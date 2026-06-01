# Shift an element off the beginning of array.
#
# Globals:
#   Modified: _return_value
#             _return_array
#
# Arguments:
#   1 = Parameter of the array.
#
# Returns:
#   None
#
# Example:
#   ```
#   my=("cherry" "manggo" "blackberry" "manggo" "blackberry")
#   array-shift my[@]
#   # Get result in variable `$_return_value and $_return_array`.
#   # _return_value=cherry
#   # _return_array=("manggo" "blackberry" "manggo" "blackberry")
#   ```
array-shift() {
    # global _return_value
    # global _return_array
    local index
    local source=("${!1}")
    unset _return_value
    unset _return_array
    _return_value=
    _return_array=()
    for (( index=1; index < ${#source[@]} ; index++ )); do
        _return_array+=("${source[$index]}")
    done
    _return_value="${source[0]}"
}

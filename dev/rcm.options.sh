#!/bin/bash
FLAG=(
    '--preview|-p'
    '--interactive|-i'
)
VALUE=(
    '--style|-s'
    '--public-key|-k'
)
CSV=(
    'long:--quiet,short:-q,parameter:verbose,flag_option:reverse'
    'long:--last-one,short:-l,parameter:through,flag_option:reverse'
    'long:--number,short:-n,parameter:numbering,type:value'
)
source $(dirname $0)/bash/functions/code-generator-parse-options/dev/code-generator-parse-options.function.sh

CodeGeneratorParseOptions \
    --compact \
    --no-error-invalid-options \
    --no-error-require-arguments \
    --no-hash-bang \
    --no-original-arguments \
    --without-end-options-double-dash \
    --clean \
    --output-file rcm.parse_options.sh \
    --debug-file rcm.debug.sh \
    $@

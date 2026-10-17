#!/bin/bash

rcm-plugin extends --plugin-parent-name=debian "$@"

rcm-plugin run-parent-method "$@"

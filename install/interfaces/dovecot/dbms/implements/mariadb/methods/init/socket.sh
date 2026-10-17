#!/bin/bash

# mariadb extend mysql
rcm-plugin extends --plugin-parent-name=mysql "$@"

rcm-plugin run-parent-method "$@"

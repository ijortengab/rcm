#!/bin/bash

if command -v git >/dev/null;then
    while read line; do
        if [[ $line =~ .sh$ ]];then
            chmod a+x "$line"
            echo -n cd /usr/local/bin'; '
            echo ln -sf "$PWD/$line"
            ln -sf "$PWD/$line" /usr/local/bin/$(basename "$line")
        fi
    done <<< `git ls-files`
else
    find * -type f -name '*.sh' | while read line; do
        chmod a+x "$line"
        echo -n cd /usr/local/bin'; '
        echo ln -sf "$PWD/$line"
        ln -sf "$PWD/$line" /usr/local/bin/$(basename "$line")
    done
fi

echo -n cd /usr/local/bin'; '
echo ln -sf rcm.sh rcm
cd /usr/local/bin
ln -sf rcm.sh rcm
cd - >/dev/null

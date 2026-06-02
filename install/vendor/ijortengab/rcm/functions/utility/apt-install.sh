apt-install() {
    local aptnotfound=
    chapter Melakukan instalasi aplikasi.
    code apt install "$@"
    [ -z "$aptinstalled" ] && aptinstalled=$(apt --installed list 2>/dev/null)
    for i in "$@"; do
        if ! grep -q "^$i/" <<< "$aptinstalled";then
            aptnotfound+=" $i"
        fi
    done
    if [ -n "$aptnotfound" ];then
        __ Menginstal.
        code apt install -y --no-install-recommends"$aptnotfound"
        apt install -y --no-install-recommends $aptnotfound
        aptinstalled=$(apt --installed list 2>/dev/null)
    else
        __ Aplikasi sudah terinstall seluruhnya.
    fi
    local aptnotfound=
    for i in "$@"; do
        if ! grep -q "^$i/" <<< "$aptinstalled";then
            aptnotfound+=" $i"
        fi
    done
    if [ -n "$aptnotfound" ];then
        __; red Gagal menginstall aplikasi:"$aptnotfound"; x
    fi
    ____
}

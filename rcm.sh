#!/bin/bash
#
# RCM - Remote Connection Manager
#
# Created by: IjorTengab http://ijortengab.id
# Homepage  : https://github.com/ijortengab/rcm
#
# Convention:
# - define is UPPER_CASE, underscore, and prefix with RCM_.
# - variable is lower_case and underscore.
# - temporary variable (return string from function) prefix with _underscore.
# - function is camelCase.
# - indent is 4 spaces.
_new_arguments=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --interactive|-i) interactive=1; shift ;;
        --last-one|-l) through=0; shift ;;
        --number=*|-n=*) numbering="${1#*=}"; shift ;;
        --number|-n) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then numbering="$2"; shift; fi; shift ;;
        --preview|-p) preview=1; shift ;;
        --public-key=*|-k=*) public_key="${1#*=}"; shift ;;
        --public-key|-k) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then public_key="$2"; shift; fi; shift ;;
        --quiet|-q) verbose=0; shift ;;
        --style=*|-s=*) style="${1#*=}"; shift ;;
        --style|-s) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then style="$2"; shift; fi; shift ;;
        *) _new_arguments+=("$1"); shift ;;
    esac
done

set -- "${_new_arguments[@]}"

_new_arguments=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -[^-]*) OPTIND=1
            while getopts ":iln:pk:qs:" opt; do
                case $opt in
                    i) interactive=1 ;;
                    l) through=0 ;;
                    n) numbering="$OPTARG" ;;
                    p) preview=1 ;;
                    k) public_key="$OPTARG" ;;
                    q) verbose=0 ;;
                    s) style="$OPTARG" ;;
                esac
            done
            shift "$((OPTIND-1))"
            ;;
        *) _new_arguments+=("$1"); shift ;;
    esac
done

set -- "${_new_arguments[@]}"

unset _new_arguments

# Define.
RCM_ROOT=$HOME/.config/rcm
RCM_DIR_PORTS=$RCM_ROOT/ports
RCM_DIR_ROUTE=$RCM_ROOT/route
RCM_EXE=$RCM_ROOT/exe
RCM_PORT_START=49152

# Default value of flag.
add_func_get_pid_cygwin=0
add_var_tunnel_success=0

# Informasi Global Variables.
# ---------------------------
#
# $lines* - Array. Penyimpanan baris-baris generated code.
#
# ```
# lines_define=()
# lines_function=()
# lines_pre=()
# lines=()
# lines_post=()
# ```
#
# Informasi global variable lainnya diperlukan contoh command line.
# -----------------------------------------------------------------
#
# Contoh:
#
# ```
# rcm login guest@virtualmachine.vm via ijortengab@office.lan:2223 via staff-it@company.com:80 -pstunnel
# rcm login guest@virtualmachine.vm via ijortengab@office.lan:2223 via staff-it@company.com:80 -psjump
# ```
#
# $argument - Array. Tempat penyimpanan seluruh argument yang masuk pada
# command line.
#
# ```
# $arguments = ( "guest@virtualmachine.vm" "via" "ijortengab@office.lan:2223" "via" "staff-it@company.com:80" "-pstunnel" )
# $arguments = ( "guest@virtualmachine.vm" "via" "ijortengab@office.lan:2223" "via" "staff-it@company.com:80" "-psjump" )
# ```
#
# $command - String. Merupakan mass-arguments pertama setelah command `rcm`.
# Value tersedia adalah `login`, `send-key`, dan `open-port`.
#
# ```
# $command = "login"
# ```
#
# $verbose - Default value adalah ''. Options `--quiet` atau `-q` akan
# mengubahnya menjadi false (0). Apabila bernilai false (0) maka rcm akan
# menggenerate code yang menghasilkan standard output.
#
# $preview - Default value adalah ''. Options `--preview` atau `-p` akan
# mengubahnya menjadi true (1). Apabila bernilai true (1) maka rcm akan
# menampilkan generate code sebagai standard output dan tidak mengeksekusi
# generate code tersebut.
#
# $through - Default value adalah ''. Options `--last-one` atau `-l` akan
# mengubahnya menjadi false (0). Command yang menggunakan variable ini adalah
# `send-key`. Apabila bernilai not false (!0), maka seluruh address (host) yang
# berada pada $route akan diberi tindakan sesuai command (dalam hal ini adalah
# send public key). Apabila bernilai false (0), maka hanya address (host)
# destination saja yang akan diberi tindakan sesuai command.
#
# $style - Default value adalah ''. Value tersedia adalah "", "jump",
# dan "tunnel". Options `--style` atau `-s` tersedia untuk mengubah default
# value. Apabila bernilai `jump`, maka generate code akan menggunakan option
# ssh bernama ProxyJump untuk melakukan lompatan koneksi, sementara apabila
# bernilai `tunnel`, maka generate code akan membuat tunnel (local port
# forwarding) untuk melakukan lompatan koneksi. Jika bernilai ``, maka
# akan menggunakan style `jump` jika open-ssh client berada pada versi 7.3
# keatas, selain itu maka akan menggunakan style `tunnel`.
#
# $public_key - Default value adalah ''. Command yang menggunakan variable
# ini adalah `send-key`. Jika bernilai '', maka `rcm` akan mencari public key
# sesuai urutan dari ssh client (lihat pada validatePublicKey::tester).
#
# $numbering - Default value adalah ''. Command yang menggunakan variable
# ini adalah `open-port`. Command open-port menggunakan option ini untuk
# mengeset port number.
#
# $route* - Array. Kumpulan dari address yang dilalui. Tiap address memiliki
# format `[USER@]HOST[:PORT]`. Jika route hanya terdiri dari satu address,
# maka berarti itu koneksi langsung tanpa melalui jump/tunnel.
# Jika route terdiri lebih dari satu address, maka address terakhir disebut
# `destination` dan address yang berada diawal dari destination disebut
# `tunnel`.
#
# ```
# $route = ( "staff-it@company.com:80" "ijortengab@office.lan:2223" "guest@virtualmachine.vm" )
# $route_string = "guest@virtualmachine.vm via ijortengab@office.lan:2223 via staff-it@company.com:80"
# $route_hosts = ( "company.com" "office.lan" "virtualmachine.vm" )
# $route_users = ( "staff-it" "ijortengab" "guest" )
# $route_ports = ( "80" "2223" "22" )
# $destination_host = "virtualmachine.vm"
# $destination_user = "guest"
# $destination_port = "22"
# ```
#
# Variable khusus jika dibutuhkan Jump:
# -------------------------------------
#
# $ssh* - Array. Kumpulan dari informasi command ssh yang telah digenerate
# sesuai kebutuhan jump.
# ```
# $ssh_route_jumps = ( "" "staff-it@company.com:80" "staff-it@company.com:80,ijortengab@office.lan:2223" )
# $ssh_route_options = ( " -p 80" " -p 2223 -J staff-it@company.com:80" " -J staff-it@company.com:80,ijortengab@office.lan:2223" )
# $ssh_route_mass_arguments = ( "staff-it@company.com" "ijortengab@office.lan" "guest@virtualmachine.vm" )
# ```
#
# Variable khusus jika dibutuhkan Tunnel:
# ---------------------------------------
#
# $local_ports - Array. Penyimpanan local port yang telah didapat untuk
# keperluan local port forwarding. Digenerate oleh fungsi yang khusus
# menggenerate local port yang free (tidak sedang digunakan oleh aplikasi
# lain). Local port yang digunakan oleh `rcm` dimulai dari angka 49152.
#
# ```
# $local_ports = ( "50012" "50013" )
# ```
#
# $route-tunnel - Array. Kumpulan dari address untuk membuat tunnel, dimana
# address destination HARUS ditempatkan pada element terakhir diperlukan
# sebagai referensi. Pada umumnya $route-tunnel sama dengan $route kecuali
# pada kasus `open-port` dengan style `jump`.
#
# $tunnel* - Array. Informasi hasil parsing `$route-tunnel` untuk kebutuhan
# pembuatan command.
#
# $destination* - String. Informasi hasil parsing `$route-tunnel` untuk
# kebutuhan pembuatan command. Destination adalah host terakhir dari `$route`
# dan juga `$route-tunnel`.
#
# ```
# $route_tunnel = ( "staff-it@company.com:80" "ijortengab@office.lan:2223" "guest@virtualmachine.vm" )
# $tunnel_count = "2"
# $tunnel_hosts = ( "company.com" "localhost" )
# $tunnel_users = ( "staff-it" "ijortengab" )
# $tunnel_ports = ( "80" "50012" )
# $destination_host = "localhost"
# $destination_user = "guest"
# $destination_port = "50013"
# $tunnel_fwd_local_ports = ( "50012" "50013" )
# $tunnel_fwd_target_hosts = ( "office.lan" "virtualmachine.vm" )
# $tunnel_fwd_target_ports = ( "2223" "22" )
# ```
#
# $ssh* - Array. Kumpulan dari informasi command ssh yang telah digenerate
# sesuai kebutuhan tunnel.
#
# ```
# $ssh_tunnel_options = ( " -p 80 -fN -L 50012:office.lan:2223" " -p 50012 -fN -L 50013:virtualmachine.vm:22" )
# $ssh_tunnel_mass_arguments = ( "staff-it@company.com" "ijortengab@localhost" )
# $ssh_tunnel_command = ( "ssh -p 80 -fN -L 50012:office.lan:2223 staff-it@company.com" "ssh -p 50012 -fN -L 50013:virtualmachine.vm:22 ijortengab@localhost" )
# $ssh_tunnel_command_info_route = ( "staff-it@company.com:80" "ijortengab@office.lan:2223" )
# $ssh_route_options = ( " -p 80" " -p 50012" " -p 50013" )
# $ssh_route_mass_arguments = ( "staff-it@company.com" "ijortengab@localhost" "guest@localhost" )
# ```

# Mencetak versi dari program ssh yang sekarang sedang digunakan. Memparse
# output dari ssh -V mengembalikan nilai float. Contoh output: 7.2, 7.4
#
# Globals:
#   None
#
# Arguments:
#   None
#
# Returns:
#   None
getSshVersion() {
    echo $(ssh -V 2>&1 | grep -o -P 'OpenSSH_\K([0-9]+\.[0-9]+)')
}

# Membandingkan dua nomor versi, apakah lebih besar, lebih kecil, atau sama.
# Credit: https://stackoverflow.com/a/4025065/7074586
#
# Globals:
#   Used: IFS
#
# Arguments:
#   $1: Versi pertama
#   $2: Versi kedua
#
# Returns:
#   0: Versi pertama sama dengan versi kedua
#   1: Versi pertama lebih bersar dari versi kedua
#   2: Versi pertama lebih kecil dari versi kedua
vercomp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}

# Mengecek bilangan adalah genap.
#
# Globals:
#   None
#
# Arguments:
#   $1: Value yang akan dicek
#
# Returns:
#   0: Value adalah bilangan genap
#   1: Value bukan bilangan genap
isEven () {
    if [[ ! $1 =~ ^-?[0-9]+$ ]];then
        echo "Argument harus angka integer (postivie atau negative)." >&2
        return
    fi
    if [[ $(( $1 % 2 )) == 1 ]];then
        return 1
    fi
    return 0
}

# Mengecek bilangan adalah ganjil.
#
# Globals:
#   None
#
# Arguments:
#   $1: Value yang akan dicek
#
# Returns:
#   0: Value adalah bilangan ganjil
#   1: Value bukan bilangan ganjil
isOdd () {
    if [[ ! $1 =~ ^-?[0-9]+$ ]];then
        echo "Argument harus angka integer (postivie atau negative)." >&2
        return
    fi
    if [[ $(( $1 % 2 )) == 1 ]];then
        return 0
    fi
    return 1
}

# Mengecek apakah mesin yang digunakan untuk eksekusi script ini adalah Cygwin.
#
# Globals:
#   None
#
# Arguments:
#   None
#
# Returns:
#   0: Mesin adalah Cygwin
#   1: Mesin bukan Cygwin
isCygwin () {
    if [[ $(uname | cut -c1-6) == "CYGWIN" ]];then
        return 0
    fi
    return 1
}

# Mencetak proses id (pid) berdasarkan command+argument.
#
# Globals:
#   Used: IFS
#
# Arguments:
#   $1: Command beserta argument yang dijalankan
#
# Returns:
#   None
getPid() {
    local pid command ifs
    if isCygwin;then
        ifs=$IFS
        ps -s | grep ssh | awk '{print $1}' | while IFS= read -r pid; do\
            command=$(cat /proc/${pid}/cmdline | tr '\0' ' ')
            command=$(echo "$command" | sed 's/\ $//')
            if [[ "$command" == "$1" ]];then
                echo $pid >&1
                break
            fi
        done
        IFS=$ifs
    else
        command="$1"
        pid=$(ps aux | grep "${command}" | grep -v grep | awk '{print $2}')
        echo $pid >&1
    fi
}

# Mengecek apakah port di localhost free dari di-listen oleh aplikasi.
#
# Globals:
#   None
#
# Arguments:
#   $1: Port yang akan dicek
#
# Returns:
#   0: Port adalah free
#   1: Port tidak free
isPortFree() {
    local port="$1" test
    if isCygwin;then
        test=`netstat -aon | grep 127.0.0.1:${port}`
        if [[ $test == "" ]];then
            return 0
        fi
        return 1
    fi
    test=`/bin/ss -nl | grep 127.0.0.1:${port}`
    if [[ $test == "" ]];then
        return 0
    fi
    return 1
}

# Validasi options yang diinput oleh user pada argument.
# Saat ini baru memvalidasi input style.
#
# Globals:
#   Used: style
#
# Arguments:
#   None
#
# Returns:
#   None
validateOptions() {
    local is_right
    # Variable $style yang dibolehkan adalah 'jump', 'tunnel', atau 'auto'.
    is_right=0
    case $style in
        jump) is_right=1 ;;
        tunnel) is_right=1 ;;
        *)
            is_right=1
            vercomp `getSshVersion` 7.3
            if [[ $? -lt 2 ]];then
                # ssh options -J available
                style=jump
            else
                # ssh options -J not available
                style=tunnel
            fi
    esac
    if [[ $is_right == 0 ]]; then
        error "Argument tidak dikenali pada opsi style: '${style}'."
    fi
}

# Validasi mass argument yang digunakan oleh internal command.
#
# Globals:
#   Used: arguments
#   Modified: route_string
#
# Arguments:
#   None
#
# Returns:
#   None
validateArgumentsBeforePopulateRoute() {
    local i j string
    for string in ${arguments[@]}; do
        route_string+="$string "
    done
    route_string=`echo "$route_string" | sed 's/\ $//'`
    for (( i=0; i < ${#arguments[@]} ; i++ )); do
        j=$(( $i + 1 ))
        if [[ ${arguments[$i]} =~ " " ]];then
            error "Error. Argument '${arguments[$i]}' mengandung karakter spasi."
        fi
        if isEven $j ;then
            if [[ ! ${arguments[$i]} == 'via' ]];then
                error "Error. Argument '${arguments[$i]}' tidak didahului dengan 'via'."
            fi
        fi
    done
    if isEven ${#arguments[@]};then
        error "Error. Argument kurang lengkap."
    fi
}

# Validasi jumlah minimal argument.
#
# Globals:
#   Used: arguments
#
# Arguments:
#   None
#
# Returns:
#   None
validateMinimalArgument() {
    if [[ ${#arguments[@]} -lt $1 ]];then
        error "Argument terlalu sedikit. Setidaknya dibutuhkan $1."
    fi
}

# Validasi keberadaan public key.
#
# Globals:
#   Used: public_key
#
# Arguments:
#   None
#
# Returns:
#   None
validatePublicKey() {
    local tester is_exists
    is_exists=0
    if [[ $public_key == '' ]];then
        tester=("$HOME/.ssh/id_rsa.pub" "$HOME/.ssh/id_dsa.pub"
                "$HOME/.ssh/id_ecdsa.pub" "$HOME/.ssh/id_ed25519.pub")
    else
        tester=("$public_key")
    fi
    for string in "${tester[@]}"
    do
        if [ -e "$string" ];then
            public_key="$string"
            is_exists=1
            break
        fi
    done
    if [[ $is_exists == 0 ]];then
        if [[ $public_key == 'auto' ]];then
            error "Public key tidak ditemukan."
        else
            error "Public key '$public_key' tidak ditemukan."
        fi
    fi
}

# Validasi argument port numbering.
#
# Globals:
#   Used: RCM_DIR_PORTS, numbering, route, route_hosts
#
# Arguments:
#   None
#
# Returns:
#   None
validateNumberingOpenPort() {
    local host_port z
    if [[ $numbering == '' ]];then
        return 0
    fi
    if [[ ! $numbering =~ ^[1-9]+[0-9]*$ ]];then
        error "Port number invalid." # Include zero.
    fi
    if [[ $numbering -gt 65535  ]];then
        error "Port number must lower than 65536."
    fi
    if isPortFree ${numbering};then
        z=$(( ${#route[@]} - 1 ))
        last_host=${route_hosts[$z]}
        mkdir -p $RCM_DIR_PORTS
        cd $RCM_DIR_PORTS
        host_port=`ls -U | grep $numbering | head -1 | xargs cat`
        if [[ $host_port == "" ]];then
            echo $last_host > $numbering
        else
            if [[ ! $host_port == $last_host ]];then
                error "Port ${numbering} has been assigned to host '${host_port}'."
            fi
        fi
    else
        error "Port ${numbering} sedang digunakan."
    fi
}

# Mencetak error ke STDERR kemudian exit.
#
# Globals:
#   None
#
# Arguments:
#   $1: String yang akan dicetak
#
# Returns:
#   None
error() {
    echo -e "\e[91m""$1""\e[39m" >&2
    exit 1
}

# Eksekusi berdasarkan (sub) command.
#
# Globals:
#   Used: command
#
# Arguments:
#   None
#
# Returns:
#   None
execute() {
    case $command in
        login|l)
            validateMinimalArgument 1
            validateArgumentsBeforePopulateRoute
            populateRoute
            executeLogin
            ;;
        send-key|sk)
            validateMinimalArgument 1
            validatePublicKey
            validateArgumentsBeforePopulateRoute
            populateRoute
            executeSendKey
            ;;
        open-port|op)
            validateMinimalArgument 2
            prepareFirstArgumentAsPort
            validateArgumentsBeforePopulateRoute
            populateRoute
            validateNumberingOpenPort
            modifyRouteBeforeOpenPort
            executeOpenPort
            ;;
        history|h)
            executeHistory
    esac
}

# Eksekusi command login.
#
# Globals:
#   Used: route, style
#         ssh_route_options, ssh_route_mass_arguments
#   Modified: route_tunnel
#
# Arguments:
#   None
#
# Returns:
#   None
executeLogin() {
    local z last_route ssh_options ssh_mass_arguments
    z=$(( ${#route[@]} - 1 )) # last index of route.
    case $style in
        tunnel)
            route_tunnel=(${route[@]})
            populateTunnel
            writeLinesTunnels
            writeLinesCheckTunnels
            ;;
        jump)
            populateJump
    esac
    ssh_options="${ssh_route_options[$z]}"
    ssh_mass_arguments=${ssh_route_mass_arguments[$z]}
    last_route=${route[$z]}
    writeLinesVerbose 'echo -e "\e[93m'"SSH Connect to ${last_route}"'\e[39m"'
    writeLines "ssh${ssh_options} ${ssh_mass_arguments}"
    saveHistory
    generateCode
}

# Eksekusi command send-key dengan menggenerate code.
#
# Globals:
#   Used: route, style, tunnel_count, through
#         ssh_route_options, ssh_route_mass_arguments
#         ssh_tunnel_options, ssh_tunnel_mass_arguments
#
# Arguments:
#   None
#
# Returns:
#   None
executeSendKey() {
    local i z destination ssh_options ssh_mass_arguments
    case $style in
        tunnel)
            route_tunnel=(${route[@]})
            populateTunnel
            z=$(( ${#route[@]} - 1 ))
            for (( i=0; i < ${#route[@]} ; i++ )); do
                destination=${route[$i]}
                ssh_options=${ssh_route_options[$i]}
                ssh_mass_arguments=${ssh_route_mass_arguments[$i]}
                if [[ ! $i == $z ]];then
                    if [[ ! $through == "0" ]];then
                        writeLinesSendKey "$destination" "$ssh_options" "$ssh_mass_arguments"
                        writeLines ''
                    fi
                    writeLinesTunnelsCreate $i
                    writeLinesTunnelsDestroy $i post
                else
                    writeLinesCheckTunnels
                    writeLinesSendKey "$destination" "$ssh_options" "$ssh_mass_arguments"
                fi
            done
            ;;
        jump)
            populateJump
            z=$(( ${#route[@]} - 1 ))
            for (( i=0; i < ${#route[@]} ; i++ )); do
                destination=${route[$i]}
                ssh_options=${ssh_route_options[$i]}
                ssh_mass_arguments=${ssh_route_mass_arguments[$i]}
                if [[ ! $i == $z ]];then
                    if [[ ! $through == "0" ]];then
                        writeLinesSendKey "$destination" "$ssh_options" "$ssh_mass_arguments"
                        writeLines ''
                    fi
                else
                    writeLinesSendKey "$destination" "$ssh_options" "$ssh_mass_arguments"
                fi
            done
    esac
    saveHistory
    generateCode
}

# Eksekusi command open-port dengan menggenerate code.
#
# Globals:
#   Used: route, route_hosts, route_ports, style, tunnel_count
#   Modified: ssh_tunnel_options, add_var_tunnel_success
#
# Arguments:
#   None
#
# Returns:
#   None
executeOpenPort() {
    local h i n y z line last y last_host last_port
    local ssh_options ssh_mass_arguments local_port
    z=$(( ${#route[@]} - 1 ))
    y=$(( $z - 1 ))
    last_host=${route_hosts[$z]}
    last_port=${route_ports[$z]}
    case $style in
        tunnel)
            route_tunnel=(${route[@]})
            populateTunnel
            for (( i=0; i < $tunnel_count ; i++ )); do
                writeLinesTunnelsCreate $i pre
            done
            ;;
        jump)
            populateJump
            # Prepare before populateTunnel.
            last_route=${route[$z]}
            second_to_last_route=${route[$y]}
            route_tunnel=("$second_to_last_route" "$last_route")
            ssh_tunnel_options=("${ssh_route_options[$y]}")
            # Create tunnel.
            populateTunnel
            writeLinesTunnelsCreate 0 pre
            ;;
    esac
    writeLinesCheckTunnels
    writeLinesVerbose 'echo -e "\e[93m'"Access to ${last_host} port ${last_port} opened from localhost port \e[95m${destination_port}\e[93m."'\e[39m"'
    if [[ $verbose == 0 ]];then
        # Output minimal ketika quiet adalah result dari open port.
        writeLines 'echo '$destination_port' >&1'
    fi
    saveHistory
    generateCode
}

# Eksekusi command history.
#
# Globals:
#   Used: RCM_DIR_ROUTE, interactive
#
# Arguments:
#   None
#
# Returns:
#   None
executeHistory() {
    local files_by_name string
    if [[ ! $interactive == 1 ]];then
        mkdir -p $RCM_DIR_ROUTE
        cd $RCM_DIR_ROUTE
        files_by_name=(`ls -vr $RCM_DIR_ROUTE | head -10`)
        for string in "${files_by_name[@]}"
        do
            cat "$string" >&1
        done
    else
        echo 'Coming soon.'
    fi
}

# Mengisi value dari variable $route* dan lainnya yang terkait.
#
# Globals:
#   Used: arguments
#   Modified: route, route_hosts, route_users, route_ports
#
# Arguments:
#   None
#
# Returns:
#   None
populateRoute() {
    local i z
    local _host _user _port
    z=$(( ${#arguments[@]} - 1 ))
    for (( i=$z; i >= 0 ; i-- )); do
        if isOdd $i;then
            continue
        fi
        route+=("${arguments[$i]}")
        explodeAddress "${arguments[$i]}"
        route_hosts+=("$_host")
        route_users+=("$_user")
        route_ports+=("$_port")
    done
    z=$(( ${#route[@]} - 1 ))
    destination_host="${route_hosts[$z]}"
    destination_user="${route_users[$z]}"
    destination_port="${route_ports[$z]}"
}

# Mengisi value dari variable $ssh_route_jumps dan lainnya yang terkait.
#
# Globals:
#   Used: route
#   Modified: ssh_route_jumps, ssh_route_options, ssh_route_mass_arguments
#
# Arguments:
#   None
#
# Returns:
#   None
populateJump() {
    local h i first second last
    local cmd ssh_options ssh_mass_arguments _host _user _port
    first=0
    second=1
    last=$(( ${#route[@]} - 1 ))
    cmd=
    for (( i=0; i < ${#route[@]} ; i++ )); do
        h=$(( $i - 1 ))
        if [[ $i -gt $first ]];then
            if [[ $i == $second ]];then
                cmd+="${route[$h]}"
            else
                cmd+=",${route[$h]}"
            fi
        fi
        explodeAddress "${route[$i]}" # populate _host _user _port
        ssh_options=''
        ssh_mass_arguments=${_host}
        if [[ ! $_user == "@" ]];then
            ssh_mass_arguments="${_user}@${_host}"
        fi
        if [[ ! ${_port} == 22 ]];then
            ssh_options+=" -p ${_port}"
        fi
        if [[ ! $cmd == '' ]];then
            ssh_options+=" -J ${cmd}"
        fi
        ssh_route_jumps+=("$cmd")
        ssh_route_options+=("$ssh_options")
        ssh_route_mass_arguments+=("$ssh_mass_arguments")
    done
}

# Mengisi value dari variable $tunnel* dan lainnya yang terkait.
#
# Globals:
#   Used: route_tunnel, ssh_tunnel_options
#   Modified: tunnel_count
#             tunnel_hosts tunnel_users tunnel_ports
#             destination_host destination_user destination_port
#             tunnel_fwd_local_ports
#             tunnel_fwd_target_hosts
#             tunnel_fwd_target_ports
#             ssh_tunnel_command, ssh_tunnel_command_info_route
#             ssh_tunnel_options, ssh_tunnel_mass_arguments
#
# Arguments:
#   None
#
# Returns:
#   None
populateTunnel() {
    local h i j n first_index last_index
    local _host _user _port hosts users ports ssh_options ssh_mass_arguments
    local cmd set_random_port
    first_index=0
    tunnel_count=$(( ${#route_tunnel[@]} - 1 ))
    last_index=$(( ${#route_tunnel[@]} - 1 )) # Last index of route_tunnel
    for (( i=0; i < ${#route_tunnel[@]} ; i++ )); do
        h=$(( $i - 1))
        explodeAddress "${route_tunnel[$i]}"
        if [[ $i == $first_index ]];then
            tunnel_host=$_host
            tunnel_port=$_port
        else
            set_random_port=1
            if [[ $i == $last_index ]];then
                if [[ ! $numbering == '' ]];then
                    set_random_port=0
                    _local_port=$numbering
                fi
            fi
            if [[ $set_random_port == 1 ]];then
                getRandomLocalPorts $_host
            fi
            tunnel_host=localhost
            tunnel_port=$_local_port
            tunnel_fwd_local_ports[$h]=$_local_port
            tunnel_fwd_target_hosts[$h]=$_host
            tunnel_fwd_target_ports[$h]=$_port
        fi
        if [[ ! $i == $last_index ]];then
            tunnel_hosts+=("$tunnel_host")
            tunnel_users+=("$_user")
            tunnel_ports+=("$tunnel_port")
        else
            destination_host="$tunnel_host"
            destination_user="$_user"
            destination_port="$tunnel_port"
        fi
    done
    # Populate ssh for tunnel and make sure port not used.
    last_index=$(( $tunnel_count - 1 )) # Last index of tunnel.
    for (( i=0; i < $tunnel_count ; i++ )); do
        j=$(( $i+1 ))
        constructSshTunnelCommand $i
        pid=`getPid "${_command}"`
        if [[ $pid == '' ]];then
            n=1
            max=10
            port_used=1
            port_changed=0
            while :
            do
                if [[ ${tunnel_fwd_local_ports[$i]} == $numbering ]];then
                    # Jika option -n didefinisikan, maka auto correct off.
                    port_used=0
                    break
                fi
                pid=`getPid "${_command}"`
                if [[ ! $pid == '' ]];then
                    port_used=0
                    break
                fi
                if isPortFree ${tunnel_fwd_local_ports[$i]};then
                    port_used=0
                    break
                fi
                port_changed=1
                getRandomLocalPorts ${tunnel_fwd_target_hosts[$i]}
                tunnel_fwd_local_ports[$i]=$_local_port
                constructSshTunnelCommand $i
                let n++
                if [[ $n -gt $max ]];then
                    break
                fi
            done
            if [[ $port_used == 1 ]];then
                error "Local port untuk koneksi ke ${tunnel_fwd_target_hosts[$i]} tidak dapat diciptakan. Pengecekan $max kali."
            fi
            if [[ $port_changed == 1 ]];then
                if [[ ! $last_index == $i ]];then
                    tunnel_ports[$j]=$_local_port
                else
                    destination_port=$_local_port
                fi
            fi
        fi
        ssh_tunnel_command+=("$_command")
        ssh_tunnel_mass_arguments+=("$_ssh_mass_arguments")
        ssh_tunnel_options+=("$_ssh_options")
        ssh_tunnel_command_info_route+=(${route_tunnel[$i]})
    done
    # Populate ssh for destination.
    # maybe gak diperlukan lagi.


    # Populate ssh_route_options, ssh_route_mass_arguments.
    last_index=$(( ${#route_tunnel[@]} - 1 )) # Last index of route_tunnel.
    for (( i=0; i < ${#route_tunnel[@]} ; i++ )); do
        ssh_options=''
        ssh_mass_arguments=''
        if [[ ! $i == $last_index ]];then
            _host=${tunnel_hosts[$i]}
            _user=${tunnel_users[$i]}
            _port=${tunnel_ports[$i]}
        else
            _host=$destination_host
            _user=$destination_user
            _port=$destination_port
        fi
        ssh_mass_arguments=$_host
        if [[ ! $_user == "@" ]];then
            ssh_mass_arguments=${_user}@${_host}
        fi
        if [[ ! $_port == 22 ]];then
            ssh_options+=" -p ${_port}"
        fi
        ssh_route_options+=("$ssh_options")
        ssh_route_mass_arguments+=("$ssh_mass_arguments")
    done
}

# Mengisi variable $local_port berdasarkan host.
#
# Globals:
#   Used: RCM_DIR_PORTS
#   Modified: _local_port, local_ports
#
# Arguments:
#   $1: Host yang akan diberikan nomor local port
#
# Returns:
#   None
#
# Port dimulai dari angka $RCM_PORT_START dan terus sampai mentok.
# Satu host bisa memiliki banyak local port tergantung kebutuhan pembuatan
# tunnel. Oleh karena itu dibuat global variable $local_ports sebagai
# penyimpanan referensi berbagai local port yang telah dibuat.
getRandomLocalPorts() {
    local string files port file

    # Mengecek apakah sebuah value sudah ada di dalam array.
    # Credit: https://stackoverflow.com/a/8574392/7074586
    #
    # Globals:
    #   None
    #
    # Arguments:
    #   $1: Value yang akan dicek
    #   $2: Array sebagai referensi
    #
    # Returns:
    #   0: Value berada pada array
    #   1: Value tidak berada pada array
    inArray () {
        local e match="$1"
        shift
        for e; do [[ "$e" == "$match" ]] && return 0; done
        return 1
    }

    mkdir -p "${RCM_DIR_PORTS}"
    cd "${RCM_DIR_PORTS}"
    # Mencari file berdasarkan contain.
    files=(`grep -r -E '^'"$1"'$' | cut -d: -f1 | sort -n`)
    port=
    for string in "${files[@]}"
    do
        if inArray $string "${local_ports[@]}";then
            continue
        else
            port=$string
            break
        fi
    done
    if [[ $port == "" ]];then
        file=$RCM_PORT_START
        while :
        do
            if [[ -e $file ]];then
                let file++
            else
                break
            fi
        done
        echo $1 > $file
        port=$file
    fi
    _local_port="$port"
    local_ports+=("$port")
}

# Mempersiapkan kondisi jika argument pertama diketahui sebagai port.
#
# Globals:
#   Used: arguments
#   Modified: _argument_port, arguments
#
# Arguments:
#   None
#
# Returns:
#   None
prepareFirstArgumentAsPort() {
    set -- "${arguments[@]}"
    if [[ $1 =~ ^[0-9]+$ ]];then
        _argument_port="$1"
        shift
        arguments=()
        while [[ $# -gt 0 ]]; do
            arguments+=("$1")
            shift
        done
    fi
}

# Melakukan modifikasi rute terkait subcommand open-port.
#
# Globals:
#   Used: _argument_port, route
#   Modified: route, route_hosts, route_users, route_ports
#
# Arguments:
#   None
#
# Returns:
#   None
modifyRouteBeforeOpenPort() {
    local last_index _host _port _user next
    if [[ ! $_argument_port == '' ]];then
        last_index=$(( ${#route[@]} -1 ))
        last_route=${route[$last_index]}
        explodeAddress "$last_route"
        _port=$_argument_port
        next=`implodeAddress "$_host" "$_user" "$_port"`
        route+=("$next")
        route_hosts+=("$_host")
        route_users+=("$_user")
        route_ports+=("$_port")
    fi
}

# Memecah address dengan format [USER@]HOST[:PORT] dengan mengisi variable
# terkait yakni $_user, $_host, $_port.
#
# Globals:
#   Modified: _user, _host, _port
#
# Arguments:
#   $1: address dengan format [USER@]HOST[:PORT]
#
# Returns:
#   None
explodeAddress() {
    _host="$1"
    _user=$(echo $_host | grep -E -o '^[^@]+@')
    if [[ $_user == "" ]];then
        _user=@
    else
        _host=$(echo $_host | sed 's/^'$_user'//' )
        _user=$(echo $_user | grep -E -o '[^@]+')
    fi
    _port=$(echo $_host | grep -E -o ':[0-9]+$')
    if [[ $_port == "" ]];then
        _port=22
    else
        _host=$(echo $_host | sed 's/'$_port'$//' )
        _port=$(echo $_port | grep -E -o '[0-9]+')
    fi
}

# Merakit kemudian mencetak address dari element user, host, port.
#
# Globals:
#   None
#
# Arguments:
#   $1: Host
#   $2: User
#   $3: Port
#
# Returns:
#   None
implodeAddress() {
    local host user port
    host=$1
    user=$2
    port=$3
    if [[ ! $user == "" ]];then
        if [[ ! $user == "@" ]];then
            host="${user}@${host}"
        fi
    fi
    if [[ ! $port == "" ]];then
        if [[ ! $port == "22" ]];then
            host="${host}:${port}"
        fi
    fi
    echo $host
}

# Memecah penamaan filename history dengan format
# [HIT_COUNT]_[DESTINATION_HOST]_[VARIATION] dengan mengisi variable
# terkait yakni $_hit, $_host, $_variation.
#
# Globals:
#   Modified: _hit, _host, _variation
#
# Arguments:
#   $1: Filename
#
# Returns:
#   None
explodeFileHistory() {
    _hit=$(echo $1 | grep -E -o '^[0-9]+' )
    _variation=$(echo $1 | grep -E -o '[0-9]+$' )
    _host=$(echo $1 | sed 's/^'$_hit'_//' | sed 's/_'$_variation'$//')
}

# Merakit kemudian mencetak filename history dari element hit, host, variation.
#
# Globals:
#   None
#
# Arguments:
#   $1: Hit
#   $2: Host
#   $3: Variation
#
# Returns:
#   None
implodeFileHistory() {
    echo "$1"_"$2"_"$3"
}

# Merakit kemudian mencetak ssh command untuk membuat tunnel.
#
# Globals:
#   Used: tunnel_users, tunnel_hosts, tunnel_ports
#         tunnel_fwd_local_ports
#         tunnel_fwd_target_hosts
#         tunnel_fwd_target_ports
#   Modified: _command, _ssh_mass_arguments, _ssh_options
#
# Arguments:
#   $1: key index dari array tunnel_*.
#
# Returns:
#   None
constructSshTunnelCommand() {
    local i
    # Reset.
    _ssh_options=
    _ssh_mass_arguments=
    i=$1
    _ssh_options=${ssh_tunnel_options[$i]}
    if [[ ! ${tunnel_users[$i]} == '@' ]];then
        _ssh_mass_arguments+="${tunnel_users[$i]}"@
    fi
    _ssh_mass_arguments+="${tunnel_hosts[$i]}"
    if [[ ! ${tunnel_ports[$i]} == '22' ]];then
        _ssh_options+=" -p ${tunnel_ports[$i]}"
    fi
    _ssh_options+=" -fN -L ${tunnel_fwd_local_ports[$i]}:${tunnel_fwd_target_hosts[$i]}:${tunnel_fwd_target_ports[$i]}"
    _command="ssh${_ssh_options} ${_ssh_mass_arguments}"
}

# Menulis baris-baris code (ssh command) untuk membuat dan menghapus tunnel.
# Hasil code disimpan di variable $lines*.
#
# Globals:
#   Used: tunnel_count
#
# Arguments:
#   $1: key index dari array tunnel_*
#   $2: position dari variable lines (pre, post, "")
#
# Returns:
#   None
writeLinesTunnels() {
    local i
    for (( i=0; i < $tunnel_count ; i++ )); do
        writeLinesTunnelsCreate $i pre
        writeLinesTunnelsDestroy $i post
    done
}

# Menulis baris-baris code (ssh command) untuk membuat tunnel.
# Hasil code disimpan di variable $lines*.
#
# Globals:
#   Used: ssh_tunnel_command, ssh_tunnel_command_info_route
#   Modified: add_func_get_pid_cygwin
#
# Arguments:
#   $1: key index dari array tunnel_*
#   $2: position dari variable lines (pre, post, "")
#
# Returns:
#   None
writeLinesTunnelsCreate() {
    local i
    local position port pid command
    i=$1
    if [[ $i == '' ]];then
        i=0
    fi
    position=$2
    writeLinesVerbose   'echo -e "\e[93m'"SSH Connect. Create tunnel on ${ssh_tunnel_command_info_route[$i]}."'\e[39m"' $position
    command="${ssh_tunnel_command[$i]}"
    pid=`getPid "${command}"`
    if [[ $pid == "" ]];then
        add_var_tunnel_success=1
        writeLines          "${ssh_tunnel_command[$i]}" $position
        if isCygwin;then
            add_func_get_pid_cygwin=1
            writeLines      "pid=\$(getPidCygwin \"${ssh_tunnel_command[$i]}\")" $position
        else
            writeLines      "pid=\$(ps aux | grep \"${ssh_tunnel_command[$i]}\" | grep -v grep | awk '{print \$2}')" $position
        fi
        writeLines          "if [[ \$pid == '' ]];then" $position
        writeLines          "    tunnel_success=0" $position
        writeLinesVerbose   '    echo -e "\e[93m- \e[91mFailed\e[93m.\e[39m"' $position
        writeLinesVerbose   "else" $position
        writeLinesVerbose   '    echo -e "\e[93m- \e[92mSuccess\e[93m. Process id: \e[95m${pid}\e[93m.\e[39m"' $position
        writeLines          "fi" $position
        writeLines          '' $position
    else
        writeLinesVerbose   'echo -e "\e[93m'"- Exists. Process id: \e[95m${pid}\e[93m."'\e[39m"' $position
        writeLinesVerbose '' $position
    fi
}

# Menulis baris-baris code (ssh command) untuk menghapus tunnel.
# Hasil code disimpan di variable $lines*.
#
# Globals:
#   Used: tunnel_count, ssh_tunnel_command, ssh_tunnel_command_info_route
#   Modified: add_func_get_pid_cygwin
#
# Arguments:
#   $1: key index dari array tunnel_*
#   $2: position dari variable lines (pre, post, "")
#
# Returns:
#   None
writeLinesTunnelsDestroy() {
    local i position last_index
    i=$1
    position=$2
    last_index=$(( $tunnel_count - 1 ))
    i=$(( $last_index - $i ))
    writeLines '' $position
    writeLinesVerbose   'echo -e "\e[93m'"Destroy tunnel on ${route[$i]}."'\e[39m"' $position
    if isCygwin;then
        add_func_get_pid_cygwin=1
        writeLines "kill \$(getPidCygwin \"${ssh_tunnel_command[$i]}\")" $position
    else
        writeLines "kill \$(ps aux | grep \"${ssh_tunnel_command[$i]}\" | grep -v grep | awk '{print \$2}')" $position
    fi
}

# Menulis baris-baris code (ssh command) untuk mengecek status tunnel.
# Hasil code disimpan di variable $lines*.
#
# Globals:
#   Used: add_var_tunnel_success
#   Modified: lines_define
#
# Arguments:
#   $1: position dari variable lines (pre, post, "")
#
# Returns:
#   None
writeLinesCheckTunnels() {
    position="$1"
    if [[ $add_var_tunnel_success == 1 ]];then
        lines_define+=("tunnel_success=1")
        writeLines        'if [[ $tunnel_success == 0 ]];then' $position
        writeLinesVerbose '    echo -e "\e[93m'"Tunnel gagal dibuat, proses dihentikan."'\e[39m"' $position
        writeLines        '    exit 1' $position
        writeLines        'fi' $position
        writeLines        '' $position
    fi
}

# Menulis baris-baris code untuk menyertakan fungsi getPidCygwin.
# Hasil code disimpan di variable $lines_function.
#
# Globals:
#   None
#
# Arguments:
#   None
#
# Returns:
#   None
writeLinesAddGetPidCygwin() {
    lines_function+=("getPidCygwin() {")
    lines_function+=("    local pid command ifs")
    lines_function+=("    ifs=\$IFS")
    lines_function+=("    ps -s | grep ssh | awk '{print \$1}' | while IFS= read -r pid; do\\")
    lines_function+=("        command=\$(cat /proc/\${pid}/cmdline | tr '\0' ' ')")
    lines_function+=("        command=\$(echo \"\$command\" | sed 's/\ \$//')")
    lines_function+=("        if [[ \"\$command\" == \"\$1\" ]];then")
    lines_function+=("            echo \$pid")
    lines_function+=("            break")
    lines_function+=("        fi")
    lines_function+=("    done")
    lines_function+=("    IFS=\$ifs")
    lines_function+=("}")
    lines_function+=("")
}

# Menyimpan code kedalam variable $lines*
#
# Globals:
#   None
#
# Arguments:
#   $1: Position dari variable lines (pre, post, "")
#   $2: Code yang akan digenerate
#
# Returns:
#   None
writeLines() {
    case $2 in
        pre) lines_pre+=("$1") ;;
        post) lines_post+=("$1") ;;
        *) lines+=("$1")
    esac
}

# Menyimpan code kedalam variable $lines* jika verbose aktif.
#
# Globals:
#   None
#
# Arguments:
#   $1: Position dari variable lines (pre, post, "")
#   $2: Code yang akan digenerate
#
# Returns:
#   None
writeLinesVerbose() {
    if [[ ! $verbose == 0 ]];then
        writeLines "$1" "$2"
    fi
}

# Menulis baris-baris code untuk mengirim public key.
# Hasil code disimpan di variable $lines*.
#
# Globals:
#   Used: tunnel_count, ssh_tunnel_command, ssh_tunnel_command_info_route
#   Modified: add_func_get_pid_cygwin
#
# Arguments:
#   $1: destination
#   $2: options
#   $3: mass_arguments
#
# Returns:
#   None
writeLinesSendKey() {
    local destination _options options mass_arguments line
    destination="$1"
    options="$2"
    mass_arguments="$3"
    _options="$options"
    options+=" -o PreferredAuthentications=publickey -o PasswordAuthentication=no"
    writeLinesVerbose 'echo -e "\e[93mTest SSH connect to '"${destination}"' using key.\e[39m"'
    writeLines        "if [[ ! \$(ssh${options} ${mass_arguments} 'echo 1' 2>/dev/null) == 1 ]];then"
    writeLinesVerbose '    echo -e "\e[93m- SSH connect using key is failed. It means process continues.\e[39m"'
    writeLinesVerbose '    echo -e "\e[93m- You need input password twice to sending public key.\e[39m"'
    writeLinesVerbose '    echo -e "\e[93mFirstly, SSH connect to make sure ~/.ssh/authorized_keys on '"${destination}"' exits.\e[39m"'
    options=$_options
    line="ssh${options} ${mass_arguments}"
    writeLines        "    ${line} 'mkdir -p .ssh && chmod 700 .ssh && touch .ssh/authorized_keys && chmod 640 .ssh/authorized_keys'"
    writeLinesVerbose '    echo -e "\e[93mSecondly, SSH connect again to sending public key to '"${destination}"'.\e[39m"'
    writeLines        "    cat ${public_key} | ${line} 'cat >> .ssh/authorized_keys'"
    writeLinesVerbose '    echo -e "\e[93mRetest SSH connect to '"${destination}"' using key.\e[39m"'
    options=$_options
    options+=" -o PreferredAuthentications=publickey -o PasswordAuthentication=no"
    writeLinesVerbose "    if [[ ! \$(ssh${options} ${mass_arguments} 'echo 1' 2>/dev/null) == 1 ]];then"
    writeLinesVerbose '        echo -e "\e[93m- \e[91mFailed\e[93m.\e[39m"'
    writeLinesVerbose '    else'
    writeLinesVerbose '        echo -e "\e[93m- \e[92mSuccess\e[93m.\e[39m"'
    writeLinesVerbose '    fi'
    writeLinesVerbose 'else'
    writeLinesVerbose '    echo -e "\e[93m- SSH connect using key is successful thus sending key is not necessary.\e[39m"'
    writeLines        'fi'
}

# Menyimpan history route kedalam file text.
#
# Globals:
#   Used: RCM_DIR_ROUTE, preview, route_string
#
# Arguments:
#   None
#
# Returns:
#   None
saveHistory() {
    local filename files_by_name files_by_contains
    local _hit _host _variation
    if [[ $preview == 0 ]];then
        mkdir -p $RCM_DIR_ROUTE
        cd $RCM_DIR_ROUTE
        # Mencari file berdasarkan contain.
        files_by_contains=(`grep -r -E '^'"${route_string}"'$' | cut -d: -f1 | sort -n`)
        if [[ ${#files_by_contains[@]} == 0 ]];then
            filename="1_${destination_host}_1"
            files_by_name=(`ls -U | grep -E '^[0-9]+'_"${destination_host}"'_[0-9]+$'`)
            if [[ ${#files_by_name[@]} -gt 0 ]];then
                n=1
                while :
                do
                    files_by_name=(`ls -U | grep -E '^[0-9]+'_"${destination_host}"'_'"$n"'$'`)
                    if [[ ${#files_by_name[@]} == 0 ]];then
                        break
                    else
                        let n++
                    fi
                done
                filename="1_${destination_host}_${n}"
            fi
            echo $route_string > $filename
        elif [[ ${#files_by_contains[@]} -gt 1 ]];then
            # Coming soon. Manage duplicate entry.
            error "Duplicate entry."
        else
            explodeFileHistory ${files_by_contains[0]}
            let _hit++
            filename=`implodeFileHistory $_hit $_host $_variation`
            mv ${files_by_contains[0]} $filename
        fi
    fi
}

# Generate code kemudian preview atau eksekusi.
#
# Globals:
#   Used: RCM_ROOT, RCM_EXE, add_func_get_pid_cygwin, add_var_tunnel_success
#         lines_define, lines_function, lines_pre, lines, lines_post
#         preview
#
# Arguments:
#   None
#
# Returns:
#   None
generateCode() {
    local execute=1 string compileLines
    if [[ $add_func_get_pid_cygwin == 1 ]];then
        writeLinesAddGetPidCygwin
    fi
    compileLines=()
    if [[ ${#lines_define[@]} -gt 0 ]];then
        lines_define+=("") # Beri space.
    fi
    for string in "${lines_define[@]}"
    do
        compileLines+=("$string")
    done
    for string in "${lines_function[@]}"
    do
        compileLines+=("$string")
    done
    for string in "${lines_pre[@]}"
    do
        compileLines+=("$string")
    done
    for string in "${lines[@]}"
    do
        compileLines+=("$string")
    done
    for string in "${lines_post[@]}"
    do
        compileLines+=("$string")
    done
    if [[ $preview == 1 ]];then
        execute=0
        echo -ne "\e[32m"
        echo "#!/bin/bash"
        for string in "${compileLines[@]}"
        do
            echo "$string"
        done
        echo -ne "\e[39m"
    fi
    if [[ $execute == 1 ]];then
        mkdir -p $RCM_ROOT
        echo '#!/bin/bash' > $RCM_EXE
        for string in "${compileLines[@]}"
        do
            echo "$string" >> $RCM_EXE
        done
        chmod u+x $RCM_EXE
        /bin/bash $RCM_EXE
        # setsid sh -c '$RCM_EXE'
    fi
}

# Jika tidak ada argument.
if [[ $1 == "" ]];then
    # Coming Soon.
    # clear
    exit
fi
command="$1";
case $command in
    login|l) shift ;;
    send-key|sk) shift ;;
    open-port|op) shift ;;
    history|h) shift ;;
    *) error "Command unknown: '$1'."
esac
arguments=("$@")
validateOptions
execute

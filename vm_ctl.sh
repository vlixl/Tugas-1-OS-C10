KELOMPOK="C10"   
header() {
    echo "==================================="
    echo "TUGAS 1 OS - KELOMPOK ${KELOMPOK}"
    echo "==================================="
}

# 1. vm_list - menampilkan daftar seluruh VM yang terdaftar
vm_list() {
    header
    echo "Memindai daftar Virtual Machine..."
    echo ""
    echo "Daftar VM terdaftar:"

    local vms
    vms=$(VBoxManage list vms 2>/dev/null)

    if [ -z "$vms" ]; then
        echo "Tidak ada VM yang terdaftar."
        return 1
    fi

    local i=1
    while IFS= read -r line; do
        local nama
        nama=$(echo "$line" | sed -E 's/^"([^"]+)".*/\1/')
        echo "${i}. ${nama}"
        i=$((i + 1))
    done <<< "$vms"
}


# 2. vm_info - menampilkan RAM, vCPU, dan status VM
vm_info() {
    local nama_vm="$1"

    if [ -z "$nama_vm" ]; then
        echo "Error: nama VM belum diisi."
        echo "Format: ./vm_ctl.sh info <nama_vm>"
        return 1
    fi

    header

    local info
    info=$(VBoxManage showvminfo "$nama_vm" --machinereadable 2>/dev/null)

    if [ -z "$info" ]; then
        echo "Error: VM '${nama_vm}' tidak ditemukan."
        return 1
    fi

    local ram vcpu status
    ram=$(echo "$info" | grep -m1 '^memory=' | cut -d= -f2)
    vcpu=$(echo "$info" | grep -m1 '^cpus=' | cut -d= -f2)
    status=$(echo "$info" | grep -m1 '^VMState=' | cut -d= -f2 | tr -d '"')

    echo "VM                : ${nama_vm}"
    echo "RAM dialokasikan  : ${ram} MB"
    echo "vCPU dialokasikan : ${vcpu}"
    echo "Status saat ini   : ${status}"
}

# 3. vm_start - menyalakan VM secara headless
vm_start() {
    local nama_vm="$1"

    if [ -z "$nama_vm" ]; then
        echo "Error: nama VM belum diisi."
        echo "Format: ./vm_ctl.sh start <nama_vm>"
        return 1
    fi

    header
    echo "Menyalakan VM '${nama_vm}' secara headless..."

    if ! VBoxManage startvm "$nama_vm" --type headless >/dev/null 2>&1; then
        echo "Gagal menyalakan VM '${nama_vm}'. Pastikan nama VM benar dan VM belum menyala."
        return 1
    fi

    sleep 2
    local status
    status=$(VBoxManage showvminfo "$nama_vm" --machinereadable 2>/dev/null \
        | grep -m1 '^VMState=' | cut -d= -f2 | tr -d '"')

    echo "VM '${nama_vm}' berhasil dinyalakan. Status: ${status}"
}

# 4. vm_stop - mematikan VM dengan aman (bukan dipaksa)
vm_stop() {
    local nama_vm="$1"

    if [ -z "$nama_vm" ]; then
        echo "Error: nama VM belum diisi."
        echo "Format: ./vm_ctl.sh stop <nama_vm>"
        return 1
    fi

    header
    echo "Mematikan VM '${nama_vm}' secara aman..."

    if ! VBoxManage controlvm "$nama_vm" acpipowerbutton >/dev/null 2>&1; then
        echo "Gagal mengirim sinyal shutdown ke VM '${nama_vm}'. Pastikan nama VM benar dan VM sedang menyala."
        return 1
    fi

    local tries=0
    local status="running"
    while [ "$status" != "poweroff" ] && [ "$tries" -lt 15 ]; do
        sleep 2
        status=$(VBoxManage showvminfo "$nama_vm" --machinereadable 2>/dev/null \
            | grep -m1 '^VMState=' | cut -d= -f2 | tr -d '"')
        tries=$((tries + 1))
    done

    if [ "$status" == "poweroff" ]; then
        echo "VM '${nama_vm}' berhasil dimatikan. Status: powered off"
    else
        echo "VM '${nama_vm}' masih dalam proses mematikan. Status terakhir: ${status}"
    fi
}

# Dispatcher sementara, buat testing bagian Anggota 1 dulu.
# Nanti Anggota 2 gabungin dengan snapshot create/list.
main() {
    local cmd="$1"
    shift

    case "$cmd" in
        list)
            vm_list
            ;;
        info)
            vm_info "$1"
            ;;
        start)
            vm_start "$1"
            ;;
        stop)
            vm_stop "$1"
            ;;
        *)
            echo "Penggunaan: ./vm_ctl.sh {list|info|start|stop} [nama_vm]"
            exit 1
            ;;
    esac
}

main "$@"
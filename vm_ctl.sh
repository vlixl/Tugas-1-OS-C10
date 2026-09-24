#!/usr/bin/env bash
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

# 5. vm_snapshot_create
# Alur: menerima nama VM dan nama snapshot, validasi input, lalu membuat snapshot.
# Justifikasi: snapshot dipakai sebagai checkpoint kondisi VM sebelum/sesudah perubahan.
vm_snapshot_create() {
    local nama_vm="$1"
    local nama_snapshot="$2"

    if [ -z "$nama_vm" ] || [ -z "$nama_snapshot" ]; then
        echo "Error: nama VM atau nama snapshot belum diisi."
        echo "Format: ./vm_ctl.sh snapshot create <nama_vm> <nama_snapshot>"
        return 1
    fi

    header
    echo "Membuat snapshot '${nama_snapshot}' pada VM '${nama_vm}'..."

    if ! VBoxManage snapshot "$nama_vm" take "$nama_snapshot" >/dev/null 2>&1; then
        echo "Gagal membuat snapshot. Pastikan nama VM benar."
        return 1
    fi

    echo "Snapshot '${nama_snapshot}' berhasil dibuat pada $(date '+%Y-%m-%d %H:%M:%S')."
}

# 6. vm_snapshot_list
# Alur: menerima nama VM, mengambil daftar snapshot, lalu menampilkannya dalam format bernomor.
# Justifikasi: output bernomor lebih mudah dibaca dan sesuai contoh output tugas.
vm_snapshot_list() {
    local nama_vm="$1"

    if [ -z "$nama_vm" ]; then
        echo "Error: nama VM belum diisi."
        echo "Format: ./vm_ctl.sh snapshot list <nama_vm>"
        return 1
    fi

    header
    echo "Daftar snapshot VM '${nama_vm}':"

    local snapshots
    snapshots=$(VBoxManage snapshot "$nama_vm" list 2>/dev/null)

    if [ $? -ne 0 ]; then
        echo "Gagal menampilkan snapshot. Pastikan nama VM benar."
        return 1
    fi

    if [ -z "$snapshots" ]; then
        echo "Tidak ada snapshot pada VM '${nama_vm}'."
        return 0
    fi

    local i=1
    while IFS= read -r line; do
        case "$line" in
            *Name:*)
                local nama_snapshot
                nama_snapshot=$(echo "$line" | sed -E 's/.*Name: ([^()]+).*/\1/' | sed 's/[[:space:]]*$//')
                echo "${i}. ${nama_snapshot}"
                i=$((i + 1))
                ;;
        esac
    done <<< "$snapshots"
}

# main - dispatcher utama untuk membaca command dari user
# Alur: command pertama menentukan fitur yang dijalankan, lalu argumen berikutnya diteruskan ke fungsi terkait.
# Justifikasi: setiap fitur dipisah dalam fungsi masing-masing, lalu main() mengatur fungsi mana yang dijalankan sesuai command user.
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
        snapshot)
            local snapshot_cmd="$1"
            shift

            case "$snapshot_cmd" in
                create)
                    vm_snapshot_create "$1" "$2"
                    ;;
                list)
                    vm_snapshot_list "$1"
                    ;;
                *)
                    echo "Penggunaan: ./vm_ctl.sh snapshot {create|list} <nama_vm> [nama_snapshot]"
                    exit 1
                    ;;
            esac
            ;;
        *)
            echo "Penggunaan: ./vm_ctl.sh {list|info|start|stop|snapshot} [argumen]"
            exit 1
            ;;
    esac
}

main "$@"

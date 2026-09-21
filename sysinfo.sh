#!/bin/bash

# sysinfo.sh dijalankan di dalam VM (guest)
# Bagian Jihan: info OS/kernel, jumlah acc, jumlah process, deteksi virtulaisasi, dan tabel laporan

KELOMPOK="C10"
OUT="sysinfo_report.txt"

banner(){
	echo "==================================="
	echo "	TUGAS 1 OS - KELOMPOK $KELOMPOK	 "
	echo "==================================="
}

get_os(){
    	OS_NAME=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
    	KERNEL=$(uname -r | cut -d- -f1)
}

get_users(){
	USER_COUNT=$(awk -F: '$3>=1000 && $3<65534 {c++} END {print c+0}' /etc/passwd)
}

get_procs(){
	PROC_COUNT=$(ps -e --no-headers | wc -l)
}

get_virt(){
	VIRT_RAW=$(systemd-detect-virt 2>/dev/null)
	case "$VIRT_RAW" in
		oracle) VIRT_NAME="VirtualBox" ;;
		none |"") VIRT_NAME="" ;;
		*) VIRT_NAME="$VIRT_RAW" ;;

	esac
	if [ -n "$VIRT_NAME" ]; then
		VIRT_STATUS="PASS"; VIRT_DETAIL="Terdeteksi: $VIRT_NAME"
	else
		VIRT_STATUS="FAIL"; VIRT_DETAIL="Tidak terdeteksi (mesin fisik)"
	fi
}

# Untuk cetak satu baris tabel: kategori, item, status, detail

row(){
	printf "| %-14s | %-20s | %-6s | %-25s |\n" "$1" "$2" "$3" "$4"
}

border(){
	echo "+----------------+----------------------+--------+---------------------------+"
}

make_report(){
	{
		echo "=========================================================================="
        	echo "                       TUGAS 1 OS - KELOMPOK $KELOMPOK"
        	echo "=========================================================================="
        	border
		row "Check Category" "Item" "Status" "Details"
		border
		row "OS" "$OS_NAME" "PASS" "Kernel $KERNEL"
		row "Users" "Regular accounts" "PASS" "$USER_COUNT  akun"
		row "Processes" "Running" "PASS" "$PROC_COUNT proses berjalan"
		row "Virtualization" "Hypervisor" "$VIRT_STATUS" "$VIRT_DETAIL"
		# TODO (Vincent) : buat  baris Disk and Memori
		border
	} > "$OUT"
}


main(){
	banner
	echo "Mengecek sistem..."
	get_os; get_users; get_procs; get_virt
	echo "	OS/Kernel 	: $OS_NAME (Kernel $KERNEL)"
	echo "	Akun pengguna 	: $USER_COUNT akun"
	echo "	Proses berjalan	: $PROC_COUNT proses"
	echo "	Virtualisasi	: $VIRT_DETAIL"
	# TODO (Vincent): Lanjut untuk hitung metrik dan pipe, tampilkn juga uptime
	
	echo "Menyimpan laporan ke $OUT"
	make_report
	echo "Laporan berhasil disimpan :D"
}

main



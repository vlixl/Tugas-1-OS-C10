#!/bin/bash

# sysinfo.sh dijalankan di dalam VM (guest)
# Bagian Jihan: info OS/kernel, jumlah acc, jumlah process, deteksi virtulaisasi, dan tabel laporan
# Bagian Vincent: get metrics, check resources (pipeline), check uptime (bonus feature)

KELOMPOK="C10"
OUT="sysinfo_report.txt"

# Cari executable C di folder yang sama dengan script ini.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
CHECKER="$SCRIPT_DIR/resource_check"

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

get_metrics(){
	# Disk: ambil kolom penggunaan (%) dari filesystem yang memuat /.
	DISK_USAGE=$(df -P / | awk '
		NR==2 {gsub(/%/, "", $5); print $5; found=1}
		END {if (!found) exit 1}
	') || return 1

	# Memori: 100 x (total - available) / total.
	# free -b memberikan angka byte. Kolom 2=total, kolom 7=available.
	# available mencakup memori yang bisa direklamasi untuk aplikasi baru.
	MEM_USAGE=$(free -b | awk '
		/^Mem:/ {
			if (NF<7 || $2<=0 || $7<0 || $7>$2) exit 1
			printf "%.6f\n", 100 * ($2-$7) / $2
			found=1
		}
		END {if (!found) exit 1}
	') || return 1

	# Pastikan yang akan dikirim ke scanf benar-benar angka.
	if [[ ! "$DISK_USAGE" =~ ^[0-9]+$ || ! "$MEM_USAGE" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
		echo "Metrik disk atau memori tidak valid." >&2
		return 1
	fi
}

check_resources(){
	local metric value status extra
	DISK_STATUS=""
	MEM_STATUS=""

	if [[ ! -x "$CHECKER" ]]; then
		echo "Executable resource_check tidak ditemukan. Kompilasi resource_check.c terlebih dahulu." >&2
		return 1
	fi

	# printf mengirim dua angka, disk lalu memori, lewat pipe ke stdin C.
	# Command substitution menangkap stdout C ke variabel RESOURCE_RESULT.
	# Format keluaran Cg: DISK <angka> <status>, lalu MEM <angka> <status>.
	RESOURCE_RESULT=$(printf '%s %s\n' "$DISK_USAGE" "$MEM_USAGE" | "$CHECKER")

	# Simpan $? langsung, sebelum menjalankan perintah lain.
	RESOURCE_CODE=$?

	# 0=PASS, 1=WARN, 2=FAIL, sisanya ditolak
	if [[ ! "$RESOURCE_CODE" =~ ^[012]$ ]]; then
		echo "Program C gagal dijalankan (exit code $RESOURCE_CODE)." >&2
		return 1
	fi

	# Baca setiap baris hasil C sebagai tiga kolom.
	# Contoh: DISK 80 WARN -> metric=DISK, value=80, status=WARN.
	while read -r metric value status extra; do
		if [[ -n "$extra" || ! "$value" =~ ^[0-9]+$ ]]; then
			echo "Format hasil C tidak valid: $metric $value $status $extra" >&2
			return 1
		fi
		case "$status" in
			PASS|WARN|FAIL) ;;
			*) echo "Status C tidak valid: $status" >&2; return 1 ;;
		esac
		case "$metric" in
			DISK) DISK_STATUS="$status" ;;
			MEM) MEM_STATUS="$status" ;;
			*) echo "Metrik C tidak dikenal: $metric" >&2; return 1 ;;
		esac
	done <<< "$RESOURCE_RESULT"

	[[ -n "$DISK_STATUS" && -n "$MEM_STATUS" ]] || return 1

	# Nilai asli dipakai untuk tampilan. C membulatkan angka keluarannya
	# dengan %.0f, tetapi menentukan status dari nilai sebelum pembulatan.
	printf -v DISK_DISPLAY '%s%%' "$DISK_USAGE"
	printf -v MEM_DISPLAY '%.2f%%' "$MEM_USAGE"
}

get_uptime(){
	# Fitur tambahan: lama guest berjalan sejak boot.
	# Angka pertama /proc/uptime adalah waktu tersebut dalam detik.
	UPTIME=$(awk '{
		hari=int($1/86400)
		jam=int(($1%86400)/3600)
		menit=int(($1%3600)/60)
		printf "%d hari %d jam %d menit", hari, jam, menit
	}' /proc/uptime)
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
		row "Disk" "$DISK_DISPLAY" "$DISK_STATUS" "Filesystem /"
		row "Memori" "$MEM_DISPLAY" "$MEM_STATUS" "RAM: total - available"
		row "Uptime" "Waktu sejak boot" "PASS" "$UPTIME"
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

	echo "Menghitung metrik varian A..."
	get_metrics || { echo "Gagal mengambil metrik." >&2; return 1; }
	check_resources || return 1
	get_uptime || { echo "Gagal membaca uptime." >&2; return 1; }
	echo " Disk usage   : $DISK_DISPLAY [$DISK_STATUS]"
	echo " Memory usage : $MEM_DISPLAY [$MEM_STATUS]"
	echo " Uptime VM    : $UPTIME"
	
	echo "Menyimpan laporan ke $OUT"
	make_report
	echo "Laporan berhasil disimpan :D"
}

main



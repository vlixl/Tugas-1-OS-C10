#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./vm_ctl.sh list
  ./vm_ctl.sh info <vm_name>
  ./vm_ctl.sh start <vm_name>
  ./vm_ctl.sh stop <vm_name>
  ./vm_ctl.sh snapshot create <vm_name> <snapshot_name>
  ./vm_ctl.sh snapshot list <vm_name>
EOF
}

find_vboxmanage() {
  if [[ -n "${VBOXMANAGE:-}" ]]; then
    printf '%s\n' "$VBOXMANAGE"
  elif command -v VBoxManage >/dev/null 2>&1; then
    command -v VBoxManage
  elif command -v VBoxManage.exe >/dev/null 2>&1; then
    command -v VBoxManage.exe
  elif [[ -x "/mnt/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" ]]; then
    printf '%s\n' "/mnt/c/Program Files/Oracle/VirtualBox/VBoxManage.exe"
  elif [[ -x "/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" ]]; then
    printf '%s\n' "/c/Program Files/Oracle/VirtualBox/VBoxManage.exe"
  else
    echo "VBoxManage not found. Install VirtualBox or set VBOXMANAGE=/path/to/VBoxManage." >&2
    exit 1
  fi
}

need_vm() {
  if [[ $# -lt 1 ]]; then
    usage >&2
    exit 1
  fi
}

vbox="$(find_vboxmanage)"
cmd="${1:-}"

vm_list() {
  "$vbox" list vms
}

vm_info() {
  "$vbox" showvminfo "$1"
}

vm_start() {
  "$vbox" startvm "$1" --type headless
}

vm_stop() {
  "$vbox" controlvm "$1" acpipowerbutton
}

vm_snapshot_create() {
  "$vbox" snapshot "$1" take "$2"
}

vm_snapshot_list() {
  "$vbox" snapshot "$1" list
}

case "$cmd" in
  list)
    vm_list
    ;;
  info)
    shift
    need_vm "$@"
    vm_info "$1"
    ;;
  start)
    shift
    need_vm "$@"
    vm_start "$1"
    ;;
  stop)
    shift
    need_vm "$@"
    vm_stop "$1"
    ;;
  snapshot)
    shift
    snapshot_cmd="${1:-}"
    shift || true
    case "$snapshot_cmd" in
      create)
        if [[ $# -lt 2 ]]; then
          usage >&2
          exit 1
        fi
        vm_snapshot_create "$1" "$2"
        ;;
      list)
        need_vm "$@"
        vm_snapshot_list "$1"
        ;;
      *)
        usage >&2
        exit 1
        ;;
    esac
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac

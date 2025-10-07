#!/bin/bash
set -euo pipefail

# =============================
# Enhanced Multi-VM Manager
# =============================

VM_DIR="${VM_DIR:-$HOME/vms}"
mkdir -p "$VM_DIR"

# Function to display header
display_header() {
    clear
    cat << "EOF"
========================================================================
 /$$$$$$$$       /$$     /$$       /$$   /$$       /$$$$$$$$       /$$   /$$
|_____ $$       |  $$   /$$/      | $$$ | $$      | $$_____/      | $$  / $$
     /$$/        \  $$ /$$/       | $$$$| $$      | $$            |  $$/ $$/ 
    /$$/          \  $$$$/        | $$ $$ $$      | $$$$$          \  $$$$/ 
   /$$/            \  $$/         | $$  $$$$      | $$__/           >$$  $$ 
  /$$/              | $$          | $$\  $$$      | $$             /$$/\  $$ 
 /$$$$$$$$          | $$          | $$ \  $$      | $$$$$$$$      | $$  \ $$ 
|________/          |__/          |__/  \__/      |________/      |__/  |__/ 
                                                                             
                            POWERED BY ZYNEX
========================================================================
EOF
}

# Function to display colored output
print_status() {
    local type=$1 message=$2
    case $type in
        "INFO") echo -e "\033[1;34m[INFO]\033[0m $message";;
        "WARN") echo -e "\033[1;33m[WARN]\033[0m $message";;
        "ERROR") echo -e "\033[1;31m[ERROR]\033[0m $message";;
        "SUCCESS") echo -e "\033[1;32m[SUCCESS]\033[0m $message";;
        "INPUT") echo -e "\033[1;36m[INPUT]\033[0m $message";;
        *) echo "[$type] $message";;
    esac
}

# Check dependencies
check_dependencies() {
    local deps=("qemu-system-x86_64" "wget" "cloud-localds" "qemu-img")
    local missing=()
    for d in "${deps[@]}"; do
        command -v "$d" >/dev/null || missing+=("$d")
    done
    if [ ${#missing[@]} -ne 0 ]; then
        print_status "ERROR" "Missing: ${missing[*]}"
        print_status "INFO" "sudo apt install qemu-system cloud-image-utils wget"
        exit 1
    fi
}
check_dependencies

# Cleanup
cleanup() { rm -f user-data meta-data; }

# List VMs
get_vm_list() { find "$VM_DIR" -name "*.conf" -exec basename {} .conf \; 2>/dev/null | sort; }

# Load VM config
load_vm_config() {
    local vm="$1" cfg="$VM_DIR/$vm.conf"
    if [[ -f "$cfg" ]]; then
        unset VM_NAME OS_TYPE CODENAME IMG_URL HOSTNAME USERNAME PASSWORD
        unset DISK_SIZE MEMORY CPUS SSH_PORT GUI_MODE PORT_FORWARDS IMG_FILE SEED_FILE CREATED
        source "$cfg"
        return 0
    else
        print_status "ERROR" "VM '$vm' config not found"
        return 1
    fi
}

# Supported OS images
declare -A OS_OPTIONS=(
    ["Ubuntu 22.04"]="ubuntu|jammy|https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
    ["Ubuntu 24.04"]="ubuntu|noble|https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
    ["Debian 11"]="debian|bullseye|https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2"
    ["Debian 12"]="debian|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
)

# VM Actions
create_new_vm() {
    read -p "Enter VM name: " VM_NAME
    [ -z "$VM_NAME" ] && { echo "Name required"; return; }
    read -p "Select OS (Ubuntu 22.04/Ubuntu 24.04/Debian 11/Debian 12): " OS
    IMG_URL="${OS_OPTIONS[$OS]##*|}"
    [ -z "$IMG_URL" ] && { echo "Invalid OS"; return; }

    DISK="$VM_DIR/$VM_NAME.qcow2"
    echo "Creating disk..."
    qemu-img create -f qcow2 "$DISK" 20G

    echo "Downloading image..."
    wget -O "$VM_DIR/$VM_NAME.img" "$IMG_URL"

    # Save config
    cat > "$VM_DIR/$VM_NAME.conf" <<EOF
VM_NAME="$VM_NAME"
IMG_FILE="$VM_DIR/$VM_NAME.img"
DISK_FILE="$DISK"
EOF

    print_status "SUCCESS" "VM $VM_NAME created"
}

start_vm() {
    local vm="$1"
    load_vm_config "$vm" || return
    echo "Starting $VM_NAME..."
    qemu-system-x86_64 -m 2048 -hda "$DISK_FILE" -boot c -enable-kvm -vnc :1 &
    print_status "SUCCESS" "$VM_NAME started (VNC :1)"
}

stop_vm() {
    local vm="$1"
    pkill -f "$VM_DIR/$vm.qcow2" && print_status "SUCCESS" "$vm stopped" || echo "Not running"
}

delete_vm() {
    local vm="$1"
    load_vm_config "$vm" || return
    rm -f "$DISK_FILE" "$IMG_FILE" "$VM_DIR/$vm.conf"
    print_status "SUCCESS" "$VM_NAME deleted"
}

# =============================
# Main interactive menu
# =============================
main_menu() {
    display_header
    echo "ZYNEX VM Manager Loaded Successfully!"
    echo "Use this script to manage your VMs."
    while true; do
        echo
        echo "1) List VMs"
        echo "2) Create VM"
        echo "3) Start VM"
        echo "4) Stop VM"
        echo "5) Delete VM"
        echo "0) Exit"
        read -p "Enter choice: " c
        case $c in
            1) vms=($(get_vm_list))
               [ ${#vms[@]} -eq 0 ] && echo "No VMs found." || printf " - %s\n" "${vms[@]}" ;;
            2) create_new_vm ;;
            3) read -p "VM name: " vm; start_vm "$vm" ;;
            4) read -p "VM name: " vm; stop_vm "$vm" ;;
            5) read -p "VM name: " vm; delete_vm "$vm" ;;
            0) echo "Exiting..."; exit 0 ;;
            *) echo "Invalid choice" ;;
        esac
    done
}

# Run
main_menu

#!/bin/bash
set -euo pipefail

# =============================
# Enhanced Multi-VM Manager
# =============================

# Function to display header
display_header() {
    clear
    cat << "EOF"
========================================================================
 /$$$$$$$$       /$$     /$$       /$$   /$$       /$$$$$$$$       /$$   /$$
|_____ $$       |  $$   /$$/      | $$$ | $$      | $$_____/      | $$  / $$
     /$$/        \  $$ /$$/       | $$$$| $$      | $$            |  $$/ $$
    /$$/          \  $$$$/        | $$ $$ $$      | $$$$$          \  $$$$/
   /$$/            \  $$/         | $$  $$$$      | $$__/           >$$  $$
  /$$/              | $$          | $$\  $$$      | $$             /$$/\  $$
 /$$$$$$$$          | $$          | $$ \  $$      | $$$$$$$$      | $$  \ $$
|________/          |__/          |__/  \__/      |________/      |__/  |__/
                                                                           
                            POWERED BY ZYNEX
========================================================================
EOF
    echo
}

# Function to display colored output
print_status() {
    local type=$1
    local message=$2
    
    case $type in
        "INFO") echo -e "\033[1;34m[INFO]\033[0m $message" ;;
        "WARN") echo -e "\033[1;33m[WARN]\033[0m $message" ;;
        "ERROR") echo -e "\033[1;31m[ERROR]\033[0m $message" ;;
        "SUCCESS") echo -e "\033[1;32m[SUCCESS]\033[0m $message" ;;
        "INPUT") echo -e "\033[1;36m[INPUT]\033[0m $message" ;;
        *) echo "[$type] $message" ;;
    esac
}

# Function to validate input
validate_input() {
    local type=$1
    local value=$2
    
    case $type in
        "number")
            if ! [[ "$value" =~ ^[0-9]+$ ]]; then
                print_status "ERROR" "Must be a number"
                return 1
            fi
            ;;
        "size")
            if ! [[ "$value" =~ ^[0-9]+[GgMm]$ ]]; then
                print_status "ERROR" "Must be a size with unit (e.g., 100G, 512M)"
                return 1
            fi
            ;;
        "port")
            if ! [[ "$value" =~ ^[0-9]+$ ]] || [ "$value" -lt 23 ] || [ "$value" -gt 65535 ]; then
                print_status "ERROR" "Must be a valid port number (23-65535)"
                return 1
            fi
            ;;
        "name")
            if ! [[ "$value" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                print_status "ERROR" "VM name can only contain letters, numbers, hyphens, and underscores"
                return 1
            fi
            ;;
        "username")
            if ! [[ "$value" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
                print_status "ERROR" "Username must start with a letter or underscore, and contain only letters, numbers, hyphens, and underscores"
                return 1
            fi
            ;;
    esac
    return 0
}

# Function to check dependencies
check_dependencies() {
    local deps=("qemu-system-x86_64" "wget" "cloud-localds" "qemu-img")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_status "ERROR" "Missing dependencies: ${missing_deps[*]}"
        print_status "INFO" "On Ubuntu/Debian, try: sudo apt install qemu-system cloud-image-utils wget"
        exit 1
    fi
}

# Cleanup temp files
cleanup() {
    [ -f "user-data" ] && rm -f "user-data"
    [ -f "meta-data" ] && rm -f "meta-data"
}

# VM list
get_vm_list() {
    find "$VM_DIR" -name "*.conf" -exec basename {} .conf \; 2>/dev/null | sort
}

# Load VM config
load_vm_config() {
    local vm_name=$1
    local config_file="$VM_DIR/$vm_name.conf"
    
    if [[ -f "$config_file" ]]; then
        unset VM_NAME OS_TYPE CODENAME IMG_URL HOSTNAME USERNAME PASSWORD
        unset DISK_SIZE MEMORY CPUS SSH_PORT GUI_MODE PORT_FORWARDS IMG_FILE SEED_FILE CREATED
        source "$config_file"
        return 0
    else
        print_status "ERROR" "Configuration for VM '$vm_name' not found"
        return 1
    fi
}

# Initialize paths
VM_DIR="${VM_DIR:-$HOME/vms}"
mkdir -p "$VM_DIR"

# Supported OS list
declare -A OS_OPTIONS=(
    ["Ubuntu 22.04"]="ubuntu|jammy|https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img|ubuntu22|ubuntu|ubuntu"
    ["Ubuntu 24.04"]="ubuntu|noble|https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img|ubuntu24|ubuntu|ubuntu"
    ["Debian 11"]="debian|bullseye|https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2|debian11|debian|debian"
    ["Debian 12"]="debian|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|debian12|debian|debian"
    ["Fedora 40"]="fedora|40|https://download.fedoraproject.org/pub/fedora/linux/releases/40/Cloud/x86_64/images/Fedora-Cloud-Base-40-1.14.x86_64.qcow2|fedora40|fedora|fedora"
    ["CentOS Stream 9"]="centos|stream9|https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2|centos9|centos|centos"
    ["AlmaLinux 9"]="almalinux|9|https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2|almalinux9|alma|alma"
    ["Rocky Linux 9"]="rockylinux|9|https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2|rocky9|rocky|rocky"
)

# Placeholder functions (you can replace these with actual VM actions)
create_new_vm() { echo "Create VM not implemented yet"; }
start_vm() { echo "Start VM \$1 not implemented yet"; }
stop_vm() { echo "Stop VM \$1 not implemented yet"; }
delete_vm() { echo "Delete VM \$1 not implemented yet"; }

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
        echo

        read -p "Enter choice: " choice
        case $choice in
            1)
                vms=($(get_vm_list))
                if [ ${#vms[@]} -eq 0 ]; then
                    echo "No VMs found."
                else
                    echo "VMs:"
                    for vm in "${vms[@]}"; do
                        echo " - $vm"
                    done
                fi
                ;;
            2) create_new_vm ;;
            3) 
                read -p "Enter VM name to start: " vm
                start_vm "$vm"
                ;;
            4) 
                read -p "Enter VM name to stop: " vm
                stop_vm "$vm"
                ;;
            5) 
                read -p "Enter VM name to delete: " vm
                delete_vm "$vm"
                ;;
            0) echo "Exiting..."; exit 0 ;;
            *) echo "Invalid choice" ;;
        esac
    done
}

# Run the menu
main_menu

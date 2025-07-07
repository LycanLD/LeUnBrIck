#!/bin/bash
set -euo pipefail

# ---- Color codes ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Disable colors if NO_COLOR is set
if [[ -n "${NO_COLOR-}" ]]; then
    RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; RESET=''
fi

DFU_UTILS_DIR="./dfu_utils"
WIND3X_DIR="./wInd3x"
FIRMWARES_DIR="./firmwares"
IPOD_SCSI="./ipodscsi_linux/ipodscsi"

WTF_PATH_2012="$FIRMWARES_DIR/WTF.x1234.RELEASE.dfu"
FW_PATH_2012="$FIRMWARES_DIR/FIRMWARE.x124a.RELEASE.dfu"

WTF_PATH_2015="$FIRMWARES_DIR/WTF.x1234.RELEASE.dfu"
FW_PATH_2015="$FIRMWARES_DIR/FIRMWARE.x124a.RELEASE.dfu"

DFU_DEVICE="05ac:1234"
WTF_DEVICE="05ac:124a"

# ---- UI Helpers ----
print_banner() {
    clear
    echo -e "${CYAN}"
    echo "      ╦  ┌─┐  ╦ ╦┌┐┌╔╗ ┬─┐╦┌─┐┬┌─"
    echo "      ║  ├┤   ║ ║│││╠╩╗├┬┘║│  ├┴┐"
    echo "      ╩═╝└─┘  ╚═╝┘└┘╚═╝┴└─╩└─┘┴ ┴"
    echo -e "${RESET}"
    echo -e "${BOLD}${CYAN}============== Le UnBrIck ===============${RESET}"
    echo -e "${BLUE}★ iPod Nano 6G/7G Unbrick/Restore Tool ★${RESET}"
    echo -e "${CYAN}        Made by Lycan  |  Ver: 1.3.1       ${RESET}"
    echo -e "${CYAN}=========================================${RESET}"
}


msg()   { echo -e "${CYAN}[*]${RESET} $*"; }
ok()    { echo -e "${GREEN}[✓]${RESET} $*"; }
warn()  { echo -e "${YELLOW}[!]${RESET} $*"; }
err()   { echo -e "${RED}[✖]${RESET} $*"; }
ask()   { echo -en "${YELLOW}[?]${RESET} $*"; }
flash() { echo -e "${BOLD}${CYAN}[⚡]${RESET} Flashing $*"; }

# ---- Install Dependencies ----
install_required_packages() {
    msg "Installing required packages..."

    if command -v apt &>/dev/null; then
        sudo apt update && sudo apt install -y git golang libusb-1.0-0-dev dfu-util make
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y git golang libusbx-devel dfu-util make
    elif command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm git go libusb dfu-util make
    elif command -v zypper &>/dev/null; then
        sudo zypper install -y git go libusb-1_0-devel dfu-util make
    elif command -v emerge &>/dev/null; then
        sudo emerge dev-vcs/git dev-lang/go virtual/libusb sys-apps/dfu-util
    elif command -v apk &>/dev/null; then
        sudo apk add git go libusb-dev dfu-util make
    else
        err "Unsupported package manager."
        exit 1
    fi
    ok "All required packages installed!"
    read -rp "Press ENTER to return to menu..."
}

# ---- Download Firmwares ----
download_firmwares() {
    msg "Checking for missing firmware files..."

    mkdir -p "$FIRMWARES_DIR/2012" "$FIRMWARES_DIR/2015" "$FIRMWARES_DIR/6G"

    FIRMWARE_URL_2012="https://github.com/lycanld/LeUnBrIck/releases/download/hidden/firmware_2012.zip"
    FIRMWARE_URL_2015="https://github.com/lycanld/LeUnBrIck/releases/download/hidden/firmware_2015.zip"
    FIRMWARE_URL_6G="https://github.com/lycanld/LeUnBrIck/releases/download/hidden/firmware_6G.zip"

    if [ ! -f "$FIRMWARES_DIR/2012/Firmware.MSE" ]; then
        msg "Downloading firmware for 2012 iPod..."
        wget -O /tmp/fw2012.zip "$FIRMWARE_URL_2012" || { err "Download failed."; return; }
        unzip -o /tmp/fw2012.zip -d "$FIRMWARES_DIR/2012/"
        ok "Extracted 2012 firmware."
    fi

    if [ ! -f "$FIRMWARES_DIR/2015/Firmware.MSE" ]; then
        msg "Downloading firmware for 2015 iPod..."
        wget -O /tmp/fw2015.zip "$FIRMWARE_URL_2015" || { err "Download failed."; return; }
        unzip -o /tmp/fw2015.zip -d "$FIRMWARES_DIR/2015/"
        ok "Extracted 2015 firmware."
    fi

    if [ ! -f "$FIRMWARES_DIR/6G/Firmware.MSE" ]; then
        msg "Downloading firmware for iPod nano 6G..."
        wget -O /tmp/fw6g.zip "$FIRMWARE_URL_6G" || { err "Download failed."; return; }
        unzip -o /tmp/fw6g.zip -d "$FIRMWARES_DIR/6G/"
        ok "Extracted 6G firmware."
    fi
}

# ---- Wait for USB ----
wait_for_usb() {
    expected="$1"
    msg "Waiting for USB device $expected..."
    for i in {1..20}; do
        if lsusb | grep -i "$expected" > /dev/null; then
            ok "Device $expected detected."
            return 0
        fi
        sleep 1
    done
    err "Device $expected not found."
    return 1
}

# ---- Flash with dfu-util ----
flash_with_dfuutil() {
    device="$1"
    file="$2"
    flash "$file to device $device..."

    set +e
    output=$(sudo dfu-util -d "$device" -D "$file" 2>&1)
    status=$?
    set -e

    echo "$output"

    if echo "$output" | grep -q "Download done."; then
        ok "Flash completed (even if it threw LIBUSB_ERROR_NO_DEVICE)."
        return 0
    elif echo "$output" | grep -q "LIBUSB_ERROR_NO_DEVICE"; then
        warn "LIBUSB_ERROR_NO_DEVICE after transfer — this is expected."
        ok "Proceeding anyway."
        return 0
    else
        err "Flash may have failed."
        read -rp "Press ENTER to return to menu..."
        return 1
    fi
}

# ---- Unbrick 2012 ----
unbrick_2012() {
    download_firmwares
    msg "Put your iPod nano 7G (2012) into DFU mode"
    echo -e "${CYAN}→ USB-A to Lightning + Hold SLEEP + HOME until black screen${RESET}"
    read -rp "Press ENTER when ready..."
    wait_for_usb "$DFU_DEVICE" || return

    [ -f "$WTF_PATH_2012" ] || { err "Missing $WTF_PATH_2012"; return; }
    flash_with_dfuutil "$DFU_DEVICE" "$WTF_PATH_2012"

    sleep 5
    wait_for_usb "$WTF_DEVICE" || return

    read -rp "Press ENTER to continue flashing firmware..."
    [ -f "$FW_PATH_2012" ] || { err "Missing $FW_PATH_2012"; return; }
    flash_with_dfuutil "$WTF_DEVICE" "$FW_PATH_2012"

    echo
    ask "Choose restore method:\n1) wInd3x\n2) Firmware.MSE via ipodscsi\nEnter 1 or 2: "
    read -r choice

    case $choice in
        1)
            sleep 5
            "$WIND3X_DIR/wInd3x" restore
            ok "Restored using wInd3x."
            ;;
        2)
            FINAL_MSE_2012="$FIRMWARES_DIR/2012/Firmware.MSE"
            [ -f "$IPOD_SCSI" ] || { err "ipodscsi not found."; return; }
            [ -f "$FINAL_MSE_2012" ] || { err "Missing Firmware.MSE."; return; }

            warn "[!] Flashing the wrong disk may harm your computer! Choose carefully."
            echo -e "\n${CYAN}→ All drives/devices:${RESET}"
            lsblk -d -o NAME,SIZE,MODEL | sed 's/^/   /'
            echo
            ask "Input the correct device (e.g., /dev/sda): "
            read -r IPOD_DEVICE

            if [[ -z "$IPOD_DEVICE" || ! -b "$IPOD_DEVICE" ]]; then
                err "Invalid or missing block device: $IPOD_DEVICE"
                read -rp "Press ENTER to return..."
                return
            fi

            sudo "$IPOD_SCSI" "$IPOD_DEVICE" writefirmware -r -p "$FINAL_MSE_2012"
            ok "Firmware flashed via ipodscsi."
            ;;
        *) warn "Invalid choice." ;;
    esac

    echo
    warn "If stuck, use Windows + iTunes to restore."
    read -rp "Press ENTER to return..."
}

# ---- Unbrick 2015 ----
unbrick_2015() {
    download_firmwares
    msg "Put your iPod nano 7G (2015) into DFU mode"
    read -rp "Press ENTER when ready..."
    wait_for_usb "$DFU_DEVICE" || return

    [ -f "$WTF_PATH_2015" ] || { err "Missing WTF: $WTF_PATH_2015"; return; }
    msg "Flashing WTF firmware..."
    flash_with_dfuutil "$DFU_DEVICE" "$WTF_PATH_2015" || return

    sleep 5
    wait_for_usb "$WTF_DEVICE" || { err "WTF mode not detected."; return; }

    ok "Device in WTF Mode. Firmware 1.1.2 available."
    ask "Flash it? (y/n): "
    read -r confirm
    confirm="${confirm,,}"  # convert to lowercase

    if [[ "$confirm" == "y" ]]; then
        [ -f "$FW_PATH_2015" ] || { err "Missing $FW_PATH_2015"; return; }
        msg "Flashing Disk Mode firmware..."
        flash_with_dfuutil "$WTF_DEVICE" "$FW_PATH_2015" || return

        sleep 5
        FINAL_MSE_2015="$FIRMWARES_DIR/2015/Firmware.MSE"
        [ -f "$IPOD_SCSI" ] || { err "ipodscsi not found."; return; }
        [ -f "$FINAL_MSE_2015" ] || { err "Missing Firmware.MSE."; return; }

        warn "[!] Flashing the wrong disk may harm your computer! Choose carefully."
        echo -e "\n${CYAN}→ All drives/devices:${RESET}"
        lsblk -d -o NAME,SIZE,MODEL | sed 's/^/   /'
        echo
        ask "Input the correct device (e.g., /dev/sda): "
        read -r IPOD_DEVICE

        if [[ -z "$IPOD_DEVICE" || ! -b "$IPOD_DEVICE" ]]; then
            err "Invalid or missing block device: $IPOD_DEVICE"
            read -rp "Press ENTER to return..."
            return
        fi

        sudo "$IPOD_SCSI" "$IPOD_DEVICE" writefirmware -r -p "$FINAL_MSE_2015"
        ok "Firmware flashed via ipodscsi."

        echo
        warn "Still stuck in white screen?"
        echo -e "${CYAN}→ Hold SLEEP + HOME → Recovery Mode → Restore via iTunes${RESET}"
    fi

    read -rp "Press ENTER to return..."
}

unbrick_6g() {
    download_firmwares
    msg "Put your iPod nano 6G into Disk Mode or WTF mode"

    ask "Choose restore method:\n1) wInd3x restore\n2) Firmware.MSE via ipodscsi\nEnter 1 or 2: "
    read -r method

    case $method in
        1)
            sleep 5
            "$WIND3X_DIR/wInd3x" restore
            ok "Restored using wInd3x."
            ;;
        2)
            FINAL_MSE_6G="$FIRMWARES_DIR/6G/Firmware.MSE"
            [ -f "$IPOD_SCSI" ] || { err "ipodscsi not found."; return; }
            [ -f "$FINAL_MSE_6G" ] || { err "Missing Firmware.MSE."; return; }

            warn "[!] Flashing the wrong disk may harm your computer! Choose carefully."
            echo -e "\n${CYAN}→ All drives/devices:${RESET}"
            lsblk -d -o NAME,SIZE,MODEL | sed 's/^/   /'
            echo
            ask "Input the correct device (e.g., /dev/sda): "
            read -r IPOD_DEVICE

            if [[ -z "$IPOD_DEVICE" || ! -b "$IPOD_DEVICE" ]]; then
                err "Invalid or missing block device: $IPOD_DEVICE"
                read -rp "Press ENTER to return..."
                return
            fi

            sudo "$IPOD_SCSI" "$IPOD_DEVICE" writefirmware -r -p "$FINAL_MSE_6G"
            ok "Firmware flashed via ipodscsi."
            ;;
        *) warn "Invalid choice." ;;
    esac

    echo
    warn "If stuck, try restoring via iTunes after Disk Mode."
    read -rp "Press ENTER to return..."
}

# ---- Main Menu ----
main_menu() {
    while true; do
        print_banner
        echo -e "${BOLD}1)${RESET} Unbrick iPod Nano 7G (2012)"
        echo -e "${BOLD}2)${RESET} Unbrick iPod Nano 7G (2015)"
        echo -e "${BOLD}3)${RESET} Unbrick iPod Nano 6G"
        echo -e "${BOLD}4)${RESET} Install Required Files/Packages (Recommended to run before unbricking!)"
        echo -e "${BOLD}5)${RESET} Quit"
        ask "Choose an option: "
        read -r opt

        case $opt in
            1) unbrick_2012 ;;
            2) unbrick_2015 ;;
            3) unbrick_6g ;;
            4) install_required_packages ;;
            5) clear; exit 0 ;;
            *) warn "Invalid option." ; sleep 1 ;;
        esac
    done
}

main_menu

#!/bin/bash
set -euo pipefail

# Check for sudo access
if ! sudo -n true 2>/dev/null; then
    echo "This script requires sudo access for USB flashing and firmware writing."
    sudo true || { echo "Sudo access required."; exit 1; }
fi

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

WTF_PATH_2012="$FIRMWARES_DIR/2012_DFU/WTF.x1234.RELEASE.dfu"
FW_PATH_2012="$FIRMWARES_DIR/2012_DFU/FIRMWARE.x1249.RELEASE.dfu"

WTF_PATH_2015="$FIRMWARES_DIR/2015_DFU/WTF.x1234.RELEASE.dfu"
FW_PATH_2015="$FIRMWARES_DIR/2015_DFU/FIRMWARE.x124a.RELEASE.dfu"

WTF_PATH_6G="$FIRMWARES_DIR/6G_DFU/WTF.x1232.RELEASE.dfu"
FW_PATH_6G="$FIRMWARES_DIR/6G_DFU/FIRMWARE.x1248.RELEASE.dfu"

DFU_DEVICE_7G="05ac:1234"
DFU_DEVICE_6G="05ac:1232"
WTF_DEVICE_2012="05ac:1249"
WTF_DEVICE_2015="05ac:124a"
WTF_DEVICE_6G="05ac:1248"

USER_CHOICE=""

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
    echo -e "${CYAN}     Made by Lycan  |  Ver: 1.4   ${RESET}"
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
        sudo apt update && sudo apt install -y git golang libhidapi-libusb0 dfu-util make usbutils
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y git golang libusbx-devel dfu-util make
    elif command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm git go libusb dfu-util usbutils make
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

# ---- Check Dependencies ----
check_dependencies() {
    msg "Checking for required dependencies..."
    missing=()
    for cmd in dfu-util lsusb wget unzip; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [ ${#missing[@]} -eq 0 ]; then
        ok "All dependencies are installed."
        return 0
    else
        warn "Missing dependencies: ${missing[*]}"
        return 1
    fi
}

# ---- Download Firmwares ----
download_firmwares() {
    local model="$1"
    msg "Checking for missing firmware files for $model..."

    FIRMWARE_URL_2012="https://github.com/lycanld/LeUnBrIck/releases/download/hidden/firmware_2012.zip"
    FIRMWARE_URL_2015="https://github.com/lycanld/LeUnBrIck/releases/download/hidden/firmware_2015.zip"
    FIRMWARE_URL_6G="https://github.com/lycanld/LeUnBrIck/releases/download/hidden/firmware_6G.zip"

    if [ "$model" = "6G" ]; then
        mkdir -p "$FIRMWARES_DIR/6G"
        if [ ! -f "$FIRMWARES_DIR/6G/Firmware.MSE" ]; then
            msg "Downloading firmware for iPod nano 6G..."
            wget -O /tmp/fw6g.zip "$FIRMWARE_URL_6G" || { err "Download failed."; return; }
            unzip -o /tmp/fw6g.zip -d "$FIRMWARES_DIR/6G/"
            ok "Extracted 6G firmware."
        fi
    elif [ "$model" = "7G" ]; then
        mkdir -p "$FIRMWARES_DIR/2012" "$FIRMWARES_DIR/2015"
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





# ---- Unbrick 6G ----
unbrick_6g() {
    download_firmwares "6G"
    msg "Put your iPod nano 6G into DFU mode"
    echo -e "${CYAN}→ Hold VOLUME DOWN + POWER until black screen + connection sound.${RESET}"
    read -rp "Press ENTER when ready..."
    wait_for_usb "$DFU_DEVICE_6G" || return

    [ -f "$WTF_PATH_6G" ] || { err "Missing WTF: $WTF_PATH_6G"; return; }
    msg "Flashing WTF firmware..."
    flash_with_dfuutil "$DFU_DEVICE_6G" "$WTF_PATH_6G" || return

    sleep 5
    wait_for_usb "$WTF_DEVICE_6G" || { err "WTF mode not detected."; return; }

    ok "Device in WTF Mode. Disk Mode firmware available."
    ask "Flash it? (y/n): "
    read -r confirm
    confirm="${confirm,,}"  # convert to lowercase

    if [[ "$confirm" == "y" ]]; then
        [ -f "$FW_PATH_6G" ] || { err "Missing $FW_PATH_6G"; return; }
        msg "Flashing Disk Mode firmware..."
        flash_with_dfuutil "$WTF_DEVICE_6G" "$FW_PATH_6G" || return

        sleep 5
        FINAL_MSE_6G="$FIRMWARES_DIR/6G/Firmware.MSE"
        [ -f "$IPOD_SCSI" ] || { err "ipodscsi not found."; return; }
        [ -f "$FINAL_MSE_6G" ] || { err "Missing Firmware.MSE."; return; }

        warn "[!] Flashing the wrong disk may harm your computer! Choose carefully."
        echo -e "\n${CYAN}→ All drives/devices:${RESET}"
        lsblk -d -o NAME,SIZE,MODEL | sed 's/^/   /'
        echo
        echo -e "${YELLOW}Note: The correct disk should be labeled 'iPod' in the MODEL column.${RESET}"
        echo

        while true; do
            ask "Input the correct device (e.g., sda or /dev/sda): "
            read -r IPOD_DEVICE

            # Auto-prepend /dev/ if user typed only the short name
            [[ "$IPOD_DEVICE" != /dev/* ]] && IPOD_DEVICE="/dev/$IPOD_DEVICE"

            if [[ -z "$IPOD_DEVICE" || ! -b "$IPOD_DEVICE" ]]; then
                err "Invalid or missing block device: $IPOD_DEVICE"
                continue
            fi

            ask "You selected $IPOD_DEVICE. Type YES to confirm: "
            read -r really
            if [[ "$really" == "YES" ]]; then
                break
            else
                warn "Aborted by user. Please try again."
            fi
        done

        sudo "$IPOD_SCSI" "$IPOD_DEVICE" writefirmware -r -p "$FINAL_MSE_6G"
        ok "Firmware flashed via ipodscsi."

        echo
        warn "Still stuck in white screen?"
        echo -e "${CYAN}→ Hold Sleep/Wake + Volume down → Disk Mode → Restore via iTunes${RESET}"
    fi

    read -rp "Press ENTER to return..."
}


# ---- Auto-detect and Unbrick iPod Nano 7G ----
unbrick_7g() {
    download_firmwares "7G"
    msg "Put your iPod nano 7G into DFU mode"
    echo -e "${CYAN}→ USB-A to Lightning + Hold SLEEP + HOME until black screen + connection sound.${RESET}"
    read -rp "Press ENTER when ready..."
    wait_for_usb "$DFU_DEVICE_7G" || return

    [ -f "$WTF_PATH_2012" ] || { err "Missing WTF firmware: $WTF_PATH_2012"; return; }
    msg "Flashing WTF firmware..."
    flash_with_dfuutil "$DFU_DEVICE_7G" "$WTF_PATH_2012" || return

    sleep 5

    msg "Detecting iPod model..."
    detected=false
    for i in {1..20}; do
        if lsusb | grep -i "$WTF_DEVICE_2012" > /dev/null; then
            MODEL="2012"
            WTF_DEVICE="$WTF_DEVICE_2012"
            FW_PATH="$FW_PATH_2012"
            FINAL_MSE="$FIRMWARES_DIR/2012/Firmware.MSE"
            ok "Detected iPod Nano 7G (2012)"
            detected=true
            break
        elif lsusb | grep -i "$WTF_DEVICE_2015" > /dev/null; then
            MODEL="2015"
            WTF_DEVICE="$WTF_DEVICE_2015"
            FW_PATH="$FW_PATH_2015"
            FINAL_MSE="$FIRMWARES_DIR/2015/Firmware.MSE"
            ok "Detected iPod Nano 7G (2015)"
            detected=true
            break
        fi
        sleep 1
    done
    if ! $detected; then
        err "Could not detect iPod model after flashing WTF firmware."
        return
    fi

    ask "Flash Disk Mode firmware for $MODEL? (y/n): "
    read -r confirm
    confirm="${confirm,,}"

    if [[ "$confirm" == "y" ]]; then
        [ -f "$FW_PATH" ] || { err "Missing Disk Mode firmware: $FW_PATH"; return; }
        msg "Flashing Disk Mode firmware..."
        flash_with_dfuutil "$WTF_DEVICE" "$FW_PATH" || return

        sleep 5
        [ -f "$IPOD_SCSI" ] || { err "ipodscsi not found."; return; }
        [ -f "$FINAL_MSE" ] || { err "Missing Firmware.MSE."; return; }

        warn "[!] Flashing the wrong disk may harm your computer! Choose carefully."
        echo -e "\n${CYAN}→ All drives/devices:${RESET}"
        lsblk -d -o NAME,SIZE,MODEL | sed 's/^/   /'
        echo
        echo -e "${YELLOW}Note: The correct disk should be labeled 'iPod' in the MODEL column.${RESET}"
        echo

        while true; do
            ask "Input the correct device (e.g., sda or /dev/sda): "
            read -r IPOD_DEVICE

            # Auto-prepend /dev/ if user typed only the short name
            [[ "$IPOD_DEVICE" != /dev/* ]] && IPOD_DEVICE="/dev/$IPOD_DEVICE"

            if [[ -z "$IPOD_DEVICE" || ! -b "$IPOD_DEVICE" ]]; then
                err "Invalid or missing block device: $IPOD_DEVICE"
                continue
            fi

            ask "You selected $IPOD_DEVICE. Type YES to confirm: "
            read -r really
            if [[ "$really" == "YES" ]]; then
                break
            else
                warn "Aborted by user. Please try again."
            fi
        done

        sudo "$IPOD_SCSI" "$IPOD_DEVICE" writefirmware -r -p "$FINAL_MSE"
        ok "Firmware flashed via ipodscsi."

        echo
        warn "Still stuck in white screen?"
        echo -e "${CYAN}→ Hold SLEEP + HOME → Recovery Mode → Restore via iTunes${RESET}"
    fi

    read -rp "Press ENTER to return..."
}

# ---- Show Credits ----
show_credits() {
    clear
    echo -e "${CYAN}=========================================${RESET}"
    echo -e "${BOLD}${CYAN}               Credits               ${RESET}"
    echo -e "${CYAN}=========================================${RESET}"
    echo
    echo -e "${GREEN}${BOLD}## 🙌 Special Thanks${RESET}"
    echo
    echo "Huge appreciation to the amazing contributors and community members who made this project possible:"
    echo
    echo -e "${YELLOW}- ${BOLD}@LycanLD${RESET}${YELLOW} — Creator of LeUnBrIck and lead developer${RESET}"
    echo -e "${YELLOW}- ${BOLD}@Ruff${RESET}${YELLOW} — Packaging, testing, and distribution${RESET}"
    echo -e "${YELLOW}- ${BOLD}@nfzerox${RESET}${YELLOW} — For ipod_theme${RESET}"
    echo -e "${YELLOW}- ${BOLD}@CUB3D${RESET}${YELLOW} - For ipod_sun${RESET}"
    echo -e "${YELLOW}- ${BOLD}@freemyipod${RESET}${YELLOW} — For wInd3x, freemyipod and ipodscsi${RESET}"
    echo -e "${YELLOW}- ${BOLD}@Stefan-Schmidt${RESET}${YELLOW} — For dfu_utils${RESET}"
    echo -e "${YELLOW}- ${BOLD}@760ceb3b9c0ba4872cadf3ce35a7a494${RESET}${YELLOW} — For ipodhax and other IPSW unpacking scripts (+ He helped me unbrick mine the hard way)${RESET}"
    echo -e "${YELLOW}- ${BOLD}@Zeehondie${RESET}${YELLOW} — Cuz he's a seal${RESET}"
    echo
    echo -e "${BLUE}---${RESET}"
    echo
    echo -e "${GREEN}${BOLD}## 💬 Join the Community${RESET}"
    echo
    echo "Want help, mods, or just to show off your themed iPod? Join us on Discord:"
    echo
    echo -e "${CYAN}- 🎨 ${BOLD}iPod Theme Discord${RESET}${CYAN}: https://discord.com/invite/SfWYYPUAEZ${RESET}"
    echo -e "${CYAN}- 🔧 ${BOLD}iPod Modding Discord${RESET}${CYAN}: https://discord.com/invite/7PnGEXjW3X${RESET}"
    echo
    echo -e "${BLUE}---${RESET}"
    echo
    echo -e "${GREEN}${BOLD}## ⭐Remember to give this project a star if you like it / if it worked for you.🌟${RESET}"
    echo
    echo -e "${BLUE}---${RESET}"
    echo
    echo -e "${GREEN}${BOLD}## 📜 License${RESET}"
    echo
    echo "MIT License — free to use, fork, and modify."
    echo "Contributions welcome!"
    echo
    echo -e "${BLUE}---${RESET}"
    echo
    echo -e "${GREEN}${BOLD}## ✨ Created by [Lycan](https://github.com/lycanld)${RESET}"
    echo
    echo -e "${YELLOW}### 📦 Distributed by ${BOLD}Ruff's Softwares & Games${RESET}${YELLOW}${RESET}"
    echo
    echo -e "${CYAN}=========================================${RESET}"
    read -rp "Press ENTER to return to menu..."
}

# ---- Main Menu ----
main_menu() {
    # Check dependencies
    if ! check_dependencies; then
        install_required_packages
    fi

    while true; do
        print_banner
        echo -e "${CYAN}=========================================${RESET}"
        echo -e "${BOLD}Select an option:${RESET}"
        echo "1. Unbrick iPod Nano 6G"
        echo "2. Unbrick iPod Nano 7G (2012/2015)"
        echo "3. Install Required Files/Packages"
        echo "4. Credits"
        echo "5. Quit"
        echo -e "${CYAN}=========================================${RESET}"
        ask "Choice: "
        read -r opt

        case $opt in
            1) USER_CHOICE="6G"; unbrick_6g ;;
            2) USER_CHOICE="7G"; unbrick_7g ;;
            3) install_required_packages ;;
            4) show_credits ;;
            5) clear; exit 0 ;;
            *) warn "Invalid option." ; sleep 1 ;;
        esac
    done
}

main_menu

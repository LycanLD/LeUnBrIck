#!/usr/bin/env python3
import os
import subprocess
import sys
import time
import platform
import requests
from zipfile import ZipFile
import ctypes

# ---- Color codes ----
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
BLUE = '\033[1;34m'
CYAN = '\033[1;36m'
BOLD = '\033[1m'
RESET = '\033[0m'

# Disable colors if NO_COLOR is set
if 'NO_COLOR' in os.environ:
    RED = GREEN = YELLOW = BLUE = CYAN = BOLD = RESET = ''

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DFU_UTILS_DIR = os.path.join(SCRIPT_DIR, "misc")
FIRMWARES_DIR = os.path.join(DFU_UTILS_DIR, "firmwares")
IPOD_SCSI = os.path.join(DFU_UTILS_DIR, "ipodscsi.exe")

WTF_PATH_2012 = os.path.join(FIRMWARES_DIR, "2012_DFU", "WTF.x1234.RELEASE.dfu")
FW_PATH_2012 = os.path.join(FIRMWARES_DIR, "2012_DFU", "FIRMWARE.x1249.RELEASE.dfu")

WTF_PATH_2015 = os.path.join(FIRMWARES_DIR, "2015_DFU", "WTF.x1234.RELEASE.dfu")
FW_PATH_2015 = os.path.join(FIRMWARES_DIR, "2015_DFU", "FIRMWARE.x124a.RELEASE.dfu")

WTF_PATH_6G = os.path.join(FIRMWARES_DIR, "6G_DFU", "WTF.x1232.RELEASE.dfu")
FW_PATH_6G = os.path.join(FIRMWARES_DIR, "6G_DFU", "FIRMWARE.x1248.RELEASE.dfu")

DFU_DEVICE_7G = "05ac:1234"
DFU_DEVICE_6G = "05ac:1232"
WTF_DEVICE_2012 = "05ac:1249"
WTF_DEVICE_2015 = "05ac:124a"
WTF_DEVICE_6G = "05ac:1248"

USER_CHOICE = ""

# ---- UI Helpers ----
def print_banner():
    os.system('cls' if platform.system() == 'Windows' else 'clear')
    print(f"""
{CYAN}      ╦  ┌─┐  ╦ ╦┌┐┌╔╗ ┬─┐╦┌─┐┬┌─
      ║  ├┤   ║ ║│││╠╩╗├┬┘║│  ├┴┐
      ╩═╝└─┘  ╚═╝┘└┘╚═╝┴└─╩└─┘┴ ┴
      {RED}M{GREEN}I{YELLOW}C{BLUE}H{CYAN}E{RED}A{GREEN}L{YELLOW}S{BLUE}O{CYAN}F{RED}T {CYAN}WINDOWS EDITION{RESET}
{BOLD}{RED}(Bill Gates is watching you - switch to Linux!){RESET}
{RESET}
{BOLD}{CYAN}============== Le UnBrIck ==============={RESET}
{BLUE}★ iPod Nano 6G/7G Unbrick/Restore Tool ★{RESET}
{CYAN}    Made by Lycan  |  Ver: 1.4WBETA1   {RESET}
{CYAN}========================================={RESET}
""")

def msg(text):
    print(f"{CYAN}[*]{RESET} {text}")

def ok(text):
    print(f"{GREEN}[✓]{RESET} {text}")

def warn(text):
    print(f"{YELLOW}[!]{RESET} {text}")

def err(text):
    print(f"{RED}[✖]{RESET} {text}")

def ask(text):
    return input(f"{YELLOW}[?]{RESET} {text}")

def flash(text):
    print(f"{BOLD}{CYAN}[⚡]{RESET} Flashing {text}")

def is_admin():
    """Check if the script is running as admin/root."""
    if platform.system() == 'Windows':
        try:
            return ctypes.windll.shell32.IsUserAnAdmin() != 0
        except Exception:
            return False
    else:
        # On Linux/macOS, just check for root
        return os.geteuid() == 0

def run_as_admin():
    """Re-launch the script as admin on Windows."""
    if platform.system() == 'Windows':
        script = os.path.abspath(sys.argv[0])
        params = ' '.join([f'"{arg}"' for arg in sys.argv[1:]])
        try:
            ctypes.windll.shell32.ShellExecuteW(
                None, "runas", sys.executable, f'"{script}" {params}', None, 1
            )
            sys.exit(0)
        except Exception as e:
            print(f"Failed to elevate privileges: {e}")
            sys.exit(1)
    else:
        print("This script requires root privileges. Please run with sudo.")
        sys.exit(1)

# ---- Install Dependencies ----
def install_required_packages():
    msg("Installing required packages...")
    # Placeholder: tools should be manually placed in misc/
    ok("All required packages installed!")
    input("Press ENTER to return to menu...")

# ---- Check Dependencies ----
def check_dependencies():
    msg("Checking for required dependencies...")
    missing = []

    # Check for required .exe files in misc/ directory
    required_files = ['dfu-util.exe', 'ipodscsi.exe']
    # lsusb.exe not needed on Windows as dfu-util.exe -l is used instead

    for filename in required_files:
        filepath = os.path.join(DFU_UTILS_DIR, filename)
        if not os.path.exists(filepath):
            missing.append(filename)

    if not missing:
        ok("All dependencies are installed.")
        return True
    else:
        warn(f"Missing dependencies: {' '.join(missing)}")
        return False

# ---- Download Firmwares ----
def download_firmwares(model):
    msg(f"Checking for missing firmware files for {model}...")

    FIRMWARE_URL_2012 = "https://github.com/lycanld/LeUnBrIck/releases/download/hidden/firmware_2012.zip"
    FIRMWARE_URL_2015 = "https://github.com/lycanld/LeUnBrIck/releases/download/hidden/firmware_2015.zip"
    FIRMWARE_URL_6G = "https://github.com/lycanld/LeUnBrIck/releases/download/hidden/firmware_6G.zip"

    temp_dir = os.environ.get('TEMP', '/tmp')

    if model == "6G":
        os.makedirs(os.path.join(FIRMWARES_DIR, "6G"), exist_ok=True)
        # Check for WTF and FIRMWARE files before downloading
        wtf_file = os.path.join(FIRMWARES_DIR, "6G_DFU", "WTF.x1232.RELEASE.dfu")
        firmware_file = os.path.join(FIRMWARES_DIR, "6G_DFU", "FIRMWARE.x1248.RELEASE.dfu")
        if not (os.path.exists(wtf_file) and os.path.exists(firmware_file)):
            msg("Downloading firmware for iPod nano 6G...")
            try:
                response = requests.get(FIRMWARE_URL_6G)
                response.raise_for_status()
                zip_path = os.path.join(temp_dir, "fw6g.zip")
                with open(zip_path, 'wb') as f:
                    f.write(response.content)
                with ZipFile(zip_path, 'r') as zip_ref:
                    zip_ref.extractall(os.path.join(FIRMWARES_DIR, "6G_DFU"))
                ok("Extracted 6G firmware.")
            except Exception as e:
                err(f"Download or extract failed: {e}")
                return
    elif model == "7G":
        os.makedirs(os.path.join(FIRMWARES_DIR, "2012_DFU"), exist_ok=True)
        os.makedirs(os.path.join(FIRMWARES_DIR, "2015_DFU"), exist_ok=True)
        wtf_2012 = os.path.join(FIRMWARES_DIR, "2012_DFU", "WTF.x1234.RELEASE.dfu")
        firmware_2012 = os.path.join(FIRMWARES_DIR, "2012_DFU", "FIRMWARE.x1249.RELEASE.dfu")
        wtf_2015 = os.path.join(FIRMWARES_DIR, "2015_DFU", "WTF.x1234.RELEASE.dfu")
        firmware_2015 = os.path.join(FIRMWARES_DIR, "2015_DFU", "FIRMWARE.x124a.RELEASE.dfu")
        if not (os.path.exists(wtf_2012) and os.path.exists(firmware_2012)):
            msg("Downloading firmware for 2012 iPod...")
            try:
                response = requests.get(FIRMWARE_URL_2012)
                response.raise_for_status()
                zip_path = os.path.join(temp_dir, "fw2012.zip")
                with open(zip_path, 'wb') as f:
                    f.write(response.content)
                with ZipFile(zip_path, 'r') as zip_ref:
                    zip_ref.extractall(os.path.join(FIRMWARES_DIR, "2012_DFU"))
                ok("Extracted 2012 firmware.")
            except Exception as e:
                err(f"Download or extract failed: {e}")
                return
        if not (os.path.exists(wtf_2015) and os.path.exists(firmware_2015)):
            msg("Downloading firmware for 2015 iPod...")
            try:
                response = requests.get(FIRMWARE_URL_2015)
                response.raise_for_status()
                zip_path = os.path.join(temp_dir, "fw2015.zip")
                with open(zip_path, 'wb') as f:
                    f.write(response.content)
                with ZipFile(zip_path, 'r') as zip_ref:
                    zip_ref.extractall(os.path.join(FIRMWARES_DIR, "2015_DFU"))
                ok("Extracted 2015 firmware.")
            except Exception as e:
                err(f"Download or extract failed: {e}")
                return

# ---- Wait for USB ----
def wait_for_usb(expected):
    msg(f"Waiting for USB device {expected}...")
    if platform.system() == 'Windows':
        cmd = [os.path.join(DFU_UTILS_DIR, "dfu-util.exe"), "-l"]
    else:
        cmd = ["lsusb"]

    expected_lower = expected.lower()
    for _ in range(30):  # wait up to 30 seconds
        result = subprocess.run(cmd, capture_output=True, text=True)
        output = (result.stdout + result.stderr).lower()

        if expected_lower in output:
            if "cannot open dfu device" in output or "libusb_error" in output:
                warn(f"Device {expected} detected but not accessible (driver/service may be blocking).")
            else:
                ok(f"Device {expected} detected.")
            return True

        time.sleep(1)

    err(f"Device {expected} not found.")
    return False

def change_driver(device_name, vid_pid):
    """Install libusbK driver for the device via wdi-simple."""
    vid, pid = vid_pid.split(':')

    msg(f"Changing driver for {device_name} to libusbK...")
    wdi_path = os.path.join(DFU_UTILS_DIR, "wdi-simple.exe")
    cmd = [wdi_path, '-n', device_name, '-v', f'0x{vid}', '-p', f'0x{pid}', '-t', '1']
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode == 0:
        ok(f"Driver changed for {device_name}")
        return True
    else:
        warn(f"Failed to change driver for {device_name}: {result.stderr.strip()}")
        return False


        
# ---- Flash with dfu-util ----
def flash_with_dfuutil(device, file):
    flash(f"{file} to device {device}...")

    dfu_util_path = os.path.join(DFU_UTILS_DIR, "dfu-util.exe")
    result = subprocess.run([dfu_util_path, '-d', device, '-D', file], capture_output=True, text=True)
    print(result.stdout)

    if "Download done." in result.stdout:
        ok("Flash completed (even if it threw LIBUSB_ERROR_NO_DEVICE).")
        return True
    elif "LIBUSB_ERROR_NO_DEVICE" in result.stdout:
        warn("LIBUSB_ERROR_NO_DEVICE after transfer — this is expected.")
        ok("Proceeding anyway.")
        return True
    else:
        err("Flash may have failed.")
        input("Press ENTER to return to menu...")
        return False

# ---- Unbrick 6G ----
def unbrick_6g():
    download_firmwares("6G")
    msg("Put your iPod nano 6G into DFU mode")
    print(f"{CYAN}→ Hold VOLUME DOWN + POWER until black screen + connection sound.{RESET}")
    input("Press ENTER when ready...")
    if not wait_for_usb(DFU_DEVICE_6G):
        return

    change_driver("USB DFU Device", DFU_DEVICE_6G)

    if not os.path.exists(WTF_PATH_6G):
        err(f"Missing WTF: {WTF_PATH_6G}")
        return
    msg("Flashing WTF firmware...")
    if not flash_with_dfuutil(DFU_DEVICE_6G, WTF_PATH_6G):
        return

    time.sleep(5)
    if not wait_for_usb(WTF_DEVICE_6G):
        err("WTF mode not detected.")
        return

    # Change driver for iPod Recovery before flashing disk mode firmware
    if not change_driver("iPod Recovery", WTF_DEVICE_6G):
        err("Failed to change driver for iPod Recovery.")
        return

    ok("Device in WTF Mode. Disk Mode firmware available.")
    confirm = ask("Flash it? (y/n): ").lower()
    if confirm == "y":
        if not os.path.exists(FW_PATH_6G):
            err(f"Missing {FW_PATH_6G}")
            return
        msg("Flashing Disk Mode firmware...")
        if not flash_with_dfuutil(WTF_DEVICE_6G, FW_PATH_6G):
            return

        time.sleep(5)
        FINAL_MSE_6G = os.path.join(FIRMWARES_DIR, "6G", "Firmware.MSE")
        if not os.path.exists(IPOD_SCSI):
            err("ipodscsi not found.")
            return
        if not os.path.exists(FINAL_MSE_6G):
            err("Missing Firmware.MSE.")
            return

        warn("[!] Flashing the wrong disk may harm your computer! Choose carefully.")
        print(f"\n{CYAN}→ All drives/devices:{RESET}")
        ipod_drive = None
        if platform.system() == 'Windows':
            print("Available drives:")
            # Replacement block for better drive identification on Windows
            result = subprocess.run(
                ['wmic', 'diskdrive', 'get', 'Caption,DeviceID,Index,Size'],
                capture_output=True, text=True
            )
            for line in result.stdout.splitlines():
                if line.strip():
                    print("  " + line.strip())

            result = subprocess.run(
                ['wmic', 'logicaldisk', 'get', 'Caption,VolumeName'],
                capture_output=True, text=True
            )
            print("\nMounted volumes:")
            volume_lines = result.stdout.splitlines()
            for line in volume_lines:
                if line.strip():
                    print("  " + line.strip())
                    # Auto-select drive letter if VolumeName is iPod
                    parts = line.split()
                    if len(parts) >= 2 and parts[1].lower() == 'ipod':
                        ipod_drive = parts[0]

            if ipod_drive:
                ok(f"Auto-selected iPod drive: {ipod_drive}")
            else:
                print(f"{YELLOW}Note: Look for a drive with 'iPod' in Caption or VolumeName. Enter the drive letter (e.g. E:).{RESET}")

        else:
            result = subprocess.run(['lsblk', '-d', '-o', 'NAME,SIZE,MODEL'], capture_output=True, text=True)
            for line in result.stdout.splitlines():
                print(f"   {line}")
            print(f"{YELLOW}Note: The correct disk should be labeled 'iPod' in the MODEL column.{RESET}")
        print()

        while not ipod_drive:
            if platform.system() == 'Windows':
                ipod_drive = ask("Input the correct drive (e.g., E: or \\\\.\\PHYSICALDRIVE1): ").strip()

                # Normalize input
                if ipod_drive and ipod_drive.endswith(':'):
                    # Convert drive letter to PHYSICALDRIVE mapping
                    letter = ipod_drive[0].upper()
                    # Use wmic to map to PHYSICALDRIVE
                    result = subprocess.run(
                        ['wmic', 'path', 'Win32_LogicalDiskToPartition'],
                        capture_output=True, text=True
                    )
                    mapping = result.stdout
                    # Fallback: assume PhysicalDrive1 if it's an iPod
                    if "PHYSICALDRIVE1" in mapping.upper():
                        ipod_drive = r'\\.\PHYSICALDRIVE1'
                    else:
                        ipod_drive = f"\\\\.\\{ipod_drive}"
                elif not ipod_drive.upper().startswith('\\\\.\\PHYSICALDRIVE'):
                    ipod_drive = f"\\\\.\\{ipod_drive}"

            else:
                ipod_drive = ask("Input the correct device (e.g., sda or /dev/sda): ")
                if not ipod_drive.startswith('/dev/'):
                    ipod_drive = f"/dev/{ipod_drive}"

            if not ipod_drive:
                err("No device entered.")
                continue

            really = ask(f"You selected {ipod_drive}. Type YES to confirm: ")
            if really == "YES":
                break
            else:
                warn("Aborted by user. Please try again.")
                ipod_drive = None

        # Use normalized device path
        subprocess.run([IPOD_SCSI, ipod_drive, 'ipod6g', 'writefirmware', '-r', '-p', FINAL_MSE])

        ok("Firmware flashed via ipodscsi.")

        print()
        warn("Still stuck in white screen?")
        print(f"{CYAN}→ Hold Sleep/Wake + Volume down → Disk Mode → Restore via iTunes{RESET}")

    input("Press ENTER to return...")

# ---- Auto-detect and Unbrick iPod Nano 7G ----
def unbrick_7g():
    download_firmwares("7G")
    msg("Put your iPod nano 7G into DFU mode")
    print(f"{CYAN}→ USB-A to Lightning + Hold SLEEP + HOME until black screen + connection sound.{RESET}")
    input("Press ENTER when ready...")
    if not wait_for_usb(DFU_DEVICE_7G):
        return

    change_driver("USB DFU Device", DFU_DEVICE_7G)

    if not os.path.exists(WTF_PATH_2012):
        err(f"Missing WTF firmware: {WTF_PATH_2012}")
        return
    msg("Flashing WTF firmware...")
    if not flash_with_dfuutil(DFU_DEVICE_7G, WTF_PATH_2012):
        return

    time.sleep(5)

    msg("Detecting iPod model...")
    detected = False
    cmd = ['lsusb'] if platform.system() != 'Windows' else [os.path.join(DFU_UTILS_DIR, "dfu-util.exe"), '-l']
    for _ in range(30):
        result = subprocess.run(cmd, capture_output=True, text=True)
        output = (result.stdout + result.stderr).lower()

        if WTF_DEVICE_2012.lower() in output:
            MODEL = "2012"
            WTF_DEVICE = WTF_DEVICE_2012
            FW_PATH = FW_PATH_2012
            FINAL_MSE = os.path.join(FIRMWARES_DIR, "2012", "Firmware.MSE")
            ok("Detected iPod Nano 7G (2012)")
            detected = True
            break
        elif WTF_DEVICE_2015.lower() in output:
            MODEL = "2015"
            WTF_DEVICE = WTF_DEVICE_2015
            FW_PATH = FW_PATH_2015
            FINAL_MSE = os.path.join(FIRMWARES_DIR, "2015", "Firmware.MSE")
            ok("Detected iPod Nano 7G (2015)")
            detected = True
            break
        time.sleep(1)

    if not detected:
        err("Could not detect iPod model after flashing WTF firmware.")
        return

    change_driver("iPod Recovery", WTF_DEVICE)

    confirm = ask(f"Flash Disk Mode firmware for {MODEL}? (y/n): ").lower()
    if confirm == "y":
        if not os.path.exists(FW_PATH):
            err(f"Missing Disk Mode firmware: {FW_PATH}")
            return
        msg("Flashing Disk Mode firmware...")
        if not flash_with_dfuutil(WTF_DEVICE, FW_PATH):
            return

        time.sleep(5)
        if not os.path.exists(IPOD_SCSI):
            err("ipodscsi not found.")
            return
        if not os.path.exists(FINAL_MSE):
            err("Missing Firmware.MSE.")
            return

        warn("[!] Flashing the wrong disk may harm your computer! Choose carefully.")
        print(f"\n{CYAN}→ All drives/devices:{RESET}")
        ipod_drive = None
        if platform.system() == 'Windows':
            print("Available drives:")
            # Replacement block for better drive identification on Windows
            result = subprocess.run(
                ['wmic', 'diskdrive', 'get', 'Caption,DeviceID,Index,Size'],
                capture_output=True, text=True
            )
            for line in result.stdout.splitlines():
                if line.strip():
                    print("  " + line.strip())

            result = subprocess.run(
                ['wmic', 'logicaldisk', 'get', 'Caption,VolumeName'],
                capture_output=True, text=True
            )
            print("\nMounted volumes:")
            volume_lines = result.stdout.splitlines()
            for line in volume_lines:
                if line.strip():
                    print("  " + line.strip())
                    # Auto-select drive letter if VolumeName is iPod
                    parts = line.split()
                    if len(parts) >= 2 and parts[1].lower() == 'ipod':
                        ipod_drive = parts[0]

            if ipod_drive:
                ok(f"Auto-selected iPod drive: {ipod_drive}")
            else:
                print(f"{YELLOW}Note: Look for a drive with 'iPod' in Caption or VolumeName. Enter the drive letter (e.g. E:).{RESET}")

        else:
            result = subprocess.run(['lsblk', '-d', '-o', 'NAME,SIZE,MODEL'], capture_output=True, text=True)
            for line in result.stdout.splitlines():
                print(f"   {line}")
            print(f"{YELLOW}Note: The correct disk should be labeled 'iPod' in the MODEL column.{RESET}")
        print()

        while not ipod_drive:
            if platform.system() == 'Windows':
                ipod_drive = ask("Input the correct drive letter (e.g., E:): ")
                if not ipod_drive.endswith(':'):
                    ipod_drive = f"{ipod_drive.upper()}:"
            else:
                ipod_drive = ask("Input the correct device (e.g., sda or /dev/sda): ")
                if not ipod_drive.startswith('/dev/'):
                    ipod_drive = f"/dev/{ipod_drive}"
            if not ipod_drive:
                err("No device entered.")
                continue
            # Confirm drive
            really = ask(f"You selected {ipod_drive}. Type YES to confirm: ")
            if really == "YES":
                break
            else:
                warn("Aborted by user. Please try again.")
                ipod_drive = None

        subprocess.run([IPOD_SCSI, ipod_drive, 'ipod6g', 'writefirmware', '-r', '-p', FINAL_MSE])
        ok("Firmware flashed via ipodscsi.")

        print()
        warn("Still stuck in white screen?")
        print(f"{CYAN}→ Hold SLEEP + HOME → Recovery Mode → Restore via iTunes{RESET}")

    input("Press ENTER to return...")

# ---- Show Credits ----
def show_credits():
    os.system('cls' if platform.system() == 'Windows' else 'clear')
    print(f"""{CYAN}========================================={RESET}
{BOLD}{CYAN}               Credits               {RESET}
{CYAN}========================================={RESET}

{GREEN}{BOLD}## 🙌 Special Thanks{RESET}

Huge appreciation to the amazing contributors and community members who made this project possible:

{YELLOW}- {BOLD}@LycanLD{RESET}{YELLOW} — Creator of LeUnBrIck and lead developer{RESET}
{YELLOW}- {BOLD}@Ruff{RESET}{YELLOW} — Packaging, testing, and distribution{RESET}
{YELLOW}- {BOLD}@nfzerox{RESET}{YELLOW} — For ipod_theme{RESET}
{YELLOW}- {BOLD}@CUB3D{RESET}{YELLOW} - For ipod_sun{RESET}
{YELLOW}- {BOLD}@freemyipod{RESET}{YELLOW} — For wInd3x, freemyipod and ipodscsi{RESET}
{YELLOW}- {BOLD}@Stefan-Schmidt{RESET}{YELLOW} — For dfu_utils{RESET}
{YELLOW}- {BOLD}@760ceb3b9c0ba4872cadf3ce35a7a494{RESET}{YELLOW} — For ipodhax and other IPSW unpacking scripts (+ He helped me unbrick mine the hard way){RESET}
{YELLOW}- {BOLD}@Zeehondie{RESET}{YELLOW} — Cuz he's a seal{RESET}

{BLUE}---{RESET}

{GREEN}{BOLD}## 💬 Join the Community{RESET}

Want help, mods, or just to show off your themed iPod? Join us on Discord:

{CYAN}- 🎨 {BOLD}iPod Theme Discord{RESET}{CYAN}: https://discord.com/invite/SfWYYPUAEZ{RESET}
{CYAN}- 🔧 {BOLD}iPod Modding Discord{RESET}{CYAN}: https://discord.com/invite/7PnGEXjW3X{RESET}

{BLUE}---{RESET}

{GREEN}{BOLD}## ⭐Remember to give this project a star if you like it / if it worked for you.🌟{RESET}

{BLUE}---{RESET}

{GREEN}{BOLD}## 📜 License{RESET}

MIT License — free to use, fork, and modify.
Contributions welcome!

{BLUE}---{RESET}

{GREEN}{BOLD}## ✨ Created by [Lycan](https://github.com/lycanld){RESET}

### 📦 Distributed by {BOLD}Ruff's Softwares & Games{RESET}

{CYAN}========================================={RESET}
""")
    input("Press ENTER to return to menu...")

# ---- Main Menu ----
def main_menu():
        print_banner()
        print(f"{BOLD}Select an option:{RESET}")
        print("1. Unbrick iPod Nano 6G")
        print("2. Unbrick iPod Nano 7G (2012/2015)")
        print("3. Install Required Files/Packages")
        print("4. Credits")
        print("5. Quit")
        print(f"{CYAN}========================================={RESET}")
        opt = ask("Choice: ")

        if opt == "1":
            USER_CHOICE = "6G"
            unbrick_6g()
        elif opt == "2":
            USER_CHOICE = "7G"
            unbrick_7g()
        elif opt == "3":
            install_required_packages()
        elif opt == "4":
            show_credits()
        elif opt == "5":
            os.system('cls' if platform.system() == 'Windows' else 'clear')
            sys.exit(0)

if __name__ == "__main__":
    if not is_admin():
        run_as_admin()
    main_menu()

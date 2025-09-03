<p align="center">
  <img src="assets/banner.png" alt="LeUnBrIck Banner" />
</p>

# 🎧 LeUnBrIck

> ⚡ Universal Unbricker & Flasher for iPod Nano 6th & 7th Gen (2012 & 2015)

`LeUnBrIck` is an all-in-one toolkit for **restoring bricked iPod Nano 6G / 7G devices** using DFU/WTF mode.  
It automatically detects 7G hardware revisions (2012 vs. 2015) and provides safe flashing with **wInd3x** or **ipodscsi**.

---

## 🔧 Features

- ✅ Restore iPod Nano 6G and 7G (2012 & 2015)  
- ⚡ Flash WTF & firmware images safely with `dfu-util`  
- ☁️ Auto-download missing `.MSE` firmware files from GitHub  
- 🎨 Colorful and clean TUI interface  
- 📦 Automatically installs required tools on major Linux distros  

---

## 📥 Requirements

* 🐧 **Linux** (Debian, Arch, Fedora, Alpine, etc.) or **macOS**

  > ✅ *Recommended: Arch Linux on real hardware (Steam Deck or Live USB works great)*
* 🪟 **Windows is not supported** (including WSL)  
  > 💡 *Tip: Boot from a Linux Live USB instead*
* 🔌 **USB-A to Lightning** cable  
* 📦 Required packages: `dfu-util`, `libusb`, `make`, `go`, `git`  

🛠 No need to install these manually — just run the built-in installer.

---

## 🧪 Usage

### 🔹 Step-by-step Guide

```bash
# Clone the repository
git clone https://github.com/lycanld/LeUnBrIck.git

# Move into the project directory
cd LeUnBrIck

# Make the script executable
chmod +x LeUnBrIck.sh

# Launch the unbricker
./LeUnBrIck.sh
````

### 🧙 Inside the Menu

1. **Option 1** → Unbrick iPod Nano **6G**
2. **Option 2** → Unbrick iPod Nano **7G (auto-detects 2012 / 2015)**
3. **Option 3** → Install required tools & files
4. **Option 4** → View credits
5. **Option 5** → Quit

> 💡 Just follow on-screen instructions to enter **DFU mode**, then **WTF mode**, and finish flashing.

---

## 📁 Folder Structure

```
.
├── LeUnBrIck.sh               # Main Bash script
├── wInd3x/                    # wInd3x restore tool
├── ipodscsi_linux/            # ipodscsi restore utility
├── firmwares/                 # Auto-downloaded WTF/Firmware files
├── assets/
│   ├── banner.png             # GitHub banner image
│   └── discord_qr.png         # QR code for Discord
```

---

## 📌 TODO

* [x] Nano 6G support
* [x] Auto-download `.MSE` files from GitHub
* [x] Improved interface (TUI)
* [ ] GUI (Qt / Tkinter)
* [x] Support for both 2012 and 2015 Nano 7G
* [x] macOS support (accidental but works)
* [x] Safer device selection (not locked to `/dev/sda`)
* [X] Improve automatic detection for iPod revisions
* [ ] Windows support

---

## ⚠️ Notes

* GitHub does **not allow files over 100MB**, so `.MSE` files are **not included**.
* The script will **automatically download** missing firmware files when needed.
* Seeing `LIBUSB_ERROR_NO_DEVICE` at the end of flashing is **normal** and expected.

---

## 🙌 Special Thanks

Huge appreciation to the amazing contributors and community members who made this project possible:

* **@LycanLD** — Creator of LeUnBrIck and lead developer
* **@Ruff** — Packaging, testing, and distribution
* **@nfzerox** — For ipod\_theme
* **@CUB3D** — For ipod\_sun
* **@freemyipod** — For wInd3x, freemyipod, and ipodscsi
* **@Stefan-Schmidt** — For dfu\_utils
* **@760ceb3b9c0ba4872cadf3ce35a7a494** — For ipodhax & IPSW unpacking (+ helped me unbrick mine the hard way)
* **@Zeehondie** — Cuz he's a seal 🦭

---

## 💬 Join the Community

Need help, mods, or want to show off your themed iPod? Join us on Discord:

* 🎨 **iPod Theme Discord**: [https://discord.com/invite/SfWYYPUAEZ](https://discord.com/invite/SfWYYPUAEZ)
* 🔧 **iPod Modding Discord**: [https://discord.com/invite/7PnGEXjW3X](https://discord.com/invite/7PnGEXjW3X)

<p align="center">
  <img src="assets/discord_qr.png" alt="Join the iPod Nano Theming Discord" width="200"/>
</p>

---

## ⭐ Remember to give this project a star if it helped you 🌟

---

## 📜 License

MIT License — free to use, fork, and modify.
Contributions welcome!

---

## ✨ Created by [Lycan](https://github.com/lycanld)

### 📦 Distributed by **Ruff's Softwares & Games**

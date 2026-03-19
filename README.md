# NixOS Configuration

Personal NixOS system configuration for **bansyne**, using a modular layout and flakes. The system uses **Sway** (Wayland) as the window manager, **SDDM** for login, and supports optional **specialisations** (e.g. gaming) from the boot menu.

---

## Overview

| Item | Choice |
|------|--------|
| **State version** | 25.11 |
| **Channel** | `nixos-unstable` (via flake) |
| **Bootloader** | GRUB (EFI) with sleek theme; NixOS generations, specialisations, and other OSes (e.g. Windows) |
| **Display** | Wayland via Sway |
| **Login** | SDDM (Catppuccin Mocha Mauve) |
| **Audio** | Pipewire (ALSA + Pulse compat) |
| **Unfree** | Allowed (Chrome, Cursor, Steam, JetBrains, etc.) |

---

## Repository Structure

```
.
├── configuration.nix      # Main entry: imports modules, boot, nix, specialisations
├── flake.nix              # Flake definition, nixpkgs input, specialArgs (e.g. wallpapers)
├── hardware-configuration.nix   # Generated hardware (disks, kernel, CPU); regenerate with nixos-generate-config
├── wallpapers/            # Optional: images here → /etc/sway/wallpapers for random wallpaper
└── modules/
    ├── locale.nix         # Hostname, NetworkManager, timezone, i18n, Wayland env vars
    ├── users.nix          # User bansyne, groups, nvm shell init, sudo
    ├── packages.nix       # System-wide packages (Sway, terminal, browser, etc.)
    ├── audio.nix          # Pipewire, ALSA, Pulse compat, rtkit
    ├── bluetooth.nix      # Bluetooth, blueman, rfkill unblock
    ├── removable-storage.nix  # udisks2 (auto-mount USB/external drives)
    ├── sway.nix            # Sway, Waybar, SDDM, XDG portals, keybindings, wallpaper
    ├── developing.nix     # Dev tools (IDEs, JDK, Docker, Flutter/fvm, etc.) — base only, not a specialisation
    └── gaming.nix          # Gaming specialisation: Steam, RetroArch, Dolphin, joycond
```

---

## Main Configuration (`configuration.nix`)

- **Imports** all modules above (hardware, locale, users, packages, audio, bluetooth, removable-storage, sway, developing).
- **Boot**: EFI + GRUB, theme `sleek-grub-theme`, `configurationLimit = 10`, `gfxmodeEfi` for a higher-resolution boot menu. `useOSProber = true` so other installed OSes (e.g. Windows) appear in the menu.
- **Nix**: flakes + nix-command enabled; unfree allowed; `programs.nix-ld.enable` for running non-Nix dynamic binaries (e.g. nvm node). **Automatic GC**: weekly timer removes generations older than 7 days (`nix.gc`).
- **Graphics**: `hardware.graphics.enable = true` (OpenGL / libGL for IDEs and games).
- **Specialisations**: `gaming` — adds `modules/gaming.nix`; select **“gaming”** at the GRUB menu to boot with Steam, RetroArch, Dolphin, etc.

---

## Modules (what each does)

### `locale.nix`

- **Hostname**: `nixos`
- **NetworkManager**: enabled
- **Timezone**: `America/Bogota`
- **Locale**: default `en_US.UTF-8`; extra LC_* for `es_CO.UTF-8` (address, time, etc.)
- **Session**: `NIXOS_OZONE_WL = "1"`, `XDG_CURRENT_DESKTOP = "sway"` for Wayland/Chromium

### `users.nix`

- **User**: `bansyne` (normal user, groups: networkmanager, wheel, audio, video, storage)
- **Sudo**: wheel without password
- **Shell**: loads **nvm** in interactive shells (install nvm manually if you use it)

### `packages.nix`

System-wide apps, including:

- **Sway stack**: sway, swaylock, swayidle, alacritty, grim, grimshot, slurp, flameshot, wl-clipboard
- **Bluetooth**: blueman
- **Utils**: git, wget, curl, xev, neovim
- **Apps**: google-chrome, code-cursor, obsidian, thunar, discord

### `audio.nix`

- **Pipewire**: enabled with ALSA and PulseAudio compatibility (32-bit ALSA supported)
- **PulseAudio**: disabled (replaced by Pipewire)
- **Realtime**: `security.rtkit.enable = true`

### `bluetooth.nix`

- **Bluetooth**: enabled, power on at boot
- **Blueman**: service enabled for GUI management
- **rfkill**: oneshot service to unblock all (Wi‑Fi/Bluetooth) at boot

### `removable-storage.nix`

- **udisks2**: enabled; USB/external drives auto-mount under `/run/media/<user>/...`

### `sway.nix`

- **Sway**: enabled with GTK wrapper; config from default Sway but **bar block removed** (only Waybar used).
- **Waybar**: bottom bar; config and style in `/etc/waybar/` (Unicode symbols, no Nerd Font); CPU, memory, disk, pulseaudio, backlight, keyboard, network, battery, tray, clock.
- **Terminal**: `alacritty` (set in `config.d/terminal.conf`).
- **Flameshot**: auto-start + `Print` → `flameshot gui`.
- **Wallpaper**: `sway-random-wallpaper` (delay 5s at start); `$mod+Shift+b` to change; looks in `$SWAY_WALLPAPERS`, `~/.config/sway/wallpapers`, `/etc/sway/wallpapers` (from repo `wallpapers/` when provided via flake).
- **Waybar reload**: `$mod+Shift+w` (kill + restart).
- **Fonts**: Noto Color Emoji for Waybar.
- **XDG portals**: enabled; `wlr` for screen sharing etc.
- **SDDM**: Wayland enabled; theme **Catppuccin Mocha Mauve**.
- **Keyboard**: X11 keymap `us` (used by Sway).
- **Default terminal**: `xdg.terminal-exec` → Alacritty.

### `developing.nix`

Development tools (always in the main profile, not a specialisation):

- **IDEs**: Android Studio, IntelliJ IDEA (wrapped so Skiko/Compose finds `libGL.so.1`), Cursor (from packages.nix)
- **VCS**: git, gh
- **Flutter**: fvm
- **Build**: gnumake, gcc, gradle, maven; **Java**: `programs.java` with JDK 21
- **Python**: python3, pip
- **Containers**: docker, docker-compose (Docker on demand, not on boot); user in `docker` group
- **DB**: DBeaver
- **Env**: `ANDROID_HOME = "$HOME/.android/sdk"`

### `gaming.nix` (specialisation)

Loaded only when you boot the **“gaming”** specialisation:

- **Emulators**: RetroArch, Dolphin
- **Controllers**: joycond (Joy-Con), evdevhook2 (Cemuhook UDP)
- **Steam**: client + steam-run; Remote Play and dedicated server firewall opened
- **Graphics**: 32-bit support enabled for Steam/games

---

## Flake (`flake.nix`)

- **Input**: `nixpkgs` from `github:NixOS/nixpkgs/nixos-unstable`.
- **Output**: `nixosConfigurations.nixos` for `x86_64-linux`.
- **Special args**: `wallpapersDir` — if `./wallpapers` exists, it’s copied to `/etc/sway/wallpapers` for the random wallpaper script.
- Unfree is set at flake level so all nixpkgs evaluation sees it.

---

## Hardware (`hardware-configuration.nix`)

Generated by `nixos-generate-config`. Defines:

- Kernel/initrd modules (e.g. nvme, usb, kvm-amd)
- Filesystems (root, `/boot` ESP, swap by UUID)
- Platform and AMD microcode

To refresh after hardware changes:

```bash
sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
```

Then rebuild. Keep this file in the flake if you want a self-contained repo.

---

## Usage

### Build and switch (from this repo)

```bash
cd /path/to/bansyne-nix-os-config
sudo nixos-rebuild switch --flake .#nixos
```

### Boot menu

The GRUB menu lists NixOS generations (up to 10), specialisations (e.g. **“gaming”**), and other installed operating systems (e.g. **Windows**). The default entry is the current NixOS configuration. Choose **“gaming”** to boot with Steam, RetroArch, Dolphin, etc.

### Wallpapers

- Add images to `wallpapers/` in the repo; the flake exposes them as `/etc/sway/wallpapers`.
- Or put images in `~/.config/sway/wallpapers` (used by `sway-random-wallpaper` if no image in the other paths).
- `$mod+Shift+b` in Sway picks a random wallpaper.

### Regenerating hardware config

```bash
sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
```

Then run `nixos-rebuild switch --flake .#nixos` as above.

### Removing old generations

**Automatic:** A systemd timer runs **weekly** (Monday 03:15) and deletes generations older than 7 days, then runs garbage collection (`nix.gc` in `configuration.nix`). You can change the schedule or use `options = [ "-d" ]` to keep only the current generation.

**Manual:** `configurationLimit = 10` only limits GRUB menu entries; old generations still use disk until GC runs. To clean up on demand:

1. **List generations** (optional):  
   `nixos-rebuild list-generations`

2. **Delete old generations and free disk**:  
   `sudo nix-collect-garbage -d`  
   (all but current) or  
   `sudo nix-collect-garbage --delete-older-than 7d`  
   (keep last 7 days).

3. **Refresh the boot menu** (so GRUB no longer shows removed entries):  
   `sudo nixos-rebuild switch --flake .#nixos`

Note: deleted generations cannot be rolled back to.

---

## Notes

- **nvm**: Node is managed via nvm (loaded in `users.nix`); install nvm yourself if needed.
- **OpenGL / Skiko**: JetBrains IDEs and Android Studio use Skiko; the wrappers in `developing.nix` set `LD_LIBRARY_PATH` so `libGL.so.1` is found (NixOS OpenGL driver path + mesa/libglvnd).
- **Cursor**: Installed in `packages.nix` so it’s available in every specialisation.

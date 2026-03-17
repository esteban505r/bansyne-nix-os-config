# System packages configuration
# All packages installed system-wide are listed here

{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # --- Window manager and Wayland ---
    sway          # i3-compatible Wayland compositor (tiling WM)
    swaylock      # Screen lock for Sway
    swayidle      # Idle management (lock, dpms, etc.)
    foot          # Fast, minimal terminal emulator
    grim          # Screenshot tool for Wayland
    slurp         # Region selector (used with grim for area screenshots)
    wl-clipboard  # Copy/paste for Wayland (wl-copy, wl-paste)

    # --- Bluetooth ---
    blueman       # Bluetooth manager GUI (pair devices, manage connections)

    # --- System utilities ---
    git           # Version control
    wget          # Download files (HTTP/HTTPS/FTP)
    curl          # Transfer data from URLs (scripts, APIs)

    # --- Applications ---
    google-chrome # Chromium-based browser (unfree)
    code-cursor  # Cursor IDE (unfree; available in all specialisations)
  ];
}

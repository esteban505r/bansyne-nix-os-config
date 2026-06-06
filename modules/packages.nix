# System packages configuration
# All packages installed system-wide are listed here

{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # --- Terminal / desktop helpers ---
    alacritty     # GPU-accelerated terminal (GNOME ships gnome-terminal too)
    flameshot     # Screenshot tool (GUI, region, tray)
    wl-clipboard  # Wayland clipboard (wl-copy / wl-paste)
    discord       # Discord chat

    # --- Bluetooth ---
    blueman       # Bluetooth manager GUI

    # --- System utilities ---
    git           # Version control
    wget          # Download files (HTTP/HTTPS/FTP)
    curl          # Transfer data from URLs
    xev           # X event monitor
    neovim        # Editor
    btop          # System monitor

    # --- Applications ---
    firefox       # Browser
    chromium      # Open-source Chromium
    file-roller   # Archive manager (GNOME)
    p7zip         # 7z CLI
    unrar         # RAR extraction (unfree)
    unzip         # ZIP extraction
  ];
}

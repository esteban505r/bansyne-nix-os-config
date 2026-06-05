# System packages configuration
# All packages installed system-wide are listed here

{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # --- Window manager and Wayland ---
    # sway: provided by programs.sway (wrapped with --unsupported-gpu for NVIDIA); do not add pkgs.sway here or SDDM will run unwrapped sway and get black screen
    swaylock      # Screen lock for Sway
    swayidle      # Idle management (lock, dpms, etc.)
    alacritty     # Terminal
    grim          # Screenshot tool for Wayland (terminal-only)
    sway-contrib.grimshot  # Screenshot helper for Sway (grim-based)
    discord       # Discord for chatting
    slurp         # Region selector (used with grim for area screenshots)
    flameshot     # Screenshot tool (GUI, region, tray); auto-started in Sway
    wl-clipboard  # Copy/paste for Wayland (wl-copy, wl-paste)

    # --- Bluetooth ---
    blueman       # Bluetooth manager GUI (pair devices, manage connections)

    # --- System utilities ---
    git           # Version control
    wget          # Download files (HTTP/HTTPS/FTP)
    curl          # Transfer data from URLs (scripts, APIs)
    xev           # Event monitor
    neovim        # Neo Vim Editor
    btop          # System monitor

    # --- Applications ---
    firefox       # Browser
    google-chrome # Chromium-based browser (unfree)
    thunar        # File manager (GUI)
    file-roller   # Archive manager (zip/rar/7z/tar)
    p7zip         # 7z CLI
    unrar         # RAR extraction (unfree)
    unzip         # ZIP extraction
  ];
}

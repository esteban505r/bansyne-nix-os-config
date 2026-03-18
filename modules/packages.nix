# System packages configuration
# All packages installed system-wide are listed here

{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # --- Window manager and Wayland ---
    sway          # i3-compatible Wayland compositor (tiling WM)
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

    # --- Applications ---
    google-chrome # Chromium-based browser (unfree)
    code-cursor  # Cursor IDE (unfree; available in all specialisations)
    obsidian     # Markdown-based note-taking and knowledge base
    thunar       # File manager (GUI)
  ];
}

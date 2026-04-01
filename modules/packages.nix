# System packages configuration
# All packages installed system-wide are listed here

{ config, pkgs, ... }:

{
  # Wrapped OBS so plugins are visible to the app. Do not also list pkgs.obs-studio in systemPackages.
  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs                       # Wayland (Sway) screen/window capture
      obs-pipewire-audio-capture   # PipeWire desktop/application audio
    ];
  };

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
    zip           # Create .zip archives (zip, zipcloak, etc.)
    xev           # Event monitor
    neovim        # Neo Vim Editor
    btop          # System monitor

    # --- Applications ---
    google-chrome # Chromium-based browser (unfree)
    code-cursor  # Cursor IDE (unfree; available in all specialisations)
    obsidian     # Markdown-based note-taking and knowledge base
    vlc          # Media player
    thunar       # File manager (GUI)
    pavucontrol  # PulseAudio volume control
    pulseaudio   # PulseAudio
    pulseaudio-ctl # PulseAudio control
  ];
}

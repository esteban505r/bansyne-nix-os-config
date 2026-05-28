# System packages configuration
# All packages installed system-wide are listed here

{ config, pkgs, inputs, ... }:

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
    warp-terminal # Warp terminal (Rust-based, AI features)
    grim          # Screenshot tool for Wayland (terminal-only)
    sway-contrib.grimshot  # Screenshot helper for Sway (grim-based)
    discord       # Discord for chatting
    slurp         # Region selector (used with grim for area screenshots)
    flameshot     # Screenshot tool (GUI, region, tray); auto-started in Sway
    wl-clipboard  # Copy/paste for Wayland (wl-copy, wl-paste)

    # --- Bluetooth ---
    blueman       # Bluetooth manager GUI (pair devices, manage connections)

    # --- Audio (PipeWire exposes Pulse API; pavucontrol = sinks/sources/volumes GUI) ---
    pavucontrol

    # --- Network ---
    bind.dnsutils # dig, host, nslookup (DNS diagnostics)
    tailscale     # Mesh VPN CLI (daemon: services.tailscale in configuration.nix)

    # --- System utilities ---
    git           # Version control
    go            # Go programming language toolchain
    wget          # Download files (HTTP/HTTPS/FTP)
    curl          # Transfer data from URLs (scripts, APIs)
    openssl       # TLS/crypto tools (openssl)
    jq            # JSON processor for scripts/automation
    websocat      # WebSocket CLI (used by waybar-oter-daemon)
    zip           # Create .zip archives (zip, zipcloak, etc.)
    xev           # Event monitor
    neovim        # Neo Vim Editor
    btop          # System monitor
    baobab 	  # Directory size analyzer
    anki-bin    # Flashcard software
    unzip
    calibre   # a📚 eBook reader
    

    # --- Applications ---
    inputs.affinity-nix.packages.${pkgs.stdenv.hostPlatform.system}.v3
    opencode      # AI coding agent (terminal)
    antigravity   # Google Antigravity IDE (agentic development)
    google-cloud-sdk # Google Cloud CLI (gcloud, gsutil, bq)
    google-cloud-sql-proxy # Cloud SQL Auth Proxy (secure TCP/Unix to instances; binary: cloud-sql-proxy)
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

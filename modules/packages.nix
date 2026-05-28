 # System packages configuration
# All packages installed system-wide are listed here

{ config, pkgs, lib, inputs, ... }:

let
  # DBeaver “Local client home” must not be a /nix/store path — it goes stale on rebuild.
  # Use /usr/local/pgsql (stable symlink to current postgresql_18) in connection settings.
  # /usr/local/bin/* symlinks help autodiscovery (NativeClientLocationUtils walks FHS dirs).
  # pg_dump major must be >= server major (match postgresql_* to your servers).
  pg = pkgs.postgresql_18;
  pgClientHome = "/usr/local/pgsql";

  # https://www.pencil.dev/ — desktop AppImage (not nixpkgs `pencil`, which is Evolus Pencil).
  # Hash must be updated when upstream replaces the unversioned download.
  pencil-dev = pkgs.appimageTools.wrapType2 {
    pname = "pencil-dev";
    version = "2026.05.24";
    src = pkgs.fetchurl {
      url = "https://www.pencil.dev/download/Pencil-linux-x86_64.AppImage";
      hash = "sha256-nuf4jVPU5wsR1MwFXr0llAOGxQ4vwiQNEoiBwPwbAXQ=";
    };
  };

  # Affinity v3 (Wine + ElementalWarrior wine; first launch runs Serif’s installer — keep default path).
  # v2 apps: inputs.affinity-nix.packages.${pkgs.stdenv.hostPlatform.system}.{photo,designer,publisher}
  # Docs: https://github.com/mrshmllow/affinity-nix
  affinity-v3 = inputs.affinity-nix.packages.${pkgs.stdenv.hostPlatform.system}.v3;
in
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

    # --- Audio (PipeWire exposes Pulse API; pavucontrol = sinks/sources/volumes GUI) ---
    pavucontrol

    # --- System utilities ---
    git           # Version control
    wget          # Download files (HTTP/HTTPS/FTP)
    curl          # Transfer data from URLs (scripts, APIs)
    dnsutils      # dig, nslookup, host (BIND client tools)
    google-cloud-sdk  # gcloud, gsutil, bq (Google Cloud CLI)
    google-cloud-sql-proxy  # Cloud SQL Auth Proxy (pg_restore/psql via localhost; Oter GCP migration)
    doctl         # DigitalOcean CLI (tear down droplets/DB after cutover)
    jq            # JSON processor for scripts/automation
    websocat      # WebSocket CLI (used by waybar-oter-daemon)
    zip           # Create .zip archives (zip, zipcloak, etc.)
    xev           # Event monitor
    neovim        # Neo Vim Editor
    btop          # System monitor
    baobab 	  # Directory size analyzer
    unzip       # Unzip files (unzip, unzipcloak, etc.)
    

    # --- Database (psql, pg_dump, … on PATH for terminals and DBeaver “local client”) ---
    postgresql_18

    # --- Applications ---
    google-chrome # Chromium-based browser (unfree)
    code-cursor  # Cursor IDE (unfree; available in all specialisations)
    antigravity  # Google Antigravity — agentic IDE (unfree)
    obsidian     # Markdown-based note-taking and knowledge base
    vlc          # Media player
    thunar       # File manager (GUI)
    anki-bin     # Anki flashcard software 
    ankiAddons.anki-connect  # Anki connect plugin
    pencil-dev   # Pencil design canvas — https://www.pencil.dev/
    affinity-v3  # Affinity v3 — https://github.com/mrshmllow/affinity-nix
  ];

  systemd.tmpfiles.rules = [
    "d /usr/local/bin 0755 root root -"
    "L+ ${pgClientHome} - - - - ${pg}"
    "L+ /usr/local/bin/psql - - - - ${pg}/bin/psql"
    "L+ /usr/local/bin/pg_dump - - - - ${pg}/bin/pg_dump"
    "L+ /usr/local/bin/pg_restore - - - - ${pg}/bin/pg_restore"
  ];

  # Replace stale postgresql-* store paths in saved DBeaver connections after rebuild.
  # (Avoid `read -d ''` in this script — `''` closes a Nix indented string.)
  system.activationScripts.dbeaver-postgresql-client = lib.stringAfter [ "users" ] ''
    home=${config.users.users.bansyne.home}
    dbeaverData="$home/.local/share/DBeaverData"
    if [ -d "$dbeaverData" ]; then
      files=$(${pkgs.gnugrep}/bin/grep -rl '/nix/store/.*-postgresql-' "$dbeaverData" \
        --include='data-sources.json' \
        --include='.data-sources.json.bak' \
        --include='org.jkiss.dbeaver.core.prefs' 2>/dev/null || true)
      if [ -n "$files" ]; then
        echo "$files" | ${pkgs.coreutils}/bin/xargs -r ${pkgs.gnused}/bin/sed -i \
          's|/nix/store/[^"]*-postgresql-[^"]*|${pgClientHome}|g'
      fi
    fi
  '';
}

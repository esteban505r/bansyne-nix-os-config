# Sway window manager configuration
# Includes XDG portal configuration for Wayland applications

{ config, pkgs, lib, ... }:

let
  # Default Sway config with the built-in bar block removed (Waybar is our only bar).
  # Must append include so config.d (nixos.conf, waybar-reload, etc.) is loaded.
  swayConfigWithoutBar = pkgs.runCommand "sway-config-no-bar" { } ''
    awk '
      /^# Read.*sway-bar/ { inbar = 1; depth = 0; next }
      inbar {
        if (/bar \{/ || /\{/) depth++
        if (/\}/) depth--
        if (depth <= 0) inbar = 0
        next
      }
      /# Special key to take a screenshot with grim/ { next }
      /bindsym Print exec grim/ { next }
      /# Your preferred terminal emulator/ { next }
      /^set \$term / { next }
      /# Start a terminal/ { next }
      /bindsym \$mod\+Return exec \$term/ { next }
      { print }
    ' ${pkgs.sway}/etc/sway/config > $out
    echo "" >> $out
    echo "include /etc/sway/config.d/*" >> $out
  '';
  # SDDM login theme (flavor: latte/frappe/macchiato/mocha; accent: blue/mauve/teal/...). Theme name must match: catppuccin-{flavor}-{accent}
  sddmTheme = pkgs.catppuccin-sddm.override { flavor = "macchiato"; accent = "teal"; };
in
{
  # Enable Sway with GTK wrapper features
  programs.sway = {
    enable = true;
    wrapperFeatures = {
      # Ensure the wrapper/session entrypoint is used by display managers (including SDDM).
      base = true;
      gtk = true;
    };
    # Required for NVIDIA proprietary driver: avoids black screen on session start (unsupported by Sway upstream)
    extraOptions = [ "--unsupported-gpu" ];
  };

  # Use custom Sway config without the default top bar (only Waybar at bottom) without the default top bar (only Waybar at bottom)
  environment.etc."sway/config".source = swayConfigWithoutBar;

  # Emoji font so Waybar icon symbols (Unicode emoji) render
  fonts.packages = [ pkgs.noto-fonts-color-emoji ];

  # Enable Waybar (status bar for Sway), positioned at bottom
  programs.waybar.enable = true;
  # Waybar config: Unicode emoji/symbols via Pango &#xNNNN; (no Nerd Font needed)
  environment.etc."waybar/config".source = pkgs.writeText "waybar-config.json" ''
    {
      "layer": "top",
      "position": "bottom",
      "height": 28,
      "modules-left": ["sway/workspaces", "sway/window"],
      "modules-center": ["cpu", "memory", "disk"],
      "modules-right": ["pulseaudio", "backlight", "keyboard", "network", "battery", "tray", "clock"],
      "sway/workspaces": {
        "format": "{name}",
        "format-icons": {
          "default": "&#x25CB;",
          "active": "&#x25CF;",
          "urgent": "&#x26A0;"
        }
      },
      "cpu": {
        "format": "&#x2699; CPU {usage}% load {load}",
        "tooltip-format": "CPU: {usage}% usage, load avg {load}",
        "interval": 2
      },
      "memory": {
        "format": "&#x1F4BE; MEM {used:0.1f}G/{total:0.1f}G ({percentage}%)",
        "tooltip-format": "RAM: {used:0.2f}G used, {avail:0.2f}G avail of {total:0.2f}G",
        "interval": 2
      },
      "disk": {
        "format": "&#x1F4BF; DISK {used:0.1f}G/{total:0.1f}G ({percentage_used}%)",
        "path": "/",
        "tooltip-format": "{path}: {used:0.2f}G used, {free:0.2f}G free of {total:0.2f}G",
        "interval": 30
      },
      "pulseaudio": {
        "format": "{icon} VOL {volume}%",
        "format-muted": "&#x1F507; VOL muted",
        "format-icons": {
          "default": ["&#x1F508;", "&#x1F509;", "&#x1F50A;"],
          "muted": "&#x1F507;"
        },
        "tooltip-format": "{desc}: {volume}%"
      },
      "backlight": {
        "format": "{icon} BRIGHT {percent}%",
        "format-icons": ["&#x1F505;", "&#x1F505;", "&#x2600;", "&#x2600;", "&#x2600;"]
      },
      "keyboard": {
        "format": "&#x2328; KB {layout}",
        "tooltip-format": "Layout: {layout}"
      },
      "network": {
        "format-wifi": "&#x1F4F6; WIFI {signalStrength}%",
        "format-ethernet": "&#x1F310; ETH connected",
        "format-disconnected": "&#x26A0; NET disconnected",
        "tooltip-format": "{ifname}: {ipaddr}"
      },
      "battery": {
        "format": "{icon} BAT {capacity}%",
        "format-charging": "&#x26A1; BAT {capacity}%",
        "format-plugged": "&#x1F50C; BAT {capacity}%",
        "format-icons": ["&#x1F50B;", "&#x1F50B;", "&#x1F50B;", "&#x1F50B;", "&#x1F50B;"],
        "interval": 10
      },
      "tray": {
        "icon-size": 18,
        "spacing": 6
      },
      "clock": {
        "format": "&#x1F550; {:%H:%M %d/%m}",
        "tooltip-format": "<big>{:%A %d %B %Y}</big>\n<tt><small>{:%H:%M}</small></tt>"
      }
    }
  '';
  # Waybar style: orange background, black text
  environment.etc."waybar/style.css".source = pkgs.writeText "waybar-style.css" ''
    * {
      border: none;
      border-radius: 0;
      font-family: sans-serif;
      font-size: 13px;
      min-height: 0;
    }
    window#waybar {
      background: #f97316;
      color: #0a0a0a;
    }
    #workspaces button {
      padding: 0 8px;
      color: #0a0a0a;
      opacity: 0.7;
    }
    #workspaces button.active {
      color: #0a0a0a;
      background: rgba(0, 0, 0, 0.2);
      opacity: 1;
    }
    #workspaces button.urgent {
      color: #0a0a0a;
      background: rgba(0, 0, 0, 0.35);
    }
    #window {
      padding: 0 10px;
      font-weight: 500;
    }
    #cpu, #memory, #disk {
      padding: 0 10px;
      margin: 0 2px;
    }
    #pulseaudio, #backlight, #keyboard, #network, #battery, #clock {
      padding: 0 10px;
      margin: 0 2px;
    }
    #tray {
      padding: 0 8px;
    }
    #clock {
      font-weight: bold;
    }
  '';

  # Default terminal: set $term and redefine Mod+Return (Sway expands $term when config is parsed, so we must redefine the binding here)
  environment.etc."sway/config.d/terminal.conf".source = pkgs.writeText "terminal.conf" ''
    set $term alacritty
    bindsym $mod+Return exec $term
  '';

  # Auto-start Flameshot (tray icon; use GUI or keybinding to take screenshots)
  # Window rule: place overlay at (0,0) so it spans all monitors (fixes multi-monitor capture)
  environment.etc."sway/config.d/flameshot.conf".source = pkgs.writeText "flameshot.conf" ''
    for_window [app_id="flameshot"] floating enable, fullscreen disable, move absolute position 0 0, border pixel 0
    exec --no-startup-id flameshot
    bindsym Print exec flameshot gui
  '';

  # Wallpaper from /home/bansyne/bansyne-nix-os-config/wallpapers (random at startup, $mod+Shift+b to change)
  environment.etc."sway/config.d/wallpaper.conf".source = pkgs.writeText "wallpaper.conf" ''
    exec --no-startup-id sh -c "sleep 5; IMG=$(find /home/bansyne/bansyne-nix-os-config/wallpapers -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) 2>/dev/null | shuf -n1); [ -n \"$IMG\" ] && swaymsg output '*' bg \"$IMG\" fill"
    bindsym $mod+Shift+b exec sh -c "IMG=$(find /home/bansyne/bansyne-nix-os-config/wallpapers -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) 2>/dev/null | shuf -n1); [ -n \"$IMG\" ] && swaymsg output '*' bg \"$IMG\" fill"
  '';

  # Start Waybar from Sway only if not already running (avoids duplicate bar with systemd or other starters)
  environment.etc."sway/config.d/waybar-reload.conf".source = pkgs.writeText "waybar-reload.conf" ''
    exec --no-startup-id sh -c 'pgrep -x waybar >/dev/null || exec waybar'
    bindsym $mod+Shift+w exec sh -c 'pkill -x waybar 2>/dev/null; while pgrep -x waybar >/dev/null; do sleep 0.1; done; waybar &'
  '';

  # Waybar systemd service: custom ExecStart; do NOT auto-start (Sway runs waybar via exec to avoid two bars). Restart with Super+Shift+w.
  systemd.user.services.waybar.wantedBy = lib.mkForce [ ];
  systemd.user.services.waybar.unitConfig = {
    PartOf = [ "sway-session.target" ];
    After = [ "sway-session.target" ];
  };
  systemd.user.services.waybar.serviceConfig.ExecStart = [
    "" # clear default
    "${config.programs.waybar.package}/bin/waybar -c /etc/waybar/config -s /etc/waybar/style.css"
  ];
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "waybar" ''
      exec ${pkgs.waybar}/bin/waybar -c /etc/waybar/config -s /etc/waybar/style.css "$@"
    '')
    sddmTheme
    pkgs.swaybg
  ];

  # Enable XDG portals for Wayland applications
  # wlr portal is required for screen sharing and other features
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    # Optional: Enable additional portals
    # extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Display manager configuration (graphical login)
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    # Theme: use a theme from nixpkgs (must be in extraPackages so SDDM can load it)
    # Popular options: catppuccin-sddm, sddm-sugar-dark, sddm-chili-theme, elegant-sddm, sddm-astronaut
    theme = "catppuccin-macchiato-teal";
    extraPackages = [ sddmTheme ];
    # Optional: override theme settings (background, font, etc.)
    # settings = {
    #   Theme = {
    #     CursorTheme = "Adwaita";
    #     Font = "Sans 12";
    #   };
    # };
  };

  # Configure keymap
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Default terminal for desktop (e.g. "Open terminal here", app launchers)
  xdg.terminal-exec = {
    enable = true;
    settings.default = [ "Alacritty.desktop" ];
  };
}

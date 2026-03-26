# Sway window manager configuration
# Includes XDG portal configuration for Wayland applications
# Oter → Waybar (daemon, env wrapper, custom modules) lives in modules/oter-waybar.nix (imported before this file).

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

  # Absolute paths: Sway's `exec` often runs without $HOME set, so $HOME/wallpapers never matched.
  wallpaperSearchRoots = [
    "${config.users.users.bansyne.home}/wallpapers"
    "${config.users.users.bansyne.home}/bansyne-nix-os-config/wallpapers"
  ];
  swayWallpaperRandomBin = pkgs.writeShellScriptBin "sway-wallpaper-random" ''
    export PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.findutils pkgs.sway pkgs.swaybg pkgs.procps ]}"
    dirs=()
    ${lib.concatMapStrings (d: ''
    [[ -d "${d}" ]] && dirs+=("${d}")
    '') wallpaperSearchRoots}
    if (( ''${#dirs[@]} == 0 )); then
      echo "sway-wallpaper-random: no wallpaper directories exist" >&2
      exit 1
    fi
    # -xtype f: include symlinks to images (-type f alone skips symlinks, so git-annex / links look "empty").
    IMG=$(find -L "''${dirs[@]}" -xtype f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) 2>/dev/null | shuf -n1)
    if [[ -z "$IMG" ]]; then
      echo "sway-wallpaper-random: no images under ''${dirs[*]}" >&2
      exit 1
    fi
    # Prefer IPC: works from any terminal inside Sway (swaybg often fails or exits if Wayland env is odd).
    if swaymsg output '*' bg "$IMG" fill 2>/dev/null; then
      exit 0
    fi
    pkill -x swaybg 2>/dev/null || true
    swaybg -i "$IMG" -m fill &
  '';
  # Delay + wait for Wayland socket so swaybg can connect (NVIDIA / slow init).
  swayWallpaperRandomDelayedBin = pkgs.writeShellScriptBin "sway-wallpaper-random-delayed" ''
    export PATH="${lib.makeBinPath [ pkgs.coreutils ]}"
    sleep 3
    for _ in $(seq 1 120); do
      [ -n "$WAYLAND_DISPLAY" ] && break
      sleep 0.05
    done
    exec ${swayWallpaperRandomBin}/bin/sway-wallpaper-random
  '';

  notificationSoundListenerBin = pkgs.writeShellScriptBin "notification-sound-listener" ''
    set -euo pipefail
    export PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.gawk pkgs.dbus pkgs.pipewire pkgs.libcanberra-gtk3 ]}"

    # Prefer PipeWire's pw-play (direct file playback) for reliability.
    # Fall back to canberra-gtk-play (event sound) if pw-play isn't available.
    SOUND_FILE="${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/message-new-instant.oga"

    play_sound() {
      if command -v pw-play >/dev/null 2>&1; then
        pw-play "$SOUND_FILE" >/dev/null 2>&1 &
      else
        canberra-gtk-play -i message-new-instant >/dev/null 2>&1 &
      fi
    }

    # Play a default sound whenever a notification is posted via the standard D-Bus API.
    # This covers "silent" notifications where the app doesn't play its own sound.
    exec dbus-monitor --session "interface='org.freedesktop.Notifications',member='Notify'" 2>/dev/null \
      | awk '
          /member=Notify/ {
            system("'"'"'sh -lc play_sound'"'"'")
          }
        '
  '';
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
      "height": 34,
      "fixed-center": true,
      "modules-left": [
        "sway/workspaces",
        "custom/oter_timer",
        "custom/oter_task",
        "custom/oter_habit",
        "custom/oter_state",
        "sway/window"
      ],
      "modules-center": ["cpu", "memory", "disk"],
      "modules-right": [
        "pulseaudio",
        "backlight",
        "sway/language",
        "network",
        "battery",
        "tray",
        "clock"
      ],
      "custom/oter_timer": {
        "format": "{}",
        "return-type": "json",
        "exec": "${config.custom.otter.waybar.sliceBin}/bin/waybar-oter-slice timer",
        "interval": 2,
        "signal": ${toString config.custom.otter.waybar.signal},
        "tooltip": true,
        "min-length": 20,
        "max-length": 96
      },
      "custom/oter_task": {
        "format": "{}",
        "return-type": "json",
        "exec": "${config.custom.otter.waybar.sliceBin}/bin/waybar-oter-slice task",
        "interval": 2,
        "signal": ${toString config.custom.otter.waybar.signal},
        "tooltip": true,
        "min-length": 24,
        "max-length": 140
      },
      "custom/oter_habit": {
        "format": "{}",
        "return-type": "json",
        "exec": "${config.custom.otter.waybar.sliceBin}/bin/waybar-oter-slice habit",
        "interval": 2,
        "signal": ${toString config.custom.otter.waybar.signal},
        "tooltip": true,
        "min-length": 24,
        "max-length": 140
      },
      "custom/oter_state": {
        "format": "{}",
        "return-type": "json",
        "exec": "${config.custom.otter.waybar.sliceBin}/bin/waybar-oter-slice state",
        "interval": 2,
        "signal": ${toString config.custom.otter.waybar.signal},
        "tooltip": true,
        "min-length": 18,
        "max-length": 80
      },
      "sway/workspaces": {
        "format": "{name}",
        "format-icons": {
          "default": "&#x25CB;",
          "active": "&#x25CF;",
          "urgent": "&#x26A0;"
        }
      },
      "sway/window": {
        "max-length": 24
      },
      "cpu": {
        "format": "&#x2699; {usage}%",
        "tooltip-format": "CPU: {usage}% · load {load}",
        "interval": 2
      },
      "memory": {
        "format": "&#x1F4BE; {percentage}%",
        "tooltip-format": "RAM: {used:0.2f}GiB / {total:0.2f}GiB ({percentage}%) · {avail:0.2f}GiB avail",
        "interval": 2
      },
      "disk": {
        "format": "&#x1F4BF; {percentage_used}%",
        "path": "/",
        "tooltip-format": "{path}: {used} used, {free} free of {total} ({percentage_used}%)",
        "interval": 30
      },
      "pulseaudio": {
        "format": "{icon} {volume}%",
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
      "sway/language": {
        "format": "&#x2328; KB {short}",
        "tooltip-format": "Layout: {long}"
      },
      "network": {
        "format-wifi": "&#x1F4F6; {signalStrength}%",
        "format-ethernet": "&#x1F310; ETH",
        "format-disconnected": "&#x26A0; —",
        "tooltip-format": "{ifname}: {ipaddr}"
      },
      "battery": {
        "format": "{icon} {capacity}%",
        "format-charging": "&#x26A1; {capacity}%",
        "format-plugged": "&#x1F50C; {capacity}%",
        "format-icons": ["&#x1F50B;", "&#x1F50B;", "&#x1F50B;", "&#x1F50B;", "&#x1F50B;"],
        "interval": 10
      },
      "tray": {
        "icon-size": 18,
        "spacing": 6,
        "show-passive-items": false,
        "icons": {
          "": "image-missing",
          "flameshot": "${pkgs.flameshot}/share/icons/hicolor/48x48/apps/flameshot.png",
          "org.flameshot.Flameshot": "${pkgs.flameshot}/share/icons/hicolor/48x48/apps/org.flameshot.Flameshot.png"
        }
      },
      "clock": {
        "format": "🕐 {:%H:%M}",
        "tooltip-format": "{:%A %e %B %Y · %H:%M}"
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
      padding: 0 8px;
      margin: 0 2px;
      font-size: 12px;
      opacity: 0.88;
    }
    #pulseaudio, #backlight, #language, #network, #battery, #clock {
      padding: 0 8px;
      margin: 0 2px;
      font-size: 12px;
      opacity: 0.9;
    }
    #tray {
      padding: 0 8px;
    }
    #custom-oter_timer,
    #custom-oter_task,
    #custom-oter_habit,
    #custom-oter_state {
      padding: 4px 12px;
      margin: 0 5px 0 0;
      border-radius: 8px;
      font-size: 14px;
      font-weight: 600;
      letter-spacing: 0.01em;
      color: #0c0a09;
      background: rgba(255, 255, 255, 0.94);
      border: 1px solid rgba(0, 0, 0, 0.14);
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.12);
    }
    #custom-oter_timer {
      margin-left: 6px;
    }
    #custom-oter_timer.oter-medium,
    #custom-oter_task.oter-medium,
    #custom-oter_habit.oter-medium,
    #custom-oter_state.oter-medium {
      color: #292524;
      background: rgba(255, 253, 250, 0.9);
      border-color: rgba(120, 53, 15, 0.25);
    }
    #custom-oter_timer.oter-bad,
    #custom-oter_task.oter-bad,
    #custom-oter_habit.oter-bad,
    #custom-oter_state.oter-bad {
      font-weight: 700;
      color: #450a0a;
      background: rgba(254, 226, 226, 0.95);
      border-color: rgba(185, 28, 28, 0.35);
    }
    #custom-oter_timer.oter-error,
    #custom-oter_task.oter-error,
    #custom-oter_habit.oter-error,
    #custom-oter_state.oter-error {
      font-weight: 600;
      font-style: normal;
      color: #431407;
      background: rgba(255, 237, 213, 0.96);
      border-color: rgba(194, 65, 12, 0.35);
    }
    #clock {
      font-weight: bold;
      font-size: 13px;
      opacity: 1;
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

  # Random wallpaper via swaybg (absolute paths; Sway exec often has no $HOME).
  environment.etc."sway/config.d/wallpaper.conf".source = pkgs.writeText "wallpaper.conf" ''
    exec --no-startup-id ${swayWallpaperRandomDelayedBin}/bin/sway-wallpaper-random-delayed
    bindsym $mod+Shift+b exec ${swayWallpaperRandomBin}/bin/sway-wallpaper-random
  '';

  # Notifications: SwayNotificationCenter (swaync) + keybinds
  environment.etc."sway/config.d/notifications.conf".source = pkgs.writeText "notifications.conf" ''
    # Start notification daemon + panel
    exec_always --no-startup-id swaync

    # Default notification sound (even for silent notifications)
    exec_always --no-startup-id ${notificationSoundListenerBin}/bin/notification-sound-listener

    # Toggle the notification panel / clear notifications
    bindsym $mod+Shift+n exec swaync-client -t
    bindsym $mod+Control+n exec swaync-client -C
  '';

  # System-wide defaults for SwayNotificationCenter (XDG config path)
  environment.etc."xdg/swaync/config.json".source = pkgs.writeText "swaync-config.json" ''
    {
      "positionX": "right",
      "positionY": "top",
      "layer": "overlay",
      "control-center-margin-top": 10,
      "control-center-margin-bottom": 10,
      "control-center-margin-right": 10,
      "control-center-margin-left": 10,
      "control-center-width": 420,
      "control-center-height": 900,
      "notification-2fa-action": true,
      "notification-window-width": 420,
      "notification-icon-size": 52,
      "notification-body-image-height": 120,
      "notification-body-image-width": 240,
      "timeout": 7,
      "timeout-low": 4,
      "timeout-critical": 0,
      "fit-to-screen": true,
      "keyboard-shortcuts": true,
      "image-visibility": "when-available",
      "transition-time": 120,
      "hide-on-clear": true,
      "hide-on-action": true
    }
  '';
  environment.etc."xdg/swaync/style.css".source = pkgs.writeText "swaync-style.css" ''
    * {
      font-family: sans-serif;
      font-size: 13px;
    }

    /* Notification popups */
    .notification-row {
      margin: 8px;
    }
    .notification {
      border-radius: 14px;
      padding: 10px;
      background: rgba(17, 17, 17, 0.92);
      color: #f5f5f5;
      border: 1px solid rgba(255, 255, 255, 0.10);
      box-shadow: 0 10px 28px rgba(0, 0, 0, 0.35);
    }
    .notification.critical {
      border: 1px solid rgba(248, 113, 113, 0.7);
      background: rgba(69, 10, 10, 0.92);
    }
    .summary {
      font-weight: 700;
      letter-spacing: 0.01em;
    }
    .body {
      opacity: 0.92;
    }
    .time {
      opacity: 0.7;
    }

    /* Control center panel */
    .control-center {
      border-radius: 18px;
      background: rgba(10, 10, 10, 0.92);
      color: #fafafa;
      border: 1px solid rgba(255, 255, 255, 0.10);
      box-shadow: 0 16px 44px rgba(0, 0, 0, 0.45);
      padding: 10px;
    }
    .control-center .widget-title {
      font-weight: 800;
      font-size: 14px;
      margin: 8px 8px 6px 8px;
    }
    .control-center .widget-label {
      opacity: 0.85;
    }
  '';

  # Waybar autostart / Super+Shift+w restart + systemd overrides: modules/oter-waybar.nix

  environment.systemPackages = [
    swayWallpaperRandomBin
    swayWallpaperRandomDelayedBin
    sddmTheme
    pkgs.swaybg
    pkgs.swaynotificationcenter
    pkgs.libnotify
    pkgs.libcanberra-gtk3
    pkgs.sound-theme-freedesktop
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

  # Default file manager for folders (file pickers, "Open folder", etc.)
  xdg.mime.defaultApplications."inode/directory" = "thunar.desktop";
}

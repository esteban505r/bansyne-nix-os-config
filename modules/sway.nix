# Sway window manager configuration
# Includes XDG portal configuration for Wayland applications

{ config, pkgs, ... }:

{
  # Enable Sway with GTK wrapper features
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  # Nerd Font for Waybar icons
  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];

  # Enable Waybar (status bar for Sway), positioned at bottom
  programs.waybar.enable = true;
  # Waybar config: defines which blocks/modules appear (left, center, right)
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
          "default": "${"\uF111"}",
          "active": "${"\uF192"}",
          "urgent": "${"\uF12A"}"
        }
      },
      "cpu": {
        "format": "${"\uF2DB"} {usage}%",
        "interval": 2
      },
      "memory": {
        "format": "${"\uF538"} {}%",
        "interval": 2
      },
      "disk": {
        "format": "${"\uF0A0"} {percentage_used}%",
        "path": "/",
        "interval": 30
      },
      "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": "${"\uF6A9"} muted",
        "format-icons": {
          "default": ["${"\uF026"}", "${"\uF027"}", "${"\uF028"}"],
          "muted": "${"\uF6A9"}"
        },
        "tooltip-format": "{desc}: {volume}%"
      },
      "backlight": {
        "format": "{icon} {percent}%",
        "format-icons": ["${"\uF5CF"}", "${"\uF5CE"}", "${"\uF5DD"}", "${"\uF5DE"}", "${"\uF185"}"]
      },
      "keyboard": {
        "format": "${"\uF11C"} {layout}",
        "tooltip-format": "Layout: {layout}"
      },
      "network": {
        "format-wifi": "${"\uF1EB"} {signalStrength}%",
        "format-ethernet": "${"\uF0AC"} connected",
        "format-disconnected": "${"\uF071"} disconnected",
        "tooltip-format": "{ifname}: {ipaddr}"
      },
      "battery": {
        "format": "{icon} {capacity}%",
        "format-charging": "${"\uF0E7"} {capacity}%",
        "format-plugged": "${"\uF1E6"} {capacity}%",
        "format-icons": ["${"\uF244"}", "${"\uF243"}", "${"\uF242"}", "${"\uF241"}", "${"\uF240"}"],
        "interval": 10
      },
      "tray": {
        "icon-size": 18,
        "spacing": 6
      },
      "clock": {
        "format": "${"\uF017"} {:%H:%M %d/%m}",
        "tooltip-format": "<big>{:%A %d %B %Y}</big>\n<tt><small>{:%H:%M}</small></tt>"
      }
    }
  '';
  # Waybar style: orange background, black text, icons via Nerd Font
  environment.etc."waybar/style.css".source = pkgs.writeText "waybar-style.css" ''
    * {
      border: none;
      border-radius: 0;
      font-family: "JetBrains Mono Nerd Font", "JetBrainsMono Nerd Font", sans-serif;
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

  # Reload Waybar (apply config/style after rebuild): Super+Shift+w, or: systemctl --user restart waybar
  environment.etc."sway/config.d/waybar-reload.conf".source = pkgs.writeText "waybar-reload.conf" ''
    bindsym $mod+Shift+w exec systemctl --user restart waybar
  '';

  # Override waybar systemd user service: use our bottom config and start after Sway (sway-session.target)
  # so waybar appears at startup instead of requiring a manual restart
  systemd.user.services.waybar.unitConfig = {
    PartOf = [ "sway-session.target" ];
    After = [ "sway-session.target" ];
    Requisite = [ "sway-session.target" ];
  };
  systemd.user.services.waybar.serviceConfig.ExecStart = [
    "" # clear default
    "${config.programs.waybar.package}/bin/waybar -c /etc/waybar/config -s /etc/waybar/style.css"
  ];
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "waybar" ''
      exec ${pkgs.waybar}/bin/waybar -c /etc/waybar/config -s /etc/waybar/style.css "$@"
    '')
  ];

  # Enable XDG portals for Wayland applications
  # wlr portal is required for screen sharing and other features
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    # Optional: Enable additional portals
    # extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Display manager configuration
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;

  # Configure keymap
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
}

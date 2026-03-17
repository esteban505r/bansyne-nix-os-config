# Sway window manager configuration
# Includes XDG portal configuration for Wayland applications

{ config, pkgs, ... }:

{
  # Enable Sway with GTK wrapper features
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  # Enable Waybar (status bar for Sway), positioned at bottom
  programs.waybar.enable = true;
  # Waybar config: defines which blocks/modules appear (left, center, right)
  environment.etc."waybar/config".source = pkgs.writeText "waybar-config.json" ''
    {
      "layer": "top",
      "position": "bottom",
      "modules-left": ["sway/workspaces", "sway/window"],
      "modules-center": [],
      "modules-right": ["pulseaudio", "network", "battery", "clock"]
    }
  '';
  # Waybar style: colors, fonts, padding (CSS). Edit this to change appearance.
  environment.etc."waybar/style.css".source = pkgs.writeText "waybar-style.css" ''
    * {
      border: none;
      border-radius: 0;
      font-family: sans-serif;
      font-size: 13px;
      min-height: 0;
    }
    window#waybar {
      background: #1e1e2e;
      color: #cdd6f4;
    }
    #workspaces button {
      padding: 0 8px;
      color: #6c7086;
    }
    #workspaces button.active {
      color: #cdd6f4;
      background: #313244;
    }
    #workspaces button.urgent {
      color: #f38ba8;
    }
    #clock, #battery, #network, #pulseaudio {
      padding: 0 10px;
      margin: 0 2px;
    }
    #clock {
      font-weight: bold;
    }
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

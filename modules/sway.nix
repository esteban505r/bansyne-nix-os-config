# Sway window manager configuration
# Includes XDG portal configuration for Wayland applications

{ config, pkgs, ... }:

{
  # Enable Sway with GTK wrapper features
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

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

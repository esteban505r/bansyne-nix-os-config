# System packages configuration
# All packages installed system-wide are listed here

{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Window manager and Wayland utilities
    sway
    swaylock
    swayidle
    # waybar: provided by sway.nix with bottom-position config
    bemenu
    foot
    grim
    slurp
    wl-clipboard

    # Bluetooth management
    blueman

    # System utilities
    git
    wget
    curl

    # Applications
    google-chrome
  ];
}

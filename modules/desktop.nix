# GNOME desktop environment + GDM display manager.

{ config, pkgs, ... }:

{
  services.xserver = {
    enable = true;
    # GDM (login screen) — Wayland by default on capable hardware, falls back to X11.
    displayManager.gdm.enable = true;
    # GNOME shell
    desktopManager.gnome.enable = true;
  };

  # Pull in the dconf service so GNOME settings persist.
  programs.dconf.enable = true;

  # Drop a handful of GNOME apps that are noise on a retro/media box.
  environment.gnome.excludePackages = with pkgs; [
    epiphany       # GNOME Web browser (we use chromium)
    geary          # mail client
    gnome-tour     # first-launch tour
    gnome-music    # we have spotify + kodi
    gnome-contacts
    gnome-maps
    gnome-weather
    totem          # video player (we have mpv/vlc)
  ];
}

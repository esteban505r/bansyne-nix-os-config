# Locale, timezone, and environment variables configuration

{ config, pkgs, ... }:

{
  # Set hostname
  networking.hostName = "nixos";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set timezone
  time.timeZone = "America/Bogota";

  # Select internationalisation properties
  i18n.defaultLocale = "en_US.UTF-8";

  # Additional locale settings
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "es_CO.UTF-8";
    LC_IDENTIFICATION = "es_CO.UTF-8";
    LC_MEASUREMENT = "es_CO.UTF-8";
    LC_MONETARY = "es_CO.UTF-8";
    LC_NAME = "es_CO.UTF-8";
    LC_NUMERIC = "es_CO.UTF-8";
    LC_PAPER = "es_CO.UTF-8";
    LC_TELEPHONE = "es_CO.UTF-8";
    LC_TIME = "es_CO.UTF-8";
  };

  # Environment variables for Wayland applications
  environment.sessionVariables = {
    # Enable Ozone Wayland platform for Chromium/Chrome
    NIXOS_OZONE_WL = "1";
    # Set desktop environment for XDG portals
    XDG_CURRENT_DESKTOP = "sway";
  };
}

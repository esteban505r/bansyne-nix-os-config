# Bluetooth configuration with blueman

{ config, pkgs, ... }:

{
  # Enable Bluetooth support
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # Enable blueman service for Bluetooth management
  services.blueman.enable = true;
}

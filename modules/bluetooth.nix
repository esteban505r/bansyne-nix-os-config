# Bluetooth configuration with blueman

{ config, pkgs, ... }:

{
  # Enable Bluetooth support
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # Enable blueman service for Bluetooth management
  services.blueman.enable = true;

  # Unblock all rfkill devices (Bluetooth, WiFi) at boot so they are not left soft-blocked
  systemd.services.rfkill-unblock = {
    description = "Unblock all rfkill devices (Bluetooth, WiFi)";
    after = [ "multi-user.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = "${pkgs.util-linux}/bin/rfkill unblock all";
  };
  
}

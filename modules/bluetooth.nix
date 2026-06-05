# Bluetooth configuration with blueman
#
# MediaTek combo Wi‑Fi/BT (e.g. MT7921 on IdeaPad): kernel 6.18.32 fails with
# "hci0: Failed to send wmt func ctrl (-22)" → bluetoothctl has no controller.
# Upstream fix: https://github.com/NixOS/nixpkgs/issues/521528

{ config, pkgs, ... }:

{
  # Enable Bluetooth support
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  boot.kernelPatches = [
    {
      name = "Bluetooth: btmtk: accept too short WMT FUNC_CTRL events";
      patch = pkgs.fetchurl {
        url = "https://git.kernel.org/pub/scm/linux/kernel/git/bluetooth/bluetooth-next.git/patch/?id=162b1adeb057d28ad84fd8a03f3c50cf08db5c62";
        hash = "sha256-ij0hQmC0U++AdXWQy6nycnDe6z4yaMoQIrSiLal5DHc=";
      };
    }
  ];

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

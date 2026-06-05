# User account configuration

{ config, pkgs, lib, ... }:

{
  # Define the main user account
  users.users.bansyne = {
    isNormalUser = true;
    description = "bansyne";
    # storage = mount removable media via udisks2
    # kvm    = hardware acceleration for QEMU / emulators that use it (e.g. PCSX2's QEMU bits, Cemu under wine)
    # input  = direct /dev/input access for some emulators / hotplugged controllers
    extraGroups = [ "networkmanager" "wheel" "audio" "video" "storage" "kvm" "input" ];
    packages = with pkgs; [];
  };

  # Allow users in the wheel group to use sudo
  security.sudo.wheelNeedsPassword = false;
}

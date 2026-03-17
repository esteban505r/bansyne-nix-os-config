# User account configuration

{ config, pkgs, ... }:

{
  # Define the main user account
  users.users.bansyne = {
    isNormalUser = true;
    description = "bansyne";
    extraGroups = [ "networkmanager" "wheel" "audio" "video" ];
    # User packages are defined in packages.nix
    packages = with pkgs; [];
  };

  # Allow users in the wheel group to use sudo
  security.sudo.wheelNeedsPassword = false;
}

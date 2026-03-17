# Main NixOS configuration file
# This file imports all modules and sets the system state version

{ config, pkgs, ... }:

{
  # Import hardware configuration
  # NOTE: hardware-configuration.nix is a generated file. You have two options:
  # 1. Include it in the flake (current approach) - makes flake self-contained
  # 2. Reference from /etc/nixos - keeps it separate but less portable
  # If you want to regenerate it: sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
  imports = [
    ./hardware-configuration.nix
    ./modules/locale.nix
    ./modules/users.nix
    ./modules/packages.nix
    ./modules/audio.nix
    ./modules/bluetooth.nix
    ./modules/sway.nix
  ];


  # Bootloader configuration
  # NOTE: You should generate hardware-configuration.nix with:
  # sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
  # This will include your actual filesystem and bootloader settings
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable flakes and nix-command
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
  };

  # Allow unfree packages (required for google-chrome, steam, android-studio, intellij, etc.)
  nixpkgs.config.allowUnfree = true;

  # System state version - should match your NixOS release
  system.stateVersion = "25.11";

  # Specialisations - create different boot entries with different configurations
  # Access specialisations at boot by selecting them from the boot menu
  specialisation = {
    # Gaming specialisation - includes RetroArch, Dolphin, and Steam
    gaming.configuration = {
      imports = [
        ./modules/gaming.nix
      ];
    };
    
    # Development specialisation - includes Android Studio, Cursor, nvm, fvm, JDK, IntelliJ, Git, etc.
    developing.configuration = {
      imports = [
        ./modules/developing.nix
      ];
    };
  };
}

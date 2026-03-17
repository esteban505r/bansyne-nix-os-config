# Main NixOS configuration file
# This file imports all modules and sets the system state version

{ config, pkgs, ... }:

{
  # Import hardware configuration
  imports = [
    ./hardware-configuration.nix
    ./modules/locale.nix
    ./modules/users.nix
    ./modules/packages.nix
    ./modules/audio.nix
    ./modules/bluetooth.nix
    ./modules/sway.nix
  ];

  # Enable flakes and nix-command
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
  };

  # Allow unfree packages (required for google-chrome, steam, android-studio, intellij, etc.)
  nixpkgs.config.allowUnfree = true;

  # System state version - should match your NixOS release
  system.stateVersion = "24.11";

  # Specializations - create different boot entries with different configurations
  # Access specializations at boot by selecting them from the boot menu
  specialisations = {
    # Gaming specialization - includes RetroArch, Dolphin, and Steam
    gaming = {
      # Inherit the base configuration and add gaming module
      configuration = {
        imports = [
          ./modules/gaming.nix
        ];
      };
    };
    
    # Development specialization - includes Android Studio, Cursor, nvm, fvm, JDK, IntelliJ, Git, etc.
    developing = {
      # Inherit the base configuration and add development module
      configuration = {
        imports = [
          ./modules/developing.nix
        ];
      };
    };
  };
}

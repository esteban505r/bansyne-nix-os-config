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
    ./modules/removable-storage.nix
    ./modules/sway.nix
  ];


  # Bootloader: GRUB with theme (replaces systemd-boot for a customizable menu)
  # Alternatives: systemd-boot = minimal, no themes; rEFInd = graphical but doesn't manage NixOS generations
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev";  # EFI: install to ESP (e.g. /boot), not a disk device
    # Limit generations in the menu
    configurationLimit = 10;
    # Themed menu (sleek: light/dark/orange/bigSur; override with pkgs.sleek-grub-theme.override { withStyle = "dark"; })
    theme = pkgs.sleek-grub-theme;
    # Optional: custom background only (if theme is null)
    # splashImage = null;
    # splashMode = "stretch";
    # Font size (when using theme that supports it)
    # fontSize = 24;
  };

  # Enable flakes and nix-command
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
  };

  # Run non-Nix dynamically linked binaries (e.g. node/npm from nvm)
  # See: https://nix.dev/permalink/stub-ld
  programs.nix-ld.enable = true;

  # Allow unfree packages (required for google-chrome, steam, android-studio, intellij, etc.)
  nixpkgs.config.allowUnfree = true;

  # OpenGL: required so libGL.so.1 is available (e.g. for JetBrains IDEs/Skiko, Android Studio, games).
  # Libraries are symlinked to /run/opengl-driver/lib. See: https://wiki.nixos.org/wiki/OpenGL
  hardware.graphics.enable = true;

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

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
    ./modules/fhs-shebangs.nix
    ./modules/users.nix
    ./modules/packages.nix
    ./modules/audio.nix
    ./modules/bluetooth.nix
    ./modules/removable-storage.nix
    ./modules/nvidia.nix
    ./modules/oter-waybar.nix
    ./modules/sway.nix
    ./modules/developing.nix
  ];


  # Bootloader: GRUB with theme (replaces systemd-boot for a customizable menu)
  # Alternatives: systemd-boot = minimal, no themes; rEFInd = graphical but doesn't manage NixOS generations
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev";  # EFI: install to ESP (e.g. /boot), not a disk device
    # Show other installed OSes (e.g. Windows) in the boot menu
    useOSProber = true;
    # Limit generations in the menu
    configurationLimit = 10;
    # Resolution for graphical boot menu (bit depth required: WxHx32). In GRUB menu press 'c' then run videoinfo to see modes.
    gfxmodeEfi = "1920x1080x32,1280x1024x32,1024x768x32,auto";
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

  # Automatically remove old generations and run garbage collection (frees disk, keeps boot menu manageable)
  # Runs weekly (Mon 03:15); keeps generations from the last 7 days. Use [ "-d" ] to keep only current.
  nix.gc = {
    automatic = true;
    dates = "Mon *-*-* 03:15:00";
    options = "--delete-older-than 7d";
  };

  # Run non-Nix dynamically linked binaries (e.g. node/npm from nvm)
  # See: https://nix.dev/permalink/stub-ld
  programs.nix-ld.enable = true;

  # Allow unfree packages (required for google-chrome, steam, android-studio, intellij, etc.)
  nixpkgs.config.allowUnfree = true;

  # OpenGL: required so libGL.so.1 is available (e.g. for JetBrains IDEs/Skiko, Android Studio, games).
  # Libraries are symlinked to /run/opengl-driver/lib. See: https://wiki.nixos.org/wiki/OpenGL
  # enable32Bit: 32-bit OpenGL/Vulkan libs for Android emulator and some games (e.g. Steam).
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  # Joy-Con / Pro Controller: joycond daemon + joycond-cemuhook (DSU)
  services.joycond.enable = true;
  programs."joycond-cemuhook".enable = true;

  # Nintendo Switch controllers on hidraw: group-readable so users in "input" can access without root
  services.udev.extraRules = ''
    KERNEL=="hidraw*", ATTRS{idVendor}=="057e", MODE="0660", GROUP="input"
  '';

  users.users.bansyne.extraGroups = [ "input" ];

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
  };
}

# Main NixOS configuration file
# This file imports all modules and sets the system state version

{ config, pkgs, lib, ... }:

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
    ./modules/sway.nix
    ./modules/developing.nix
  ];


  # Bootloader: Lanzaboote (Secure Boot + signed UKIs via systemd-boot).
  # Manual keys: sudo sbctl create-keys (if /var/lib/sbctl has no keys), rebuild, sudo sbctl verify,
  # firmware in Setup Mode, then sudo sbctl enroll-keys --microsoft. See:
  # https://nix-community.github.io/lanzaboote/getting-started/
  boot.loader.grub.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.systemd-boot.configurationLimit = 10;
  # Prevent editing the kernel cmdline from the boot menu (Secure Boot hardening).
  boot.loader.systemd-boot.editor = false;

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };

  # Windows on the same ESP as NixOS is usually picked up automatically. Separate ESP/disk:
  # boot.loader.systemd-boot.windows.<name> + EDK2 shell handle discovery (nixpkgs systemd-boot docs).

  environment.systemPackages = [
    pkgs.sbctl
    pkgs.efibootmgr
  ];

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

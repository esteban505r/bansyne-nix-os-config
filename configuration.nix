# Main NixOS configuration file
# This file imports all modules and sets the system state version

{ config, pkgs, lib, ... }:

let
  rootUuid = lib.last (lib.splitString "/" config.fileSystems."/".device);
  appendSpecialisationEntries = ''
    ( set +e
      TOPLEVEL="''$1"
      [ -z "''$TOPLEVEL" ] && exit 0
      [ ! -d "''$TOPLEVEL/specialisation" ] && exit 0
      add_entry() {
        local name="''$1" display="''$2"
        local p="''$TOPLEVEL/specialisation/''$name"
        [ -f "''$p/kernel" ] || return 0
        local params=$(cat "''$p/kernel-params") init=$(readlink -f "''$p/init")
        local kernel=$(readlink -f "''$p/kernel") initrd=$(readlink -f "''$p/initrd")
        cat >> /boot/grub/grub.cfg << ENTRY

    menuentry "NixOS - ''$display" {
      search --fs-uuid --set=root ${rootUuid}
      linux ''$kernel init=''$init ''$params
      initrd ''$initrd
    }
    ENTRY
      }
      add_entry gaming Gaming
      add_entry developing Developing
      true
    ) || true
  '';
in
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


  # Bootloader: GRUB with theme (replaces systemd-boot for a customizable menu)
  # Alternatives: systemd-boot = minimal, no themes; rEFInd = graphical but doesn't manage NixOS generations
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev";  # EFI: install to ESP (e.g. /boot), not a disk device
    configurationLimit = 10;
    configurationName = "Default";
    theme = pkgs.sleek-grub-theme;
    # Append Gaming/Developing entries when GRUB is installed (toplevel in $1)
    extraInstallCommands = appendSpecialisationEntries;
  };

  # Enable flakes and nix-command
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
  };

  # Allow unfree packages (required for google-chrome, steam, android-studio, intellij, etc.)
  nixpkgs.config.allowUnfree = true;

  # System state version - should match your NixOS release
  system.stateVersion = "25.11";

  # Specialisations - create different boot entries (shown next to "NixOS - Default" in GRUB)
  # After rebuild, run: sudo nixos-rebuild boot  (then reboot to see entries)
  # If Gaming/Developing don't appear, check: ls /run/current-system/specialisation/
  specialisation = {
    gaming.configuration = {
      imports = [ ./modules/gaming.nix ];
      boot.loader.grub.configurationName = lib.mkForce "Gaming";
    };
    developing.configuration = {
      imports = [ ./modules/developing.nix ];
      boot.loader.grub.configurationName = lib.mkForce "Developing";
    };
  };
}

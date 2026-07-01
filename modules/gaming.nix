# Gaming specialization module
# Installs RetroArch, Dolphin, Steam, and Lutris (SP Football Life 2026, etc.)

{ config, pkgs, lib, ... }:

let
  # Proton/UMU runners: util-linux avoids getopt errors from steam-runtime-tools.
  umuLauncher = pkgs.umu-launcher.override {
    extraPkgs = p: [ p.util-linux ];
  };

  # Lutris FHS env: Wine + winetricks so the SPFL install script can run dotnet48/8, vcrun2022, etc.
  # See: https://wiki.nixos.org/wiki/Lutris
  lutrisPackage = pkgs.lutris.override {
    extraPkgs = p: with p; [
      umuLauncher
      winetricks
      wineWow64Packages.stable
      util-linux
    ];
  };
in
{
  # Label in GRUB for this profile (otherwise: "NixOS - (gaming - …)")
  boot.loader.grub.configurationName = "Gaming";

  # Gaming packages
  environment.systemPackages = with pkgs; [
    # --- Emulators ---
    retroarch-full  # RetroArch frontend bundled with all libretro cores
    dolphin-emu     # GameCube and Wii emulator

    # --- Steam ---
    steam         # Steam client and store
    steam-run     # Run arbitrary programs in Steam's runtime (libs, Proton)

    # --- Lutris / Wine (SP Football Life 2026 and other Windows games) ---
    winetricks
    wineWow64Packages.stable
    gamescope     # Optional compositor; SPFL yaml sets ENABLE_GAMESCOPE_WSI=0 if black screen
    vulkan-tools  # vulkaninfo / vkcube — useful when DXVK fails to download
    dxvk          # Fallback if Lutris cache download fails (flickering/missing textures)
  ] ++ [
    lutrisPackage # >= 0.5.20 required; nixpkgs ships 0.5.22
    umuLauncher
  ];

  # Default game install location (Steam Deck guide uses ~/Games; user is bansyne here).
  systemd.tmpfiles.rules = [
    "d /home/bansyne/Games 0755 bansyne users -"
  ];

  # Lutris esync: raise open-file limit (https://wiki.nixos.org/wiki/Lutris#Using_Esync)
  systemd.settings.Manager.DefaultLimitNOFILE = "524288:524288";
  security.pam.loginLimits = [
    {
      domain = "bansyne";
      type = "hard";
      item = "nofile";
      value = "524288";
    }
  ];

  # Lutris downloads umu-run with #!/usr/bin/python3; symlink NixOS umu-launcher after rebuild.
  system.activationScripts.lutrisUmuLauncher = lib.stringAfter [ "users" ] ''
    UMU_RUNTIME="/home/bansyne/.local/share/lutris/runtime/umu"
    mkdir -p "$UMU_RUNTIME"
    ln -sfn ${umuLauncher}/bin/umu-run "$UMU_RUNTIME/umu-run"
    ln -sfn ${umuLauncher}/bin/umu-run "$UMU_RUNTIME/umu-run.py"
    chown -R bansyne:users "$UMU_RUNTIME"
  '';

  # Joy-Con: services.joycond + programs.joycond-cemuhook are enabled in configuration.nix

  # Enable Steam with proper configuration
  programs.steam = {
    enable = true;
    # Open firewall for Remote Play
    remotePlay.openFirewall = true;
    # Open firewall for dedicated servers
    dedicatedServer.openFirewall = true;
  };

  # Enable graphics support (required for Steam, Lutris/Wine, and many games)
  hardware.graphics.enable = true;

  # Enable 32-bit support (required for Steam, Wine, and many games)
  hardware.graphics.enable32Bit = true;

  # Note: Pipewire (configured in audio.nix) already provides PulseAudio compatibility
  # for 32-bit applications, so no additional configuration is needed
}

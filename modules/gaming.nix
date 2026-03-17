# Gaming specialization module
# Installs RetroArch, Dolphin, and Steam with proper configuration

{ config, pkgs, ... }:

{
  # Gaming packages
  environment.systemPackages = with pkgs; [
    # --- Emulators ---
    retroarch     # Multi-system emulator frontend (libretro cores)
    dolphin-emu   # GameCube and Wii emulator

    # --- Controllers ---
    joycond       # Nintendo Joy-Con driver/daemon (pairing, motion)
    evdevhook2    # Cemuhook UDP server for gamepad/motion (Cemu, etc.)

    # --- Steam ---
    steam         # Steam client and store
    steam-run     # Run arbitrary programs in Steam’s runtime (libs, Proton)
  ];

  # Enable Steam with proper configuration
  programs.steam = {
    enable = true;
    # Open firewall for Remote Play
    remotePlay.openFirewall = true;
    # Open firewall for dedicated servers
    dedicatedServer.openFirewall = true;
  };

  # Enable graphics support (required for Steam and many games)
  hardware.graphics.enable = true;
  
  # Enable 32-bit support (required for Steam and many games)
  hardware.graphics.enable32Bit = true;

  # Note: Pipewire (configured in audio.nix) already provides PulseAudio compatibility
  # for 32-bit applications, so no additional configuration is needed
}

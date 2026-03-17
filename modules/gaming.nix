# Gaming specialization module
# Installs RetroArch, Dolphin, and Steam with proper configuration

{ config, pkgs, ... }:

{
  # Gaming packages
  environment.systemPackages = with pkgs; [
    # RetroArch - Multi-system emulator frontend
    retroarch
    
    # Dolphin - GameCube and Wii emulator
    dolphin-emu
    
    # Steam - Gaming platform and store
    steam
    steam-run-native
  ];

  # Enable Steam with proper configuration
  programs.steam = {
    enable = true;
    # Open firewall for Remote Play
    remotePlay.openFirewall = true;
    # Open firewall for dedicated servers
    dedicatedServer.openFirewall = true;
  };

  # Enable 32-bit support (required for Steam and many games)
  hardware.opengl.driSupport32Bit = true;
  
  # Enable OpenGL (should already be enabled, but ensuring it's explicit)
  hardware.opengl.enable = true;

  # Note: Pipewire (configured in audio.nix) already provides PulseAudio compatibility
  # for 32-bit applications, so no additional configuration is needed
}

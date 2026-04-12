# Audio configuration with Pipewire
# Provides ALSA and PulseAudio compatibility
#
# AirPlay as *sender* (this PC → AirPlay speakers / some TVs):
# PipeWire’s RAOP module discovers AirPlay *receivers* on the LAN and exposes them
# as normal output devices (e.g. in pavucontrol / wpctl). This is **audio only** —
# Apple’s screen-mirroring AirPlay protocol is not implemented for Linux→TV video.
# Requires Avahi (enabled in miracast.nix for mDNS). See:
# https://wiki.nixos.org/wiki/PipeWire#AirPlay/RAOP_configuration
# https://docs.pipewire.org/page_module_raop_discover.html

{ config, pkgs, ... }:

{
  # Enable Pipewire for audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # RAOP timing/control (UDP 6001–6002) when streaming *to* AirPlay devices
    raopOpenFirewall = true;
    extraConfig.pipewire."10-airplay-raop" = {
      "context.modules" = [
        {
          name = "libpipewire-module-raop-discover";
          # args = { "raop.latency.ms" = 500; };  # if you hear dropouts, try raising
        }
      ];
    };
    # Optional: Enable JACK if needed
    # jack.enable = true;
  };

  # Disable PulseAudio (Pipewire replaces it)
  services.pulseaudio.enable = false;

  # Enable realtime audio processing
  security.rtkit.enable = true;
}

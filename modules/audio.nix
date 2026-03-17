# Audio configuration with Pipewire
# Provides ALSA and PulseAudio compatibility

{ config, pkgs, ... }:

{
  # Enable Pipewire for audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # Optional: Enable JACK if needed
    # jack.enable = true;
  };

  # Disable PulseAudio (Pipewire replaces it)
  services.pulseaudio.enable = false;

  # Enable realtime audio processing
  security.rtkit.enable = true;
}

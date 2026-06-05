# Multimedia: media players, codecs, transcoding, and audio tools.

{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # --- Players ---
    mpv                       # Lightweight, scriptable video player
    vlc                       # Plays anything; DVD/Blu-ray
    kodi                      # HTPC / media-center frontend
    jellyfin-media-player     # Native Jellyfin client

    # --- Codecs / transcoding ---
    ffmpeg-full               # Encoders/decoders incl. libfdk, x264/x265, av1
    handbrake                 # DVD/Blu-ray/file transcoder (ghb GUI + CLI)
    mkvtoolnix                # MKV mux/demux/edit
    mediainfo-gui             # Inspect media files

    # --- Audio ---
    audacity                  # Audio editor
    easyeffects               # Pipewire EQ / plugins
    pavucontrol               # Pulse/Pipewire mixer
    spotify                   # Spotify client (unfree)
    crosspipe                 # Pipewire patchbay (replaces helvum)

    # --- Image / misc ---
    imv                       # Lightweight Wayland image viewer
    gimp                      # Image editor
    yt-dlp                    # Download videos from YouTube / 1000+ sites

    # --- Optical media ---
    libdvdcss                 # CSS decryption for commercial DVDs
  ];

  # Kodi: also enable as a system service so it can be launched from a TTY
  # (optional; comment out if you only ever launch Kodi from inside Sway).
  # services.cage = { enable = false; program = "${pkgs.kodi}/bin/kodi-standalone"; };
}

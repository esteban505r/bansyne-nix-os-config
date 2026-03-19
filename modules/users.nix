# User account configuration

{ config, pkgs, lib, ... }:

{
  # Load nvm in interactive shells (install with: n). Silence "bash: hash: hashing disabled" (nvm uses hash; NixOS has it disabled).
  environment.interactiveShellInit = ''
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" 2>/dev/null

    # Android SDK: prefer ~/Android/Sdk (Android Studio default on Linux), then ~/.android/sdk. Adds emulator, platform-tools, cmdline-tools to PATH.
    if [ -d "$HOME/Android/Sdk" ]; then export ANDROID_HOME="$HOME/Android/Sdk"
    elif [ -d "$HOME/.android/sdk" ]; then export ANDROID_HOME="$HOME/.android/sdk"
    elif [ -z "$ANDROID_HOME" ]; then export ANDROID_HOME="$HOME/.android/sdk"; fi
    export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

    # NixOS runs many vendor binaries without an RPATH set; the Android emulator
    # (and its QEMU binary) need X11, ALSA, PulseAudio, etc. via LD_LIBRARY_PATH.
    # On Wayland (Sway): QT_QPA_PLATFORM=xcb forces XWayland so the emulator window
    # uses GPU acceleration instead of software rendering (avoids "Qt wayland plugin" fallback).
    emulator() {
      if [ ! -x "$ANDROID_HOME/emulator/emulator" ]; then
        command emulator "$@"
        return $?
      fi

      if [ -n "$LD_LIBRARY_PATH" ]; then
        export LD_LIBRARY_PATH="${lib.makeLibraryPath [
          pkgs.libX11
          pkgs.libXext
          pkgs.libXrender
          pkgs.libXtst
          pkgs.libXi
          pkgs.libXrandr
          pkgs.libXcursor
          pkgs.libXfixes
          pkgs.alsa-lib
          pkgs.libuuid
          pkgs.libpulseaudio
          pkgs.libpng
          pkgs.nspr
          pkgs.nss
          pkgs.expat
          pkgs.libdrm
          pkgs.libxcb
          pkgs.libxkbfile
          pkgs.libbsd
          pkgs.xcbutilcursor
          pkgs.xcbutilwm
          pkgs.xcbutilkeysyms
          pkgs.xcbutilimage
          pkgs.xcbutil
          pkgs.libxkbcommon
          pkgs.zlib
          pkgs.libICE
          pkgs.libSM
          pkgs.glib
        ]}:$LD_LIBRARY_PATH"
      else
        export LD_LIBRARY_PATH="${lib.makeLibraryPath [
          pkgs.libX11
          pkgs.libXext
          pkgs.libXrender
          pkgs.libXtst
          pkgs.libXi
          pkgs.libXrandr
          pkgs.libXcursor
          pkgs.libXfixes
          pkgs.alsa-lib
          pkgs.libuuid
          pkgs.libpulseaudio
          pkgs.libpng
          pkgs.nspr
          pkgs.nss
          pkgs.expat
          pkgs.libdrm
          pkgs.libxcb
          pkgs.libxkbfile
          pkgs.libbsd
          pkgs.xcbutilcursor
          pkgs.xcbutilwm
          pkgs.xcbutilkeysyms
          pkgs.xcbutilimage
          pkgs.xcbutil
          pkgs.libxkbcommon
          pkgs.zlib
          pkgs.libICE
          pkgs.libSM
          pkgs.glib
        ]}"
      fi

      QT_QPA_PLATFORM=xcb exec "$ANDROID_HOME/emulator/emulator" "$@"
    }
  '';

  # Define the main user account
  users.users.bansyne = {
    isNormalUser = true;
    description = "bansyne";
    # storage = mount removable media via udisks2
    # kvm = allow Android Emulator/QEMU to use hardware acceleration instead of slow fallbacks
    extraGroups = [ "networkmanager" "wheel" "audio" "video" "storage" "kvm" ];
    # User packages are defined in packages.nix
    packages = with pkgs; [];
  };

  # Allow users in the wheel group to use sudo
  security.sudo.wheelNeedsPassword = false;
}

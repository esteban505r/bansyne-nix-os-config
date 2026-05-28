# Development specialization module
# Installs development tools: Android Studio, Cursor, nvm, fvm, JDK, IntelliJ, Git, etc.
#
# --- Skiko / libGL.so.1 on NixOS ---
# JetBrains IDEs and Android Studio use Skiko (Compose) which loads libskiko-*.so from ~/.skiko;
# that .so depends on libGL.so.1. On NixOS, OpenGL libs live in the store or /run/opengl-driver,
# so the JVM cannot find them unless LD_LIBRARY_PATH is set.
#
# Recommended NixOS setup (see NixOS wiki OpenGL, nixpkgs#278507, #397059):
# 1. Enable OpenGL: hardware.graphics.enable = true (done in configuration.nix).
# 2. For JetBrains IDEs: nixpkgs PR #397059 (April 2025) added libGL to the package extraLdPath;
#    on nixos-unstable/25.05+ IDEA may work unwrapped; we keep wrappers for compatibility and for
#    Android Studio (its FHS env does not pass LD_LIBRARY_PATH to the JVM that loads ~/.skiko).
# 3. Wrappers set LD_LIBRARY_PATH to /run/opengl-driver/lib (NixOS standard) plus mesa/libglvnd
#    so the JVM finds libGL.so.1 when loading Skiko.
# 4. JBR's AWT (libawt_xawt.so) needs X11 libs (libXext, libX11, etc.) for Compose desktop / Swing;
#    include them so Run configurations (e.g. Compose Multiplatform desktop) find them.

{ config, pkgs, lib, ... }:

let
  # OpenGL + X11 + fonts + emulator: NixOS OpenGL path, mesa/libglvnd for libGL; X11 for JBR AWT;
  # freetype for libfontmanager; libpng for Android emulator QEMU (qemu-system-x86_64).
  libPath = "/run/opengl-driver/lib:" + lib.makeLibraryPath [
    pkgs.mesa
    pkgs.libglvnd
    pkgs.libX11
    pkgs.libXext
    pkgs.libXrender
    pkgs.libXtst
    pkgs.libXi
    pkgs.libXrandr
    pkgs.libXcursor
    pkgs.libXfixes
    pkgs.freetype
    pkgs.fontconfig
    pkgs.libpng
    pkgs.nspr
    pkgs.nss
    pkgs.expat
    pkgs.libdrm
    pkgs.libxcb
    pkgs.libxkbfile
    pkgs.libbsd
    # Qt xcb platform plugin (emulator UI): needs libxcb-cursor and related xcb-util libs
    pkgs.xcbutilcursor
    pkgs.xcbutilwm
    pkgs.xcbutilkeysyms
    pkgs.xcbutilimage
    pkgs.xcbutil
    # Qt xcb plugin (keyboard / toolkit glue)
    pkgs.libxkbcommon
    pkgs.zlib
    pkgs.libICE
    pkgs.libSM
    pkgs.glib
  ];
  # On Wayland (e.g. Sway) the emulator's Qt UI often lacks the Wayland plugin and falls back to
  # software rendering, causing lag. Forcing xcb uses XWayland and restores GPU-accelerated window.
  wrapJetbrains = name: pkg: binName:
    pkgs.writeShellScriptBin binName ''
      export LD_LIBRARY_PATH="${libPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      export QT_QPA_PLATFORM=xcb
      export _JAVA_AWT_WM_NONREPARENTING=1
      exec ${pkg}/bin/${binName} "$@"
    '';
  android-studio-wrapped = wrapJetbrains "android-studio" pkgs.android-studio "android-studio";
  idea-wrapped = wrapJetbrains "idea" pkgs.jetbrains.idea "idea";
  # DBeaver discovers pg_dump/psql via PATH or “local client” path; nixpkgs’ wrapper does not add postgres.
  # Same postgresql_* as modules/packages.nix so pg_dump major matches your DB servers.
  dbeaver-wrapped = pkgs.symlinkJoin {
    name = "dbeaver-wrapped";
    paths = [ pkgs.dbeaver-bin ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm -f $out/bin/dbeaver
      makeWrapper ${pkgs.dbeaver-bin}/bin/dbeaver $out/bin/dbeaver \
        --prefix PATH : ${lib.makeBinPath [ pkgs.postgresql_18 ]}
      # Upstream .desktop Exec= points at dbeaver-bin; patch so menu launches get the same PATH.
      sed -i "s|Exec=.*|Exec=env NO_AT_BRIDGE=1 $out/bin/dbeaver %U|" \
        $out/share/applications/dbeaver.desktop
    '';
    meta.mainProgram = "dbeaver";
  };
in
{
  # Studio runs $ANDROID_HOME/emulator/emulator by full path; child processes may not see the
  # IDE wrapper's LD_LIBRARY_PATH. Export the same lib path for the whole Sway session so Qt's
  # xcb platform plugin (emulator UI) can load libxcb-cursor and friends.
  # AWT/Compose desktop (Oter, Gradle :run) need NONREPARENTING on Sway/Wayland to avoid black gaps.
  programs.sway.extraSessionCommands = lib.mkIf config.programs.sway.enable (lib.mkAfter ''
    export LD_LIBRARY_PATH="${libPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export _JAVA_AWT_WM_NONREPARENTING=1
  '');

  # Development packages
  environment.systemPackages = with pkgs; [
    # --- Version control ---
    git           # Distributed version control
    gh            # GitHub CLI (PRs, issues, repos from terminal)

    # --- IDEs and editors ---
    android-studio-wrapped   # Android IDE (wrapped so Skiko/Compose can find libGL)
    android-tools # adb, fastboot (Android Debug Bridge; in PATH)
    idea-wrapped      # IntelliJ IDEA (wrapped so Skiko/Compose can find libGL)
    # Cursor is in base (packages.nix) so it’s available in every specialisation

    # Node.js: not installed here; manage manually (nvm, fnm, or nix-shell per project).

    # --- Flutter ---
    fvm            # Flutter Version Manager (per-project Flutter versions)

    # --- Build tools ---
    go             # Go compiler and toolchain (go, gofmt)
    gnumake        # GNU Make (required by node-gyp for native npm addons)
    gcc            # C/C++ compiler (required by node-gyp)
    gradle         # Java/Kotlin build tool
    maven          # Java build and dependency management
    openssl        # TLS/crypto toolkit (openssl CLI; headers/libs for native builds)
    dbeaver-wrapped # DBeaver + postgres client tools on PATH (pg_dump, psql, …)

    # --- Python ---
    python3              # Python interpreter
    python3Packages.pip   # pip package installer

    # --- Containers ---
    docker         # Container runtime
    docker-compose # Multi-container orchestration (compose files)

    # --- CLI utilities ---
    ripgrep        # Fast recursive grep (rg)
    fd             # Simple, fast find alternative
    bat            # Cat with syntax highlighting and paging
    eza            # Modern ls (icons, git status, tree)
    uv             # Package manager for Node.js
    claude-code      # AI assistant
    opencode         # AI coding agent (terminal)
  ];

  # Nix-managed JDK: installs JDK and sets JAVA_HOME (single source of truth)
  programs.java = {
    enable = true;
    package = pkgs.jdk25;  # OpenJDK 25 LTS; use pkgs.jdk17 or pkgs.jdk11 for older
  };

  # Note: Android Studio is installed as a package above
  # There is no programs.android-studio option in NixOS
  #
  # --- Android Emulator performance (NixOS + Sway/Wayland) ---
  # If the emulator is slow after starting to use it, try:
  # 1. AVD Manager → Edit AVD → Show Advanced → Emulated Performance:
  #    - Graphics: "Hardware - GLES 2.0" (or "Automatic"); OpenGL ES renderer: "Desktop native OpenGL", API: max.
  #    - Disable "Auto-save current state to Quickboot" (snapshots cause I/O stalls).
  # 2. Verify KVM: ~/Android/Sdk/emulator/emulator -accel-check (should show KVM (Linux) yes).
  # 3. If still slow, try running with: steam-run ~/Android/Sdk/emulator/emulator -avd YOUR_AVD -feature -Vulkan
  # 4. Wrapper and emulator() already set QT_QPA_PLATFORM=xcb so the emulator window uses XWayland (GPU) on Sway.

  # Enable Docker
  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;  # Don't start on boot, start manually when needed
  };

  # Add user to docker group
  # Note: This will merge with existing groups from users.nix
  users.users.bansyne.extraGroups = [ "docker" ];

  # Environment variables for development
  environment.variables = {
    # JAVA_HOME is set by programs.java
    # Android SDK path (on Linux, Android Studio typically defaults to ~/Android/Sdk).
    ANDROID_HOME = "$HOME/Android/Sdk";
    ANDROID_SDK_ROOT = "$HOME/Android/Sdk";
  };
}

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

{ config, pkgs, lib, ... }:

let
  # NixOS OpenGL driver path (populated when hardware.graphics.enable = true) + mesa/libglvnd for libGL.so.1
  libPath = "/run/opengl-driver/lib:" + lib.makeLibraryPath [ pkgs.mesa pkgs.libglvnd ];
  wrapJetbrains = name: pkg: binName:
    pkgs.writeShellScriptBin binName ''
      export LD_LIBRARY_PATH="${libPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      exec ${pkg}/bin/${binName} "$@"
    '';
  android-studio-wrapped = wrapJetbrains "android-studio" pkgs.android-studio "android-studio";
  idea-wrapped = wrapJetbrains "idea" pkgs.jetbrains.idea "idea";
in
{
  # Development packages
  environment.systemPackages = with pkgs; [
    # --- Version control ---
    git           # Distributed version control
    gh            # GitHub CLI (PRs, issues, repos from terminal)

    # --- IDEs and editors ---
    android-studio-wrapped   # Android IDE (wrapped so Skiko/Compose can find libGL)
    idea-wrapped      # IntelliJ IDEA (wrapped so Skiko/Compose can find libGL)
    # Cursor is in base (packages.nix) so it’s available in every specialisation

    # Node.js: not installed here; manage manually (nvm, fnm, or nix-shell per project).

    # --- Flutter ---
    fvm            # Flutter Version Manager (per-project Flutter versions)

    # --- Build tools ---
    gnumake        # GNU Make (required by node-gyp for native npm addons)
    gcc            # C/C++ compiler (required by node-gyp)
    gradle         # Java/Kotlin build tool
    maven          # Java build and dependency management
    dbeaver-bin    # Database management tool

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
  ];

  # Nix-managed JDK: installs JDK and sets JAVA_HOME (single source of truth)
  programs.java = {
    enable = true;
    package = pkgs.jdk21;  # OpenJDK 21 LTS; use pkgs.jdk17 or pkgs.jdk11 for older
  };

  # Note: Android Studio is installed as a package above
  # There is no programs.android-studio option in NixOS

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
    # Android SDK path (Android Studio sets this, but explicit is better)
    ANDROID_HOME = "$HOME/.android/sdk";
  };
}

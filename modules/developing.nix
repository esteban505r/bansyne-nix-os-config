# Development specialization module
# Installs development tools: Android Studio, Cursor, nvm, fvm, JDK, IntelliJ, Git, etc.

{ config, pkgs, ... }:

{
  # Development packages
  environment.systemPackages = with pkgs; [
    # --- Version control ---
    git           # Distributed version control
    gh            # GitHub CLI (PRs, issues, repos from terminal)

    # --- Java ---
    jdk21         # OpenJDK 21 LTS (use jdk17/jdk11 if needed)

    # --- IDEs and editors ---
    android-studio   # Android IDE (SDK, emulator, build tools)
    jetbrains.idea   # IntelliJ IDEA
    # Cursor is in base (packages.nix) so it’s available in every specialisation

    # Node.js: not installed here; manage manually (nvm, fnm, or nix-shell per project).

    # --- Flutter ---
    fvm            # Flutter Version Manager (per-project Flutter versions)

    # --- Build tools ---
    gradle         # Java/Kotlin build tool
    maven          # Java build and dependency management

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

  # Enable Java support
  programs.java = {
    enable = true;
    package = pkgs.jdk21;
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
    # Set JAVA_HOME
    JAVA_HOME = "${pkgs.jdk21}";
    # Android SDK path (Android Studio sets this, but explicit is better)
    ANDROID_HOME = "$HOME/.android/sdk";
  };
}

# Development specialization module
# Installs development tools: Android Studio, Cursor, nvm, fvm, JDK, IntelliJ, Git, etc.

{ config, pkgs, ... }:

{
  # Development packages
  environment.systemPackages = with pkgs; [
    # Version control
    git
    gh  # GitHub CLI
    
    # Java Development Kit (JDK)
    jdk21  # Latest LTS JDK, change to jdk17 or jdk11 if needed
    
    # IDEs and Editors
    android-studio  # Android Studio IDE
    jetbrains.idea  # IntelliJ IDEA (formerly idea-ultimate)
    code-cursor  # Cursor IDE (latest from nixos-unstable; unfree)
    
    # Node.js and version managers
    nodejs_20  # Node.js LTS
    nodePackages.npm  # npm package manager
    # Note: nvm (Node Version Manager) is typically a shell script installed in user's home
    # For nvm-like functionality in NixOS, consider:
    # - Using nix-shell with different nodejs versions
    # - Installing nvm manually: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    # - Using direnv with nix-shell for per-project node versions
    
    # Flutter Version Manager
    fvm  # Flutter Version Manager
    
    # Build tools
    gradle
    maven
    
    # Additional development utilities
    python3
    python3Packages.pip
    
    # Docker (useful for development)
    docker
    docker-compose
    
    # Additional tools
    ripgrep  # Fast text search
    fd  # Simple and fast alternative to find
    bat  # Cat clone with syntax highlighting
    eza  # Modern ls replacement
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

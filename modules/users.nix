# User account configuration

{ config, pkgs, ... }:

{
  # Load nvm in interactive shells (install with: n). Silence "bash: hash: hashing disabled" (nvm uses hash; NixOS has it disabled).
  environment.interactiveShellInit = ''
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" 2>/dev/null
  '';

  # Define the main user account
  users.users.bansyne = {
    isNormalUser = true;
    description = "bansyne";
    extraGroups = [ "networkmanager" "wheel" "audio" "video" "storage" ]; # storage = mount removable media via udisks2
    # User packages are defined in packages.nix
    packages = with pkgs; [];
  };

  # Allow users in the wheel group to use sudo
  security.sudo.wheelNeedsPassword = false;
}

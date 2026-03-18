{
  description = "NixOS configuration for bansyne";

  inputs = {
    # NixOS unstable channel
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    # Main NixOS configuration
    # Specializations (gaming, developing) are defined in configuration.nix
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        # Wallpapers from repo (add images to wallpapers/, commit so flake copy includes it)
        wallpapersDir = if builtins.pathExists ./wallpapers then ./wallpapers else null;
      };
      modules = [
        # Allow unfree packages (required for Cursor, Steam, Android Studio, etc.)
        # Must be set at flake level so nixpkgs is instantiated with it
        { nixpkgs.config.allowUnfree = true; }
        ./configuration.nix
      ];
    };
  };
}

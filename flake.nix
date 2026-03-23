{
  description = "NixOS configuration for bansyne";

  inputs = {
    # NixOS unstable channel
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, lanzaboote, ... }@inputs: {
    # Main NixOS configuration
    # Specializations (gaming, developing) are defined in configuration.nix
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Allow unfree packages (required for Cursor, Steam, Android Studio, etc.)
        # Must be set at flake level so nixpkgs is instantiated with it
        { nixpkgs.config.allowUnfree = true; }
        lanzaboote.nixosModules.lanzaboote
        ./configuration.nix
      ];
    };
  };
}

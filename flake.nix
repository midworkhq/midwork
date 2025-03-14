{
  description = "Midwork.com machines defined by flakes";
  inputs = {
    # Reusable packages for nixos configs
    # Use the version of nixpkgs that has been tested to work with SrvOS
    srvos.url = "github:nix-community/srvos";
    nixpkgs.follows = "srvos/nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Allows us to fetch the updating list of ssh keys for Onni
    onnimonni-ssh-keys = {
      url = "https://github.com/onnimonni.keys";
      flake = false;
    };
  };
  outputs = inputs@{ self, nixpkgs, srvos, disko, sops-nix, ... }: {
    nixosConfigurations.rusty = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        inherit inputs;
      };
      modules = [
        # This machine is a server
        srvos.nixosModules.server
        # Deployed on the Intel Hetzner bare metal hardware
        # Replace '-intel' with '-amd' if you want to use AMD
        srvos.nixosModules.hardware-hetzner-online-intel
        # Setup disks with disko
        disko.nixosModules.disko
        # Decrypt secrets with SOPS
        sops-nix.nixosModules.sops
        # Finally the server specific configuration here
        ./nixos/servers/rusty.nix
      ];
    };
  };
}
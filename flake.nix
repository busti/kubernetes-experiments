{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
    common.url = "git+file:///home/busti/projects/os-common";
  };

  outputs = { self, nixpkgs, flake-utils, common, ... }:
    # Config for the dev shell
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [
          (final: prev: {
            terraform = prev.terraform.withPlugins (plugins: [
              plugins.libvirt
            ]);
          })
        ];

        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        make-boot-image = pkgs.writeShellScriptBin "make-boot-image" ''
          nix build .#nixosConfigurations.etcd.config.system.build.qcow2
        '';
      in {
        devShells.default = pkgs.mkShell rec {
          nativeBuildInputs = with pkgs; [
            terraform
            make-boot-image
          ];
        };
      }
    ) // {
      # individual host configurations
      nixosConfigurations = {
        etcd = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            common.nixosModules.server
            ./configurations/image.nix
          ];
        };
      };
    };
}

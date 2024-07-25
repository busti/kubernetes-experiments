{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-24.05";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    common.url = "git+file:///home/busti/projects/os-common";
    nixus.url = "github:infinisil/nixus";
  };

  outputs = { self, nixpkgs, unstable, flake-utils, common, nixus, ... }:
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

        rebuild = pkgs.writeShellScriptBin "rebuild" ''
          terraform destroy --auto-approve
          terraform apply --auto-approve
          until ssh -o StrictHostKeyChecking=no nixos@test.k8s.local; do
            sleep 1
          done
        '';

        make-boot-image = pkgs.writeShellScriptBin "make-boot-image" ''
          nix build .#nixosConfigurations.image.config.system.build.qcow2
        '';
      in {
        devShells.default = pkgs.mkShell rec {
          nativeBuildInputs = with pkgs; [
            terraform libxslt cdrtools
            rebuild make-boot-image
          ];
        };

        packages.deployer = import nixus {
          nixpkgs = nixpkgs;
          deploySystem = system;
        } {
          options.defaults = nixpkgs.lib.mkOption {
            type = nixpkgs.lib.types.submodule {
              options.configuration = nixpkgs.lib.mkOption {
                type = nixpkgs.lib.types.submoduleWith {
                  specialArgs.unstable = unstable;
                  modules = [];
                };
              };
            };
          };

          config = {
            defaults = {name, lib, ...}: {
              inherit nixpkgs;
            };

            nodes = {
              test = {
                host = "root@localhost";
                configuration.imports = [
                  common.nixosModules.server
                  ./configurations/etcd.nix
                ];
              };
            };
          };

          # imports = [ ./deploy.nix ];
        };

        apps.default = flake-utils.lib.mkApp {
          drv = self.packages.${system}.deployer;
          exePath = "";
        };
      }
    ) // {
      # individual host configurations
      nixosConfigurations = {
        # lightweight base server-image
        image = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./configurations/image.nix
          ];
        };
      };
    };
}

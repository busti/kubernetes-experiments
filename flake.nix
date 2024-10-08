{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-24.05";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    common.url = "git+file:///home/busti/projects/os-common";
    nixus.url = "github:infinisil/nixus";
  };

  outputs = inputs @ { self, nixpkgs, unstable, flake-utils, common, nixus, ... }:
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

        make-default-image = pkgs.writeShellScriptBin "make-default-image" ''
          nix build -o images/default .#nixosConfigurations.image_default.config.system.build.qcow2
        '';

        make-router-image = pkgs.writeShellScriptBin "make-router-image" ''
          nix build -o images/router .#nixosConfigurations.image_router.config.system.build.qcow2
        '';

        connect = pkgs.writeShellScriptBin "connect" ''
          until ssh -o StrictHostKeyChecking=no nixos@test.k8s.host; do
            sleep 1
          done
        '';

        rebuild = pkgs.writeShellScriptBin "rebuild" ''
          terraform destroy --auto-approve
          terraform apply --auto-approve
          # connect
        '';

      in {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            terraform libxslt cdrtools
            make-default-image make-router-image connect rebuild
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
                  ./configurations/default.nix
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
        image_default = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs };
          modules = [
            ./configurations/image_default.nix
          ];
        };

        image_router = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs };
          modules = [
            ./configurations/image_router.nix
          ];
        };
      };
    };
}

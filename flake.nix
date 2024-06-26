{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }: 
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
      in {
        devShells.default = pkgs.mkShell rec {
          nativeBuildInputs = with pkgs; [
            terraform
          ];
        };
      }
    );
}

{ config, lib, pkgs, ... }: {
  imports = [ ./boot.nix ];
  system.stateVersion = "24.05";
}
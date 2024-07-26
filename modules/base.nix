{ config, lib, pkgs, ... }: {
  imports = [ ./boot.nix ];
  system.stateVersion = "24.05";

  # prevent nixos from creating a read-only /etc/hostname file
  networking.hostName = "";
}
{ config, lib, pkgs, ... }: {
  imports = [ ./boot.nix ];
  system.stateVersion = "24.05";

  # prevent nixos from creating a read-only /etc/hostname file
  networking.hostName = "";

  users.users.test = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    initialPassword = "changeme";
  };

  security.sudo.wheelNeedsPassword = false;

  services = {
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "prohibit-password";
      };
    };
  };
}
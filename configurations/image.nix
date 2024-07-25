{ config, lib, pkgs, modulesPath, ... }: {
  imports = [
    ../modules/base.nix
  ];

  environment.systemPackages = with pkgs; [
    cloud-init
  ];

  system.build.qcow2 = import "${modulesPath}/../lib/make-disk-image.nix" {
    inherit lib config pkgs;
    # diskSize = 10240;
    format = "qcow2";
    partitionTableType = "hybrid";
    # postVM = "mv $out/nixos.qcow2 $out/test.qcow2";
  };

  users.users.nixos = {
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

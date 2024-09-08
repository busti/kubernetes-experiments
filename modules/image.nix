{ config, lib, pkgs, modulesPath, ... }: {
  environment.systemPackages = with pkgs; [
    cloud-init
  ];

  system.build.qcow2 = import "${modulesPath}/../lib/make-disk-image.nix" {
    inherit lib config pkgs;
    format = "qcow2";
    partitionTableType = "hybrid";
  };

  # we only need cloud-init for the first boot. After switching the VM for the first time it can disappear.
  services.cloud-init.enable = true;
}
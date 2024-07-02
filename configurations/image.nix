{ config, lib, pkgs, modulesPath, ... }: {
  imports = [
    "${toString modulesPath}/profiles/qemu-guest.nix"
    ../modules/base.nix
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    autoResize = true;
    fsType = "ext4";
  };

  boot.kernelParams = [ "console=ttyS0" ];
  boot.loader.grub.device = lib.mkDefault "/dev/vda";

  system.build.qcow2 = import "${modulesPath}/../lib/make-disk-image.nix" {
    inherit lib config pkgs;
    # diskSize = 10240;
    format = "qcow2";
    partitionTableType = "hybrid";
    # postVM = "mv $out/nixos.qcow2 $out/test.qcow2";
  };
}

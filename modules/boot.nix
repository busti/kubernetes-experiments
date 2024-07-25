{ modulesPath, ... }: {
  imports = [
    "${toString modulesPath}/profiles/qemu-guest.nix"
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    autoResize = true;
  };

  boot.growPartition = true;
  boot.kernelParams = [ "console=ttyS0" ];
  boot.loader.grub.device = "/dev/vda";
  boot.loader.timeout = 1;

  services.qemuGuest.enable = true;
  services.cloud-init.enable = true;
}
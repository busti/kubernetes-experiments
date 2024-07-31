terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7.6"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

resource "libvirt_network" "k8s" {
  name   = "k8s"
  mode   = "nat"
  domain = "k8s.local"
  addresses = ["10.42.0.0/24", "fd00::1/64"]

  dns {
    enabled = true
  }
}

resource "libvirt_cloudinit_disk" "commoninit" {
  name = "commoninit.iso"
  user_data = <<-EOF
    #cloud-config
    users:
    - name: 'nixos'
      plain_text_passwd: 'changeme'
      ssh_authorized_keys:
      - '${file("~/.ssh/id_ed25519.pub")}'
    hostname: test.k8s.local
    fqdn: test.k8s.local
    power_state: # reboot to apply hostname
      mode: reboot
      message: Bye Bye
      timeout: 30
      condition: True
  EOF
}

resource "null_resource" "generate_boot" {
  provisioner "local-exec" {
    command = "make-boot-image"
  }

  triggers = {
    qcow_image = fileexists("result/nixos.qcow2")
  }
}

resource "libvirt_volume" "boot" {
  name = "boot"
  source = null_resource.generate_boot.triggers.qcow_image ? "result/nixos.qcow2" : ""
}

resource "libvirt_volume" "main" {
  name           = "main"
  base_volume_id = libvirt_volume.boot.id
  size           = 10737418240
}

resource "libvirt_domain" "test" {
  name = "test.k8s.local"
  memory = 1024

  disk {
    volume_id = libvirt_volume.main.id
  }

  network_interface {
    network_id = libvirt_network.k8s.id
  }

  cloudinit = libvirt_cloudinit_disk.commoninit.id
}
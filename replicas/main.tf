terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7.6"
    }
  }
}

variable "name" {
  type = string
  description = "Name for the machine and related resources"
}

variable "boot_volume_id" {
  type = string
  description = "Boot Image Resource"
}

variable "network_id" {
  type = string
  description = "Libvirt network to attach the machines to"
}

resource "libvirt_cloudinit_disk" "commoninit" {
  name = "cloudinit_${var.name}.iso"
  user_data = <<-EOF
    #cloud-config
    users:
    - name: 'nixos'
      plain_text_passwd: 'changeme'
      ssh_authorized_keys:
      - '${file("~/.ssh/id_ed25519.pub")}'
    hostname: ${var.name}
    fqdn: ${var.name}.k8s.host
    power_state: # reboot to apply hostname
      mode: reboot
      message: Bye Bye
      timeout: 30
      condition: True
  EOF
}

resource "libvirt_volume" "runtime" {
  name           = var.name
  base_volume_id = var.boot_volume_id
  size           = 10737418240 # 10GB
}

resource "libvirt_domain" "node" {
  name = var.name
  memory = 1024

  disk {
    volume_id = libvirt_volume.runtime.id
  }

  network_interface {
    network_id = var.network_id
  }

  cloudinit = libvirt_cloudinit_disk.commoninit.id
}
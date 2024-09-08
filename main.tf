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
  mode   = "none"
}

resource "null_resource" "generate_default" {
  provisioner "local-exec" {
    command = "make-default-image"
  }

  triggers = {
    qcow_image = fileexists("images/default/nixos.qcow2")
  }
}

resource "null_resource" "generate_router" {
  provisioner "local-exec" {
    command = "make-router-image"
  }

  triggers = {
    qcow_image = fileexists("images/router/nixos.qcow2")
  }
}

resource "libvirt_volume" "default" {
  name = "default"
  source = null_resource.generate_default.triggers.qcow_image ? "images/default/nixos.qcow2" : ""
}

resource "libvirt_volume" "router" {
  name = "router"
  source = null_resource.generate_router.triggers.qcow_image ? "images/router/nixos.qcow2" : ""
}

module "replicas" {
  source = "./replicas"

  for_each = toset(["c1"])

  name           = each.key
  boot_volume_id = libvirt_volume.default.id
  network_id     = libvirt_network.k8s.id
}

module "router" {
  source = "./replicas"

  name = "router"
  boot_volume_id = libvirt_volume.router.id
  network_id = libvirt_network.k8s.id
}
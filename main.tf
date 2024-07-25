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
  addresses = ["10.42.0.0/24"]

  dns {
    enabled = true
  }

  xml {
    # By default, DHCP range is the whole subnet.
    # We will eventually want virtual IPs, so try to make space for them.
    # XSLT (I have no idea what I'm doing),
    # because of https://github.com/dmacvicar/terraform-provider-libvirt/issues/794
    xslt = <<EOF
      <?xml version="1.0" ?>
      <xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
        <xsl:output omit-xml-declaration="yes" indent="yes"/>
        <xsl:template match="node()|@*">
           <xsl:copy>
             <xsl:apply-templates select="node()|@*"/>
           </xsl:copy>
        </xsl:template>

        <xsl:template match="/network/ip/dhcp/range">
          <xsl:copy>
            <xsl:attribute name="start">10.42.0.100</xsl:attribute>
            <xsl:apply-templates select="@*[not(local-name()='start')]|node()"/>
          </xsl:copy>
        </xsl:template>
      </xsl:stylesheet>
    EOF
  }
}

resource "libvirt_cloudinit_disk" "commoninit" {
  name = "commoninit.iso"
    user_data = <<EOF
#cloud-config
users:
- name: 'nixos'
  plain_text_passwd: 'changeme'
  ssh_authorized_keys:
  - '${file("~/.ssh/id_ed25519.pub")}'
runcmd:
  - echo '2' > /var/tmp/hello-world.txt
hostname: test
fqdn: test.k8s.local
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
  name = "test"
  memory = 1024

  disk {
    volume_id = libvirt_volume.main.id
  }

  network_interface {
    network_id = libvirt_network.k8s.id
  }

  cloudinit = libvirt_cloudinit_disk.commoninit.id
}
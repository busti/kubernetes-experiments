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
  addresses = ["10.69.0.0/24"]

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
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output omit-xml-declaration="yes" indent="yes"/>
  <xsl:template match="node()|@*">
     <xsl:copy>
       <xsl:apply-templates select="node()|@*"/>
     </xsl:copy>
  </xsl:template>

  <xsl:template match="/network/ip/dhcp/range">
    <xsl:copy>
      <xsl:attribute name="start">10.240.0.100</xsl:attribute>
      <xsl:apply-templates select="@*[not(local-name()='start')]|node()"/>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>
EOF
  }
}

resource "libvirt_domain" "terraform_test" {
  name = "terraform_test"
}
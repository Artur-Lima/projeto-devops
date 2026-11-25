locals {
  compartment_id = var.compartment_ocid != "" ? var.compartment_ocid : var.tenancy_ocid
}

# Rede privada virtual da aplicação
resource "oci_core_vcn" "vcn" {
  compartment_id = local.compartment_id
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "${var.nome}-vcn"
  dns_label      = "devops"
}

# Saída/entrada para a internet
resource "oci_core_internet_gateway" "igw" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "${var.nome}-igw"
  enabled        = true
}

resource "oci_core_route_table" "publica" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "${var.nome}-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

# Firewall da nuvem: só as portas que a stack usa
resource "oci_core_security_list" "web" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "${var.nome}-sl"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # ICMP (ping e path MTU discovery)
  ingress_security_rules {
    protocol = "1"
    source   = "0.0.0.0/0"
  }

  dynamic "ingress_security_rules" {
    for_each = var.portas_entrada
    content {
      protocol = "6" # TCP
      source   = ingress_security_rules.value == 22 ? var.origem_ssh : "0.0.0.0/0"
      tcp_options {
        min = ingress_security_rules.value
        max = ingress_security_rules.value
      }
    }
  }
}

resource "oci_core_subnet" "publica" {
  compartment_id    = local.compartment_id
  vcn_id            = oci_core_vcn.vcn.id
  cidr_block        = "10.0.1.0/24"
  display_name      = "${var.nome}-subnet"
  dns_label         = "publica"
  route_table_id    = oci_core_route_table.publica.id
  security_list_ids = [oci_core_security_list.web.id]
}

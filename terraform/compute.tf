data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# Imagem mais recente do sistema escolhido, compatível com o shape
data "oci_core_images" "sistema" {
  compartment_id           = local.compartment_id
  operating_system         = var.sistema
  operating_system_version = var.versao_sistema
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance" "vm" {
  compartment_id      = local.compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "${var.nome}-vm"
  shape               = var.shape

  # Shapes Flex precisam de CPU/memória explícitas; shapes fixos não aceitam o bloco
  dynamic "shape_config" {
    for_each = strcontains(var.shape, "Flex") ? [1] : []
    content {
      ocpus         = var.ocpus
      memory_in_gbs = var.memoria_gb
    }
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.publica.id
    assign_public_ip = true
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.sistema.images[0].id
  }

  metadata = {
    ssh_authorized_keys = trimspace(file(pathexpand(var.ssh_public_key_path)))
  }

  # Uma imagem mais nova publicada depois não deve recriar a VM
  lifecycle {
    ignore_changes = [source_details]
  }
}

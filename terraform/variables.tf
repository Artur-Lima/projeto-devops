# ---------- Autenticação na OCI (Perfil → API keys) ----------
variable "tenancy_ocid" {
  description = "OCID do tenancy"
  type        = string
}

variable "user_ocid" {
  description = "OCID do usuário dono da API key"
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint da API key"
  type        = string
}

variable "private_key_path" {
  description = "Caminho da chave privada da API key (.pem) — nunca versionar"
  type        = string
}

variable "region" {
  description = "Região da OCI"
  type        = string
  default     = "sa-saopaulo-1"
}

variable "compartment_ocid" {
  description = "Compartimento onde os recursos serão criados (vazio = raiz do tenancy)"
  type        = string
  default     = ""
}

# ---------- Acesso SSH à VM ----------
variable "ssh_public_key_path" {
  description = "Chave pública instalada na VM"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_private_key_path" {
  description = "Chave privada correspondente, gravada no inventário do Ansible"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

# ---------- VM ----------
variable "nome" {
  description = "Prefixo dos nomes dos recursos"
  type        = string
  default     = "projeto-devops"
}

variable "shape" {
  description = "Shape da VM. A1.Flex (ARM) e E2.1.Micro (AMD) são Always Free"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "ocpus" {
  description = "OCPUs (só para shapes Flex)"
  type        = number
  default     = 1
}

variable "memoria_gb" {
  description = "Memória em GB (só para shapes Flex)"
  type        = number
  default     = 6
}

variable "sistema" {
  description = "Sistema operacional da imagem"
  type        = string
  default     = "Oracle Linux"

  validation {
    condition     = contains(["Oracle Linux", "Canonical Ubuntu"], var.sistema)
    error_message = "Use \"Oracle Linux\" ou \"Canonical Ubuntu\" (os dois são suportados pelo Ansible)."
  }
}

variable "versao_sistema" {
  description = "Versão do sistema (Oracle Linux: 8 ou 9 | Ubuntu: 22.04 ou 24.04)"
  type        = string
  default     = "9"
}

# ---------- Rede ----------
variable "portas_entrada" {
  description = "Portas TCP liberadas na security list: SSH, HTTP, HTTPS e Uptime Kuma"
  type        = list(number)
  default     = [22, 80, 443, 3001]
}

variable "origem_ssh" {
  description = "CIDR autorizado a acessar o SSH (restrinja ao seu IP: x.x.x.x/32)"
  type        = string
  default     = "0.0.0.0/0"
}

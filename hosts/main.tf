terraform {
  required_version = ">= 0.13"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.9.8"
    }
  }
}

provider "libvirt" {
  uri = var.libvirt_uri
}

module "vm" {
  source = "../modules/vm"

  name              = var.name
  memory            = var.memory
  vcpu              = var.vcpu
  autostart         = var.autostart
  pool              = var.pool
  pool_target_path  = var.pool_target_path
  base_volume_name  = var.base_volume_name
  disk_size         = var.disk_size
  disk_size_unit    = var.disk_size_unit
  mac_address       = var.mac_address
  macvtap_interface = var.macvtap_interface
  network_name      = var.network_name
  data_disk_devices = var.data_disk_devices
  nested_virt       = var.nested_virt
}

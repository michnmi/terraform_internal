variable "libvirt_uri" {
  type        = string
  description = "Libvirt connection URI (e.g. qemu+ssh://user@host/system)"
}

variable "name" {
  type        = string
  description = "VM name (used for domain and volume)"
}

variable "memory" {
  type        = number
  default     = 1024
  description = "RAM in MiB"
}

variable "vcpu" {
  type    = number
  default = 2
}

variable "autostart" {
  type    = bool
  default = true
}

variable "pool" {
  type        = string
  description = "Libvirt storage pool name"
}

variable "pool_target_path" {
  type        = string
  description = "Filesystem path where the libvirt pool stores volumes"
}

variable "base_volume_name" {
  type        = string
  description = "Filename of the base qcow2 image within pool_target_path"
}

variable "disk_size" {
  type        = number
  default     = 20
  description = "VM disk size — must be >= base image virtual size"
}

variable "disk_size_unit" {
  type    = string
  default = "GiB"
}

variable "mac_address" {
  type        = string
  description = "MAC address for macvtap interface (lowercase — maps to static DHCP on Mikrotik)"
}

variable "macvtap_interface" {
  type    = string
  default = "enp0s25"
}

variable "network_name" {
  type    = string
  default = "default"
}

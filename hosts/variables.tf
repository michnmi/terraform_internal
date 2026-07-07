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
  type        = string
  default     = "default"
  description = "Libvirt network name for secondary interface"
}

variable "data_disk_device" {
  type        = string
  default     = ""
  description = "Path to a pre-existing raw block device (e.g. ZFS zvol) for a second disk. Leave empty for VMs with no external data disk."
}

variable "nested_virt" {
  type        = bool
  default     = false
  description = "Expose host CPU virtualization features (vmx/svm) to the guest. Required for VMs that themselves run KVM/QEMU (e.g. a Packer/QEMU build VM)."
}

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
  description = "Libvirt storage pool for the VM disk"
}

variable "disk_size" {
  type        = number
  default     = 20
  description = "VM disk size. Must be >= the virtual size of the base image (check with: qemu-img info --force-share <base.qcow2> | grep 'virtual size')"
}

variable "disk_size_unit" {
  type        = string
  default     = "GiB"
  description = "Unit for disk_size (KiB, MiB, GiB, TiB)"
}

variable "pool_target_path" {
  type        = string
  description = "Filesystem path where the libvirt pool stores volumes. Find it with: virsh pool-dumpxml <pool> | grep '<path>'"
}

variable "base_volume_name" {
  type        = string
  description = "Filename of the base qcow2 image within pool_target_path (e.g. docker-base.qcow2)"
}

variable "mac_address" {
  type        = string
  description = "MAC address for the macvtap interface (maps to static DHCP lease on Mikrotik)"
}

variable "macvtap_interface" {
  type        = string
  default     = "enp0s25"
  description = "Physical host NIC to attach macvtap to"
}

variable "network_name" {
  type        = string
  description = "Libvirt network name for the secondary interface (e.g. default)"
  default     = "default"
}

variable "data_disk_device" {
  type        = string
  default     = ""
  description = "Path to a pre-existing raw block device (e.g. a ZFS zvol under /dev/zvol/...) to attach as a second disk. Leave empty for VMs with no external data disk. Terraform does not create this device — it must already exist on the host."
}

variable "nested_virt" {
  type        = bool
  default     = false
  description = "Expose host CPU virtualization features (vmx/svm) to the guest via cpu mode=host-passthrough. Required for VMs that themselves run KVM/QEMU (e.g. a Packer/QEMU build VM). Also requires nested virtualization enabled on the physical host's kvm_intel/kvm_amd module."
}

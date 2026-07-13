terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}

resource "libvirt_volume" "this" {
  name          = "${var.name}.qcow2"
  pool          = var.pool
  capacity      = var.disk_size
  capacity_unit = var.disk_size_unit

  backing_store = {
    path = "${var.pool_target_path}/${var.base_volume_name}"
    format = {
      type = "qcow2"
    }
  }

  target = {
    format = {
      type = "qcow2"
    }
  }
}

locals {
  # vda is the qcow2 boot disk; additional data disks take vdb, vdc, vdd, ...
  data_disk_letters = ["b", "c", "d", "e", "f", "g", "h", "i"]

  disks = concat(
    [
      {
        driver = {
          name = "qemu"
          type = "qcow2"
        }
        source = {
          file = {
            file = libvirt_volume.this.path
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
      }
    ],
    [
      for index, device in var.data_disk_devices : {
        driver = {
          name  = "qemu"
          type  = "raw"
          cache = "none"
          io    = "native"
        }
        source = {
          block = {
            dev = device
          }
        }
        target = {
          dev = "vd${local.data_disk_letters[index]}"
          bus = "virtio"
        }
      }
    ]
  )
}

resource "libvirt_domain" "this" {
  name        = var.name
  type        = "kvm"
  memory      = var.memory
  memory_unit = "MiB"
  vcpu        = var.vcpu
  autostart   = var.autostart
  running     = true

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "pc"
  }

  cpu = var.nested_virt ? {
    mode = "host-passthrough"
  } : null

  devices = {
    disks = local.disks

    interfaces = [
      {
        model = { type = "virtio" }
        mac   = { address = var.mac_address }
        source = {
          direct = {
            dev  = var.macvtap_interface
            mode = "bridge"
          }
        }
      },
      {
        model = { type = "virtio" }
        source = {
          network = {
            network = var.network_name
          }
        }
      }
    ]

    serial = [
      {
        type = "pty"
      }
    ]

    consoles = [
      {
        type = "pty"
        target = {
          type = "serial"
          port = 0
        }
      }
    ]
  }
}

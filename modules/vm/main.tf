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

resource "libvirt_domain" "this" {
  name        = var.name
  type        = "kvm"
  memory      = var.memory
  memory_unit = "MiB"
  vcpu        = var.vcpu
  autostart = var.autostart
  running   = true

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "pc"
  }

  devices = {
    disks = [
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
    ]

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

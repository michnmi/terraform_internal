# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Single Terraform repository managing KVM/libvirt VMs across multiple physical hosts, replacing multiple scattered per-VM repos. Provider: `dmacvicar/libvirt` v0.9.8.

**Goal**: Jenkins runs one job per VM. Each job checks out this repo, supplies VM-specific variables as job parameters, and runs `terraform apply` from the `hosts/` directory. No hostnames, credentials, or VM-specific values are hardcoded in the codebase.

## Repository Structure

```
hosts/           # Single Terraform root — provider and module wired to variables
  main.tf        # provider "libvirt" uses var.libvirt_uri; calls modules/vm
  variables.tf   # all variables including libvirt_uri
  backend.tf     # local backend — path supplied at terraform init time
modules/vm/      # Reusable VM module (libvirt_volume + libvirt_domain)
Jenkinsfile      # Declarative pipeline — one job per VM, parameters-driven
```

## Architecture Decisions

- **Single `hosts/` root** — originally designed as one directory per host (`hosts/vmhost01/`, `hosts/vmhost03/`), then merged into one since the code is identical once the provider URI is a variable. Environment is determined entirely by runtime values.
- **No hostnames in code** — the libvirt connection URI is `var.libvirt_uri`, supplied by Jenkins from the credentials store. The directory structure and HCL contain no references to actual host names.
- **No VM definitions in code** — VMs are not hardcoded as module blocks. One generic `module "vm"` block passes all variables through. Adding a VM means adding a Jenkins job, not editing HCL.
- **Scheduled jobs in Jenkins, not this repo** — scheduled/recurring VM jobs are configured in Jenkins directly using the Parameterized Scheduler plugin and exported to the separate Jenkins XML repo. No scheduler Jenkinsfiles live here.

## CI/CD Design

- **One Jenkins job per VM** — same codebase, different parameter values per run
- **Two environments**: test and prod — distinguished only by the `libvirt_uri` credential and the state file path prefix
- **State**: local backend stored on an NFS share mounted by the Jenkins master; each VM gets its own `.tfstate` file identified by `<env>/<vm_name>.tfstate`

### Jenkins prerequisites

**Credentials** (Manage Jenkins → Credentials → Secret Text / SSH):

| ID | Type | Value |
|---|---|---|
| `test-libvirt-uri` | Secret Text | `qemu+ssh://jenkins_automation@<test-host>/system` |
| `prod-libvirt-uri` | Secret Text | `qemu+ssh://jenkins_automation@<prod-host>/system` |
| `jenkins-automation-user` | SSH Username with private key | ed25519 private key for jenkins_automation |

**Global environment variable** (Manage Jenkins → System → Global properties):

| Name | Value |
|---|---|
| `TF_STATE_BASE_PATH` | NFS mount path where state files are stored (e.g. `/mnt/nfs/terraform-states`) |

**Known hosts**: the Jenkins user must have the libvirt host keys in `~/.ssh/known_hosts`. One-time setup on the Jenkins master:
```bash
sudo -u jenkins ssh-keyscan -H <test-host> >> /var/lib/jenkins/.ssh/known_hosts
sudo -u jenkins ssh-keyscan -H <prod-host> >> /var/lib/jenkins/.ssh/known_hosts
```

### How the Jenkinsfile works

- `TF_VAR_*` environment variables are set from job parameters in the `environment` block — Terraform picks these up automatically, no `-var` flags needed on commands
- `libvirt_uri` is assembled at runtime: base URI from Secret Text credential + keyfile path from `sshUserPrivateKey` binding → composed via `withEnv`
- The full URI passed to Terraform looks like: `qemu+ssh://jenkins_automation@<host>/system?keyfile=<tmp-path>`
- Jenkins automatically cleans up the temp key file when the `withCredentials` block exits
- `TF_LOG = 'INFO'` is set globally; change to `TRACE` temporarily when debugging provider connectivity

### Jenkins job flow (per VM)

```
Init   → terraform init -backend-config="path=<NFS>/<env>/<vm>.tfstate" -reconfigure
Plan   → terraform plan          (runs for action=plan or action=apply)
Apply  → terraform apply         (runs for action=apply only)
Destroy→ confirmation prompt, then terraform destroy (runs for action=destroy only)
```

### Parameter reference

| Parameter | Required for destroy? | Description |
|---|---|---|
| `ACTION` | yes | plan / apply / destroy |
| `ENVIRONMENT` | yes | test / prod |
| `VM_NAME` | yes | VM name |
| `POOL` | yes | Libvirt storage pool name |
| `MAC_ADDRESS` | plan/apply only | MAC for macvtap (must be lowercase) |
| `POOL_TARGET_PATH` | plan/apply only | Filesystem path where pool stores volumes |
| `BASE_VOLUME_NAME` | plan/apply only | Base qcow2 filename in pool |
| `MEMORY` | plan/apply only | RAM in MiB (default 1024) |
| `VCPU` | plan/apply only | vCPU count (default 2) |
| `DISK_SIZE` | plan/apply only | Disk size in GiB (default 20) |
| `MACVTAP_INTERFACE` | plan/apply only | Physical NIC for macvtap (default enp0s25) |
| `NETWORK_NAME` | plan/apply only | Secondary libvirt network (default default) |
| `DATA_DISK_DEVICE` | plan/apply only | Path to a pre-existing raw block device for a second disk (e.g. `/dev/zvol/data_disk/<vm>-volume`). Blank if the VM has no external data disk |

### Scheduling jobs

Scheduled/recurring VM jobs are configured in Jenkins using the **Parameterized Scheduler plugin** (not via Jenkinsfiles in this repo). Format:

```
0 6 * * 1-5 %ACTION=apply;ENVIRONMENT=test;VM_NAME=test-vm;POOL=test;MAC_ADDRESS=52:54:00:ea:17:01;POOL_TARGET_PATH=/vmhost_qcow/test;BASE_VOLUME_NAME=test-vm-base.qcow2;DISK_SIZE=24
```

Export the job XML and commit it to the separate Jenkins XML repo.

## Local Testing

Create a `hosts/test.tfvars` file (gitignored) with your values:

```hcl
libvirt_uri      = "qemu+ssh://user@<host>/system?keyfile=/path/to/key"
name             = "test-vm"
pool             = "test"
pool_target_path = "/vmhost_qcow/test"
base_volume_name = "test-vm-base.qcow2"
mac_address      = "52:54:00:ea:17:01"
disk_size        = 24
```

Then run from `hosts/`:
```bash
terraform init
terraform plan  -var-file=test.tfvars
terraform apply -var-file=test.tfvars
terraform destroy -var-file=test.tfvars
```

## Common Commands

```bash
# Format all .tf files (run from repo root)
terraform fmt -recursive
terraform validate
```

## Module Architecture

### `modules/vm/`

Defines one VM: a `libvirt_volume` (CoW clone from a base image via `backing_store`) and a `libvirt_domain` (KVM, x86_64, `pc` machine type).

**Networking**: two interfaces — macvtap on the physical NIC (MAC address maps to a static DHCP lease on the Mikrotik router) and a secondary libvirt network interface.

**Storage**: the volume clones from a base qcow2 via `backing_store.path`. libvirt v0.9.x has no data source for volumes, so the path is constructed from `pool_target_path` + `base_volume_name`. To find the correct path on a host:
```bash
virsh pool-dumpxml <pool-name> | grep '<path>'
virsh vol-list <pool-name>
```

**Optional second disk (`data_disk_device`)**: some VMs (e.g. `emby-test`/`emby-prod`) need an external data disk backed by a pre-existing raw block device (a ZFS zvol under `/dev/zvol/...`), separate from the qcow2 boot volume. Terraform does not create or manage this device — it must already exist on the host. When `data_disk_device` is non-empty, `modules/vm/main.tf` appends a second `disks` entry (`source.block.dev`, `driver = { type = "raw", cache = "none", io = "native" }`, `target.dev = "vdb"`) via a `local.disks` built with `concat()`; when empty, the VM gets only the single qcow2 boot disk. This replaces an older, pre-v0.9.x approach (from a standalone `emby-test` config predating this repo) that used an XSLT `xml` block to inject the raw disk into the domain XML because the `~>0.6` provider had no native block-device disk support — v0.9.8 supports it natively via `source.block`, so no XSLT hack is needed.

### `hosts/main.tf`

Declares the provider (URI from variable) and one `module "vm"` block that passes all variables through to `modules/vm`. This is the single Terraform root for all environments.

### Module variables (required)

| Variable | Description |
|---|---|
| `libvirt_uri` | Libvirt connection URI (e.g. `qemu+ssh://user@host/system?keyfile=/path/to/key`) |
| `name` | VM name — used for both domain and volume |
| `pool` | Libvirt storage pool name for the VM disk |
| `pool_target_path` | Filesystem path where the pool stores files |
| `base_volume_name` | Filename of the base qcow2 image (must already exist in the pool) |
| `mac_address` | MAC for macvtap interface (Mikrotik DHCP reservation) |

Defaults: `memory=1024` (MiB), `vcpu=2`, `autostart=true`, `disk_size=20` (GiB), `macvtap_interface="enp0s25"`, `network_name="default"`, `data_disk_device=""` (no second disk).

**MAC addresses must be lowercase** — libvirt normalizes them internally and the provider will produce a state inconsistency error if uppercase is used.

**`disk_size` must match or exceed the base image's virtual size** — if the overlay is smaller than the base, the GPT backup partition table falls outside the presented disk boundary and partitions become unreadable. Always verify with: `qemu-img info --force-share <base.qcow2> | grep 'virtual size'`

**`memory_unit = "MiB"` is required** — libvirt's default unit is KiB, so omitting it causes `memory = 1024` to be interpreted as 1 MiB instead of 1 GiB.

**Disk driver must be explicit** — without `driver = { name = "qemu", type = "qcow2" }` in the disk block, libvirt defaults to `raw` and cannot read the qcow2 backing store.

**Serial console requires guest configuration** — the base image needs `console=ttyS0` in the kernel cmdline and `serial-getty@ttyS0.service` enabled.

**No `memoryBacking access="shared"`** — the old standalone `emby-test` domain had this set (likely a leftover test-only artifact), but `emby-prod` never had it and it was deliberately not carried into this module. Don't add it when porting other legacy per-VM configs unless there's a specific reason (e.g. vhost-user/shared-memory device support).

## Status

- `modules/vm/` end-to-end validated: `terraform apply` creates and boots the VM, `virsh console` works, `terraform destroy` cleanly removes it.
- `hosts/` single-root structure implemented and working.
- `Jenkinsfile` implemented and tested: plan/apply/destroy all working via Jenkins parameterized job.
- Scheduled jobs: handled via Parameterized Scheduler plugin in Jenkins, not in this repo.

## NFS State Backend Notes

The `local` backend with a path on NFS works correctly. The main consideration is file locking — NFSv4 has reliable built-in locking; NFSv3 uses a separate NLM daemon which can be less reliable. Since each VM has its own state file and runs its own Jenkins job, concurrent access to the same state file is not expected, making locking a low risk. If stale lock issues arise, add `-lock=false` to the terraform commands.

## v0.9.x Breaking Changes from v0.8.x

Already accounted for in this module:
- `libvirt_volume`: `base_volume_name`, `base_volume_pool`, `format` are gone → use `backing_store { path, format { type } }` + `target { format { type } }` + explicit `capacity`
- `libvirt_domain`: `type = "kvm"` is now required; `network_interface`, `disk`, `console` blocks are gone → everything is under `devices = { interfaces = [...], disks = [...], consoles = [...] }`
- Macvtap: was `macvtap = "enp0s25"` → now `source = { direct = { dev = "enp0s25", mode = "bridge" } }`
- No `libvirt_volume` data source exists in v0.9.x — volume paths must be provided explicitly

# Kestra Flows Repository

Organized collection of Kestra workflow templates.

## Structure

```
kestra-flows/
├── proxmox/
│   ├── README.md                    # Proxmox flows overview
│   ├── TEMPLATE_USAGE_GUIDE.md      # Detailed usage guide
│   ├── proxmox-vm-from-template.yml # Basic VM clone flow
│   └── proxmox-vm-cloudinit.yml     # Cloud-init VM flow
└── (future flows...)
```

## Quick Start

### 1. Prerequisites
- Kestra running (e.g., at `http://172.22.95.179:8080`)
- Proxmox VE with API access
- Proxmox template VM prepared

### 2. Install Proxmox Plugin
```bash
# In Kestra UI: Administration → Plugins → Install
# Search: io.kestra.plugin.proxmox
# Or via config: KESTRA_PLUGINS="io.kestra.plugin.proxmox:proxmox-plugin"
```

### 3. Import Flows
```bash
# Via Kestra UI
# Flows → Import → Upload YAML → Select file

# Via API
curl -X POST http://172.22.95.179:8080/api/v1/flows/import \
  -F "file=@kestra-flows/proxmox/proxmox-vm-cloudinit.yml"
```

### 4. Execute Flow
```bash
# Via UI: Flows → Select flow → Execute → Fill inputs → Execute

# Via API
curl -X POST http://172.22.95.179:8080/api/v1/executions/proxmox-vm-cloudinit \
  -H "Content-Type: application/json" \
  -d @inputs.json
```

## Flow Selection Guide

| Need | Use This Flow |
|------|---------------|
| Simple clone of pre-configured VM | `proxmox-vm-from-template.yml` |
| Dynamic config (SSH keys, IP, DNS) | `proxmox-vm-cloudinit.yml` |
| First time / testing | `proxmox-vm-from-template.yml` |
| Production / automation | `proxmox-vm-cloudinit.yml` |

## Inputs Quick Reference

### Basic Flow (7 required, 3 optional)
```json
{
  "proxmox_host": "https://pve.example.com:8006",
  "proxmox_user": "root@pam",
  "proxmox_password": "password",
  "proxmox_node": "pve-node1",
  "template_vmid": "9000",
  "new_vmid": "1001",
  "vm_name": "my-vm"
}
```

### Cloud-Init Flow (8 required, 9 optional)
```json
{
  "proxmox_host": "https://pve.example.com:8006",
  "proxmox_user": "root@pam",
  "proxmox_password": "password",
  "proxmox_node": "pve-node1",
  "template_vmid": "9000",
  "new_vmid": "1001",
  "vm_name": "my-vm",
  "ssh_public_key": "ssh-rsa AAAAB3... user@host"
}
```

## Proxmox Template Setup

### Basic Template
```bash
# 1. Create VM, install OS, configure
# 2. Install guest agent
apt install qemu-guest-agent && systemctl enable qemu-guest-agent
# 3. Shutdown & convert
qm shutdown <vmid> && qm template <vmid>
```

### Cloud-Init Template
```bash
# 1. Download cloud image
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

# 2. Create & configure VM
qm create 9000 --name ubuntu-2204-cloudinit --memory 2048 --net0 virtio,bridge=vmbr0
qm importdisk 9000 jammy-server-cloudimg-amd64.img local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --serial0 socket --vga serial0
qm set 9000 --agent enabled=1

# 3. Cloud-init defaults
qm set 9000 --ciuser ubuntu --cipassword ubuntu --sshkeys ~/.ssh/id_rsa.pub
qm set 9000 --ipconfig0 ip=dhcp

# 4. Convert to template
qm template 9000
```

## Security Best Practices

1. **Use API Tokens** (not passwords):
   ```bash
   pveum user token add kestra@pam kestra-token -privsep 0
   # user: "kestra@pam!kestra-token", password: "token-value"
   ```

2. **Minimal Permissions** - Create dedicated role:
   ```bash
   pveum role add KestraVM -privs "VM.Clone VM.Config.Disk VM.Config.CPU VM.Config.Memory VM.Config.Network VM.Config.Options VM.PowerMgmt Datastore.Allocate"
   pveum user add kestra@pam -password "secure-pass"
   pveum aclmod / -user kestra@pam -role KestraVM
   ```

3. **Store Secrets in Kestra** - Use Kestra's secret management

## Documentation

- `proxmox/README.md` - Overview & quick reference
- `proxmox/TEMPLATE_USAGE_GUIDE.md` - Complete usage guide with all details

## Support

- Kestra Docs: https://kestra.io/docs
- Proxmox API: https://pve.proxmox.com/wiki/Proxmox_VE_API
- Plugin: https://github.com/kestra-io/plugins/tree/master/proxmox
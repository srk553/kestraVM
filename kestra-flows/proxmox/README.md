# Kestra Proxmox VM Templates

Two Kestra flows for creating VMs in Proxmox by cloning templates.

## Prerequisites

1. **Proxmox VE** with API access
2. **Kestra** with Proxmox plugin installed
3. **Template VM** in Proxmox (for basic template) or **Cloud-Init enabled template** (for cloud-init template)

## Template 1: Basic Clone (`proxmox-vm-from-template.yml`)

Simple VM clone from template with basic configuration.

### Required Inputs
| Input | Description | Example |
|-------|-------------|---------|
| `proxmox_host` | Proxmox API URL | `https://proxmox.example.com:8006` |
| `proxmox_user` | API user | `root@pam` |
| `proxmox_password` | API password/token | `your-password` |
| `proxmox_node` | Source node | `pve-node1` |
| `template_vmid` | Template VMID | `9000` |
| `new_vmid` | New VMID (unique) | `1001` |
| `vm_name` | VM name | `web-server-01` |

### Optional Inputs
| Input | Default | Description |
|-------|---------|-------------|
| `target_node` | same as source | Target node for clone |
| `full_clone` | `true` | Full vs linked clone |
| `start_vm` | `true` | Auto-start after creation |

---

## Template 2: Cloud-Init (`proxmox-vm-cloudinit.yml`)

Advanced VM creation with cloud-init configuration (SSH keys, network, user).

### Required Inputs
| Input | Description | Example |
|-------|-------------|---------|
| `proxmox_host` | Proxmox API URL | `https://proxmox.example.com:8006` |
| `proxmox_user` | API user or token | `root@pam` or `kestra@pam!token1` |
| `proxmox_password` | Password or token secret | `your-secret` |
| `proxmox_node` | Source node | `pve-node1` |
| `template_vmid` | Cloud-init template VMID | `9000` |
| `new_vmid` | New VMID | `1001` |
| `vm_name` | VM name | `k8s-worker-01` |
| `ssh_public_key` | SSH public key | `ssh-rsa AAAAB3... user@host` |

### Optional Inputs
| Input | Default | Description |
|-------|---------|-------------|
| `ci_user` | `ubuntu` | Cloud-init username |
| `ci_password` | (none) | Cloud-init password |
| `ip_config` | `ip=dhcp` | Network config |
| `dns_servers` | `8.8.8.8,1.1.1.1` | DNS servers |
| `memory_mb` | `4096` | RAM in MB |
| `cores` | `2` | CPU cores |
| `disk_size_gb` | `32` | Disk size |
| `storage` | `local-lvm` | Storage pool |
| `bridge` | `vmbr0` | Network bridge |
| `start_vm` | `true` | Auto-start |

---

## Proxmox Template Preparation

### For Basic Template
1. Create VM with desired OS
2. Install packages, configure
3. Shutdown VM
4. **Convert to Template** (right-click → Convert to Template)

### For Cloud-Init Template
1. Create VM with cloud-init enabled OS (Ubuntu Cloud Image, etc.)
2. Install `qemu-guest-agent`
3. Configure cloud-init in `/etc/cloud/cloud.cfg`
4. Shutdown VM
5. **Convert to Template**
6. Ensure template has:
   - Cloud-Init drive (IDE2)
   - Serial console for guest agent
   - QEMU Guest Agent enabled

---

## Usage in Kestra

### 1. Import Flow
```bash
# Via Kestra UI: Flows → Import → Upload YAML
# Or via API:
curl -X POST http://kestra:8080/api/v1/flows/import \
  -F "file=@proxmox-vm-cloudinit.yml"
```

### 2. Execute Flow
```bash
# Via Kestra UI: Execute → Fill inputs → Execute
# Or via API:
curl -X POST http://kestra:8080/api/v1/executions/proxmox-vm-cloudinit \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": {
      "proxmox_host": "https://pve.example.com:8006",
      "proxmox_user": "root@pam",
      "proxmox_password": "secret",
      "proxmox_node": "pve-node1",
      "template_vmid": "9000",
      "new_vmid": "1001",
      "vm_name": "my-vm",
      "ssh_public_key": "ssh-rsa AAAAB3NzaC1yc2E... user@host"
    }
  }'
```

### 3. Using API Token (Recommended)
Instead of password, use Proxmox API tokens:
1. Create token: `pveum user token add root@pam kestra -privsep 0`
2. Use: `proxmox_user: "root@pam!kestra"` and `proxmox_password: "token-value"`

---

## Example: Ubuntu Cloud Image Template

```bash
# Download Ubuntu cloud image
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

# Create VM
qm create 9000 --name ubuntu-2204-template --memory 2048 --net0 virtio,bridge=vmbr0

# Import disk
qm importdisk 9000 jammy-server-cloudimg-amd64.img local-lvm

# Configure
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --serial0 socket --vga serial0
qm set 9000 --agent enabled=1

# Cloud-init defaults
qm set 9000 --ciuser ubuntu --cipassword ubuntu --sshkeys ~/.ssh/id_rsa.pub
qm set 9000 --ipconfig0 ip=dhcp

# Convert to template
qm template 9000
```

---

## Kestra Plugin Installation

Add to your Kestra Docker compose or configuration:

```yaml
# docker-compose.yml
services:
  kestra:
    image: kestra/kestra:latest
    # ... other config
    environment:
      KESTRA_PLUGINS: "io.kestra.plugin.proxmox:proxmox-plugin"
```

Or install via Kestra UI: Administration → Plugins → Install `io.kestra.plugin.proxmox`

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Auth failed | Check user/token permissions in Proxmox (Datastore.Allocate, VM.Clone, VM.Config) |
| Template not found | Verify template_vmid exists and is a template |
| VMID conflict | Use unique new_vmid |
| Cloud-init not working | Ensure template has cloud-init drive (ide2) and guest agent |
| Network not configured | Check bridge name matches Proxmox config |
| Timeout waiting for IP | Increase timeout, check DHCP on bridge |

---

## Files in this Directory

- `proxmox-vm-from-template.yml` - Basic clone flow
- `proxmox-vm-cloudinit.yml` - Advanced cloud-init flow
- `README.md` - This documentation
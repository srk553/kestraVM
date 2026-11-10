# kestraVM - Proxmox VM Provisioning with Kestra

Collection of Kestra flow templates for managing Proxmox VE virtual machines.

## Repository Structure

```
kestraVM/
├── FIXES_DOCUMENTATION.md              # Complete fix documentation
├── kestra-docker-setup.md              # Docker/Kestra setup guide
├── kestra-docker-compose-comparison.md # Official vs custom compose
└── kestra-flows/
    ├── README.md                       # Flows index
    └── proxmox/
        ├── README.md                   # Proxmox flows overview
        ├── TEMPLATE_USAGE_GUIDE.md     # Detailed usage guide
        ├── execute-flow.sh             # CLI helper script
        ├── inputs-example.json         # Sample inputs
        ├── test-inputs.json            # Test inputs template
        ├── all-flows.json              # All flows export
        ├── all-flows.yml               # All flows export (YAML)
        ├── proxmox-test-connection.yml # Connection test
        ├── proxmox-static-test.yml     # Working reference
        ├── proxmox-list-templates.yml  # List templates
        ├── proxmox-list-vms.yml        # List VMs
        ├── proxmox-vm-from-template.yml# Clone from ubuntu24.04template
        └── proxmox-vm-cloudinit.yml    # Cloud-init version (WIP)
```

## Quick Start

### Prerequisites
- Kestra running (e.g., `http://your-kestra:8080`)
- Proxmox VE with API access
- Template VM in Proxmox (e.g., `ubuntu24.04template`)

### 1. Install Proxmox Plugin
The plugin is included in standard Kestra Docker image (`kestra/kestra:latest`).

### 2. Configure Kestra Secret
Add to docker-compose.yml:
```yaml
environment:
  KESTRA_CONFIGURATION: |
    kestra:
      secret:
        type: CONFIG
        config:
          secrets:
            PROXMOX_PASSWORD: "your-proxmox-password"
```

### 3. Import Flows
Via Kestra UI: **Flows → Import → Upload YAML**

Or via API:
```bash
curl -u user:pass -X POST http://kestra:8080/api/v1/flows/import \
  -F "fileUpload=@proxmox-vm-from-template.yml"
```

### 4. Execute Flow
```bash
curl -u user:pass -X POST http://kestra:8080/api/v1/executions/proxmox-vm-from-template \
  -H "Content-Type: application/json" \
  -d '{"proxmox_password": "secret", "new_vmid": 1001, "vm_name": "my-vm"}'
```

## Available Flows

| Flow | Purpose | Inputs |
|------|---------|--------|
| `proxmox-test-connection` | Test Proxmox API connectivity | host, node, user, password |
| `proxmox-static-test` | Working reference (hardcoded) | password only |
| `proxmox-list-templates` | List all templates on pve1 | password only |
| `proxmox-list-vms` | List all VMs on pve1 | password only |
| `proxmox-vm-from-template` | Clone from ubuntu24.04template | password, new_vmid, vm_name, target_node |

## Proxmox Template Setup

Create template `ubuntu24.04template`:
```bash
# Download Ubuntu 24.04 cloud image
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

# Create VM
qm create 9000 --name ubuntu24.04template --memory 2048 --net0 virtio,bridge=vmbr0

# Import disk
qm importdisk 9000 noble-server-cloudimg-amd64.img local-lvm

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

## Proxmox API Permissions

Create dedicated user/token:
```bash
# Create role with minimal privileges
pveum role add KestraVM -privs "VM.Clone VM.Config.Disk VM.Config.CPU VM.Config.Memory VM.Config.Network VM.Config.Options VM.PowerMgmt Datastore.Allocate"

# Create user
pveum user add kestra@pam -password "secure-password"

# Assign role
pveum aclmod / -user kestra@pam -role KestraVM

# Or create token (recommended)
pveum user token add kestra@pam kestra-token -privsep 0
```

## Configuration

### Hardcoded Values (in flows)
- Proxmox host: `172.22.95.201`
- Port: `8006`
- Source node: `pve1`
- Username: `root@pam`
- Template: `ubuntu24.04template`
- SSL verification: `false`

### Inputs for Clone Flow
| Input | Type | Required | Default |
|-------|------|----------|---------|
| proxmox_password | STRING | Yes | - |
| new_vmid | INT | Yes | - |
| vm_name | STRING | Yes | - |
| target_node | STRING | Yes | pve1 |
| full_clone | BOOL | No | true |
| start_vm | BOOL | No | true |

## Documentation

- [Fixes Documentation](FIXES_DOCUMENTATION.md) - All troubleshooting fixes
- [Docker Setup](kestra-docker-setup.md) - Kestra installation
- [Compose Comparison](kestra-docker-compose-comparison.md) - Official vs custom
- [Template Usage Guide](kestra-flows/proxmox/TEMPLATE_USAGE_GUIDE.md) - Detailed flow docs
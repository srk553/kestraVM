# Kestra Proxmox VM Templates - Complete Usage Guide

## Overview

Two Kestra flow templates for creating VMs in Proxmox by cloning templates:

| Template | Use Case | Complexity |
|----------|----------|------------|
| `proxmox-vm-from-template.yml` | Basic clone, pre-configured OS | Simple |
| `proxmox-vm-cloudinit.yml` | Dynamic config via cloud-init | Advanced |

---

## Template 1: Basic Clone (`proxmox-vm-from-template.yml`)

### What It Does
1. **Clones** a template VM to a new VMID
2. **Configures** hardware (CPU, RAM, disk, network)
3. **Starts** the VM (optional)
4. **Waits** for IP address via QEMU Guest Agent
5. **Logs** VM details

### Flow Structure (112 lines)

```
┌─────────────────────────────────────┐
│           INPUTS (10)               │
│  - proxmox_host (required)          │
│  - proxmox_user (required)          │
│  - proxmox_password (required)      │
│  - proxmox_node (required)          │
│  - template_vmid (required)         │
│  - new_vmid (required)              │
│  - vm_name (required)               │
│  - target_node (optional)           │
│  - full_clone (optional, default T) │
│  - start_vm (optional, default T)   │
└──────────────┬──────────────────────┘
               ▼
┌─────────────────────────────────────┐
│        TASK 1: clone_vm             │
│  io.kestra.plugin.proxmox.vm.Clone  │
│  - Full or linked clone             │
│  - Optional target node             │
└──────────────┬──────────────────────┘
               ▼
┌─────────────────────────────────────┐
│      TASK 2: configure_vm           │
│  io.kestra.plugin.proxmox.vm.Config │
│  - Memory: 4096 MB                  │
│  - Cores: 2                         │
│  - CPU: host                        │
│  - Network: virtio, bridge=vmbr0    │
│  - Disk: local-lvm, 32GB            │
│  - Boot: scsi0                      │
│  - QEMU Agent: enabled              │
└──────────────┬──────────────────────┘
               ▼
┌─────────────────────────────────────┐
│      TASK 3: start_vm (conditional) │
│  io.kestra.plugin.proxmox.vm.Start  │
│  Runs only if start_vm == true      │
└──────────────┬──────────────────────┘
               ▼
┌─────────────────────────────────────┐
│     TASK 4: wait_for_ip (cond.)     │
│  io.kestra.plugin.proxmox.vm.Wait   │
│  ForIp                              │
│  Timeout: 300s                      │
└──────────────┬──────────────────────┘
               ▼
┌─────────────────────────────────────┐
│      TASK 5: output_vm_info         │
│  Logs VM details + IP               │
└─────────────────────────────────────┘
```

### Required Proxmox Permissions
- `VM.Clone`
- `VM.Config.Disk`
- `VM.Config.CPU`
- `VM.Config.Memory`
- `VM.Config.Network`
- `VM.Config.Options`
- `VM.PowerMgmt`
- `Datastore.Allocate` (on target storage)

---

## Template 2: Cloud-Init (`proxmox-vm-cloudinit.yml`)

### What It Does
1. **Clones** a cloud-init enabled template
2. **Configures cloud-init** (user, SSH keys, network, DNS)
3. **Configures hardware** (fully parameterized)
4. **Starts** the VM (optional)
5. **Waits** for QEMU Guest Agent
6. **Retrieves** network info (IPv4/IPv6)
7. **Logs** complete connection details

### Flow Structure (207 lines)

```
┌─────────────────────────────────────┐
│           INPUTS (17)               │
│  Required (8):                      │
│  - proxmox_host, user, password     │
│  - proxmox_node, template_vmid      │
│  - new_vmid, vm_name                │
│  - ssh_public_key                   │
│  Optional (9):                      │
│  - ci_user (default: ubuntu)        │
│  - ci_password (optional)           │
│  - ip_config (default: dhcp)        │
│  - dns_servers (default: 8.8.8.8,   │
│    1.1.1.1)                         │
│  - memory_mb (default: 4096)        │
│  - cores (default: 2)               │
│  - disk_size_gb (default: 32)       │
│  - storage (default: local-lvm)     │
│  - bridge (default: vmbr0)          │
│  - start_vm (default: true)         │
└──────────────┬──────────────────────┘
               ▼
┌─────────────────────────────────────┐
│        TASK 1: clone_vm             │
│  Full clone (always)                │
└──────────────┬──────────────────────┘
               ▼
┌─────────────────────────────────────┐
│    TASK 2: configure_cloudinit      │
│  io.kestra.plugin.proxmox.vm.       │
│  CloudInit                          │
│  - User, SSH keys, IP config, DNS   │
│  - Conditional password             │
└──────────────┬──────────────────────┘
               ▼
┌─────────────────────────────────────┐
│    TASK 3: configure_hardware       │
│  io.kestra.plugin.proxmox.vm.Config │
│  - All params from inputs           │
│  - virtio-scsi-pci controller       │
│  - QEMU Agent enabled               │
└──────────────┬──────────────────────┘
               ▼
┌─────────────────────────────────────┐
│      TASK 4: start_vm (cond.)       │
│  Start if start_vm == true          │
└──────────────┬──────────────────────┘
               ▼
┌─────────────────────────────────────┐
│   TASK 5: wait_for_agent (cond.)    │
│  Wait for QEMU Guest Agent (300s)   │
└──────────────┬──────────────────────┘
               ▼
┌─────────────────────────────────────┐
│  TASK 6: get_network_info (cond.)   │
│  Retrieve IPv4/IPv6 from agent      │
└──────────────┬──────────────────────┘
               ▼
┌─────────────────────────────────────┐
│  TASK 7: output_summary (cond.)     │
│  OR TASK 8: output_summary_no_start │
│  Detailed connection info           │
└─────────────────────────────────────┘
```

### Key Differences from Basic Template

| Feature | Basic | Cloud-Init |
|---------|-------|------------|
| SSH Key Injection | ❌ | ✅ |
| Dynamic Network Config | ❌ | ✅ |
| Custom DNS | ❌ | ✅ |
| Parameterized Hardware | ❌ (hardcoded) | ✅ |
| IP Retrieval | WaitForIp | NetworkInfo (agent) |
| Password Auth Option | ❌ | ✅ |
| Storage Selection | ❌ (hardcoded) | ✅ |
| Bridge Selection | ❌ (hardcoded) | ✅ |

---

## How to Use

### 1. Prepare Proxmox Template

#### For Basic Template:
```bash
# 1. Create VM with OS installed
# 2. Install qemu-guest-agent
apt install qemu-guest-agent
systemctl enable qemu-guest-agent

# 3. Shutdown and convert to template
qm shutdown <vmid>
qm template <vmid>
```

#### For Cloud-Init Template:
```bash
# 1. Download cloud image
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

# 2. Create VM
qm create 9000 --name ubuntu-2204-cloudinit --memory 2048 --net0 virtio,bridge=vmbr0

# 3. Import disk
qm importdisk 9000 jammy-server-cloudimg-amd64.img local-lvm

# 4. Configure hardware
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --serial0 socket --vga serial0
qm set 9000 --agent enabled=1

# 5. Cloud-init defaults
qm set 9000 --ciuser ubuntu --cipassword ubuntu --sshkeys ~/.ssh/id_rsa.pub
qm set 9000 --ipconfig0 ip=dhcp

# 6. Convert to template
qm template 9000
```

### 2. Install Kestra Proxmox Plugin

Add to Kestra configuration:
```yaml
# Option 1: Environment variable
KESTRA_PLUGINS: "io.kestra.plugin.proxmox:proxmox-plugin"

# Option 2: Kestra UI → Administration → Plugins → Install
```

### 3. Import Flow to Kestra

```bash
# Via API
curl -X POST http://172.22.95.179:8080/api/v1/flows/import \
  -F "file=@proxmox-vm-cloudinit.yml"

# Or via UI: Flows → Import → Upload YAML
```

### 4. Execute Flow

#### Via Kestra UI:
1. Go to **Flows** → `proxmox-vm-cloudinit`
2. Click **Execute**
3. Fill in required inputs
4. Click **Execute**

#### Via API:
```bash
curl -X POST http://172.22.95.179:8080/api/v1/executions/proxmox-vm-cloudinit \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": {
      "proxmox_host": "https://pve.example.com:8006",
      "proxmox_user": "root@pam",
      "proxmox_password": "your-password",
      "proxmox_node": "pve-node1",
      "template_vmid": "9000",
      "new_vmid": "1001",
      "vm_name": "k8s-worker-01",
      "ssh_public_key": "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC... user@host",
      "memory_mb": "8192",
      "cores": "4",
      "disk_size_gb": "50"
    }
  }'
```

#### Using API Token (Recommended):
```bash
# Create token in Proxmox:
# pveum user token add root@pam kestra -privsep 0

curl -X POST http://172.22.95.179:8080/api/v1/executions/proxmox-vm-cloudinit \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": {
      "proxmox_host": "https://pve.example.com:8006",
      "proxmox_user": "root@pam!kestra",
      "proxmox_password": "TOKEN_VALUE_HERE",
      "proxmox_node": "pve-node1",
      "template_vmid": "9000",
      "new_vmid": "1001",
      "vm_name": "k8s-worker-01",
      "ssh_public_key": "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC... user@host"
    }
  }'
```

---

## Input Parameters Explained

### Proxmox Connection
| Parameter | Description | Format |
|-----------|-------------|--------|
| `proxmox_host` | Proxmox API endpoint | `https://IP:8006` |
| `proxmox_user` | User or token | `root@pam` or `user@realm!tokenid` |
| `proxmox_password` | Password or token secret | string |

### VM Identification
| Parameter | Description | Example |
|-----------|-------------|---------|
| `proxmox_node` | Source Proxmox node | `pve-node1` |
| `template_vmid` | Template VM ID | `9000` |
| `new_vmid` | New VM ID (unique) | `1001` |
| `vm_name` | Display name | `web-server-01` |

### Cloud-Init (Cloud-Init Template Only)
| Parameter | Description | Default |
|-----------|-------------|---------|
| `ssh_public_key` | **Required** - Your SSH pub key | - |
| `ci_user` | Cloud-init username | `ubuntu` |
| `ci_password` | Password (optional) | none |
| `ip_config` | Network config | `ip=dhcp` |
| `dns_servers` | DNS servers | `8.8.8.8,1.1.1.1` |

### Hardware (Cloud-Init Template Only)
| Parameter | Description | Default |
|-----------|-------------|---------|
| `memory_mb` | RAM in MB | `4096` |
| `cores` | CPU cores | `2` |
| `disk_size_gb` | Disk size | `32` |
| `storage` | Storage pool | `local-lvm` |
| `bridge` | Network bridge | `vmbr0` |

### Behavior
| Parameter | Description | Default |
|-----------|-------------|---------|
| `start_vm` | Auto-start after creation | `true` |
| `full_clone` | Full vs linked (basic only) | `true` |

---

## Network Configuration Examples

### DHCP (Default)
```yaml
ip_config: "ip=dhcp"
```

### Static IP
```yaml
ip_config: "ip=192.168.1.100/24,gw=192.168.1.1"
```

### Multiple IPs
```yaml
ip_config: "ip=192.168.1.100/24,gw=192.168.1.1 ip6=auto"
```

### VLAN Tagged
```yaml
ip_config: "ip=10.0.10.100/24,gw=10.0.10.1"
# Requires bridge with VLAN awareness
```

---

## Output & Results

### Successful Execution Returns:
```
==========================================
VM CREATION COMPLETE
==========================================
VMID: 1001
Name: k8s-worker-01
Node: pve-node1
Template: 9000
Memory: 4096 MB
Cores: 2
Disk: 32 GB on local-lvm
Network: vmbr0
User: ubuntu
IPv4: 192.168.1.100
SSH: ssh ubuntu@192.168.1.100
==========================================
```

### Access Your VM:
```bash
# SSH using the injected key
ssh ubuntu@<IPv4_FROM_OUTPUT>

# Or via Proxmox console
qm terminal <vmid>
```

---

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `401 Unauthorized` | Bad credentials | Check user/password or token |
| `403 Forbidden` | Insufficient permissions | Add required privileges in Proxmox |
| `Template not found` | Wrong template_vmid | Verify template exists on node |
| `VMID already exists` | Duplicate new_vmid | Use unique VMID |
| `Cloud-init not applied` | Template missing cloud-init drive | Recreate template with `ide2` cloudinit |
| `WaitForAgent timeout` | Guest agent not running | Install `qemu-guest-agent` in template |
| `No IP returned` | DHCP not working | Check bridge config, use static IP |

---

## Required Proxmox User Permissions

Create a dedicated user/token with minimal privileges:

```bash
# Create role
pveum role add KestraVM -privs "VM.Clone VM.Config.Disk VM.Config.CPU VM.Config.Memory VM.Config.Network VM.Config.Options VM.PowerMgmt Datastore.Allocate"

# Create user
pveum user add kestra@pam -password "secure-password"

# Assign role
pveum aclmod / -user kestra@pam -role KestraVM

# Or create token (preferred)
pveum user token add kestra@pam kestra-token -privsep 0
# Use: user=kestra@pam!kestra-token, password=token-value
```

---

## Files in This Project

```
/home/lab/mykes/
├── proxmox-vm-from-template.yml   # Basic clone flow (112 lines)
├── proxmox-vm-cloudinit.yml       # Cloud-init flow (207 lines)
└── README.md                      # This documentation
```

---

## Next Steps

1. **Test with basic template first** - simpler, fewer inputs
2. **Move to cloud-init** - for production, dynamic config
3. **Add triggers** - schedule, webhook, or API-based
4. **Add notifications** - Slack, email on completion
5. **Create flow for VM lifecycle** - resize, snapshot, delete
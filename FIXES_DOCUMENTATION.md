# Kestra Proxmox Setup - Complete Fix Documentation

## Overview
This document tracks all fixes applied to get Kestra running with Proxmox integration on server 172.22.95.179.

---

## 1. Docker & Kestra Installation

### 1.1 Server Access
- **Server**: 172.22.95.179
- **User**: srk
- **Password**: srk123 (SSH)
- **Kestra UI Credentials**: srk@gmail.com / Srk@12345

### 1.2 Docker Compose (Final Working Version)
```yaml
volumes:
  postgres-data:
    driver: local
  kestra-data:
    driver: local

services:
  postgres:
    image: postgres:18
    container_name: kestra-postgres
    volumes:
      - postgres-data:/var/lib/postgresql
    environment:
      POSTGRES_DB: kestra
      POSTGRES_USER: kestra
      POSTGRES_PASSWORD: k3str4
    healthcheck:
      test: "pg_isready -d \${POSTGRES_DB} -U \${POSTGRES_USER}"
      interval: 10s
      timeout: 10s
      retries: 10
    restart: unless-stopped

  kestra:
    image: kestra/kestra:latest
    pull_policy: always
    container_name: kestra
    restart: unless-stopped
    stop_grace_period: 6m
    user: "root"
    command: server standalone
    volumes:
      - kestra-data:/app/storage
      - /var/run/docker.sock:/var/run/docker.sock
      - /tmp/kestra-wd:/tmp/kestra-wd
    environment:
      KESTRA_CONFIGURATION: |
        datasources:
          postgres:
            url: jdbc:postgresql://postgres:5432/kestra
            driverClassName: org.postgresql.Driver
            username: kestra
            password: k3str4
        kestra:
          server:
            basic-auth:
              username: srk@gmail.com
              password: Srk@12345
          repository:
            type: postgres
          storage:
            type: local
            local:
              base-path: "/app/storage"
          queue:
            type: postgres
          tasks:
            tmp-dir:
              path: /tmp/kestra-wd/tmp
          url: http://localhost:8080/
          secret:
            type: CONFIG
            config:
              secrets:
                PROXMOX_PASSWORD: "mllab@tcoe"
    ports:
      - "8080:8080"
    depends_on:
      postgres:
        condition: service_healthy
```

### Key Fixes Applied:
| Issue | Fix |
|-------|-----|
| Kestra not starting | Added `command: server standalone` |
| Config not loading | Used `KESTRA_CONFIGURATION` with nested YAML |
| DB not ready | Added PostgreSQL healthcheck + `depends_on: condition: service_healthy` |
| Docker tasks fail | Added `user: "root"` + `/var/run/docker.sock` mount |
| Task working dir missing | Added `/tmp/kestra-wd:/tmp/kestra-wd` volume |
| Wrong datasource name | Used `postgres` (not `default`) |
| Password security | Added secret config for PROXMOX_PASSWORD |

---

## 2. Proxmox Plugin - Schema Fixes

### 2.1 Input Field Names
**Error**: `Unrecognized field "name"`
**Fix**: Changed all inputs from `name:` to `id:`
```yaml
# Before (wrong)
- name: proxmox_host
  type: STRING

# After (correct)
- id: proxmox_host
  type: STRING
```

### 2.2 Boolean Type
**Error**: `Could not resolve type id 'BOOLEAN'`
**Fix**: Changed `BOOLEAN` → `BOOL`
```yaml
# Before
type: BOOLEAN

# After
type: BOOL
```

### 2.3 Authentication Field
**Error**: `Unrecognized field "user"`
**Fix**: Changed `user:` → `username:`
```yaml
# Before
user: "root@pam"

# After
username: "root@pam"
```

### 2.4 Host Format
**Error**: `Target host is not specified`
**Fix**: Host must include full URL with protocol and port
```yaml
# Before (wrong)
host: "172.22.95.201"

# After (correct) - but we used separate port field
host: "172.22.95.201"
port: 8006
```

---

## 3. Proxmox Task Types - Corrected

### 3.1 Available Task Types (from plugin)
```bash
io.kestra.plugin.proxmox.cluster.ListResources  # for nodes/resources
io.kestra.plugin.proxmox.vm.List                # for VMs
io.kestra.plugin.proxmox.template.List          # for templates
io.kestra.plugin.proxmox.vm.Clone               # clone VM
io.kestra.plugin.proxmox.vm.Config              # configure VM
io.kestra.plugin.proxmox.vm.Start               # start VM
io.kestra.plugin.proxmox.task.WaitForTask       # wait for async ops
```

### 3.2 Non-Existent Types (Removed)
| Wrong Type | Replacement |
|------------|-------------|
| `NodeList` | `cluster.ListResources` |
| `VmList` | `vm.List` |
| `TemplateList` | `template.List` |
| `WaitForIp` | Not available |
| `WaitForAgent` | Not available |
| `NetworkInfo` | Not available |
| `CloudInit` | Not available |

---

## 4. Flow Files Created/Updated

### Location
```
/home/lab/mykes/kestra-flows/proxmox/
├── proxmox-test-connection.yml      # Test connection (ListResources)
├── proxmox-static-test.yml          # Working static test
├── proxmox-list-templates.yml       # List templates (hardcoded host)
├── proxmox-list-vms.yml             # List VMs (hardcoded host)
├── proxmox-vm-from-template.yml     # Clone from ubuntu24.04template
├── proxmox-vm-cloudinit.yml         # Cloud-init version (needs fixes)
├── test-inputs.json                 # Sample inputs
├── execute-flow.sh                  # Helper script
├── README.md                        # Documentation
└── TEMPLATE_USAGE_GUIDE.md          # Detailed guide
```

### 4.1 Simplified Flows (Hardcoded Host)
All test flows now use hardcoded values matching the working static test:
```yaml
inputs:
  - id: proxmox_password
    type: STRING
    required: true

tasks:
  - type: io.kestra.plugin.proxmox.xxx.List
    host: "172.22.95.201"
    port: 8006
    node: "pve1"
    username: "root@pam"
    password: "{{ inputs.proxmox_password }}"
    verifySsl: false
```

### 4.2 VM Clone Flow (from ubuntu24.04template)
```yaml
inputs:
  - id: proxmox_password
  - id: new_vmid
  - id: vm_name
  - id: target_node (optional)
  - id: full_clone (default: true)
  - id: start_vm (default: true)

tasks:
  - clone_vm: Clone from vmid="ubuntu24.04template"
  - wait_for_clone: WaitForTask
  - configure_vm: Set memory=4096, cores=2, disk=32G
  - start_vm: Start (conditional)
  - wait_for_start: WaitForTask
  - get_vm_info: List to verify
```

---

## 5. Kestra Secret Usage

### In docker-compose.yml:
```yaml
secret:
  type: CONFIG
  config:
    secrets:
      PROXMOX_PASSWORD: "mllab@tcoe"
```

### In flows:
```yaml
password: "{{ secret('PROXMOX_PASSWORD') }}"
```

---

## 6. API Import Commands

```bash
# Import flow
curl -u srk@gmail.com:Srk@12345 -X POST http://172.22.95.179:8080/api/v1/flows/import \
  -F "fileUpload=@/home/lab/mykes/kestra-flows/proxmox/proxmox-test-connection.yml"

# Execute flow
curl -u srk@gmail.com:Srk@12345 -X POST http://172.22.95.179:8080/api/v1/executions/proxmox-test-connection \
  -H "Content-Type: application/json" \
  -d '{"proxmox_password": "your-password"}'
```

---

## 7. Troubleshooting Quick Reference

| Error | Solution |
|-------|----------|
| `Target host not specified` | Use `host` + `port` fields, not full URL in host |
| `Unrecognized field "name"` | Use `id:` for inputs |
| `Type BOOLEAN not found` | Use `BOOL` |
| `Unrecognized field "user"` | Use `username:` |
| `No plugin registered for type` | Check task type exists in plugin (ListResources, vm.List, template.List) |
| `401 Unauthorized` | Check basic-auth credentials in docker-compose |
| `DB connection failed` | Wait for postgres healthcheck, check k3str4 password |

---

## 8. Proxmox Template Requirements

For `ubuntu24.04template` to work:
1. Template VM exists with VMID `ubuntu24.04template` (or numeric VMID)
2. Has cloud-init configured (for cloud-init flow)
3. Has qemu-guest-agent installed
4. Converted to template in Proxmox (`qm template <vmid>`)

---

## 9. Files Structure

```
/home/lab/mykes/
├── kestra-docker-setup.md              # Initial setup docs
├── kestra-docker-compose-comparison.md # Official vs custom compose
└── kestra-flows/
    ├── README.md                        # Main index
    └── proxmox/
        ├── README.md                    # Proxmox flows overview
        ├── TEMPLATE_USAGE_GUIDE.md      # Complete usage guide
        ├── proxmox-test-connection.yml  # Connection test
        ├── proxmox-static-test.yml      # Static test (working)
        ├── proxmox-list-templates.yml   # List templates
        ├── proxmox-list-vms.yml         # List VMs
        ├── proxmox-vm-from-template.yml # Clone from ubuntu24.04template
        ├── proxmox-vm-cloudinit.yml     # Cloud-init (WIP)
        ├── test-inputs.json             # Sample inputs
        └── execute-flow.sh              # CLI helper
```
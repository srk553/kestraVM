# Kestra Docker Setup on Remote Server (172.22.95.179)

## Server Details
- **IP**: 172.22.95.179
- **OS**: Ubuntu 26.04 LTS (Resolute Raccoon)
- **User**: srk
- **Password**: srk123

---

## Step-by-Step Documentation

### 1. SSH Connection Setup

| Action | Command | Result |
|--------|---------|--------|
| Test SSH connectivity | `nc -zv 172.22.95.179 22` | ✅ Port 22 open |
| Try default users (lab, root, ubuntu, etc.) | `ssh user@172.22.95.179` | ❌ Failed |
| **Success with user `srk`** | `ssh srk@172.22.95.179` | ✅ Connected |

### 2. Initial Environment Check

```bash
ssh srk@172.22.95.179 "cat /etc/os-release"
```
**Output**: Ubuntu 26.04 LTS

```bash
ssh srk@172.22.95.179 "docker --version"
```
**Output**: `bash: docker: command not found` - Docker not installed

```bash
ssh srk@172.22.95.179 "groups"
```
**Output**: `srk adm cdrom sudo dip plugdev users lxd` - User has sudo access

### 3. Docker Installation (In Progress)

Since password is required for sudo, using `expect` script to automate:

**Prerequisites to install:**
- ca-certificates
- curl
- gnupg
- lsb-release

**Docker Repository Setup:**
1. Create keyrings directory
2. Add Docker GPG key
3. Add Docker repository
4. Install Docker packages
5. Add user to docker group

---

## Next Steps (To Complete)

### 4. Install Kestra via Docker Compose

Create `docker-compose.yml` for Kestra:

```yaml
version: '3.8'

services:
  kestra:
    image: kestra/kestra:latest
    container_name: kestra
    ports:
      - "8080:8080"
    volumes:
      - kestra_data:/app/storage
      - ./config:/app/config
    environment:
      - KESTRA_CONFIGURATION=/app/config/kestra.yml
    restart: unless-stopped

  postgres:
    image: postgres:15-alpine
    container_name: kestra-postgres
    environment:
      - POSTGRES_USER=kestra
      - POSTGRES_PASSWORD=kestra
      - POSTGRES_DB=kestra
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped

volumes:
  kestra_data:
  postgres_data:
```

### 5. Start Kestra

```bash
docker compose up -d
```

### 6. Verify Installation

```bash
docker compose ps
curl http://172.22.95.179:8080
```

---

## Commands Reference

| Task | Command |
|------|---------|
| SSH to server | `ssh srk@172.22.95.179` |
| Check Docker | `docker --version` |
| Start Kestra | `cd /path/to/kestra && docker compose up -d` |
| View logs | `docker compose logs -f kestra` |
| Stop Kestra | `docker compose down` |
| Update Kestra | `docker compose pull && docker compose up -d` |
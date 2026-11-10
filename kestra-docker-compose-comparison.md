# Docker Compose Comparison: Custom vs Official Kestra

## Official Kestra docker-compose.yml (from GitHub)
```yaml
volumes:
  postgres-data:
    driver: local
  kestra-data:
    driver: local

services:
  postgres:
    image: postgres:18
    volumes:
      - postgres-data:/var/lib/postgresql
    environment:
      POSTGRES_DB: kestra
      POSTGRES_USER: kestra
      POSTGRES_PASSWORD: k3str4
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -d $${POSTGRES_DB} -U $${POSTGRES_USER}"]
      interval: 10s
      timeout: 10s
      retries: 10

  kestra:
    image: kestra/kestra:latest
    pull_policy: always
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
    ports:
      - "8080:8080"
    depends_on:
      postgres:
        condition: service_healthy
```

---

## Key Differences

| Aspect | Our Version | Official Version | Impact |
|--------|-------------|------------------|--------|
| **PostgreSQL Image** | `postgres:15-alpine` | `postgres:18` | Newer PG version, better performance |
| **Healthcheck** | ❌ None | ✅ `pg_isready` | Official waits for DB ready before Kestra starts |
| **Depends_on** | Simple `depends_on: - postgres` | `condition: service_healthy` | Prevents Kestra starting before DB ready |
| **Kestra User** | Default (non-root) | `user: "root"` | Required for Docker socket access |
| **Docker Socket** | ❌ Not mounted | ✅ `/var/run/docker.sock:/var/run/docker.sock` | Required for Docker task plugin |
| **Working Dir Volume** | ❌ None | ✅ `/tmp/kestra-wd:/tmp/kestra-wd` | Required for task working directory |
| **Config Method** | Env vars (flat) | YAML in `KESTRA_CONFIGURATION` | Official uses nested YAML config |
| **Datasource Name** | `default` | `postgres` | Must match in config |
| **Password** | `kestra` | `k3str4` | Different default password |
| **Storage Path** | `/app/storage` | `/app/storage` (base-path) | Same |
| **Tasks Temp Dir** | `/tmp/kestra` | `/tmp/kestra-wd/tmp` | Uses mounted volume |
| **Stop Grace Period** | Default | `6m` | Allows long-running tasks to finish |
| **Pull Policy** | Default | `always` | Always pulls latest image |

---

## Critical Missing Pieces in Our Version

1. **No PostgreSQL healthcheck** - Kestra starts before DB is ready
2. **No `depends_on: condition: service_healthy`** - Same issue
3. **No Docker socket mount** - Docker tasks won't work
4. **No working directory volume** - Task execution may fail
5. **Wrong datasource name** - Used `default` but config expects `postgres`
6. **Flat env vars vs nested YAML** - Kestra prefers YAML config
7. **Non-root user** - Can't access Docker socket

---

## Fixed docker-compose.yml (Based on Official)

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
      test: ["CMD-SHELL", "pg_isready -d $${POSTGRES_DB} -U $${POSTGRES_USER}"]
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
    ports:
      - "8080:8080"
    depends_on:
      postgres:
        condition: service_healthy
```

---

## Apply Official Version

```bash
# On remote server
ssh srk@172.22.95.179 "cat > /home/srk/kestra/docker-compose.yml << 'EOF'
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
      test: ["CMD-SHELL", "pg_isready -d $${POSTGRES_DB} -U $${POSTGRES_USER}"]
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
    ports:
      - "8080:8080"
    depends_on:
      postgres:
        condition: service_healthy
EOF"

# Then restart
ssh srk@172.22.95.179 "cd /home/srk/kestra && docker compose down -v && docker compose up -d"
```

---

## Expected Result

After applying official compose:
- PostgreSQL starts with healthcheck
- Kestra waits for `service_healthy` before starting
- Docker tasks will work (socket mounted)
- Task working directory available
- Proper config via YAML
- All required properties set correctly
# Legoland 🧱

A modular Docker Compose repository for testing, optimizing, and migrating self-hosted services.
Each service stack is an independent "brick" that plugs into a shared network — easy to swap, extend, or replace.

## Repository structure

```
Legoland/
├── docker-compose.yml          # Shared infrastructure (networks)
├── .env.example                # Global environment variables
├── Makefile                    # Convenience commands
├── tests/
│   └── test-stack.sh           # Stack validation test suite
└── services/
    ├── traefik/                # Reverse proxy + automatic HTTPS (Let's Encrypt)
    │   ├── docker-compose.yml
    │   ├── .env.example
    │   └── config/
    │       └── traefik.yml     # Traefik static configuration
    ├── portainer/              # Docker management UI
    │   ├── docker-compose.yml
    │   └── .env.example
    ├── monitoring/             # Prometheus + Grafana
    │   ├── docker-compose.yml
    │   ├── .env.example
    │   └── prometheus/
    │       └── prometheus.yml
    ├── vaultwarden/            # Self-hosted password manager
    │   ├── docker-compose.yml
    │   └── .env.example
    ├── changedetection/        # Price tracking & page change monitor
    │   ├── docker-compose.yml
    │   └── .env.example
    └── searxng/                # Privacy-respecting metasearch (deal search)
        ├── docker-compose.yml
        ├── .env.example
        └── config/
            └── settings.yml    # Engine configuration
```

## Quick start

### 1 – Prerequisites

- Docker Engine ≥ 26
- Docker Compose plugin ≥ 2.24
- `make` (optional but recommended)
- A registered domain with DNS A-records pointing to your server

### 2 – Configure environment

```bash
cp .env.example .env
# Edit .env and set DOMAIN, ACME_EMAIL, TZ
```

Copy any service-specific `.env.example` files as well:

```bash
cp services/monitoring/.env.example services/monitoring/.env
# Edit GRAFANA_ADMIN_PASSWORD
```

### 3 – Create shared networks

```bash
make networks
# or: docker compose -f docker-compose.yml up -d
```

### 4 – Prepare Traefik (once)

```bash
make traefik-init   # creates acme.json with correct permissions
```

### 5 – Start services

Start all at once:
```bash
make up
```

Or start individual stacks:
```bash
make traefik-up
make portainer-up
make monitoring-up
make vaultwarden-up
make changedetection-up
make searxng-up
```

### 6 – Stop services

```bash
make down
```

## Available Makefile targets

| Target | Description |
|--------|-------------|
| `make networks` | Create shared Docker networks |
| `make traefik-init` | Initialize Traefik ACME file (run once) |
| `make traefik-up` | Start Traefik |
| `make portainer-up` | Start Portainer |
| `make monitoring-up` | Start Prometheus + Grafana |
| `make up` | Start **all** services |
| `make down` | Stop **all** services |
| `make traefik-logs` | Follow Traefik logs |
| `make portainer-logs` | Follow Portainer logs |
| `make monitoring-logs` | Follow monitoring stack logs |
| `make vaultwarden-up` | Start Vaultwarden |
| `make vaultwarden-down` | Stop Vaultwarden |
| `make vaultwarden-logs` | Follow Vaultwarden logs |
| `make changedetection-up` | Start Changedetection.io (price tracker) |
| `make changedetection-down` | Stop Changedetection.io |
| `make changedetection-logs` | Follow Changedetection.io logs |
| `make searxng-up` | Start SearXNG (metasearch engine) |
| `make searxng-down` | Stop SearXNG |
| `make searxng-logs` | Follow SearXNG logs |
| `make test` | Run stack validation tests |
| `make test-quick` | Run quick validation tests |

## Services

### Traefik
- **Image:** `traefik:v3.3`
- **Purpose:** Reverse proxy, automatic TLS via Let's Encrypt, route traffic to other services by domain
- **Dashboard:** `https://traefik.<DOMAIN>` (protected with HTTP basic auth)

### Portainer
- **Image:** `portainer/portainer-ce:lts`
- **Purpose:** Web UI for managing Docker containers, images, volumes, and networks
- **URL:** `https://portainer.<DOMAIN>`

### Monitoring (Prometheus + Grafana)
- **Images:** `prom/prometheus:v3.2.1`, `grafana/grafana:11.5.2`
- **Purpose:** Metrics collection and visualization
- **Prometheus:** `https://prometheus.<DOMAIN>`
- **Grafana:** `https://grafana.<DOMAIN>` (default login: `admin` / value of `GRAFANA_ADMIN_PASSWORD`)

### Vaultwarden
- **Image:** `vaultwarden/server:1.32.7`
- **Purpose:** Self-hosted Bitwarden-compatible password manager
- **URL:** `https://vault.<DOMAIN>`
- **Admin panel:** `https://vault.<DOMAIN>/admin` (protected with admin token)

### Changedetection.io (Price Tracking)
- **Images:** `ghcr.io/dgtlmoon/changedetection.io:0.48`, `browserless/chrome:1-playwright-chromium`
- **Purpose:** Monitor websites for price changes, stock availability, and page updates with visual diffs
- **URL:** `https://prices.<DOMAIN>`
- **Features:** Visual screenshot comparison, CSS/XPath/JSONPath extraction, notifications (email, Telegram, Discord, Slack, webhooks), configurable check intervals, headless browser for JS-rendered pages

### SearXNG (Deal Search)
- **Images:** `searxng/searxng:2024.12.23-e69b36cc0`, `redis:7-alpine`
- **Purpose:** Privacy-respecting metasearch engine for discount/deal searching across 70+ search engines
- **URL:** `https://search.<DOMAIN>`
- **Features:** Aggregates Google, Bing, DuckDuckGo and more, shopping-focused engine weights, dark theme, German locale default, Redis result caching

## Testing

Run the test suite to validate compose files, security policies, and configuration consistency:

```bash
make test        # full test suite
make test-quick  # skip slow checks
```

The test suite validates:
- Compose file syntax and configuration
- Security policies (no-new-privileges, cap_drop, resource limits, healthchecks, pids_limit)
- Configuration consistency (.env.example files, network attachment, Traefik labels)
- Docker socket mount security (read-only)
- Makefile target coverage for all services

## Adding a new service

1. Create a new directory under `services/<name>/`.
2. Add a `docker-compose.yml` that attaches to `legoland_proxy` (and optionally `legoland_monitoring`).
3. Expose the service via Traefik labels.
4. Add `.env.example` with service-specific variables.
5. Add `make` targets to the `Makefile`.

Example skeleton:
```yaml
services:
  myapp:
    image: myapp:latest
    container_name: myapp
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    read_only: true
    tmpfs:
      - /tmp:noexec,nosuid,size=64m
    deploy:
      resources:
        limits:
          memory: 256m
          cpus: "0.5"
          pids: 100
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`myapp.${DOMAIN}`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls.certresolver=letsencrypt"
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:8080/health || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 15s

networks:
  proxy:
    external: true
    name: legoland_proxy
```

## Security notes

- `.env` files are excluded from version control via `.gitignore` — **never commit secrets**.
- Traefik dashboard is protected by HTTP basic auth; change the default credentials before exposing it.
- `acme.json` (TLS certificates) is also excluded from version control.
- Use the Let's Encrypt staging server (`caServer` option in `traefik.yml`) during initial setup to avoid rate limits.

### Container hardening

All services are hardened with the following security defaults:

- **`no-new-privileges: true`** — prevents privilege escalation inside containers
- **`cap_drop: ALL`** — drops all Linux capabilities; only required caps are added back via `cap_add`
- **`read_only: true`** — read-only root filesystem (where supported); writable `/tmp` via `tmpfs`
- **Resource limits** — memory and CPU caps prevent runaway containers
- **`pids` limit** — caps process count to prevent fork bombs
- **Healthchecks** — every service has a health probe for automated restart and monitoring
- **Docker socket** — mounted read-only (`:ro`) on services that require it

Run `make test` to verify all security policies are applied correctly.

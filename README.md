# Legoland 🧱

A modular Docker Compose repository for testing, optimizing, and migrating self-hosted services.
Each service stack is an independent "brick" that plugs into a shared network — easy to swap, extend, or replace.

## Repository structure

```
Legoland/
├── docker-compose.yml          # Shared infrastructure (networks)
├── .env.example                # Global environment variables
├── Makefile                    # Convenience commands
└── services/
    ├── traefik/                # Reverse proxy + automatic HTTPS (Let's Encrypt)
    │   ├── docker-compose.yml
    │   ├── .env.example
    │   └── config/
    │       └── traefik.yml     # Traefik static configuration
    ├── portainer/              # Docker management UI
    │   ├── docker-compose.yml
    │   └── .env.example
    └── monitoring/             # Prometheus + Grafana
        ├── docker-compose.yml
        ├── .env.example
        └── prometheus/
            └── prometheus.yml
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
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`myapp.${DOMAIN}`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls.certresolver=letsencrypt"

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

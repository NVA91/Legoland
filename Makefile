.DEFAULT_GOAL := help

COMPOSE = docker compose

# ─────────────────────────────────────────────────────────────────────────────
# Help
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: help
help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ─────────────────────────────────────────────────────────────────────────────
# Networks
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: networks
networks: ## Create shared Docker networks
	$(COMPOSE) -f docker-compose.yml up -d

.PHONY: networks-down
networks-down: ## Remove shared Docker networks
	$(COMPOSE) -f docker-compose.yml down

# ─────────────────────────────────────────────────────────────────────────────
# Traefik
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: traefik-init
traefik-init: ## Create acme.json for Traefik (run once)
	touch services/traefik/acme.json
	chmod 600 services/traefik/acme.json

.PHONY: traefik-up
traefik-up: networks ## Start Traefik
	$(COMPOSE) -f services/traefik/docker-compose.yml --env-file .env up -d

.PHONY: traefik-down
traefik-down: ## Stop Traefik
	$(COMPOSE) -f services/traefik/docker-compose.yml down

.PHONY: traefik-logs
traefik-logs: ## Show Traefik logs
	$(COMPOSE) -f services/traefik/docker-compose.yml logs -f

# ─────────────────────────────────────────────────────────────────────────────
# Portainer
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: portainer-up
portainer-up: networks ## Start Portainer
	$(COMPOSE) -f services/portainer/docker-compose.yml --env-file .env up -d

.PHONY: portainer-down
portainer-down: ## Stop Portainer
	$(COMPOSE) -f services/portainer/docker-compose.yml down

.PHONY: portainer-logs
portainer-logs: ## Show Portainer logs
	$(COMPOSE) -f services/portainer/docker-compose.yml logs -f

# ─────────────────────────────────────────────────────────────────────────────
# Monitoring
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: monitoring-up
monitoring-up: networks ## Start Prometheus + Grafana
	$(COMPOSE) -f services/monitoring/docker-compose.yml --env-file .env up -d

.PHONY: monitoring-down
monitoring-down: ## Stop Prometheus + Grafana
	$(COMPOSE) -f services/monitoring/docker-compose.yml down

.PHONY: monitoring-logs
monitoring-logs: ## Show monitoring stack logs
	$(COMPOSE) -f services/monitoring/docker-compose.yml logs -f

# ─────────────────────────────────────────────────────────────────────────────
# All-in-one
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: up
up: traefik-up portainer-up monitoring-up ## Start all services

.PHONY: down
down: ## Stop all services
	$(COMPOSE) -f services/monitoring/docker-compose.yml down
	$(COMPOSE) -f services/portainer/docker-compose.yml down
	$(COMPOSE) -f services/traefik/docker-compose.yml down

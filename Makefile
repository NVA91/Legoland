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
# Vaultwarden
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: vaultwarden-up
vaultwarden-up: networks ## Start Vaultwarden
	$(COMPOSE) -f services/vaultwarden/docker-compose.yml --env-file .env up -d

.PHONY: vaultwarden-down
vaultwarden-down: ## Stop Vaultwarden
	$(COMPOSE) -f services/vaultwarden/docker-compose.yml down

.PHONY: vaultwarden-logs
vaultwarden-logs: ## Show Vaultwarden logs
	$(COMPOSE) -f services/vaultwarden/docker-compose.yml logs -f

# ─────────────────────────────────────────────────────────────────────────────
# Changedetection (price tracking)
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: changedetection-up
changedetection-up: networks ## Start Changedetection.io (price tracker)
	$(COMPOSE) -f services/changedetection/docker-compose.yml --env-file .env up -d

.PHONY: changedetection-down
changedetection-down: ## Stop Changedetection.io
	$(COMPOSE) -f services/changedetection/docker-compose.yml down

.PHONY: changedetection-logs
changedetection-logs: ## Show Changedetection.io logs
	$(COMPOSE) -f services/changedetection/docker-compose.yml logs -f

# ─────────────────────────────────────────────────────────────────────────────
# SearXNG (deal search)
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: searxng-up
searxng-up: networks ## Start SearXNG (metasearch engine)
	$(COMPOSE) -f services/searxng/docker-compose.yml --env-file .env up -d

.PHONY: searxng-down
searxng-down: ## Stop SearXNG
	$(COMPOSE) -f services/searxng/docker-compose.yml down

.PHONY: searxng-logs
searxng-logs: ## Show SearXNG logs
	$(COMPOSE) -f services/searxng/docker-compose.yml logs -f

# ─────────────────────────────────────────────────────────────────────────────
# Testing
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: test
test: ## Run stack validation tests
	./tests/test-stack.sh

.PHONY: test-quick
test-quick: ## Run quick stack validation tests
	./tests/test-stack.sh --quick

# ─────────────────────────────────────────────────────────────────────────────
# All-in-one
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: up
up: traefik-up portainer-up monitoring-up vaultwarden-up changedetection-up searxng-up ## Start all services

.PHONY: down
down: ## Stop all services
	$(COMPOSE) -f services/searxng/docker-compose.yml down
	$(COMPOSE) -f services/changedetection/docker-compose.yml down
	$(COMPOSE) -f services/vaultwarden/docker-compose.yml down
	$(COMPOSE) -f services/monitoring/docker-compose.yml down
	$(COMPOSE) -f services/portainer/docker-compose.yml down
	$(COMPOSE) -f services/traefik/docker-compose.yml down

#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Legoland – Docker stack test suite
#
# Validates compose files, security policies, and configuration consistency.
#
# Usage:
#   ./tests/test-stack.sh          # run all tests
#   ./tests/test-stack.sh --quick  # skip slow tests (image pull checks)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0
SKIP=0
QUICK=false

[[ "${1:-}" == "--quick" ]] && QUICK=true

# Colors (disabled if not a terminal)
if [[ -t 1 ]]; then
  GREEN='\033[0;32m' RED='\033[0;31m' YELLOW='\033[0;33m' BLUE='\033[0;34m' NC='\033[0m'
else
  GREEN='' RED='' YELLOW='' BLUE='' NC=''
fi

pass() { PASS=$((PASS + 1)); printf "${GREEN}  PASS${NC}  %s\n" "$1"; }
fail() { FAIL=$((FAIL + 1)); printf "${RED}  FAIL${NC}  %s\n" "$1"; }
skip() { SKIP=$((SKIP + 1)); printf "${YELLOW}  SKIP${NC}  %s\n" "$1"; }
section() { printf "\n${BLUE}── %s ──${NC}\n" "$1"; }

# ─────────────────────────────────────────────────────────────────────────────
# 1. YAML / Compose config validation
# ─────────────────────────────────────────────────────────────────────────────
section "Compose config validation"

# Create a temporary .env for validation if one doesn't exist
TEMP_ENV=false
if [[ ! -f "$REPO_ROOT/.env" ]]; then
  cp "$REPO_ROOT/.env.example" "$REPO_ROOT/.env"
  TEMP_ENV=true
fi

# Root compose
if docker compose -f "$REPO_ROOT/docker-compose.yml" config --quiet 2>/dev/null; then
  pass "docker-compose.yml is valid"
else
  fail "docker-compose.yml is invalid"
fi

# Service compose files
for svc_dir in "$REPO_ROOT"/services/*/; do
  svc_name="$(basename "$svc_dir")"
  compose_file="$svc_dir/docker-compose.yml"
  [[ -f "$compose_file" ]] || continue

  # Merge service-level .env.example if it exists (for validation only)
  svc_env=""
  if [[ -f "$svc_dir/.env.example" ]]; then
    svc_env="$svc_dir/.env.example"
  fi

  if docker compose -f "$compose_file" --env-file "$REPO_ROOT/.env" \
      ${svc_env:+--env-file "$svc_env"} config --quiet 2>/dev/null; then
    pass "$svc_name/docker-compose.yml is valid"
  else
    fail "$svc_name/docker-compose.yml is invalid"
  fi
done

# Clean up temp env
[[ "$TEMP_ENV" == true ]] && rm -f "$REPO_ROOT/.env"

# ─────────────────────────────────────────────────────────────────────────────
# 2. Security policy checks
# ─────────────────────────────────────────────────────────────────────────────
section "Security policy checks"

for compose_file in "$REPO_ROOT"/services/*/docker-compose.yml; do
  svc_name="$(basename "$(dirname "$compose_file")")"

  # Check no-new-privileges
  if grep -q "no-new-privileges:true" "$compose_file"; then
    pass "$svc_name: no-new-privileges is set"
  else
    fail "$svc_name: missing no-new-privileges:true"
  fi

  # Check cap_drop: ALL
  if grep -q "cap_drop:" "$compose_file" && grep -A1 "cap_drop:" "$compose_file" | grep -q "ALL"; then
    pass "$svc_name: cap_drop ALL is set"
  else
    fail "$svc_name: missing cap_drop: ALL"
  fi

  # Check resource limits
  if grep -q "limits:" "$compose_file"; then
    pass "$svc_name: resource limits are defined"
  else
    fail "$svc_name: missing resource limits"
  fi

  # Check healthcheck
  if grep -q "healthcheck:" "$compose_file"; then
    pass "$svc_name: healthcheck is defined"
  else
    fail "$svc_name: missing healthcheck"
  fi

  # Check pids limit (inside deploy.resources.limits)
  if grep -q "pids:" "$compose_file"; then
    pass "$svc_name: pids limit is set"
  else
    fail "$svc_name: missing pids limit"
  fi
done

# ─────────────────────────────────────────────────────────────────────────────
# 3. Configuration consistency checks
# ─────────────────────────────────────────────────────────────────────────────
section "Configuration consistency"

# Every service directory must have an .env.example
for svc_dir in "$REPO_ROOT"/services/*/; do
  svc_name="$(basename "$svc_dir")"
  if [[ -f "$svc_dir/.env.example" ]]; then
    pass "$svc_name: .env.example exists"
  else
    fail "$svc_name: missing .env.example"
  fi
done

# All compose files must reference legoland_proxy network
for compose_file in "$REPO_ROOT"/services/*/docker-compose.yml; do
  svc_name="$(basename "$(dirname "$compose_file")")"
  if grep -q "legoland_proxy" "$compose_file"; then
    pass "$svc_name: attached to legoland_proxy network"
  else
    fail "$svc_name: not attached to legoland_proxy network"
  fi
done

# All compose files should use Traefik labels
for compose_file in "$REPO_ROOT"/services/*/docker-compose.yml; do
  svc_name="$(basename "$(dirname "$compose_file")")"
  if grep -q "traefik.enable=true" "$compose_file"; then
    pass "$svc_name: Traefik routing labels present"
  else
    fail "$svc_name: missing Traefik routing labels"
  fi
done

# Sensitive files must be in .gitignore
section "Gitignore checks"

gitignore="$REPO_ROOT/.gitignore"
for pattern in ".env" "acme.json"; do
  if grep -q "$pattern" "$gitignore"; then
    pass ".gitignore covers $pattern"
  else
    fail ".gitignore missing $pattern"
  fi
done

# ─────────────────────────────────────────────────────────────────────────────
# 4. Docker socket security
# ─────────────────────────────────────────────────────────────────────────────
section "Docker socket security"

for compose_file in "$REPO_ROOT"/services/*/docker-compose.yml; do
  svc_name="$(basename "$(dirname "$compose_file")")"
  if grep -q "docker.sock" "$compose_file"; then
    if grep -q "docker.sock.*:ro" "$compose_file" || grep -A1 "docker.sock" "$compose_file" | grep -q ":ro"; then
      pass "$svc_name: docker.sock is mounted read-only"
    else
      fail "$svc_name: docker.sock is mounted writable (should be :ro)"
    fi
  else
    pass "$svc_name: no docker.sock mount (good)"
  fi
done

# ─────────────────────────────────────────────────────────────────────────────
# 5. Makefile target coverage
# ─────────────────────────────────────────────────────────────────────────────
section "Makefile target coverage"

makefile="$REPO_ROOT/Makefile"
for svc_dir in "$REPO_ROOT"/services/*/; do
  svc_name="$(basename "$svc_dir")"
  if grep -q "${svc_name}-up" "$makefile"; then
    pass "Makefile has ${svc_name}-up target"
  else
    fail "Makefile missing ${svc_name}-up target"
  fi
done

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
printf "\n${BLUE}── Summary ──${NC}\n"
printf "  ${GREEN}Passed:${NC}  %d\n" "$PASS"
printf "  ${RED}Failed:${NC}  %d\n" "$FAIL"
printf "  ${YELLOW}Skipped:${NC} %d\n" "$SKIP"
printf "  Total:   %d\n" "$((PASS + FAIL + SKIP))"

[[ $FAIL -eq 0 ]] && printf "\n${GREEN}All tests passed!${NC}\n" || printf "\n${RED}Some tests failed.${NC}\n"
exit "$FAIL"

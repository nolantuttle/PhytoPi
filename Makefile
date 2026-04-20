COMPOSE      := docker compose -f docker-compose.rpi.yml
COMPOSE_P    := $(COMPOSE) -p phytopi
FLUTTER      := /home/phytopi/flutter/bin/flutter
ENV_KIOSK    := user_interface/.env.kiosk

.PHONY: help \
        up down restart logs \
        stop-ui    start-ui    restart-ui    logs-ui \
        stop-sensors start-sensors restart-sensors logs-sensors \
        stop-ai    start-ai    restart-ai    logs-ai \
        stop-camera start-camera restart-camera logs-camera \
        build-ui update

# ── Default target ────────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "  PhytoPi service management"
	@echo ""
	@echo "  Full stack"
	@echo "    make up            – start all services"
	@echo "    make down          – stop + remove all containers (safe, data volumes kept)"
	@echo "    make restart       – restart all services"
	@echo "    make logs          – tail logs from all services"
	@echo ""
	@echo "  Individual services  (ui | sensors | ai | camera)"
	@echo "    make stop-ui       – graceful stop  (SIGTERM → clean shutdown)"
	@echo "    make start-ui      – start stopped container"
	@echo "    make restart-ui    – stop then start"
	@echo "    make logs-ui       – follow logs"
	@echo "    (same pattern for sensors / ai / camera)"
	@echo ""
	@echo "  Build"
	@echo "    make build-ui      – flutter build linux (reads .env.kiosk)"
	@echo "    make update        – git pull + selective rebuild (same as scripts/update.sh)"
	@echo ""

# ── Full stack ────────────────────────────────────────────────────────────────
up:
	$(COMPOSE_P) up -d

# 'stop' sends SIGTERM; containers shut down cleanly before Docker removes them.
# Data volumes are preserved.
down:
	$(COMPOSE_P) down

restart:
	$(COMPOSE_P) restart

logs:
	$(COMPOSE_P) logs -f --tail=50

# ── UI ────────────────────────────────────────────────────────────────────────
# 'docker compose stop' sends SIGTERM and waits (default 10s) before SIGKILL.
# The Flutter process saves state and exits cleanly on SIGTERM.
stop-ui:
	$(COMPOSE_P) stop ui

start-ui:
	$(COMPOSE_P) start ui

restart-ui:
	$(COMPOSE_P) restart ui

logs-ui:
	$(COMPOSE_P) logs -f --tail=50 ui

# ── Sensors (C controller) ────────────────────────────────────────────────────
# The C binary handles SIGTERM: it flushes the SQLite DB and closes GPIO before exit.
stop-sensors:
	$(COMPOSE_P) stop sensors

start-sensors:
	$(COMPOSE_P) start sensors

restart-sensors:
	$(COMPOSE_P) restart sensors

logs-sensors:
	$(COMPOSE_P) logs -f --tail=50 sensors

# ── AI worker ─────────────────────────────────────────────────────────────────
# Python handles SIGTERM: current job is abandoned (marked 'failed') and re-queued
# automatically on next worker startup.
stop-ai:
	$(COMPOSE_P) stop ai

start-ai:
	$(COMPOSE_P) start ai

restart-ai:
	$(COMPOSE_P) restart ai

logs-ai:
	$(COMPOSE_P) logs -f --tail=50 ai

# ── Camera ────────────────────────────────────────────────────────────────────
stop-camera:
	$(COMPOSE_P) stop camera

start-camera:
	$(COMPOSE_P) start camera

restart-camera:
	$(COMPOSE_P) restart camera

logs-camera:
	$(COMPOSE_P) logs -f --tail=50 camera

# ── Build UI bundle ───────────────────────────────────────────────────────────
# After this finishes, inotifywait inside the ui container auto-restarts the app.
build-ui:
	@set -a; . ./$(ENV_KIOSK); set +a; \
	cd user_interface && $(FLUTTER) build linux --release \
	  --dart-define=SUPABASE_URL="$$SUPABASE_URL" \
	  --dart-define=SUPABASE_ANON_KEY="$$SUPABASE_ANON_KEY" \
	  --dart-define=KIOSK_MODE=true \
	  --dart-define=PHYTOPI_STREAM_URL="$${PHYTOPI_STREAM_URL:-http://phytopi.local:8000/stream.mjpg}"
	@echo "Build done – ui container will auto-restart."

# ── Full update (git pull + selective rebuild) ────────────────────────────────
update:
	bash scripts/update.sh

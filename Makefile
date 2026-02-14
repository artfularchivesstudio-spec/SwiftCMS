.PHONY: build run test clean docker-up docker-down migrate seed

# ─── Build & Run ──────────────────────────────────────────────
build:
	swift build

run:
	swift run App serve --hostname 0.0.0.0 --port 8080

test:
	swift test

clean:
	swift package clean
	rm -rf .build

# ─── Docker ───────────────────────────────────────────────────
docker-up:
	docker compose up -d

docker-down:
	docker compose down

docker-build:
	docker compose build

docker-logs:
	docker compose logs -f app

# ─── Database ─────────────────────────────────────────────────
migrate:
	swift run App migrate --yes

migrate-revert:
	swift run App migrate --revert --yes

seed:
	swift run App migrate --yes

# ─── Development ──────────────────────────────────────────────
dev: docker-up
	@echo "Waiting for services..."
	@sleep 3
	swift run App serve --hostname 0.0.0.0 --port 8080

setup:
	cp .env.example .env
	docker compose up -d postgres redis meilisearch
	@echo "Waiting for services to start..."
	@sleep 5
	swift build
	@echo "Setup complete. Run 'make run' to start the server."

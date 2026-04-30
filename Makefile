# Makefile (racine du repo API)

.PHONY: proto-generate proto-check dev test

# Régénérer le code Rust depuis BSR
proto-generate:
	buf generate
	@echo "✅ Proto code regenerated from BSR"

# Vérifier que le code généré est à jour
proto-check:
	buf generate
	@if [ -n "$$(git diff --name-only crates/proto-gen/src/gen/)" ]; then \
		echo "❌ Proto code is stale. Run 'make proto-generate' and commit."; \
		git diff --stat crates/proto-gen/src/gen/; \
		exit 1; \
	fi
	@echo "✅ Proto code is up to date"

# Démarrer l'environnement de dev
dev:
	cd docker/dev && docker compose up -d
	@echo "🚀 Dev environment started"
	@echo "   API:      http://localhost:50051 (gRPC)"
	@echo "   Kafka UI: http://localhost:8080"
	@echo "   MinIO:    http://localhost:9001"

logs:
	cd docker/dev && docker compose logs -f api

# Lancer les tests
test:
	cargo nextest run

# Tout reconstruire proprement
clean-generate:
	rm -rf crates/proto-gen/src/gen/*.rs
	buf generate
	cargo check
	@echo "✅ Clean regeneration complete"
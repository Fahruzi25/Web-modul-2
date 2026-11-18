# ============================================================================
# SuryaLog Cloud -- Module 2 Makefile
# Commands: make build | scan | up | test | push | down | clean | toy-image
# ============================================================================

REGISTRY ?= ghcr.io/suryalog
VERSION  ?= v1.0.0

.PHONY: all build scan up test status logs push down clean toy-image

all: build scan up test

build:
	@echo "[+] Building multi-stage container images..."
	docker compose build

scan:
	@echo "[+] Running image hygiene & security audit..."
	bash image_hygiene_check.sh

up:
	@echo "[+] Starting 5-service container stack with Docker Compose..."
	docker compose up -d
	@echo "[+] Waiting for healthchecks..."
	docker compose ps

test:
	@echo "[+] Running automated API smoke tests..."
	@python3 -c "import urllib.request, json; \
		h = json.loads(urllib.request.urlopen('http://localhost:8080/healthz').read().decode()); \
		assert h['status'] in ['ok', 'degraded'], 'Health failed'; print('[PASS] /healthz'); \
		s = json.loads(urllib.request.urlopen('http://localhost:8080/summary').read().decode()); \
		assert s['rows'] == 240, f'Expected 240 rows, got {s[\"rows\"]}'; \
		assert s['plants'] == 10, f'Expected 10 plants, got {s[\"plants\"]}'; \
		assert abs(s['total_kwh'] - 231.20) < 0.01, f'Expected 231.20 total_kwh, got {s[\"total_kwh\"]}'; \
		assert abs(s['mean_irradiance'] - 1.83) < 0.01, f'Expected 1.83 mean_irradiance, got {s[\"mean_irradiance\"]}'; \
		assert s['peak_hour'] == 12, f'Expected peak_hour 12, got {s[\"peak_hour\"]}'; \
		assert abs(s['peak_kwh'] - 3.42) < 0.01, f'Expected 3.42 peak_kwh, got {s[\"peak_kwh\"]}'; \
		print('[PASS] /summary (rows=240, total_kwh=231.20, mean_irradiance=1.83)'); \
		r = json.loads(urllib.request.urlopen('http://localhost:8080/readings').read().decode()); \
		assert r['count'] > 0, 'No readings returned'; print('[PASS] /readings'); \
		print('=== 3/3 SMOKE TESTS PASSED [GREEN] ===')"

status:
	docker compose ps

logs:
	docker compose logs -f

toy-image:
	bash toy_container_demo.sh

push:
	@echo "[+] Tagging and pushing images to ${REGISTRY}..."
	docker tag suryalog/api:v1.0.0 ${REGISTRY}/api:${VERSION}
	docker tag suryalog/worker:v1.0.0 ${REGISTRY}/worker:${VERSION}
	docker tag suryalog/web:v1.0.0 ${REGISTRY}/web:${VERSION}
	docker push ${REGISTRY}/api:${VERSION}
	docker push ${REGISTRY}/worker:${VERSION}
	docker push ${REGISTRY}/web:${VERSION}

down:
	@echo "[+] Tearing down container stack..."
	docker compose down -v

clean: down
	@echo "[+] Cleaning images and temporary artifacts..."
	docker rmi -f suryalog/api:v1.0.0 suryalog/worker:v1.0.0 suryalog/web:v1.0.0 || true
	rm -f toy-suryalog-image.tar.gz

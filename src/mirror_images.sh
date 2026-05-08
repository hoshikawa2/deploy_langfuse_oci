#!/bin/bash
set -e

# =========================

# ⚙️ CONFIG

# =========================

export REGION="iad"
export TENANCY_NAMESPACE="idavixsf5sbx"
export REGISTRY="${REGION}.ocir.io/${TENANCY_NAMESPACE}"

# Tags fixas (produção)

export LANGFUSE_TAG="3.167.4"
export LANGFUSE_WORKER_TAG="3.167"
export CLICKHOUSE_TAG="24.3"
export REDIS_TAG="7.2"
export POSTGRES_TAG="15"

echo "🔐 Login no OCI Registry..."
docker login ${REGION}.ocir.io

# =========================

# 🟢 LANGFUSE (API)

# =========================

echo "📦 Langfuse..."
docker pull langfuse/langfuse:${LANGFUSE_TAG}
docker tag langfuse/langfuse:${LANGFUSE_TAG} ${REGISTRY}/langfuse:${LANGFUSE_TAG}
docker push ${REGISTRY}/langfuse:${LANGFUSE_TAG}

# =========================
# 🟢 LANGFUSE WORKER
# =========================

echo "📦 Langfuse Worker..."

docker pull langfuse/langfuse-worker:${LANGFUSE_WORKER_TAG}

docker tag langfuse/langfuse-worker:${LANGFUSE_WORKER_TAG} \
           ${REGISTRY}/langfuse-worker:${LANGFUSE_WORKER_TAG}

docker push ${REGISTRY}/langfuse-worker:${LANGFUSE_WORKER_TAG}

# =========================

# 🟣 CLICKHOUSE

# =========================

echo "📦 ClickHouse..."
docker pull clickhouse/clickhouse-server:${CLICKHOUSE_TAG}
docker tag clickhouse/clickhouse-server:${CLICKHOUSE_TAG} ${REGISTRY}/clickhouse:${CLICKHOUSE_TAG}
docker push ${REGISTRY}/clickhouse:${CLICKHOUSE_TAG}

# =========================

# 🔴 REDIS

# =========================

echo "📦 Redis..."
docker pull redis:${REDIS_TAG}
docker tag redis:${REDIS_TAG} ${REGISTRY}/redis:${REDIS_TAG}
docker push ${REGISTRY}/redis:${REDIS_TAG}

# =========================

# 🟡 POSTGRES (OPCIONAL)

# =========================

echo "📦 Postgres..."
docker pull postgres:${POSTGRES_TAG}
docker tag postgres:${POSTGRES_TAG} ${REGISTRY}/postgres:${POSTGRES_TAG}
docker push ${REGISTRY}/postgres:${POSTGRES_TAG}

echo "✅ Todas as imagens foram transferidas com sucesso!"

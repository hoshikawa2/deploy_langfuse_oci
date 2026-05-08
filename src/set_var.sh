#!/bin/bash
set -ex

echo "========================================"
echo "🚀 INICIANDO DEPLOY LANGFUSE"
echo "========================================"

# =========================

# 🔐 CONFIG SECRETS (OCIDs)

# =========================

echo ""
echo "🔐 Etapa 1: Configurando OCIDs dos secrets..."

export OCI_SECRET_OCI_SECRET="ocid1.vaultsecret.oc1.iad.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
export OCI_SECRET_OCI_ACCESS="ocid1.vaultsecret.oc1.iad.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

export OCI_SECRET_SALT="ocid1.vaultsecret.oc1.iad.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
export OCI_SECRET_ENCRYPTION="ocid1.vaultsecret.oc1.iad.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
export OCI_SECRET_NEXTAUTH="ocid1.vaultsecret.oc1.iad.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

export OCI_SECRET_CLICKHOUSE="ocid1.vaultsecret.oc1.iad.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
export OCI_SECRET_REDIS="ocid1.vaultsecret.oc1.iad.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
export OCI_SECRET_DB="ocid1.vaultsecret.oc1.iad.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

export OCI_NAMESPACE="xxxxxxxxxxx"

echo "✅ OCIDs carregados"

# =========================

# ⚙️ CONFIG OCI

# =========================

echo ""
echo "⚙️ Etapa 2: Configuração OCI..."

export OCI_PROFILE=DEFAULT
export OCI_REGION=us-ashburn-1

echo "✔️ Profile: $OCI_PROFILE"
echo "✔️ Region:  $OCI_REGION"

# =========================

# 📦 REGISTRY

# =========================

echo ""
echo "📦 Etapa 3: Configurando registry..."

export REGION="iad"
export TENANCY_NAMESPACE=${OCI_NAMESPACE}
export REGISTRY="${REGION}.ocir.io/${TENANCY_NAMESPACE}"

echo "✔️ Registry: $REGISTRY"

# =========================

# 🧩 DEPLOY CONFIG

# =========================

echo ""
echo "🧩 Etapa 4: Configuração do deploy..."

export APP_NAME="langfuse"
export K8S_NAMESPACE="langfuse"

export IMAGE_REPOSITORY="${REGISTRY}"
export LANGFUSE_TAG="3.167.4"
export LANGFUSE_WORKER_TAG="3.167"

export CLICKHOUSE_TAG="24.3"
export REDIS_TAG="7.2"
export POSTGRES_TAG="15"

echo "✔️ App: $APP_NAME"
echo "✔️ Namespace: $K8S_NAMESPACE"
echo "✔️ Image: $IMAGE_REPOSITORY:$LANGFUSE_TAG"

# =========================

# 🌐 URL

# =========================

echo ""
echo "🌐 Etapa 5: URL..."

export NEXTAUTH_URL="http://localhost:8087"

echo "✔️ URL: $NEXTAUTH_URL"

# =========================

# 🔐 FUNÇÃO SECRET

# =========================

get_secret() {
  local secret_ocid=$1

  echo "🔎 Buscando secret: $secret_ocid" >&2

  oci secrets secret-bundle get \
    --secret-id "$secret_ocid" \
    --query 'data."secret-bundle-content".content' \
    --raw-output | base64 --decode
}
# =========================

# 🔥 CARREGAR SECRETS

# =========================

echo ""
echo "🔐 Etapa 6: Carregando secrets do OCI..."

export DB_PASSWORD=$(get_secret "$OCI_SECRET_DB")
export DATABASE_URL="postgresql://langfuse:${DB_PASSWORD}@${APP_NAME}-db:5432/langfuse"
echo "✔️ DATABASE_URL carregado"

export REDIS_AUTH=$(get_secret "$OCI_SECRET_REDIS")
echo "✔️ REDIS_AUTH carregado"

export CLICKHOUSE_PASSWORD=$(get_secret "$OCI_SECRET_CLICKHOUSE")
echo "✔️ CLICKHOUSE_PASSWORD carregado"

export NEXTAUTH_SECRET=$(get_secret "$OCI_SECRET_NEXTAUTH")
echo "✔️ NEXTAUTH_SECRET carregado"


export ENCRYPTION_KEY=$(get_secret "$OCI_SECRET_ENCRYPTION" | tr -d '\r\n')

export S3_ACCESS_KEY=$(get_secret "$OCI_SECRET_OCI_ACCESS")
export S3_SECRET_KEY=$(get_secret "$OCI_SECRET_OCI_SECRET")

# Corrige automaticamente caso a key esteja inválida
if ! [[ "$ENCRYPTION_KEY" =~ ^[a-fA-F0-9]{64}$ ]]; then
  echo "⚠️ ENCRYPTION_KEY inválida no Vault. Gerando automaticamente..."

  ENCRYPTION_KEY=$(openssl rand -hex 32)

  echo "🔐 Nova ENCRYPTION_KEY:"
  echo "$ENCRYPTION_KEY"
fi

echo "✔️ ENCRYPTION_KEY carregado"

export SALT=$(get_secret "$OCI_SECRET_SALT")
echo "✔️ SALT carregado"

# =========================

# ⚡ REDIS

# =========================

echo ""
echo "⚡ Etapa 7: Config Redis..."

export REDIS_HOST="${APP_NAME}-redis"
export REDIS_PORT="6379"

echo "✔️ Redis: $REDIS_HOST:$REDIS_PORT"

# =========================

# 📊 CLICKHOUSE

# =========================

echo ""
echo "📊 Etapa 8: Config ClickHouse..."

export CLICKHOUSE_URL="http://${APP_NAME}-clickhouse:8123"
export CLICKHOUSE_USER="default"
export CLICKHOUSE_MIGRATION_URL="clickhouse://${APP_NAME}-clickhouse:9000"
export CLICKHOUSE_CLUSTER_ENABLED="false"

echo "✔️ ClickHouse: $CLICKHOUSE_URL"

# =========================

# ☁️ OBJECT STORAGE

# =========================

echo ""
echo "☁️ Etapa 9: Config OCI Object Storage..."

export LANGFUSE_S3_EVENT_UPLOAD_BUCKET="langfuse-events"
export LANGFUSE_S3_EVENT_UPLOAD_REGION="${OCI_REGION}"
export LANGFUSE_S3_EVENT_UPLOAD_ENDPOINT="https://${OCI_NAMESPACE}.compat.objectstorage.${OCI_REGION}.oraclecloud.com"
#export LANGFUSE_USE_OCI_NATIVE_OBJECT_STORAGE="true"
echo "✔️ Bucket eventos: $LANGFUSE_S3_EVENT_UPLOAD_BUCKET"

# =========================

# 🚀 DEPLOY

# =========================

echo ""
echo "🚀 Etapa 10: Aplicando Kubernetes..."

echo "📄 Preview YAML (primeiras linhas):"
envsubst < langfuse_dest.yaml | head -n 20

echo ""
echo "📦 Aplicando..."

echo ""
echo "📄 Gerando YAML final..."

envsubst < langfuse_dest.yaml > final.yaml

echo ""
echo "📄 Preview:"
head -n 20 final.yaml

echo ""
echo "🔍 Validando YAML..."

kubectl apply --dry-run=client -f final.yaml

echo ""
echo "📦 Aplicando..."

# kubectl apply -f final.yaml

echo ""
echo "========================================"
echo "🎯 DEPLOY FINALIZADO COM SUCESSO!"
echo "========================================"

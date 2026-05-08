#!/bin/bash
set -ex

echo "🔐 Atualizando secrets no OCI Vault..."

# =========================
# ⚙️ CONFIG
# =========================

export OCI_SECRET_OCI_SECRET="ocid1.vaultsecret.oc1.iad.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
export OCI_SECRET_OCI_ACCESS="ocid1.vaultsecret.oc1.iad.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

export OCI_SECRET_SALT="ocid1.vaultsecret.oc1.iad.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
export OCI_SECRET_ENCRYPTION="ocid1.vaultsecret.oc1.iad.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
export OCI_SECRET_NEXTAUTH="ocid1.vaultsecret.oc1.iad.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

export OCI_SECRET_CLICKHOUSE="ocid1.vaultsecret.oc1.iad.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
export OCI_SECRET_REDIS="ocid1.vaultsecret.oc1.iad.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
export OCI_SECRET_DB="ocid1.vaultsecret.oc1.iad.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
export USER_OCID="ocid1.user.oc1..xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# O par de keys de Custom Keys não pode ser gerado automaticamente pois não é fornecido o Secret. Isso só é possível via Console OCi
export OCI_ACCESS_KEY="88328a8bd76fe91d9891ef5a95169c981c56dd16"
export OCI_SECRET_KEY="/kzBzm14HLP9WybwHtAXmNyyJB6WUU74bI2cVeNYhaQ="

# =========================
# 🔑 VALORES
# =========================

DB_PASSWORD="langfuse123"

REDIS_PASSWORD="redis123"

CLICKHOUSE_PASSWORD="clickhouse123"

NEXTAUTH_SECRET_VALUE="nextauth-secret-123"

SALT_VALUE="salt-secret-123"

# ⚠️ OBRIGATÓRIO:
# 64 chars hex / 256 bits
ENCRYPTION_KEY=$(openssl rand -hex 32)

echo "🔐 ENCRYPTION_KEY gerada:"
echo "$ENCRYPTION_KEY"

# =========================
# 🔧 FUNÇÃO UPDATE
# =========================

update_secret() {

  local secret_ocid=$1
  local value=$2

  echo "🔄 Atualizando secret: $secret_ocid"

  local base64_value
  base64_value=$(printf "%s" "$value" | base64 | tr -d '\n')

  oci vault secret update-base64 \
    --secret-id "$secret_ocid" \
    --secret-content-content "$base64_value"
}

# =========================
# 🔥 UPDATE
# =========================

update_secret "$OCI_SECRET_DB" "$DB_PASSWORD"

update_secret "$OCI_SECRET_REDIS" "$REDIS_PASSWORD"

update_secret "$OCI_SECRET_CLICKHOUSE" "$CLICKHOUSE_PASSWORD"

update_secret "$OCI_SECRET_NEXTAUTH" "$NEXTAUTH_SECRET_VALUE"

update_secret "$OCI_SECRET_ENCRYPTION" "$ENCRYPTION_KEY"

update_secret "$OCI_SECRET_SALT" "$SALT_VALUE"

echo ""
echo "✅ Secrets atualizados com sucesso!"
echo ""
echo "👉 ENCRYPTION_KEY usada:"
echo "$ENCRYPTION_KEY"

update_secret "$OCI_SECRET_OCI_ACCESS" "$OCI_ACCESS_KEY"

update_secret "$OCI_SECRET_OCI_SECRET" "$OCI_SECRET_KEY"
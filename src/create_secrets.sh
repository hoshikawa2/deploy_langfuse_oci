#!/bin/bash
set -ex

echo "🔐 Criando secrets no OCI Vault..."

# =========================
# ⚙️ CONFIG
# =========================

export COMPARTMENT_ID="ocid1.compartment.oc1..aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

export VAULT_ID="ocid1.vault.oc1.iad.aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

export KEY_ID="ocid1.key.oc1.iad.aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

export PREFIX="langfuse"

# =========================
# 🔑 SENHAS
# =========================

# Senha comum simples
if [ -z "$COMMON_SECRET" ]; then
  echo "🔑 Gerando COMMON_SECRET..."
  COMMON_SECRET=$(openssl rand -base64 32 | tr -d '\n')
fi

# ENCRYPTION_KEY precisa:
# - 64 chars
# - hexadecimal
# - 256 bits
if [ -z "$ENCRYPTION_KEY" ]; then
  echo "🔐 Gerando ENCRYPTION_KEY..."
  ENCRYPTION_KEY=$(openssl rand -hex 32)
fi

echo "👉 COMMON_SECRET: $COMMON_SECRET"
echo "👉 ENCRYPTION_KEY: $ENCRYPTION_KEY"

# =========================
# 🔧 FUNÇÃO
# =========================

create_secret() {

  local name=$1
  local value=$2

  echo "📦 Criando secret: $name"

  local base64_value
  base64_value=$(printf "%s" "$value" | base64 | tr -d '\n')

  oci vault secret create-base64 \
    --compartment-id "$COMPARTMENT_ID" \
    --vault-id "$VAULT_ID" \
    --key-id "$KEY_ID" \
    --secret-name "$name" \
    --secret-content-content "$base64_value" \
    --query 'data.id' \
    --raw-output
}

# =========================
# 🔥 CRIAR SECRETS
# =========================

DB_SECRET=$(create_secret "${PREFIX}-db-password" "$COMMON_SECRET")

REDIS_SECRET=$(create_secret "${PREFIX}-redis" "$COMMON_SECRET")

CLICKHOUSE_SECRET=$(create_secret "${PREFIX}-clickhouse" "$COMMON_SECRET")

NEXTAUTH_SECRET=$(create_secret "${PREFIX}-nextauth" "$COMMON_SECRET")

# 👇 SOMENTE ESTA KEY TEM FORMATO ESPECIAL
ENCRYPTION_SECRET=$(create_secret "${PREFIX}-encryption" "$ENCRYPTION_KEY")

SALT_SECRET=$(create_secret "${PREFIX}-salt" "$COMMON_SECRET")

OCI_ACCESS_SECRET=$(create_secret "${PREFIX}-oci-access" "$COMMON_SECRET")

OCI_SECRET_SECRET=$(create_secret "${PREFIX}-oci-secret" "$COMMON_SECRET")

# =========================
# 📤 OUTPUT
# =========================

echo ""
echo "✅ Secrets criados com sucesso!"
echo ""

echo "export OCI_SECRET_DB=$DB_SECRET"
echo "export OCI_SECRET_REDIS=$REDIS_SECRET"
echo "export OCI_SECRET_CLICKHOUSE=$CLICKHOUSE_SECRET"
echo "export OCI_SECRET_NEXTAUTH=$NEXTAUTH_SECRET"
echo "export OCI_SECRET_ENCRYPTION=$ENCRYPTION_SECRET"
echo "export OCI_SECRET_SALT=$SALT_SECRET"
echo "export OCI_SECRET_OCI_ACCESS=$OCI_ACCESS_SECRET"
echo "export OCI_SECRET_OCI_SECRET=$OCI_SECRET_SECRET"

echo ""
echo "💡 Salve isso no seu pipeline ou env.sh"
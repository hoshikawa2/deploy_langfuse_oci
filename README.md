# 🚀 Tutorial Completo — Deploy do Langfuse no Oracle Kubernetes Engine (OKE)

## 📌 Introdução

Este tutorial apresenta um processo completo para implantação do Langfuse no Oracle Cloud Infrastructure (OCI), utilizando:

- Oracle Kubernetes Engine (OKE)
- OCI Container Registry (OCIR)
- OCI Vault
- OCI Object Storage
- PostgreSQL
- Redis
- ClickHouse

Além do deployment em si, este tutorial cobre:
- arquitetura do Langfuse
- conceitos fundamentais
- purpose de cada componente
- gerenciamento de imagens Docker
- secrets centralizados no OCI Vault
- preparação de ambiente
- deployment automatizado via Kubernetes YAML

## 🧠 O que é o Langfuse

Langfuse é uma plataforma de observabilidade para aplicações de IA generativa.

Ele permite:
- rastrear chamadas de LLM
- armazenar traces
- monitorar prompts
- analisar custos
- acompanhar latência
- versionar prompts
- inspecionar tool calls
- avaliar qualidade de respostas

## 🏗️ Arquitetura Geral

Componentes:
- PostgreSQL
- Redis
- ClickHouse
- Langfuse API
- Langfuse Worker
- OCI Vault
- OCI Object Storage
- OCIR
- OKE

## 🔐 OCI Vault

Os scripts create_secrets.sh e update_secret.sh criam e atualizam secrets no OCI Vault.

Antes de iniciar esta etapa, crie um VAULT e UMA ENCRYPTION KEY. Busque pelos OCID destes 2 componentes para setar dentro de seu script create_secrets.sh e update_secret.sh

A ENCRYPTION_KEY precisa possuir:
- 64 caracteres
- hexadecimal
- 256 bits

Exemplo:

```bash
ENCRYPTION_KEY=$(openssl rand -hex 32)
```

## 📦 OCI Registry (OCIR)

O script mirror_images.sh copia imagens públicas para o registry privado OCI.

Exemplo:

```bash
docker pull langfuse/langfuse:3.1.0

docker tag langfuse/langfuse:3.1.0 iad.ocir.io/namespace/langfuse:3.1.0

docker push iad.ocir.io/namespace/langfuse:3.1.0
```

O mesmo ocorre para:
- langfuse-worker
- redis
- postgres
- clickhouse

## ☸️ Kubernetes Deployment

O arquivo final.yaml contém:
- StorageClass
- PVCs
- Deployments
- StatefulSets
- Services
- HPA

## PostgreSQL

Responsável por:
- usuários
- traces
- prompts
- configurações

Readiness probe:

```yaml
pg_isready -U langfuse
```

## Redis

Responsável por:
- filas
- cache
- jobs

## ClickHouse

Responsável por:
- analytics
- métricas
- observabilidade

## Langfuse API

Responsável por:
- UI
- API
- autenticação

## Langfuse Worker

Responsável por:
- filas
- processamento assíncrono
- exports

## initContainers

Utilizados para aguardar:
- PostgreSQL
- Redis
- ClickHouse

antes da inicialização dos pods.

Exemplo:

```yaml
until nc -z langfuse-db 5432
```

## 🌐 OCI Load Balancer

Service utilizado:

```yaml
kind: Service
type: LoadBalancer
```

Healthcheck:

```yaml
oci.oraclecloud.com/healthcheck-path: "/api/public/health"
```

## ☁️ OCI Object Storage

Utilizado para:
- eventos
- batches
- exports

Auth utilizada:

```yaml
LANGFUSE_OCI_AUTH_TYPE=instance_principal
```

## ⚙️ Principais Variáveis

| Variável | Função |
|---|---|
| DATABASE_URL | PostgreSQL |
| REDIS_AUTH | Redis |
| CLICKHOUSE_PASSWORD | ClickHouse |
| NEXTAUTH_SECRET | Auth |
| ENCRYPTION_KEY | Criptografia |
| SALT | Salt |
| NEXTAUTH_URL | URL pública |

# 📦 Fluxo Completo — Imagens, OCI Vault e Deployment Final

## 🎯 Objetivo

Antes do deployment do Langfuse no Oracle Kubernetes Engine (OKE), existem algumas etapas preparatórias fundamentais.

Essas etapas possuem dois objetivos principais:

1. Centralizar imagens Docker em um registry privado OCI (OCIR)
2. Centralizar secrets no OCI Vault para que o deployment Kubernetes possa consumir valores seguros dinamicamente

O fluxo completo funciona assim:

```text
Docker Hub
    ↓
Mirror para OCI Registry (OCIR)
    ↓
Criação de Secrets no OCI Vault
    ↓
Captura dos OCIDs dos Secrets
    ↓
Leitura dinâmica via OCI CLI
    ↓
envsubst
    ↓
Geração do final.yaml
    ↓
kubectl apply
```

>**Nota:** Antes de iniciar o processo de deployment, certifque-se de que exista um dynamic group e as policies estejam de acordo na OCI.

Dynamic Group oke-langfuse:
ALL {instance.compartment.id = 'ocid1.compartment.oc1..aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'}
- Todos os recursos deste compartment estarão habilitados para as policies abaixo


Algumas policies importantes:
- Allow dynamic-group oke-langfuse to manage objects in compartment kubernetes
- Allow dynamic-group oke-langfuse to read buckets in compartment kubernetes
- Allow dynamic-group oke-langfuse to manage volume-family in compartment kubernetes

---

# 🟢 Etapa 1 — Publicar Imagens no OCI Registry (OCIR)

## 📌 Objetivo

O Kubernetes do OKE precisa baixar imagens Docker.

Embora seja possível utilizar imagens públicas diretamente do Docker Hub, em ambientes corporativos normalmente utilizamos um registry privado OCI por motivos de:

* segurança
* governança
* performance
* disponibilidade
* controle de versões
* evitar rate limit do Docker Hub

---

# 📦 Imagens utilizadas

O deployment utiliza:

| Imagem                       | Função    |
| ---------------------------- | --------- |
| langfuse/langfuse            | API/UI    |
| langfuse/langfuse-worker     | Worker    |
| postgres                     | Banco     |
| redis                        | Cache     |
| clickhouse/clickhouse-server | Analytics |

---

# 🔄 Processo de Mirror

O script:

```text
mirror_images.sh
```

executa:

1. Pull da imagem pública
2. Tag para o OCIR
3. Push para o registry OCI

---

# Exemplo

## Pull

```bash
docker pull langfuse/langfuse:3.1.0
```

## Tag

```bash
docker tag langfuse/langfuse:3.1.0 iad.ocir.io/namespace/langfuse:3.1.0
```

## Push

```bash
docker push iad.ocir.io/namespace/langfuse:3.1.0
```

---

# 📌 Resultado Final

Após isso, o Kubernetes utilizará:

```text
iad.ocir.io/SEU_NAMESPACE/langfuse:3.1.0
```

em vez da imagem pública.

---

# 🔐 Etapa 2 — Criar Secrets no OCI Vault

## 📌 Objetivo

O deployment possui:

* senhas
* tokens
* chaves de criptografia

Esses valores NÃO devem ficar hardcoded no YAML.

Por isso usamos:

* OCI Vault
* OCI KMS

---

# 🧠 Secrets utilizados

| Secret              | Finalidade           |
| ------------------- | -------------------- |
| DB_PASSWORD         | PostgreSQL           |
| REDIS_AUTH          | Redis                |
| CLICKHOUSE_PASSWORD | ClickHouse           |
| NEXTAUTH_SECRET     | Auth Langfuse        |
| ENCRYPTION_KEY      | Criptografia interna |
| SALT                | Salt interno         |

---

# 🔧 Script utilizado

Arquivo:

```text
create_secrets.sh
```

---

# 📌 Como funciona

O script:

1. Gera senhas
2. Gera ENCRYPTION_KEY
3. Codifica em Base64
4. Cria os secrets no OCI Vault

---

# 🔐 ENCRYPTION_KEY

A variável:

```bash
ENCRYPTION_KEY=$(openssl rand -hex 32)
```

gera:

* 32 bytes
* 64 chars hex
* 256 bits

Formato obrigatório do Langfuse.

---

# 📤 Resultado do Script

Ao final, o OCI Vault retorna:

```bash
export OCI_SECRET_DB=ocid1.vaultsecret...
```

Esses valores são os:

* OCIDs dos secrets

---

# 🧠 O que é o OCID do Secret?

Cada secret criado no OCI Vault recebe um identificador único:

```text
ocid1.vaultsecret.oc1....
```

Esse OCID é utilizado depois para:

* localizar
* ler
* atualizar

o conteúdo do secret.

---

# 🔥 Etapa 3 — Capturar os OCIDs

## 📌 Objetivo

Os scripts seguintes precisam saber:

* qual secret acessar
* onde buscar a senha

Por isso os OCIDs precisam ser armazenados.

---

# 📌 Exemplo

```bash
export OCI_SECRET_DB="ocid1.vaultsecret.oc1..."
```

---

# 📌 Utilização

Esses OCIDs serão utilizados no:

```text
set_var.sh
```

---

# ⚙️ Etapa 4 — Carregar Secrets Dinamicamente

## 📌 Objetivo

Antes de gerar o YAML final:

* precisamos buscar os valores reais no OCI Vault

---

# 🔧 Função utilizada

```bash
get_secret() {

  oci secrets secret-bundle get \
    --secret-id "$secret_ocid" \
    --query 'data."secret-bundle-content".content' \
    --raw-output | base64 --decode
}
```

---

# 📌 O que ocorre aqui

O script:

1. Chama OCI CLI
2. Busca o secret
3. Recebe Base64
4. Decodifica
5. Exporta para variável de ambiente

---

# 📌 Exemplo

```bash
export DB_PASSWORD=$(get_secret "$OCI_SECRET_DB")
```

---

# 📌 Resultado

Agora temos:

```bash
export DB_PASSWORD="senha_real"
```

em memória no shell.

---

# 🧩 Etapa 5 — Construção do final.yaml

## 📌 Objetivo

O arquivo:

```text
langfuse_dest.yaml
```

possui placeholders:

```yaml
${DB_PASSWORD}
```
---

# ⚙️ Variáveis de Ambiente — Langfuse no OKE

## 📌 Introdução

O deployment do Langfuse depende de diversas variáveis de ambiente responsáveis por configurar:

* banco de dados
* cache
* analytics
* autenticação
* object storage
* OCI
* imagens
* Kubernetes
* URLs
* segurança

Essas variáveis são carregadas principalmente pelo:

```text id="vars1"
set_var.sh
```

e posteriormente injetadas no:

```text id="vars2"
final.yaml
```

através do:

```bash id="vars3"
envsubst
```

---

# 🧩 Variáveis de Configuração OCI

---

## OCI_PROFILE

```bash id="vars4"
export OCI_PROFILE=DEFAULT
```

### Objetivo

Define qual profile do OCI CLI será utilizado.

### Origem

Arquivo:

```text id="vars5"
~/.oci/config
```

### Exemplo

```ini id="vars6"
[DEFAULT]
user=...
fingerprint=...
tenancy=...
region=...
```

---

## OCI_REGION

```bash id="vars7"
export OCI_REGION=us-ashburn-1
```

### Objetivo

Define a região OCI utilizada por:

* Vault
* Object Storage
* Registry
* APIs OCI

### Exemplos

| Região    | Valor         |
| --------- | ------------- |
| Ashburn   | us-ashburn-1  |
| São Paulo | sa-saopaulo-1 |

---

## OCI_NAMESPACE

```bash id="vars8"
export OCI_NAMESPACE="idavixsf5sbx"
```

### Objetivo

Namespace do OCI Object Storage e OCIR.

Utilizado em:

* Registry
* Bucket endpoints

---

# 📦 Variáveis do OCI Registry (OCIR)

---

## REGION

```bash id="vars9"
export REGION="iad"
```

### Objetivo

Região curta utilizada pelo OCIR.

### Exemplos

| Região OCI    | Short Name |
| ------------- | ---------- |
| us-ashburn-1  | iad        |
| sa-saopaulo-1 | gru        |

---

## TENANCY_NAMESPACE

```bash id="vars10"
export TENANCY_NAMESPACE=${OCI_NAMESPACE}
```

### Objetivo

Namespace do tenancy no OCIR.

---

## REGISTRY

```bash id="vars11"
export REGISTRY="${REGION}.ocir.io/${TENANCY_NAMESPACE}"
```

### Resultado

```text id="vars12"
iad.ocir.io/idavixsf5sbx
```

### Objetivo

Registry privado OCI utilizado pelo Kubernetes.

---

# 🧠 Variáveis do Deployment

---

## APP_NAME

```bash id="vars13"
export APP_NAME="langfuse"
```

### Objetivo

Prefixo dos recursos Kubernetes.

### Exemplos

Gera:

* langfuse-db
* langfuse-redis
* langfuse-clickhouse

---

## K8S_NAMESPACE

```bash id="vars14"
export K8S_NAMESPACE="langfuse"
```

### Objetivo

Namespace Kubernetes onde os recursos serão criados.

---

## IMAGE_REPOSITORY

```bash id="vars15"
export IMAGE_REPOSITORY="${REGISTRY}"
```

### Objetivo

Define o registry utilizado pelas imagens.

### Resultado

```text id="vars16"
iad.ocir.io/idavixsf5sbx
```

---

## IMAGE_TAG

```bash id="vars17"
export IMAGE_TAG="3.1.0"
```

### Objetivo

Tag da imagem principal Langfuse.

---

## CLICKHOUSE_TAG

```bash id="vars18"
export CLICKHOUSE_TAG="23.8"
```

### Objetivo

Versão do ClickHouse.

---

## REDIS_TAG

```bash id="vars19"
export REDIS_TAG="7.2"
```

### Objetivo

Versão Redis.

---

## POSTGRES_TAG

```bash id="vars20"
export POSTGRES_TAG="15"
```

### Objetivo

Versão PostgreSQL.

---

# 🌐 Variáveis de URL

---

## NEXTAUTH_URL

```bash id="vars21"
export NEXTAUTH_URL="https://langfuse.seudominio.com"
```

### Objetivo

URL pública utilizada pelo frontend do Langfuse.

### Impacto

Utilizada para:

* login
* redirects
* cookies
* OAuth

---

# 🔐 Variáveis de Secrets OCI Vault

---

## OCI_SECRET_DB

```bash id="vars22"
export OCI_SECRET_DB="ocid1.vaultsecret..."
```

### Objetivo

OCID do secret contendo a senha PostgreSQL.

---

## OCI_SECRET_REDIS

```bash id="vars23"
export OCI_SECRET_REDIS="ocid1.vaultsecret..."
```

### Objetivo

OCID do secret Redis.

---

## OCI_SECRET_CLICKHOUSE

```bash id="vars24"
export OCI_SECRET_CLICKHOUSE="ocid1.vaultsecret..."
```

### Objetivo

OCID da senha ClickHouse.

---

## OCI_SECRET_NEXTAUTH

```bash id="vars25"
export OCI_SECRET_NEXTAUTH="ocid1.vaultsecret..."
```

### Objetivo

Secret de autenticação do Langfuse.

---

## OCI_SECRET_ENCRYPTION

```bash id="vars26"
export OCI_SECRET_ENCRYPTION="ocid1.vaultsecret..."
```

### Objetivo

Secret utilizado para criptografia interna.

---

## OCI_SECRET_SALT

```bash id="vars27"
export OCI_SECRET_SALT="ocid1.vaultsecret..."
```

### Objetivo

Salt interno do Langfuse.

---

# 🔥 Variáveis Carregadas Dinamicamente

Estas variáveis são carregadas via:

```bash id="vars28"
get_secret()
```

---

## DB_PASSWORD

```bash id="vars29"
export DB_PASSWORD=$(get_secret "$OCI_SECRET_DB")
```

### Objetivo

Senha PostgreSQL.

---

## DATABASE_URL

```bash id="vars30"
export DATABASE_URL="postgresql://langfuse:${DB_PASSWORD}@${APP_NAME}-db:5432/langfuse"
```

### Objetivo

Connection string PostgreSQL.

### Estrutura

```text id="vars31"
postgresql://USUARIO:SENHA@HOST:PORTA/BANCO
```

---

## REDIS_AUTH

```bash id="vars32"
export REDIS_AUTH=$(get_secret "$OCI_SECRET_REDIS")
```

### Objetivo

Senha Redis.

---

## CLICKHOUSE_PASSWORD

```bash id="vars33"
export CLICKHOUSE_PASSWORD=$(get_secret "$OCI_SECRET_CLICKHOUSE")
```

### Objetivo

Senha ClickHouse.

---

## NEXTAUTH_SECRET

```bash id="vars34"
export NEXTAUTH_SECRET=$(get_secret "$OCI_SECRET_NEXTAUTH")
```

### Objetivo

Secret JWT/Auth do Langfuse.

---

## ENCRYPTION_KEY

```bash id="vars35"
export ENCRYPTION_KEY=$(get_secret "$OCI_SECRET_ENCRYPTION")
```

### Objetivo

Criptografia interna.

### Requisitos

* 64 chars
* hexadecimal
* 256 bits

### Validação

```bash id="vars36"
openssl rand -hex 32
```

---

## SALT

```bash id="vars37"
export SALT=$(get_secret "$OCI_SECRET_SALT")
```

### Objetivo

Salt interno utilizado pelo Langfuse.

---

# ⚡ Redis

---

## REDIS_HOST

```bash id="vars38"
export REDIS_HOST="${APP_NAME}-redis"
```

### Objetivo

Hostname Redis interno Kubernetes.

---

## REDIS_PORT

```bash id="vars39"
export REDIS_PORT="6379"
```

### Objetivo

Porta Redis.

---

# 📊 ClickHouse

---

## CLICKHOUSE_URL

```bash id="vars40"
export CLICKHOUSE_URL="http://${APP_NAME}-clickhouse:8123"
```

### Objetivo

Endpoint HTTP ClickHouse.

---

## CLICKHOUSE_USER

```bash id="vars41"
export CLICKHOUSE_USER="default"
```

### Objetivo

Usuário ClickHouse.

---

## CLICKHOUSE_MIGRATION_URL

```bash id="vars42"
export CLICKHOUSE_MIGRATION_URL="clickhouse://${APP_NAME}-clickhouse:9000"
```

### Objetivo

Endpoint nativo ClickHouse utilizado pelas migrations.

---

## CLICKHOUSE_CLUSTER_ENABLED

```bash id="vars43"
export CLICKHOUSE_CLUSTER_ENABLED="false"
```

### Objetivo

Define se ClickHouse opera em cluster distribuído.

---

# ☁️ OCI Object Storage

---

## LANGFUSE_S3_EVENT_UPLOAD_BUCKET

```bash id="vars44"
export LANGFUSE_S3_EVENT_UPLOAD_BUCKET="langfuse-events"
```

### Objetivo

Bucket de eventos.

---

## LANGFUSE_S3_EVENT_UPLOAD_REGION

```bash id="vars45"
export LANGFUSE_S3_EVENT_UPLOAD_REGION="${OCI_REGION}"
```

### Objetivo

Região do bucket.

---

## LANGFUSE_S3_EVENT_UPLOAD_ENDPOINT

```bash id="vars46"
export LANGFUSE_S3_EVENT_UPLOAD_ENDPOINT="https://${OCI_NAMESPACE}.compat.objectstorage.${OCI_REGION}.oraclecloud.com"
```

### Objetivo

Endpoint S3-compatible OCI.

---

## LANGFUSE_USE_OCI_NATIVE_OBJECT_STORAGE

```bash id="vars47"
export LANGFUSE_USE_OCI_NATIVE_OBJECT_STORAGE="true"
```

### Objetivo

Ativa integração OCI nativa.

---

## LANGFUSE_OCI_AUTH_TYPE

```bash id="vars48"
export LANGFUSE_OCI_AUTH_TYPE="instance_principal"
```

### Objetivo

Utiliza Instance Principal em vez de Access Key.

### Benefício

Não precisamos:

* access key
* secret key

---

# 📌 Resumo Geral

## Principais categorias

| Categoria      | Variáveis                       |
| -------------- | ------------------------------- |
| OCI            | OCI_REGION, OCI_PROFILE         |
| Registry       | REGISTRY, IMAGE_REPOSITORY      |
| Kubernetes     | APP_NAME, K8S_NAMESPACE         |
| PostgreSQL     | DATABASE_URL                    |
| Redis          | REDIS_AUTH                      |
| ClickHouse     | CLICKHOUSE_URL                  |
| Security       | NEXTAUTH_SECRET, ENCRYPTION_KEY |
| OCI Vault      | OCI_SECRET_*                    |
| Object Storage | LANGFUSE_S3_*                   |

---

# 🚀 Fluxo Completo

```text id="vars49"
OCI Vault
   ↓
get_secret()
   ↓
export VARIAVEIS
   ↓
envsubst
   ↓
final.yaml
   ↓
kubectl apply
```

---

# ✅ Resultado Final

Ao final:

* todas variáveis ficam centralizadas
* secrets permanecem seguros
* deployment torna-se parametrizável
* ambiente fica reproduzível
* stack torna-se adequada para CI/CD e produção


---

# 🔧 Substituição dinâmica

O script utiliza:

```bash
envsubst < langfuse_dest.yaml > final.yaml
```

---

# 📌 O que acontece

O Linux substitui:

```yaml
${DB_PASSWORD}
```

por:

```yaml
langfuse123
```

---

# 📌 Resultado

É gerado:

```text
final.yaml
```

com:

* todas variáveis preenchidas
* senhas reais
* URLs reais
* tags reais
* namespace real

---

# ☸️ Etapa 6 — Deployment Kubernetes

## 📌 Objetivo

Aplicar:

* Deployments
* Services
* StatefulSets
* PVCs
* HPAs

no OKE.

>**Nota:** É importante frisar que em regime produtivo, as etapas de gerar imagens, setar variaveis e executar a atualização no YAML de deployment final não são etapas necessárias. Pressupõe-se que as variáveis e as imagens já estejam preparadas para a execução de uma esteira produtiva. Estas etapas anteriores apenas servem para este tutorial como ilustração de como os recursos de OCI se comportam. 

---

# 🔧 Comando

```bash
kubectl apply -f final.yaml
```

>**Nota:** O arquivo de deployment final.yaml publica a solução em um endpoint com DNS: https://langfuse.seu. Lembre-se de alterar

---

# 📌 Resultado

O Kubernetes:

* cria pods
* cria services
* cria volumes
* cria load balancer
* sobe Langfuse

---

# 🔒 Benefícios dessa Arquitetura

## Segurança

Nenhuma senha:

* hardcoded
* commitada
* salva no YAML final do template

---

## Governança

Secrets centralizados no OCI Vault.

---

## Escalabilidade

O mesmo template pode ser usado para:

* DEV
* QA
* PROD

mudando apenas:

* variáveis
* secrets
* tags

---

## Reutilização

O deployment torna-se:

* parametrizável
* automatizável
* CI/CD friendly

---

# 🚀 Fluxo Final Consolidado

```text
1. mirror_images.sh
   ↓
2. create_secrets.sh
   ↓
3. capturar OCIDs
   ↓
4. set_var.sh
   ↓
5. envsubst
   ↓
6. final.yaml
   ↓
7. kubectl apply
```

---

# Testando a Solução

Abra o browser para validar a UI do Langfuse. O Load-Balancer foi criado para uma subnet privada, nada impede de se criar em uma subnet pública.
Para poder acessar talvez seja necessário executar o ssh em túnel como o exemplo:

    ssh -i /mnt/d/Dropbox/ORACLE/sshkeybundle/Privatekey.pem opc@129.158.211.144 -L 8087:10.0.20.44:80


E depois acessar via browser com:

    http://localhost:8087

![img.png](images/img.png)


![img_1.png](images/img_1.png)

![img_2.png](images/img_2.png)


---

# ✅ Resultado Final

Ao final:

* imagens privadas OCI
* secrets centralizados
* deployment automatizado
* stack observável
* Langfuse operacional no OKE
* arquitetura segura e escalável


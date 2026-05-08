# Configuração TLS/SSL para PostgreSQL e Redis no Langfuse (OCI)

## Objetivo

Este documento descreve como configurar comunicação segura via TLS/SSL entre:

* Langfuse
* Langfuse Worker
* PostgreSQL gerenciado na OCI
* Redis gerenciado na OCI

O objetivo é garantir:

* criptografia em trânsito
* proteção contra interceptação de tráfego
* compliance corporativo
* aderência a políticas de segurança enterprise
* suporte a ambientes privados e híbridos

---

# Arquitetura

```text
Langfuse Pod
    ↓ TLS
OCI PostgreSQL

Langfuse Worker
    ↓ TLS
OCI Redis
```

---

# Conceitos Importantes

## TLS

TLS (Transport Layer Security) criptografa a comunicação entre cliente e servidor.

Benefícios:

* impede sniffing de rede
* protege senhas
* protege payloads
* protege traces e eventos
* evita MITM (Man In The Middle)

---

# PostgreSQL TLS

O PostgreSQL suporta TLS nativamente.

O cliente pode:

* validar certificado
* validar hostname
* exigir criptografia

---

# Redis TLS

O Redis gerenciado da OCI suporta TLS.

A conexão é realizada normalmente em:

```text
6380
```

em vez da porta padrão:

```text
6379
```

---

# Estratégia Recomendada

## PostgreSQL

Usar:

```text
sslmode=require
```

ou idealmente:

```text
sslmode=verify-full
```

---

## Redis

Usar:

```text
rediss://
```

em vez de:

```text
redis://
```

---

# PostgreSQL — Configuração TLS

## DATABASE_URL sem TLS

```yaml
DATABASE_URL=postgresql://langfuse:password@postgres.internal:5432/langfuse
```

---

# DATABASE_URL com TLS

## sslmode=require

```yaml
DATABASE_URL=postgresql://langfuse:password@postgres.internal:5432/langfuse?sslmode=require
```

---

# sslmode disponíveis

| Valor       | Descrição            |
| ----------- | -------------------- |
| disable     | sem TLS              |
| allow       | tenta TLS            |
| prefer      | prefere TLS          |
| require     | exige TLS            |
| verify-ca   | valida CA            |
| verify-full | valida CA + hostname |

---

# Recomendação Enterprise

Usar:

```text
sslmode=verify-full
```

---

# Exemplo Enterprise PostgreSQL

```yaml
DATABASE_URL=postgresql://langfuse:password@postgres.internal:5432/langfuse?sslmode=verify-full
```

---

# Certificado CA PostgreSQL

Para verify-full normalmente é necessário:

* CA bundle
* certificado raiz
* trust chain

---

# Montando certificado CA no Kubernetes

## Secret TLS

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-ca
  namespace: langfuse

type: Opaque
stringData:
  ca.crt: |
    -----BEGIN CERTIFICATE-----
    ...
    -----END CERTIFICATE-----
```

---

# Volume Mount PostgreSQL CA

```yaml
volumeMounts:
  - name: postgres-ca
    mountPath: /etc/ssl/postgres
    readOnly: true
```

---

# Volume PostgreSQL CA

```yaml
volumes:
  - name: postgres-ca
    secret:
      secretName: postgres-ca
```

---

# DATABASE_URL com CA

```yaml
DATABASE_URL=postgresql://langfuse:password@postgres.internal:5432/langfuse?sslmode=verify-full&sslrootcert=/etc/ssl/postgres/ca.crt
```

---

# Redis TLS

# REDIS_URL sem TLS

```yaml
REDIS_URL=redis://:password@redis.internal:6379
```

---

# REDIS_URL com TLS

```yaml
REDIS_URL=rediss://:password@redis.internal:6380
```

---

# Diferença redis:// vs rediss://

| Prefixo   | TLS |
| --------- | --- |
| redis://  | Não |
| rediss:// | Sim |

---

# Certificado Redis CA

## Secret Redis

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: redis-ca
  namespace: langfuse

type: Opaque
stringData:
  ca.crt: |
    -----BEGIN CERTIFICATE-----
    ...
    -----END CERTIFICATE-----
```

---

# Volume Mount Redis

```yaml
volumeMounts:
  - name: redis-ca
    mountPath: /etc/ssl/redis
    readOnly: true
```

---

# Volume Redis

```yaml
volumes:
  - name: redis-ca
    secret:
      secretName: redis-ca
```

---

# Variáveis Redis TLS

```yaml
env:

  - name: REDIS_URL
    value: "rediss://:password@redis.internal:6380"

  - name: NODE_EXTRA_CA_CERTS
    value: "/etc/ssl/redis/ca.crt"
```

---

# NODE_EXTRA_CA_CERTS

## Objetivo

Permite ao Node.js confiar na CA customizada.

Isso é importante quando:

* Redis usa CA privada
* PostgreSQL usa CA privada
* OCI usa certificados internos
* ambientes corporativos usam PKI própria

---

# Configuração Completa — Langfuse

```yaml
containers:
  - name: langfuse

    image: langfuse:latest

    env:

      - name: DATABASE_URL
        value: "postgresql://langfuse:password@postgres.internal:5432/langfuse?sslmode=verify-full&sslrootcert=/etc/ssl/postgres/ca.crt"

      - name: REDIS_URL
        value: "rediss://:password@redis.internal:6380"

      - name: NODE_EXTRA_CA_CERTS
        value: "/etc/ssl/redis/ca.crt"

    volumeMounts:

      - name: postgres-ca
        mountPath: /etc/ssl/postgres
        readOnly: true

      - name: redis-ca
        mountPath: /etc/ssl/redis
        readOnly: true

volumes:

  - name: postgres-ca
    secret:
      secretName: postgres-ca

  - name: redis-ca
    secret:
      secretName: redis-ca
```

---

# Configuração Completa — Worker

```yaml
containers:
  - name: worker

    env:

      - name: DATABASE_URL
        value: "postgresql://langfuse:password@postgres.internal:5432/langfuse?sslmode=verify-full&sslrootcert=/etc/ssl/postgres/ca.crt"

      - name: REDIS_URL
        value: "rediss://:password@redis.internal:6380"

      - name: NODE_EXTRA_CA_CERTS
        value: "/etc/ssl/redis/ca.crt"
```

---

# OCI PostgreSQL — Observações

Dependendo do serviço OCI:

* PostgreSQL pode exigir TLS
* pode fornecer CA própria
* pode exigir whitelist de cipher suites

---

# OCI Redis — Observações

OCI Cache with Redis normalmente:

* já expõe TLS
* usa porta 6380
* exige autenticação
* suporta CA pública

---

# Teste PostgreSQL TLS

## Dentro do pod

```bash
psql "postgresql://langfuse:password@postgres.internal:5432/langfuse?sslmode=require"
```

---

# Validar SSL PostgreSQL

```sql
SHOW ssl;
```

Resultado esperado:

```text
on
```

---

# Teste Redis TLS

```bash
redis-cli \
  -h redis.internal \
  -p 6380 \
  --tls \
  -a password
```

---

# Validar certificado Redis

```bash
openssl s_client -connect redis.internal:6380
```

---

# Segurança Recomendada

## Nunca usar

```text
sslmode=disable
```

em produção.

---

# Recomendação OCI

## Rede privada

Preferencialmente:

* OKE privado
* PostgreSQL privado
* Redis privado
* Service Gateway
* sem IP público

---

# OCI Vault

Idealmente:

* senhas no OCI Vault
* certificados no OCI Vault
* integração via External Secrets Operator

---

# Melhor prática enterprise

## mTLS

Em ambientes críticos pode ser usado:

* mutual TLS
* client certificates
* autenticação bilateral

---

# Troubleshooting

# PostgreSQL

## certificate verify failed

Normalmente:

* CA incorreta
* hostname inválido
* sslrootcert ausente

---

# Redis

## self signed certificate

Normalmente:

* NODE_EXTRA_CA_CERTS ausente
* CA não montada

---

# timeout TLS

Verificar:

* NSG
* Security List
* rota privada
* porta 6380 liberada

---

# Benefícios da Configuração TLS

## Segurança

Protege:

* traces
* prompts
* tokens
* payloads
* credenciais

---

# Compliance

Ajuda em:

* LGPD
* ISO 27001
* SOC2
* PCI

---

# Arquitetura Recomendada Final

```text
OKE Cluster
   ├── Langfuse
   ├── Worker
   └── ClickHouse

TLS
   ↓
OCI PostgreSQL

TLS
   ↓
OCI Redis

Object Storage
   ↓
OCI S3 Compatible API
```

---

# Referências

OCI PostgreSQL:

[https://docs.oracle.com/en-us/iaas/Content/postgresql/home.htm](https://docs.oracle.com/en-us/iaas/Content/postgresql/home.htm)

OCI Redis:

[https://docs.oracle.com/en-us/iaas/Content/redis/home.htm](https://docs.oracle.com/en-us/iaas/Content/redis/home.htm)

PostgreSQL SSL:

[https://www.postgresql.org/docs/current/libpq-ssl.html](https://www.postgresql.org/docs/current/libpq-ssl.html)

Redis TLS:

[https://redis.io/docs/manual/security/encryption/](https://redis.io/docs/manual/security/encryption/)

## Mutual TLS (mTLS)

### 📚 O que é mTLS?

**Mutual TLS (mTLS)** é como um **aperto de mão secreto duplo** 🤝 - ambos os lados precisam se identificar antes de conversar!

```
┌─────────────┐                    ┌─────────────┐
│   Cliente   │ ◄──── mTLS ────► │  Servidor   │
│ (tem cert.) │                    │ (tem cert.) │
└─────────────┘                    └─────────────┘
    ↓                                    ↓
  "Aqui está                          "Aqui está
   meu crachá!"                        meu crachá!"
```

### 🎯 Como funciona passo a passo

#### 1️⃣ **Sem mTLS (comunicação normal)**
```
Cliente ──────► Servidor
        HTTP
    (sem segurança)
```

#### 2️⃣ **Com TLS tradicional**
```
Cliente ──────► Servidor
        HTTPS
    (só o servidor 
    se identifica)
```

#### 3️⃣ **Com mTLS no Istio**
```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│   Pod A  │────►│  Envoy   │────►│  Envoy   │────►│   Pod B  │
└──────────┘     └──────────┘     └──────────┘     └──────────┘
                  ↓                  ↓
              Certificado         Certificado
                do A                do B
```

### ⏱️ Impacto de Performance do mTLS

```
┌─────────────────────────────────────────────┐
│         Latência Adicional do mTLS          │
├─────────────────────────────────────────────┤
│                                             │
│  Sem TLS:        ━━━━━━━━━━━ 10ms         │
│                                             │
│  Com TLS:        ━━━━━━━━━━━━━━ 12ms      │
│                         +2ms               │
│                                             │
│  Com mTLS:       ━━━━━━━━━━━━━━━━ 15ms    │
│                         +5ms               │
│                                             │
│  mTLS (cache):   ━━━━━━━━━━━━━ 11ms       │
│                         +1ms               │
└─────────────────────────────────────────────┘

📊 Overhead típico:
• Primeira conexão: +3-5ms
• Conexões subsequentes (com cache): +0.5-1ms
• CPU adicional: ~10-15%
```

### 🔧 Todas as Configurações de mTLS

#### **1. PeerAuthentication - Configurações Completas**

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  # Seletor específico (opcional)
  selector:
    matchLabels:
      app: minha-app
      version: v1
  
  # Modo global
  mtls:
    mode: STRICT  # STRICT | PERMISSIVE | DISABLE
  
  # Configurações por porta
  portLevelMtls:
    8080:
      mode: DISABLE     # HTTP na porta 8080
    8443:
      mode: STRICT      # HTTPS obrigatório na 8443
    9090:
      mode: PERMISSIVE  # Flexível na 9090
```

**Visualização dos Modos por Porta:**
```
┌──────────────────────────────────────┐
│          Pod com Multi-Portas        │
├──────────────────────────────────────┤
│                                      │
│  :8080 ──► DISABLE   🔓 (plaintext) │
│  :8443 ──► STRICT    🔒 (mTLS only) │
│  :9090 ──► PERMISSIVE 🔐 (ambos)    │
│                                      │
└──────────────────────────────────────┘
```

#### **2. DestinationRule - Configurações de Cliente**

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: configuracao-cliente
spec:
  host: meu-servico.production.svc.cluster.local
  
  # Configuração de tráfego
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL  # Opções abaixo
      # mode: DISABLE       - Sem TLS
      # mode: SIMPLE        - TLS unidirecional
      # mode: MUTUAL        - mTLS com certs customizados
      # mode: ISTIO_MUTUAL  - mTLS automático do Istio
      
      # Para MUTUAL mode (certificados customizados)
      clientCertificate: /etc/certs/client-cert.pem
      privateKey: /etc/certs/client-key.pem
      caCertificates: /etc/certs/ca-cert.pem
      
      # Configurações avançadas
      sni: meu-servico.exemplo.com
      subjectAltNames:
      - meu-servico.production
      - meu-servico.staging
      
      # Versões TLS suportadas
      minProtocolVersion: TLSV1_2  # TLSV1_0 | TLSV1_1 | TLSV1_2 | TLSV1_3
      maxProtocolVersion: TLSV1_3
    
    # Configurações de conexão
    connectionPool:
      tcp:
        maxConnections: 100
        connectTimeout: 5s
        tcpKeepAlive:
          time: 600s
          interval: 30s
          probes: 10
      http:
        http1MaxPendingRequests: 100
        http2MaxRequests: 100
        maxRequestsPerConnection: 2
        h2UpgradePolicy: UPGRADE  # UPGRADE | DO_NOT_UPGRADE | AUTOMATIC
```

### 📋 Headers Avançados no Istio

#### **Headers de Segurança Automáticos**

```yaml
apiVersion: networking.istio.io/v1beta1
kind: EnvoyFilter
metadata:
  name: security-headers
spec:
  workloadSelector:
    labels:
      app: minha-app
  configPatches:
  - applyTo: HTTP_FILTER
    match:
      context: SIDECAR_INBOUND
      listener:
        filterChain:
          filter:
            name: "envoy.filters.network.http_connection_manager"
    patch:
      operation: INSERT_BEFORE
      value:
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua
          inline_code: |
            function envoy_on_request(request_handle)
              -- Headers de segurança
              request_handle:headers():add("x-frame-options", "DENY")
              request_handle:headers():add("x-content-type-options", "nosniff")
              request_handle:headers():add("x-xss-protection", "1; mode=block")
              
              -- Headers mTLS
              local cert = request_handle:connection():ssl():peerCertificatePresented()
              if cert then
                request_handle:headers():add("x-client-cert-present", "true")
                request_handle:headers():add("x-client-cert-sha", 
                  request_handle:connection():ssl():sha256PeerCertificateDigest())
              end
            end
```

**Fluxo de Headers com mTLS:**
```
┌────────────────────────────────────────────────┐
│              Headers Injetados                  │
├────────────────────────────────────────────────┤
│                                                │
│  Requisição Original:                          │
│  ┌──────────────────┐                         │
│  │ GET /api         │                         │
│  │ Host: app        │                         │
│  └──────────────────┘                         │
│           ↓                                    │
│  Após Istio + mTLS:                           │
│  ┌─────────────────────────────────────┐     │
│  │ GET /api                            │     │
│  │ Host: app                           │     │
│  │ x-forwarded-client-cert: Hash=xxx   │     │
│  │ x-forwarded-proto: https            │     │
│  │ x-request-id: uuid-123              │     │
│  │ x-b3-traceid: trace-456             │     │
│  │ x-client-cert-present: true         │     │
│  │ x-frame-options: DENY               │     │
│  │ x-envoy-peer-metadata: {...}        │     │
│  └─────────────────────────────────────┘     │
└────────────────────────────────────────────────┘
```

### 🛡️ Políticas de Autorização Avançadas

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: politica-avancada
spec:
  selector:
    matchLabels:
      app: servico-critico
  
  # Regras de DENY (processadas primeiro)
  action: DENY
  rules:
  - to:
    - operation:
        methods: ["DELETE", "PUT"]
    when:
    - key: source.namespace
      notValues: ["admin", "system"]
    
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: politica-allow
spec:
  selector:
    matchLabels:
      app: servico-critico
  
  # Regras de ALLOW
  action: ALLOW
  rules:
  # Regra 1: Admin tem acesso total
  - from:
    - source:
        principals: ["cluster.local/ns/admin/sa/admin-service-account"]
    to:
    - operation:
        methods: ["*"]
  
  # Regra 2: Usuários autenticados podem ler
  - from:
    - source:
        namespaces: ["production", "staging"]
    to:
    - operation:
        methods: ["GET", "HEAD", "OPTIONS"]
    when:
    # Condições baseadas em headers
    - key: request.headers[x-user-role]
      values: ["user", "admin", "viewer"]
    # Condições baseadas em JWT
    - key: request.auth.claims[role]
      values: ["authenticated"]
    # Condições baseadas em IP
    - key: source.ip
      values: ["10.0.0.0/8", "172.16.0.0/12"]
  
  # Regra 3: Webhook específico
  - from:
    - source:
        ipBlocks: ["203.0.113.0/24"]
    to:
    - operation:
        paths: ["/webhook/*"]
        methods: ["POST"]
    when:
    - key: request.headers[x-webhook-secret]
      values: ["secret-token-123"]
```

### 🔄 Configurações de Retry e Timeout

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: configuracao-resiliente
spec:
  hosts:
  - meu-servico
  http:
  - timeout: 10s  # Timeout global
    retries:
      attempts: 3
      perTryTimeout: 3s
      retryOn: 5xx,reset,connect-failure,refused-stream
      retryRemoteLocalities: true
    
    # Headers de controle
    headers:
      request:
        set:
          x-request-start: "%START_TIME%"
          x-envoy-max-retries: "3"
          x-envoy-retry-on: "5xx"
        add:
          x-custom-header: "value"
        remove:
        - x-internal-debug
      
      response:
        set:
          x-response-time: "%DURATION%"
          x-upstream-service-time: "%RESP(x-envoy-upstream-service-time)%"
        add:
          x-served-by: "istio-proxy"
```

### 📊 Monitoramento e Debug de mTLS

#### **Comandos Úteis para Debug**

```bash
# 1. Verificar status do mTLS
istioctl authn tls-check <pod-name> <service-name>.<namespace>.svc.cluster.local

# Saída esperada:
# HOST:PORT                                    STATUS     SERVER     CLIENT     AUTHN POLICY     DESTINATION RULE
# service.namespace.svc.cluster.local:8080    OK         STRICT     ISTIO_MUTUAL     default/ns     service-dr

# 2. Ver certificados
istioctl proxy-config secret <pod-name> -n <namespace>

# 3. Logs detalhados
kubectl logs <pod-name> -c istio-proxy -n <namespace> | grep -i tls

# 4. Métricas
kubectl exec <pod-name> -c istio-proxy -- curl -s localhost:15000/stats/prometheus | grep tls
```

**Dashboard de Monitoramento:**
```
┌─────────────────────────────────────────────────┐
│           Métricas mTLS em Tempo Real           │
├─────────────────────────────────────────────────┤
│                                                  │
│  📈 Conexões TLS Ativas:        1,234          │
│  ✅ Handshakes Bem-sucedidos:   99.8%          │
│  ❌ Falhas de Certificado:      0.2%           │
│  ⏱️ Latência média (p50):       1.2ms          │
│  ⏱️ Latência média (p99):       5.8ms          │
│  🔄 Certificados Renovados:     12/hora        │
│  📦 Overhead de CPU:            12%            │
│  💾 Uso de Memória (cache):     45MB           │
│                                                  │
│  Gráfico de Latência:                           │
│  6ms ┤     ╭─╮                                 │
│  4ms ┤  ╭──╯ ╰─╮    ╭─╮                      │
│  2ms ┤──╯      ╰────╯ ╰──────                │
│      └────────────────────────────────          │
│       10:00  10:30  11:00  11:30  12:00        │
└─────────────────────────────────────────────────┘
```

### 🚀 Otimizações de Performance

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: istio-custom-config
  namespace: istio-system
data:
  mesh: |
    defaultConfig:
      # Otimizações de TLS
      proxyStatsMatcher:
        inclusionRegexps:
        - ".*outlier_detection.*"
        - ".*circuit_breakers.*"
        - ".*tls.*"
      
      # Cache de sessão TLS
      sds:
        token_path: /var/run/secrets/tokens
        enable_cache: true
        cache_size: 1000
        cache_ttl: 3600s
      
      # Configurações de performance
      concurrency: 2  # Threads do Envoy
      
    # Configuração global de mTLS
    defaultHttpRetryPolicy:
      numRetries: 2
    
    # Tempo de vida dos certificados
    defaultWorkloadCertTTL: 24h
    maxWorkloadCertTTL: 90d
```

### 🎓 Melhores Práticas e Dicas

```
┌──────────────────────────────────────────────────┐
│            Checklist de Implementação             │
├──────────────────────────────────────────────────┤
│                                                   │
│  ✅ Desenvolvimento                              │
│  □ Começar com PERMISSIVE                        │
│  □ Testar conectividade                          │
│  □ Migrar gradualmente para STRICT               │
│                                                   │
│  ✅ Staging                                      │
│  □ STRICT em serviços críticos                   │
│  □ Monitorar latência                            │
│  □ Configurar alertas                            │
│                                                   │
│  ✅ Produção                                     │
│  □ STRICT por padrão                             │
│  □ PERMISSIVE apenas em migrações                │
│  □ Rotation automática de certificados           │
│  □ Backup de configurações                       │
│                                                   │
│  ⚠️ Cuidados                                     │
│  • Não misturar STRICT e DISABLE no mesmo NS    │
│  • Sempre testar com istioctl analyze            │
│  • Monitorar CPU/Memória após ativar mTLS       │
│  • Configurar timeouts apropriados               │
└──────────────────────────────────────────────────┘
```

### 🔥 Troubleshooting Comum

```yaml
# Problema 1: Connection Refused
# Solução: Verificar PeerAuthentication
istioctl analyze -n <namespace>

# Problema 2: Certificado Expirado
# Solução: Verificar e renovar
kubectl get secret -n istio-system istio-ca-secret -o json | \
  jq -r '.data["ca-cert.pem"]' | base64 -d | \
  openssl x509 -text -noout

# Problema 3: Alta Latência
# Solução: Ajustar cache
apiVersion: v1
kind: ConfigMap
metadata:
  name: istio-ca-config
data:
  # Aumentar cache
  CITADEL_CACHE_SIZE: "5000"
  CITADEL_CACHE_TTL: "7200"
```

### 📈 Exemplo Completo: Sistema Bancário

```yaml
# Namespace com mTLS obrigatório
apiVersion: v1
kind: Namespace
metadata:
  name: banking
  labels:
    istio-injection: enabled
---
# mTLS STRICT para todo namespace
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: banking
spec:
  mtls:
    mode: STRICT
---
# Serviço de Transações
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: transaction-service
  namespace: banking
spec:
  hosts:
  - transaction
  http:
  - match:
    - headers:
        x-transaction-type:
          exact: high-value
    headers:
      request:
        set:
          x-security-level: "maximum"
          x-audit-required: "true"
          x-encryption: "AES-256"
    timeout: 5s
    retries:
      attempts: 1  # Sem retry para transações
  - match:
    - headers:
        x-transaction-type:
          exact: standard
    headers:
      request:
        set:
          x-security-level: "standard"
    timeout: 10s
    retries:
      attempts: 3
---
# Política de Autorização
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: transaction-auth
  namespace: banking
spec:
  selector:
    matchLabels:
      app: transaction
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/banking/sa/authorized-service"]
    to:
    - operation:
        methods: ["POST"]
        paths: ["/api/v1/transaction/*"]
    when:
    - key: request.headers[x-api-key]
      values: ["valid-api-key-*"]
    - key: request.headers[x-transaction-signature]
      values: ["*"]  # Deve estar presente
```

**Arquitetura Visual do Sistema Bancário:**
```
┌────────────────────────────────────────────────────────────┐
│                    Banking Namespace (mTLS STRICT)          │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  🏦 Frontend          💰 Transaction         🔐 Vault      │
│  ┌─────────┐         ┌─────────┐           ┌─────────┐    │
│  │   Pod   │──mTLS──►│   Pod   │──mTLS────►│   Pod   │    │
│  │ :8080   │         │ :8443   │           │ :8200   │    │
│  └─────────┘         └─────────┘           └─────────┘    │
│       │                    │                     │         │
│       ↓                    ↓                     ↓         │
│  Headers:             Headers:              Headers:       │
│  x-user-id           x-transaction-id      x-vault-token   │
│  x-session           x-security-level      x-encryption    │
│                      x-audit-required                      │
│                                                             │
│  📊 Métricas:                                              │
│  • Latência mTLS: +2ms                                     │
│  • CPU Overhead: 15%                                       │
│  • Handshakes/sec: 450                                     │
│  • Cache Hit Rate: 98.5%                                   │
└────────────────────────────────────────────────────────────┘
```


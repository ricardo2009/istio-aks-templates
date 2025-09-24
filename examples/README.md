# 🚀 Exemplos de Configuração - Istio Templates

Este diretório contém exemplos práticos de como usar os templates Istio em diferentes cenários.

## 📁 Estrutura de Exemplos

- `basic-webapp/` - Aplicação web simples com Gateway e VirtualService
- `microservices/` - Conjunto de microserviços com service mesh completo
- `security-focused/` - Configuração com mTLS e políticas de segurança rigorosas
- `canary-deployment/` - Deployment canário com traffic splitting
- `multi-cluster/` - Configuração para múltiplos clusters

## 🎯 Como Usar os Exemplos

1. **Copie** o exemplo mais próximo do seu caso de uso
2. **Adapte** o `values.yaml` para sua aplicação
3. **Teste** com o preprocessor: `./scripts/preprocess-templates.sh`
4. **Deploy** usando os workflows do GitHub Actions

## 📚 Exemplos Disponíveis

### 1. Basic Web App
```yaml
# Configuração mínima para uma aplicação web
global:
  app: "my-webapp"
  version: "1.0.0"

trafficManagement:
  gateway:
    enabled: true
    hosts: ["webapp.company.com"]
```

### 2. Microservices Architecture
```yaml
# Configuração para múltiplos serviços
global:
  app: "ecommerce"
  version: "2.1.0"

trafficManagement:
  virtualService:
    enabled: true
    routes:
      - match: [{uri: {prefix: "/api/users"}}]
        route: [{destination: {host: "user-service"}}]
      - match: [{uri: {prefix: "/api/orders"}}]
        route: [{destination: {host: "order-service"}}]
```

### 3. Security First
```yaml
# Máxima segurança com mTLS e políticas
security:
  peerAuthentication:
    enabled: true
    mtlsMode: "STRICT"
  authorizationPolicy:
    enabled: true
    defaultAction: "DENY"
```

> 💡 **Dica**: Consulte os diretórios específicos para configurações completas de cada exemplo.
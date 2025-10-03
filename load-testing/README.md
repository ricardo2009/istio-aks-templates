# Load Testing Environment - 600k RPS

Este diretório contém a infraestrutura e ferramentas para testes de carga de alta performance, projetados para atingir **600.000 requisições por segundo (600k RPS)** na plataforma e-commerce.

## 🎯 Objetivos de Performance

### Metas Principais
- **Throughput**: 600.000 RPS sustentados
- **Latência P95**: < 100ms
- **Latência P99**: < 200ms
- **Taxa de Erro**: < 0.01%
- **Disponibilidade**: 99.99%

### Cenários de Teste
1. **Baseline Test**: Validação de funcionalidade básica
2. **Load Test**: Carga normal esperada (100k RPS)
3. **Stress Test**: Carga máxima suportada (600k RPS)
4. **Spike Test**: Picos de tráfego (800k RPS por 5 minutos)
5. **Endurance Test**: Teste de resistência (24 horas a 300k RPS)

## 🏗️ Arquitetura de Load Testing

### Componentes Principais

```
load-testing/
├── infrastructure/          # Terraform para cluster de load testing
├── tools/                  # Ferramentas de teste (K6, Artillery, NBomber)
├── scenarios/              # Cenários de teste específicos
├── data/                   # Dados de teste e fixtures
├── scripts/                # Scripts de automação
├── monitoring/             # Dashboards e alertas específicos
├── results/                # Resultados e relatórios
└── ci-cd/                  # Pipelines de teste automatizado
```

### Cluster de Load Testing
- **Nodes**: 20x Standard_D16s_v3 (16 vCPUs, 64GB RAM cada)
- **Total**: 320 vCPUs, 1.28TB RAM
- **Network**: Accelerated Networking habilitado
- **Storage**: Premium SSD para logs e resultados

### Ferramentas de Teste
1. **K6**: Testes de carga JavaScript/TypeScript
2. **Artillery**: Testes de carga Node.js
3. **NBomber**: Testes de carga .NET
4. **Vegeta**: Testes de carga Go
5. **Custom Tools**: Ferramentas específicas em Python/Go

## 🚀 Estratégia de Escalonamento

### Distribuição de Carga
- **Frontend**: 150k RPS (25%)
- **API Gateway**: 600k RPS (100%)
- **Product Service**: 300k RPS (50%)
- **User Service**: 120k RPS (20%)
- **Order Service**: 60k RPS (10%)
- **Payment Service**: 30k RPS (5%)

### Padrões de Tráfego
- **Read Heavy**: 80% GET, 20% POST/PUT/DELETE
- **Cache Hit Rate**: 85% para produtos, 60% para usuários
- **Geographic Distribution**: 40% US, 30% EU, 20% APAC, 10% Others

## 📊 Monitoramento e Métricas

### Métricas Coletadas
- **Application Metrics**: Latência, throughput, taxa de erro
- **Infrastructure Metrics**: CPU, memória, rede, disco
- **Istio Metrics**: Service mesh performance
- **Database Metrics**: CosmosDB RU/s, latência, throttling
- **Cache Metrics**: Redis hit rate, latência, memória

### Dashboards
- **Real-time Performance**: Métricas em tempo real
- **Historical Analysis**: Análise de tendências
- **Error Analysis**: Análise detalhada de erros
- **Resource Utilization**: Utilização de recursos

## 🔧 Configuração e Execução

### Pré-requisitos
1. Cluster AKS de load testing provisionado
2. Ferramentas de teste instaladas
3. Dados de teste preparados
4. Monitoramento configurado

### Execução Rápida
```bash
# Provisionar infraestrutura
cd infrastructure
terraform apply

# Executar teste básico
cd ../scripts
./run-baseline-test.sh

# Executar teste de 600k RPS
./run-stress-test.sh --target-rps=600000 --duration=30m

# Gerar relatório
./generate-report.sh --test-id=stress-600k
```

### Execução Avançada
```bash
# Teste customizado
./run-custom-test.sh \
  --scenario=ecommerce-peak \
  --target-rps=600000 \
  --duration=1h \
  --ramp-up=10m \
  --ramp-down=5m \
  --users=50000 \
  --regions=us-east,eu-west,asia-southeast

# Teste de endurance
./run-endurance-test.sh \
  --target-rps=300000 \
  --duration=24h \
  --check-interval=5m
```

## 📈 Otimizações Implementadas

### Aplicação
- **Connection Pooling**: Pools otimizados para CosmosDB e Redis
- **Caching Strategy**: Multi-layer caching (L1: In-memory, L2: Redis, L3: CDN)
- **Async Processing**: Processamento assíncrono para operações pesadas
- **Circuit Breakers**: Proteção contra cascading failures

### Infraestrutura
- **Node Optimization**: Nodes otimizados para alta performance
- **Network Optimization**: Accelerated networking e proximity placement
- **Storage Optimization**: Premium SSD com high IOPS
- **Kubernetes Optimization**: Configurações otimizadas do kubelet

### Istio Service Mesh
- **Sidecar Optimization**: Configurações otimizadas do Envoy
- **Traffic Management**: Load balancing e circuit breaking
- **Security**: mTLS otimizado para performance
- **Observability**: Telemetria otimizada

## 🎛️ Configurações de Performance

### NGINX Ingress
- **Worker Processes**: Auto (baseado em CPU cores)
- **Worker Connections**: 16384 por worker
- **Keepalive**: 10000 requests por connection
- **Buffer Sizes**: Otimizados para alta throughput

### KEDA Autoscaling
- **Scaling Triggers**: Múltiplas métricas (RPS, CPU, Memory, Queue Length)
- **Scaling Speed**: Agressivo para scale-up, conservador para scale-down
- **Min/Max Replicas**: Configurado por serviço baseado em capacity planning

### CosmosDB
- **Provisioned Throughput**: 100,000 RU/s por container
- **Consistency Level**: Session (balance entre performance e consistência)
- **Indexing Policy**: Otimizado para queries específicas
- **Partitioning**: Estratégia otimizada por workload

## 🔍 Análise de Resultados

### Relatórios Gerados
1. **Performance Summary**: Resumo executivo dos resultados
2. **Detailed Metrics**: Métricas detalhadas por componente
3. **Error Analysis**: Análise detalhada de erros e falhas
4. **Resource Utilization**: Utilização de recursos durante o teste
5. **Recommendations**: Recomendações de otimização

### Critérios de Sucesso
- ✅ **600k RPS sustentados** por pelo menos 30 minutos
- ✅ **P95 < 100ms** durante todo o teste
- ✅ **Taxa de erro < 0.01%** 
- ✅ **Zero downtime** durante o teste
- ✅ **Auto-scaling responsivo** (< 30s para scale-up)

## 🚨 Troubleshooting

### Problemas Comuns
1. **High Latency**: Verificar CPU/Memory, network, database
2. **High Error Rate**: Verificar logs, circuit breakers, timeouts
3. **Scaling Issues**: Verificar KEDA metrics, resource limits
4. **Network Bottlenecks**: Verificar bandwidth, connections

### Ferramentas de Debug
- **kubectl**: Verificar status dos pods e recursos
- **istioctl**: Analisar configuração do service mesh
- **Grafana**: Visualizar métricas em tempo real
- **Jaeger**: Analisar traces distribuídos
- **Azure Monitor**: Monitorar recursos Azure

## 📚 Documentação Adicional

- [Guia de Configuração](./docs/configuration-guide.md)
- [Cenários de Teste](./docs/test-scenarios.md)
- [Troubleshooting Guide](./docs/troubleshooting.md)
- [Performance Tuning](./docs/performance-tuning.md)
- [Best Practices](./docs/best-practices.md)

# Tutorial 01: Configurar Azure Monitor (Prometheus Gerenciado)

## 📋 Índice

- [O que é Azure Monitor?](#o-que-é-azure-monitor)
- [Por que usar Prometheus Gerenciado?](#por-que-usar-prometheus-gerenciado)
- [Pré-requisitos](#pré-requisitos)
- [Passo 1: Verificar Estado Atual](#passo-1-verificar-estado-atual)
- [Passo 2: Criar Azure Monitor Workspace](#passo-2-criar-azure-monitor-workspace)
- [Passo 3: Habilitar Métricas no AKS](#passo-3-habilitar-métricas-no-aks)
- [Passo 4: Configurar Scraping do Istio](#passo-4-configurar-scraping-do-istio)
- [Passo 5: Verificar Funcionamento](#passo-5-verificar-funcionamento)
- [Troubleshooting](#troubleshooting)

---

## O que é Azure Monitor?

**Azure Monitor** é o serviço de monitoramento nativo do Azure que coleta, analisa e age sobre telemetria de seus recursos cloud e on-premises.

### Componentes principais:

1. **Azure Monitor Workspace**: Armazena métricas do Prometheus
2. **Managed Prometheus**: Serviço Prometheus totalmente gerenciado
3. **Azure Managed Grafana**: Visualização de métricas

### Diagrama da Arquitetura:

```
┌─────────────────────────────────────────────────────────────┐
│                      AKS CLUSTER                            │
│  ┌──────────────┐         ┌──────────────┐                 │
│  │   Istio      │────────▶│ ama-metrics  │                 │
│  │   Metrics    │         │   DaemonSet  │                 │
│  └──────────────┘         └──────┬───────┘                 │
│                                   │                         │
└───────────────────────────────────┼─────────────────────────┘
                                    │
                                    │ HTTPS (Managed Identity)
                                    ▼
┌─────────────────────────────────────────────────────────────┐
│            Azure Monitor Workspace                          │
│  • Armazenamento de métricas (18 meses)                    │
│  • PromQL queries                                           │
│  • Recording rules                                          │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│            Azure Managed Grafana                            │
│  • Dashboards pré-configurados                             │
│  • Alertas                                                  │
│  • Visualizações customizadas                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Por que usar Prometheus Gerenciado?

### ❌ Problemas do Prometheus MANUAL (que instalamos antes):

| Problema | Impacto |
|----------|---------|
| **Gerenciamento manual** | Você precisa atualizar, fazer backup, escalar |
| **Armazenamento limitado** | EmptyDir = dados perdidos se pod reiniciar |
| **Sem alta disponibilidade** | 1 pod = single point of failure |
| **Sem backup automático** | Perda de histórico de métricas |
| **Configuração complexa** | Scraping configs manuais |
| **Sem integração Azure** | Não aparece no portal Azure |

### ✅ Vantagens do Azure Monitor (Prometheus Gerenciado):

| Vantagem | Benefício |
|----------|-----------|
| **Totalmente gerenciado** | Microsoft cuida de updates, HA, backups |
| **Armazenamento 18 meses** | Histórico longo, sem custo adicional |
| **Alta disponibilidade** | SLA 99.9%, replicação automática |
| **Escalabilidade automática** | Suporta milhões de séries temporais |
| **Integração nativa** | Azure Portal, Grafana, Alerts |
| **Segurança** | Managed Identity, RBAC, Private Link |
| **Custo previsível** | Paga apenas por ingestão e queries |
| **Zero manutenção** | Foco na aplicação, não na infraestrutura |

### 💰 Modelo de Custo:

- **Ingestão**: ~$0.60 por milhão de samples
- **Queries**: ~$0.01 por 1000 queries
- **Armazenamento**: INCLUÍDO (18 meses)
- **Não paga por**: CPU, memória, pods, storage

**Exemplo real**: Cluster com 10 nós, 100 pods = ~$30-50/mês

---

## Pré-requisitos

### ✅ Checklist antes de começar:

- [ ] Azure CLI instalado (`az version`)
- [ ] kubectl configurado (`kubectl version`)
- [ ] Acesso ao cluster AKS (`kubectl get nodes`)
- [ ] Permissões no Azure:
  - [ ] `Contributor` no Resource Group
  - [ ] `Monitoring Metrics Publisher` (será criado automaticamente)
- [ ] Parâmetros capturados (execute `scripts/setup/capture-lab-parameters.ps1`)

### Carregar parâmetros:

```powershell
# Carrega as variáveis de ambiente do arquivo de configuração
. ../../aks-labs.config

Write-Host "Cluster: $CLUSTER_NAME" -ForegroundColor Cyan
Write-Host "Resource Group: $CLUSTER_RESOURCE_GROUP" -ForegroundColor Cyan
Write-Host "Location: $CLUSTER_LOCATION" -ForegroundColor Cyan
```

**O que observar**: Verifique se os valores estão corretos. Se aparecerem vazios, execute o script de captura primeiro.

**Por que fazer isso**: Garante que estamos trabalhando com o cluster correto e todos os comandos usarão os parâmetros dinâmicos.

---

## Passo 1: Verificar Estado Atual

### 1.1. Verificar se Azure Monitor já está habilitado

```powershell
Write-Host "`n═══ Verificando Azure Monitor ═══" -ForegroundColor Yellow

$monitorStatus = az aks show `
    --resource-group $CLUSTER_RESOURCE_GROUP `
    --name $CLUSTER_NAME `
    --query "azureMonitorProfile.metrics.enabled" `
    --output tsv

if ($monitorStatus -eq "true") {
    Write-Host "✓ Azure Monitor JÁ está habilitado!" -ForegroundColor Green
} else {
    Write-Host "⚠ Azure Monitor NÃO está habilitado" -ForegroundColor Yellow
    Write-Host "  Vamos habilitar nos próximos passos..." -ForegroundColor Cyan
}
```

**O que observar**: 
- `true` = já está habilitado (pode pular para passo 4)
- `null` ou erro = não está habilitado (continue)

**Por que fazer isso**: Evita reconfigurar algo que já está funcionando e permite diagnosticar problemas.

### 1.2. Verificar se Prometheus MANUAL está rodando

```powershell
Write-Host "`n═══ Verificando Prometheus Manual ═══" -ForegroundColor Yellow

$prometheusManual = kubectl get deployment prometheus -n istio-system -o json 2>$null

if ($null -ne $prometheusManual) {
    Write-Host "⚠ ATENÇÃO: Prometheus MANUAL detectado!" -ForegroundColor Red
    Write-Host "  Este será REMOVIDO para usar Azure Monitor" -ForegroundColor Yellow
    Write-Host ""
    
    # Mostrar recursos que serão removidos
    kubectl get all -n istio-system -l app.kubernetes.io/name=prometheus
    
    $confirm = Read-Host "`nDeseja remover o Prometheus manual agora? (s/N)"
    if ($confirm -eq 's' -or $confirm -eq 'S') {
        Write-Host "Removendo Prometheus manual..." -ForegroundColor Yellow
        
        kubectl delete deployment prometheus -n istio-system
        kubectl delete svc prometheus -n istio-system
        kubectl delete configmap prometheus -n istio-system
        kubectl delete serviceaccount prometheus -n istio-system
        
        Write-Host "✓ Prometheus manual removido!" -ForegroundColor Green
    } else {
        Write-Host "⏭ Pulando remoção. ATENÇÃO: conflitos podem ocorrer!" -ForegroundColor Yellow
    }
} else {
    Write-Host "✓ Nenhum Prometheus manual encontrado" -ForegroundColor Green
}
```

**O que observar**:
- Lista de deployments, services, configmaps
- Certifique-se de que são recursos do Prometheus manual, não do Azure Monitor

**Por que fazer isso**: O Prometheus manual conflita com o Azure Monitor. Ambos tentariam scrape as mesmas métricas, causando duplicação e inconsistências.

---

## Passo 2: Criar Azure Monitor Workspace

### 2.1. Definir nome do workspace

```powershell
Write-Host "`n═══ Criando Azure Monitor Workspace ═══" -ForegroundColor Yellow

# Nome do workspace (deve ser único no resource group)
$MONITOR_WORKSPACE_NAME = "amw-$CLUSTER_NAME"

Write-Host "Nome do workspace: $MONITOR_WORKSPACE_NAME" -ForegroundColor Cyan
```

**Por que este nome**: Prefixo `amw-` (Azure Monitor Workspace) + nome do cluster facilita identificação.

### 2.2. Verificar se workspace já existe

```powershell
$existingWorkspace = az monitor account show `
    --name $MONITOR_WORKSPACE_NAME `
    --resource-group $CLUSTER_RESOURCE_GROUP `
    --output json 2>$null

if ($null -ne $existingWorkspace) {
    $workspace = $existingWorkspace | ConvertFrom-Json
    $MONITOR_WORKSPACE_ID = $workspace.id
    
    Write-Host "✓ Workspace já existe!" -ForegroundColor Green
    Write-Host "  ID: $MONITOR_WORKSPACE_ID" -ForegroundColor Gray
} else {
    Write-Host "Criando novo workspace..." -ForegroundColor Cyan
    
    # Criar workspace
    $workspace = az monitor account create `
        --name $MONITOR_WORKSPACE_NAME `
        --resource-group $CLUSTER_RESOURCE_GROUP `
        --location $CLUSTER_LOCATION `
        --output json | ConvertFrom-Json
    
    $MONITOR_WORKSPACE_ID = $workspace.id
    
    Write-Host "✓ Workspace criado com sucesso!" -ForegroundColor Green
    Write-Host "  ID: $MONITOR_WORKSPACE_ID" -ForegroundColor Gray
}
```

**O que observar**:
- Se criar novo: aguarde ~30 segundos para provisionamento
- Anote o ID do workspace (será usado no próximo passo)

**Por que fazer isso**: O workspace é onde as métricas Prometheus serão armazenadas. É um recurso separado para permitir compartilhamento entre clusters.

### 2.3. Salvar workspace ID no config

```powershell
# Atualizar arquivo de configuração com o workspace ID
$configPath = "../../aks-labs.config"
$configContent = Get-Content $configPath

# Substituir ou adicionar AZURE_MONITOR_WORKSPACE_ID
if ($configContent -match "AZURE_MONITOR_WORKSPACE_ID=") {
    $configContent = $configContent -replace "AZURE_MONITOR_WORKSPACE_ID=.*", "AZURE_MONITOR_WORKSPACE_ID=$MONITOR_WORKSPACE_ID"
} else {
    $configContent += "`nAZURE_MONITOR_WORKSPACE_ID=$MONITOR_WORKSPACE_ID"
}

$configContent | Out-File -FilePath $configPath -Encoding UTF8 -Force

Write-Host "✓ Workspace ID salvo em $configPath" -ForegroundColor Green
```

**Por que fazer isso**: Salva o ID para uso futuro sem precisar buscar novamente.

---

## Passo 3: Habilitar Métricas no AKS

### 3.1. Habilitar o addon de métricas

```powershell
Write-Host "`n═══ Habilitando Métricas no AKS ═══" -ForegroundColor Yellow

Write-Host "Este processo:" -ForegroundColor Cyan
Write-Host "  1. Instala o agente ama-metrics (DaemonSet)" -ForegroundColor Gray
Write-Host "  2. Configura Managed Identity para acesso ao workspace" -ForegroundColor Gray
Write-Host "  3. Inicia scraping automático de métricas Kubernetes" -ForegroundColor Gray
Write-Host "  Tempo estimado: 2-3 minutos" -ForegroundColor Gray
Write-Host ""

az aks update `
    --resource-group $CLUSTER_RESOURCE_GROUP `
    --name $CLUSTER_NAME `
    --enable-azure-monitor-metrics `
    --azure-monitor-workspace-resource-id $MONITOR_WORKSPACE_ID

Write-Host "✓ Addon de métricas habilitado!" -ForegroundColor Green
```

**O que observar**:
- Comando pode levar 2-3 minutos
- Não deve haver erros de permissão
- Se erro "workspace not found": aguarde 30s e tente novamente

**Por que fazer isso**: Este comando configura toda a integração entre AKS e Azure Monitor, incluindo:
- Instalação do agente de coleta (ama-metrics)
- Criação de Managed Identity
- Configuração de RBAC
- Início do scraping de métricas

### 3.2. Verificar DaemonSet instalado

```powershell
Write-Host "`n═══ Verificando Instalação ═══" -ForegroundColor Yellow

Write-Host "Aguardando pods ama-metrics ficarem prontos..." -ForegroundColor Cyan
Start-Sleep -Seconds 30

# Verificar DaemonSet Linux
Write-Host "`nPods Linux (ama-metrics-node):" -ForegroundColor White
kubectl get ds ama-metrics-node -n kube-system

Write-Host "`nStatus dos pods:" -ForegroundColor White
kubectl get pods -n kube-system -l app.kubernetes.io/name=ama-metrics
```

**O que observar**:
- `DESIRED` = número de nós Linux no cluster
- `CURRENT` = número de pods criados
- `READY` = número de pods prontos
- Todos devem estar `Running` e `Ready` (2/2)

**Exemplo de saída esperada**:
```
NAME                DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE
ama-metrics-node    3         3         3       3            3
```

**Por que fazer isso**: Verifica se o agente foi instalado em todos os nós e está funcionando corretamente.

### 3.3. Verificar ReplicaSets

```powershell
Write-Host "`nReplicaSets de coleta:" -ForegroundColor White
kubectl get rs -n kube-system | Select-String "ama-metrics"
```

**O que observar**:
- `ama-metrics-<hash>`: Coletor principal (1 replica)
- `ama-metrics-ksm-<hash>`: Kube-state-metrics (1 replica)

**Por que fazer isso**: Estes componentes coletam métricas específicas do Kubernetes (deployments, pods, etc).

---

## Passo 4: Configurar Scraping do Istio

### 4.1. Entender o que vamos fazer

O Azure Monitor precisa saber **onde** buscar métricas do Istio. Fazemos isso criando um **ServiceMonitor** (CRD do Prometheus).

**Pontos de coleta do Istio**:

| Componente | Endpoint | Métricas |
|------------|----------|----------|
| **Envoy sidecars** | `:15020/stats/prometheus` | Request rate, latency, errors |
| **Istiod** | `:15014/metrics` | Control plane health |
| **Ingress Gateway** | `:15020/stats/prometheus` | Gateway traffic |

### 4.2. Criar ServiceMonitor para Istio

```powershell
Write-Host "`n═══ Configurando Scraping do Istio ═══" -ForegroundColor Yellow

Write-Host "Criando ServiceMonitor para coletar métricas do Istio..." -ForegroundColor Cyan
```

Crie o arquivo `manifests/01-monitoring/istio-servicemonitor.yaml`:

```yaml
# ServiceMonitor para Azure Monitor coletar métricas do Istio
# Este arquivo instrui o ama-metrics a fazer scrape dos endpoints do Istio
apiVersion: azmonitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: istio-mesh-metrics
  namespace: kube-system  # DEVE estar em kube-system para Azure Monitor
  labels:
    app: istio
    monitoring: azure-monitor
spec:
  # Seleciona TODOS os services com label istio
  selector:
    matchLabels:
      istio: mixer  # Label comum em serviços Istio
  # Busca em TODOS os namespaces
  namespaceSelector:
    any: true
  # Define os endpoints para scraping
  endpoints:
    # Endpoint 1: Envoy sidecars (métricas de tráfego)
    - port: http-envoy-prom
      path: /stats/prometheus
      interval: 30s  # Coleta a cada 30 segundos
      scrapeTimeout: 10s
      relabelings:
        - sourceLabels: [__meta_kubernetes_pod_label_app]
          targetLabel: app
        - sourceLabels: [__meta_kubernetes_pod_label_version]
          targetLabel: version
        - sourceLabels: [__meta_kubernetes_namespace]
          targetLabel: namespace
---
# ServiceMonitor específico para Istiod (control plane)
apiVersion: azmonitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: istiod-metrics
  namespace: kube-system
  labels:
    app: istiod
    monitoring: azure-monitor
spec:
  selector:
    matchLabels:
      app: istiod
  namespaceSelector:
    matchNames:
      - aks-istio-system  # Namespace do Istio no AKS
  endpoints:
    - port: http-monitoring
      path: /metrics
      interval: 30s
      scrapeTimeout: 10s
---
# ServiceMonitor para Istio Ingress Gateway
apiVersion: azmonitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: istio-ingressgateway-metrics
  namespace: kube-system
  labels:
    app: istio-ingressgateway
    monitoring: azure-monitor
spec:
  selector:
    matchLabels:
      app: aks-istio-ingressgateway-external
  namespaceSelector:
    matchNames:
      - aks-istio-ingress  # Namespace do ingress gateway no AKS
  endpoints:
    - port: http-envoy-prom
      path: /stats/prometheus
      interval: 30s
      scrapeTimeout: 10s
```

**Explicação linha por linha**:

| Linha | O que faz | Por que |
|-------|-----------|---------|
| `apiVersion: azmonitoring.coreos.com/v1` | Usa a API do Azure Monitor | AKS usa versão customizada do ServiceMonitor |
| `namespace: kube-system` | OBRIGATÓRIO estar neste namespace | Azure Monitor só lê ServiceMonitors de kube-system |
| `selector.matchLabels` | Quais services monitorar | Seleciona por labels Kubernetes |
| `namespaceSelector.any: true` | Buscar em todos namespaces | Pega métricas de qualquer namespace |
| `port: http-envoy-prom` | Nome da porta no service | Deve corresponder ao service do Istio |
| `interval: 30s` | Frequência de coleta | Balanço entre precisão e carga |
| `relabelings` | Adiciona labels customizadas | Facilita filtros no Grafana |

### 4.3. Aplicar ServiceMonitor

```powershell
kubectl apply -f ../../manifests/01-monitoring/istio-servicemonitor.yaml

Write-Host "✓ ServiceMonitor criado!" -ForegroundColor Green
```

**O que observar**:
- Deve criar 3 ServiceMonitors
- Não deve haver erros de CRD (Custom Resource Definition)

**Por que fazer isso**: Sem ServiceMonitor, o Azure Monitor não sabe onde buscar métricas do Istio. É como dar um mapa para o coletor.

### 4.4. Verificar scraping ativo

```powershell
Write-Host "`n═══ Verificando Scraping ═══" -ForegroundColor Yellow

# Aguardar propagação da configuração
Write-Host "Aguardando propagação (30s)..." -ForegroundColor Cyan
Start-Sleep -Seconds 30

# Verificar logs do ama-metrics
Write-Host "`nLogs do ama-metrics (últimas 20 linhas):" -ForegroundColor White
$amaPod = kubectl get pods -n kube-system -l app.kubernetes.io/name=ama-metrics -o jsonpath='{.items[0].metadata.name}'
kubectl logs $amaPod -n kube-system --tail=20 | Select-String "istio"
```

**O que observar**:
- Linhas contendo "istio" ou "envoy"
- Mensagens de "successfully scraped"
- Nenhum erro de conexão

**Exemplo de log esperado**:
```
level=info ts=2025-10-01T12:34:56.789Z caller=scrape.go:123 component=scrape_manager target=istio-mesh msg="Successfully scraped" samples=1234
```

**Por que fazer isso**: Confirma que o scraping está funcionando antes de configurar o Flagger.

---

## Passo 5: Verificar Funcionamento

### 5.1. Consultar métricas no Azure Monitor

```powershell
Write-Host "`n═══ Consultando Métricas ═══" -ForegroundColor Yellow

Write-Host "Aguardando primeira coleta de métricas (60s)..." -ForegroundColor Cyan
Start-Sleep -Seconds 60

# Query PromQL para verificar métricas Istio
$query = 'istio_requests_total{}'

Write-Host "`nExecutando query PromQL: $query" -ForegroundColor Cyan

az monitor metrics list-metrics `
    --resource $MONITOR_WORKSPACE_ID `
    --metrics $query `
    --start-time (Get-Date).AddMinutes(-5).ToString("yyyy-MM-ddTHH:mm:ssZ") `
    --end-time (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
```

**O que observar**:
- Se retornar resultados = métricas estão chegando ✅
- Se vazio = aguardar mais 2-3 minutos e tentar novamente
- Se erro = verificar ServiceMonitor e logs

**Por que fazer isso**: Confirma end-to-end que métricas estão sendo coletadas e armazenadas.

### 5.2. Verificar no Azure Portal

```powershell
Write-Host "`n═══ Verificar no Portal Azure ═══" -ForegroundColor Yellow

$portalUrl = "https://portal.azure.com/#resource$MONITOR_WORKSPACE_ID/overview"

Write-Host "Abra o portal Azure:" -ForegroundColor Cyan
Write-Host $portalUrl -ForegroundColor White
Write-Host ""
Write-Host "No portal, verifique:" -ForegroundColor Yellow
Write-Host "  1. Métricas recentes sendo ingeridas" -ForegroundColor Gray
Write-Host "  2. Nenhum erro de coleta" -ForegroundColor Gray
Write-Host "  3. Taxa de ingestão (samples/sec)" -ForegroundColor Gray

Read-Host "`nPressione Enter após verificar no portal"
```

**O que observar no portal**:
- **Overview**: Taxa de ingestão, número de séries temporais
- **Metrics Explorer**: Executar queries PromQL
- **Workbooks**: Dashboards pré-configurados

**Por que fazer isso**: Portal Azure oferece visualização mais rica que CLI.

### 5.3. Gerar tráfego para teste

```powershell
Write-Host "`n═══ Gerando Tráfego de Teste ═══" -ForegroundColor Yellow

Write-Host "Enviando requisições para gerar métricas..." -ForegroundColor Cyan

# Buscar IP do gateway
$gatewayIP = kubectl get svc aks-istio-ingressgateway-external -n aks-istio-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

if ([string]::IsNullOrWhiteSpace($gatewayIP)) {
    Write-Host "⚠ Gateway IP não disponível ainda" -ForegroundColor Yellow
} else {
    # Enviar 20 requisições
    Write-Host "Enviando 20 requisições para http://$gatewayIP" -ForegroundColor Cyan
    
    for ($i = 1; $i -le 20; $i++) {
        try {
            $response = Invoke-WebRequest -Uri "http://$gatewayIP" -TimeoutSec 5 -UseBasicParsing
            Write-Host "  [$i/20] Status: $($response.StatusCode)" -ForegroundColor Gray
        } catch {
            Write-Host "  [$i/20] Erro: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        Start-Sleep -Milliseconds 500
    }
    
    Write-Host "`n✓ Tráfego gerado! Métricas devem aparecer em ~30s" -ForegroundColor Green
}
```

**O que observar**:
- Respostas HTTP 200 (OK) ou 301 (Redirect)
- Erros são OK se aplicação não estiver configurada ainda

**Por que fazer isso**: Gera métricas reais para testar o pipeline de monitoramento.

### 5.4. Query de verificação final

```powershell
Write-Host "`n═══ Query de Verificação Final ═══" -ForegroundColor Yellow

Start-Sleep -Seconds 30

Write-Host "Executando query PromQL de teste..." -ForegroundColor Cyan

# Esta query mostra taxa de requisições por segundo
$query = @'
rate(istio_requests_total[1m])
'@

# Executar via kubectl (mais rápido que CLI)
kubectl run prometheus-query --rm -it --restart=Never --image=curlimages/curl -- sh -c "
curl -s 'http://ama-metrics-prometheus-service.kube-system.svc.cluster.local:9090/api/v1/query?query=$query'
"
```

**O que observar**:
- JSON com resultados (campo `data.result`)
- Se vazio: aguardar mais tempo ou verificar ServiceMonitor
- Se erro 404: serviço Prometheus não acessível

**Por que fazer isso**: Testa o endpoint Prometheus interno do Azure Monitor.

---

## Troubleshooting

### Problema 1: Pods ama-metrics não iniciam

**Sintomas**:
```
ama-metrics-node-xxxxx   0/2   ImagePullBackOff
```

**Diagnóstico**:
```powershell
kubectl describe pod -n kube-system <pod-name> | Select-String "Error"
```

**Soluções**:
1. Verificar quota de imagens no subscription
2. Verificar conectividade com mcr.microsoft.com
3. Tentar pull manual: `kubectl run test --rm -it --image=mcr.microsoft.com/azuremonitor/containerinsights/ciprod:latest`

---

### Problema 2: ServiceMonitor não está coletando

**Sintomas**:
```
No metrics matching query
```

**Diagnóstico**:
```powershell
# Verificar se ServiceMonitor existe
kubectl get servicemonitor -n kube-system

# Verificar logs do ama-metrics
kubectl logs -n kube-system -l app.kubernetes.io/name=ama-metrics --tail=50
```

**Soluções**:
1. Verificar se ServiceMonitor está em `kube-system`
2. Verificar labels nos services Istio: `kubectl get svc -n aks-istio-system --show-labels`
3. Verificar se portas estão corretas
4. Recriar ServiceMonitor

---

### Problema 3: Métricas não aparecem no Portal

**Sintomas**:
- Pods funcionando
- Logs mostram scraping OK
- Mas portal não mostra métricas

**Diagnóstico**:
```powershell
# Verificar status do workspace
az monitor account show --name $MONITOR_WORKSPACE_NAME --resource-group $CLUSTER_RESOURCE_GROUP
```

**Soluções**:
1. Aguardar 5-10 minutos (latência de ingestão)
2. Verificar RBAC: Managed Identity precisa de `Monitoring Metrics Publisher`
3. Verificar se workspace está na mesma região do cluster
4. Verificar firewall/NSG se usando Private Link

---

### Problema 4: Queries PromQL não funcionam

**Sintomas**:
```
Error executing query: context deadline exceeded
```

**Diagnóstico**:
```powershell
# Testar conectividade com workspace
Test-NetConnection -ComputerName $MONITOR_WORKSPACE_NAME.prometheus.monitor.azure.com -Port 443
```

**Soluções**:
1. Verificar sintaxe PromQL (usar Metrics Explorer no portal)
2. Reduzir intervalo de tempo (últimos 15 minutos)
3. Verificar se métrica existe: `az monitor metrics list --resource $MONITOR_WORKSPACE_ID`

---

## ✅ Checklist de Conclusão

Ao final deste tutorial, você deve ter:

- [ ] Azure Monitor Workspace criado
- [ ] Addon de métricas habilitado no AKS
- [ ] Pods `ama-metrics-node` rodando em todos os nós (X/X Ready)
- [ ] Pods `ama-metrics` e `ama-metrics-ksm` rodando (1/1 Ready)
- [ ] ServiceMonitors do Istio criados (3 recursos)
- [ ] Métricas Istio aparecendo no Azure Monitor
- [ ] Query PromQL funcionando
- [ ] Tráfego de teste gerando métricas
- [ ] Prometheus manual REMOVIDO (se existia)

---

## 📚 Próximos Passos

1. **Tutorial 02**: Configurar Azure Key Vault para certificados TLS
2. **Tutorial 03**: Instalar Flagger com Azure Monitor
3. **Tutorial 04**: Configurar canary deployment
4. **Tutorial 05**: Testar progressive delivery completo

---

## 🔗 Referências

- [Azure Monitor Docs](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/prometheus-metrics-overview)
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Istio Metrics](https://istio.io/latest/docs/reference/config/metrics/)
- [Service Monitors](https://learn.microsoft.com/en-us/azure/azure-monitor/containers/prometheus-metrics-scrape-crd)

---

**Dúvidas?** Verifique os logs: `kubectl logs -n kube-system -l app.kubernetes.io/name=ama-metrics`

**Próximo tutorial**: [02-setup-key-vault.md](./02-setup-key-vault.md)

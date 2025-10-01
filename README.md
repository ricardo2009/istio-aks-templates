# 🚀 Istio Managed Add-on Lab - AKS Demo# 🚀 Istio Managed Add-on Demo Lab para AKS# 🚀 Istio Templates para AKS# Istio Templates para AKS com Jinja2yq --version



> **Laboratório prático de Istio no AKS** - Canary + Blue-Green + A/B Testing + mTLS + JWT + Telemetry + Egress Control funcionando simultaneamente.



---[![Deploy](https://github.com/ricardo2009/istio-aks-templates/actions/workflows/deploy.yml/badge.svg)](https://github.com/ricardo2009/istio-aks-templates/actions/workflows/deploy.yml)



## 📖 Tutorial Completo[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)



**➡️ [LAB_TUTORIAL.md](./docs/LAB_TUTORIAL.md)** - Deploy, validação, testes e troubleshooting em um único documento.> **Estratégia Helm sem Helm** - Templates familiares com `{{ .Values.xxx }}` processados por renderizador Python customizado.envsubst --version



---## 🎯 Visão Geral



## 🚀 Quick Start (3 comandos)



```powershellEste repositório fornece um **laboratório completo e unificado** de demonstração do **Istio Managed Add-on** no Azure Kubernetes Service (AKS). O objetivo é demonstrar todas as capacidades principais do Istio em um único ambiente `demo`, incluindo:

# 1. Criar namespace com injeção Istio

kubectl create namespace pets; kubectl label namespace pets istio.io/rev=asm-1-23[![Deploy](https://github.com/ricardo2009/istio-aks-templates/actions/workflows/deploy.yml/badge.svg)](https://github.com/ricardo2009/istio-aks-templates/actions/workflows/deploy.yml)Este repositório fornece um conjunto de templates Istio modulares renderizados com Jinja2. O objetivo é substituir o uso de Helm/envsubst por uma abordagem 100% declarativa, reutilizável e fácil de automatizar em pipelines CI/CD no Azure Kubernetes Service (AKS) com o add-on Istio.az --version



# 2. Aplicar manifestos- **Gerenciamento de Tráfego**: Canary, Blue-Green, A/B Testing unificados

kubectl apply -f manifests/demo/

- **Segurança**: mTLS STRICT, autenticação JWT, autorização RBAC[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

# 3. Aguardar pods prontos

kubectl wait --for=condition=ready pod -l app=pets -n pets --timeout=300s- **Observabilidade**: Telemetria, tracing distribuído, métricas customizadas

```

- **Controle de Egress**: ServiceEntry e Sidecar para acesso externo controladoistio-templates/

**Validação rápida:**

```powershell

$GATEWAY_IP = kubectl get svc -n aks-istio-ingress aks-istio-ingressgateway-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

Invoke-WebRequest -Uri "http://$GATEWAY_IP/headers" -Headers @{"Host"="pets.contoso.com"}### ✨ Características## 🎯 **Visão Geral**

```



---

- 🎨 **Demonstração Abrangente**: Todos os recursos Istio em um único namespace## Visão geralenvsubst < traffic-management/gateway.yaml > processed-gateway.yaml

## ✅ O Que Está Implementado

- 🔒 **Segurança Completa**: mTLS, JWT (Azure AD), AuthorizationPolicy

- ✅ **Canary** (90/10), **Blue-Green** (path `/bg`), **A/B Testing** (header `X-User-Group`)

- ✅ **mTLS STRICT** + **JWT (Azure AD)** + **RBAC** (6 ServiceAccounts)- 🔄 **Estratégias de Deploy**: Canary, Blue-Green, A/B Testing unificadosEste repositório fornece templates Istio **modulares** e **reutilizáveis** para Azure Kubernetes Service (AKS), utilizando sintaxe familiar do Helm sem a dependência do Helm.

- ✅ **Telemetry** (Zipkin + custom tags) + **Prometheus** + **Kiali**

- ✅ **Egress Control** (ServiceEntry + Sidecar)- 📊 **Observabilidade Total**: Telemetria, Tracing (Zipkin), tags customizadas

- ✅ **6 Deployments** (httpbin) + **2 Gateways** (externo HTTPS + interno HTTP)

- 🌐 **Controle de Egress**: ServiceEntry + Sidecar para APIs externasenvsubst < traffic-management/virtualservice.yaml > processed-virtualservice.yaml

---

- 🤖 **CI/CD Ready**: GitHub Actions validação e deploy automatizado

## 📂 Estrutura

- 📚 **Documentação Completa**: Guias práticos e tutoriais passo-a-passo### ✨ **Características**

```

manifests/demo/   → 13 arquivos YAML (workloads, gateways, virtualservices, security, observability)

docs/             → LAB_TUTORIAL.md (tutorial unificado)

.github/workflows/ → deploy.yml (CI/CD automático)## 📁 Estrutura do Projeto- **Modularidade**: templates organizados por domínios (`traffic`, `security`, `workloads`).env | grep -E "(APP_NAME|SERVICE_HOST|NAMESPACE)"

scripts/          → validate_templates.py, test_ci_workflow.sh

```



---```- 🎨 **Sintaxe Helm**: `{{ .Values.app.name }}`, condicionais, loops



## 📊 Observabilidadeistio-aks-demo-lab/



```powershell├── .github/workflows/- 🔄 **Zero Dependência**: Sem Helm, apenas Python + Jinja2- **Reuso**: macros compartilhadas para metadados, rótulos e métricas.envsubst < template.yaml

# Prometheus (métricas)

kubectl port-forward -n aks-istio-system svc/prometheus 9090:9090│   └── deploy.yml              # Workflow CI/CD (validação + deploy demo)



# Kiali (topologia)├── manifests/demo/             # Manifestos Istio (ambiente demo único)- 🌍 **Multi-ambiente**: Dev, Staging, Production

kubectl port-forward -n aks-istio-system svc/kiali 20001:20001

│   ├── gateway.yaml            # Gateway externo (HTTPS com TLS)

# Zipkin (tracing)

kubectl port-forward -n aks-istio-system svc/zipkin 9411:9411│   ├── gateway-internal.yaml  # Gateway interno- 🤖 **CI/CD Ready**: GitHub Actions otimizado- **Configuração declarativa**: valores versionados em `config/values` e overlays por ambiente em `config/environments`.yq e '.' processed-manifest.yaml

```

│   ├── virtualservice.yaml    # Routing unificado (canary/blue-green/A/B)

---

│   ├── destinationrule.yaml   # 6 subsets + traffic policies- 🔒 **Seguro**: mTLS, PeerAuthentication, políticas de segurança

## 🔧 Operações

│   ├── peerauthentication.yaml # mTLS STRICT

**Ajustar Canary para 50/50:**

```powershell│   ├── requestauthentication.yaml # JWT validation (Azure AD)- 📊 **Observável**: Labels e anotações padronizadas- **Renderização determinística**: script Python que combina valores + templates e gera manifests prontos para aplicar com `kubectl`.# peer-authentication.yaml

kubectl patch virtualservice pets -n pets --type merge -p '{"spec":{"http":[{"name":"canary-default","route":[{"destination":{"host":"pets.pets.svc.cluster.local","subset":"canary"},"weight":50},{"destination":{"host":"pets.pets.svc.cluster.local","subset":"primary"},"weight":50}]}]}}'

```│   ├── authorizationpolicy.yaml # RBAC (JWT claims + ServiceAccounts)



**Alternar Blue-Green para 100% Blue:**│   ├── serviceaccounts.yaml   # 6 ServiceAccounts (primary/canary/blue/green/variant-a/variant-b)

```powershell

kubectl patch virtualservice pets -n pets --type merge -p '{"spec":{"http":[{"name":"blue-green","match":[{"uri":{"prefix":"/bg"}}],"rewrite":{"uri":"/"},"route":[{"destination":{"host":"pets.pets.svc.cluster.local","subset":"blue"},"weight":100},{"destination":{"host":"pets.pets.svc.cluster.local","subset":"green"},"weight":0}]}]}}'│   ├── serviceentry.yaml      # Egress para api.catfacts.ninja

```

│   ├── sidecar.yaml           # Controle de egress por workload## 🚀 **Quick Start**apiVersion: security.istio.io/v1beta1

---

│   └── telemetry.yaml         # Tracing config (Zipkin + custom tags)

**📖 Documentação completa em [LAB_TUTORIAL.md](./docs/LAB_TUTORIAL.md)**

├── templates/                  # Templates Helm (para futuro uso)

│   └── values.yaml            # Valores base

├── scripts/### **1. Instalação**## Estrutura de diretórioskind: PeerAuthentication

│   ├── helm_render.py         # Renderizador de templates

│   ├── sync_tls_secret.py     # Sincronização de certificados TLS (Key Vault → AKS)

│   ├── validate_templates.py  # Validação de manifestos demo

│   └── test_ci_workflow.sh    # Simulação local do CI/CD```bashmetadata:

├── docs/

│   ├── USAGE.md               # Guia de uso completogit clone https://github.com/ricardo2009/istio-aks-templates.git

│   ├── KEYVAULT.md            # Configuração Azure Key Vault

│   ├── MANUAL_ROLLOUT_TUTORIAL.md # Tutorial de rollout manualcd istio-aks-templates```  name: ${PA_NAME}

│   ├── VALIDATION.md          # Validação e testes

│   ├── CICD.md                # Configuração CI/CDpip install -r requirements.txt

│   └── IMPROVEMENTS.md        # Melhorias futuras

└── README.md                  # Este arquivo```.  namespace: ${NAMESPACE}

```



## 🚀 Quick Start

### **2. Renderizar Templates**├── config/spec:

### 1. Pré-requisitos



- **Azure CLI** (`az`) configurado e autenticado

- **kubectl** instalado e configurado para o cluster AKS```bash│   ├── environments/         # Overrides por ambiente (dev, staging, prod)  mtls:

- **Python 3.9+** com `pip`

- **Cluster AKS** com Istio Managed Add-on habilitado# Ambiente staging

- **Azure Key Vault** (opcional, para certificados TLS)

python scripts/helm_render.py -t templates -v templates/values-staging.yaml -o manifests/staging│   └── values/               # Configuração base modular    mode: ${MTLS_MODE}  # STRICT para prod, PERMISSIVE para dev

### 2. Instalação



```powershell

# Clone o repositório# Ambiente production├── docs/                     # Documentação complementar```

git clone https://github.com/ricardo2009/istio-aks-templates.git

cd istio-aks-templatespython scripts/helm_render.py -t templates -v templates/values-production.yaml -o manifests/production



# Instale as dependências Python```├── scripts/

pip install -r requirements.txt

```



### 3. Deploy no AKS### **3. Deploy no AKS**│   └── render.py             # Renderizador oficial (Jinja2)### Políticas de Autorização



```powershell

# Criar namespace com injeção Istio

kubectl create namespace pets```bash├── templates/

kubectl label namespace pets istio.io/rev=asm-1-23

kubectl apply -f manifests/staging/

# Aplicar manifestos demo

kubectl apply -f manifests/demo/```│   ├── _shared/              # Macros utilitárias```yaml

```



### 4. Validação

## 📁 **Estrutura do Projeto**│   └── modules/# authorization-policy.yaml

```bash

# Verificar recursos Istio

kubectl get gateway,virtualservice,destinationrule,peerauthentication -n pets

```│       ├── security/         # PeerAuthentication, AuthorizationPolicy, ...apiVersion: security.istio.io/v1beta1

# Verificar políticas de segurança

kubectl get requestauthentication,authorizationpolicy -n petsistio-aks-templates/



# Verificar ServiceAccounts├── .github/workflows/           # CI/CD GitHub Actions│       ├── traffic/          # Gateway, VirtualService, DestinationRulekind: AuthorizationPolicy

kubectl get serviceaccounts -n pets

│   └── deploy.yml              # Workflow principal

# Verificar telemetria

kubectl get telemetry -n pets├── templates/                   # Templates Helm-style│       └── workloads/        # HorizontalPodAutoscaler (HPA)metadata:



# Verificar egress│   ├── values.yaml             # Valores padrão

kubectl get serviceentry,sidecar -n pets

```│   ├── values-staging.yaml     # Configuração staging└── requirements.txt          # Dependências Python necessárias  name: ${AUTH_POLICY_NAME}



## 🎨 Recursos Implementados│   ├── values-production.yaml  # Configuração production



### 🔐 Segurança│   ├── gateway.yaml            # Template Gateway```spec:



- **mTLS STRICT**: Comunicação criptografada entre todos os serviços│   ├── virtualservice.yaml     # Template VirtualService

- **JWT Validation**: Autenticação via Azure AD (issuer/jwksUri)

- **AuthorizationPolicy**: RBAC baseado em JWT claims (groups) e ServiceAccounts│   ├── destinationrule.yaml    # Template DestinationRule  action: ${AUTH_ACTION}  # ALLOW/DENY

- **6 ServiceAccounts**: Identidade separada para cada variante de deployment

│   └── peerauthentication.yaml # Template PeerAuthentication

### 🔄 Gerenciamento de Tráfego

├── manifests/                   # Output renderizado (gitignored)## Pré-requisitos  rules:

- **Canary Routing**: 90% primary / 10% canary (default)

- **Blue-Green**: Path `/bg/*` para ambiente blue-green│   ├── staging/                # Manifests staging

- **A/B Testing**: Header `X-User-Group` para variantes (alpha→variant-a, beta→variant-b)

- **Retries e Timeouts**: Configuração de resiliência│   └── production/             # Manifests production  - from:

- **Traffic Policies**: LEAST_REQUEST, connection pooling, outlier detection

├── scripts/

### 📊 Observabilidade

│   └── helm_render.py          # Renderizador principal- Python 3.9+    - source:

- **Tracing**: Integração Zipkin com sampling 10%

- **Custom Tags**: user-group, release-track extraídos de headers HTTP├── docs/                       # Documentação

- **Labels Padronizados**: app, version, release-track para todos os recursos

│   ├── USAGE.md               # Guia de uso- Pip (para instalar as dependências)        principals: ["cluster.local/ns/${NAMESPACE}/sa/${SERVICE_ACCOUNT}"]

### 🌐 Controle de Egress

│   └── CICD.md                # Configuração CI/CD

- **ServiceEntry**: Permite acesso a `api.catfacts.ninja` (HTTPS)

- **Sidecar**: Restringe egress apenas para namespace, istio-system e APIs autorizadas└── README.md                   # Este arquivo- Kubectl configurado para o cluster AKS (deploy manual ou via pipeline)```



## 🤖 CI/CD com GitHub Actions```



### Workflow Automático- Azure CLI (opcional, apenas se for provisionar/gerenciar o cluster)



O workflow `.github/workflows/deploy.yml` executa:## 🔧 **Configuração por Ambiente**



1. **Validação**:## 📊 Observabilidade

   - Lint YAML dos manifestos

   - Validação de sintaxe Istio/Kubernetes### **Staging** (`values-staging.yaml`)



2. **Deploy Demo**:- Namespace: `pets-staging`Instale as dependências Python:

   - Sincronização de certificados TLS (Key Vault → AKS)

   - Criação de namespace `pets` com label Istio- mTLS: `PERMISSIVE` (desenvolvimento)

   - Aplicação de todos os manifestos demo

   - Verificação de status dos recursos- Routing: 90% primary, 10% canary### Métricas Automáticas



### Configuração Necessária- Domain: `pets-staging.contoso.com`



**GitHub Secrets**:```powershell

- `AZURE_CREDENTIALS`: Service Principal para autenticação Azure

- `AKS_RESOURCE_GROUP`: Nome do Resource Group do AKS### **Production** (`values-production.yaml`)

- `AKS_CLUSTER_NAME`: Nome do cluster AKS

- `AZURE_KEYVAULT_NAME`: Nome do Key Vault (opcional, para TLS)- Namespace: `pets-prod`python -m pip install -r requirements.txt```bash



**GitHub Environment**:- mTLS: `STRICT` (máxima segurança)

- `demo`: Environment para deploy (opcional: adicionar approval gate)

- Routing: 95% primary, 5% canary```# Verificar métricas do Prometheus

## 📖 Documentação

- Domain: `pets.contoso.com`

- 📚 [**Guia de Uso**](docs/USAGE.md) - Como usar todos os recursos do lab

- 🔑 [**Key Vault Setup**](docs/KEYVAULT.md) - Configuração de certificados TLSkubectl port-forward -n aks-istio-system svc/prometheus 9090:9090

- 🚀 [**Tutorial de Rollout Manual**](docs/MANUAL_ROLLOUT_TUTORIAL.md) - Passo-a-passo de deploy

- 🧪 [**Validação e Testes**](docs/VALIDATION.md) - Como validar o lab## 🎨 **Exemplos de Templates**

- 🔄 [**CI/CD Setup**](docs/CICD.md) - Configuração GitHub Actions

- 📈 [**Melhorias Futuras**](docs/IMPROVEMENTS.md) - Roadmap e ideias## Configuração de valores



## 🔧 Comandos Úteis### **Gateway com TLS**



### Validação Local```yaml# Grafana (se instalado)



```bashapiVersion: networking.istio.io/v1beta1

# Validar manifestos demo

python scripts/validate_templates.py -m manifests/demokind: GatewayOs valores são separados em arquivos temáticos para facilitar a manutenção.kubectl port-forward -n aks-istio-system svc/grafana 3000:3000



# Lint YAMLmetadata:

yamllint manifests/demo/*.yaml

  name: {{ .Values.network.gateway.name }}```

# Dry-run no cluster

kubectl apply --dry-run=client -f manifests/demo/  namespace: {{ .Values.network.gateway.namespace }}

```

spec:### `config/values/global.yaml`

### Monitoramento

  selector:

```bash

# Logs do Ingress Gateway    istio: aks-istio-ingressgateway-external### Tracing com Jaeger

kubectl logs -n aks-istio-ingress -l app=aks-istio-ingressgateway-external --tail=50

  servers:

# Métricas Prometheus

kubectl port-forward -n aks-istio-system svc/prometheus 9090:9090  - port:Define metadados padrão usados por todos os manifests.



# Tracing Zipkin (se disponível)      number: 443

kubectl port-forward -n aks-istio-system svc/zipkin 9411:9411

      name: https```bash

# Kiali (se disponível)

kubectl port-forward -n aks-istio-system svc/kiali 20001:20001      protocol: HTTPS

```

    hosts:```yaml# Acessar Jaeger UI

### Teste de Tráfego

{{- range .Values.network.gateway.hosts }}

```bash

# Endpoint padrão (90% primary, 10% canary)    - {{ . }}global:kubectl port-forward -n aks-istio-system svc/jaeger-query 16686:16686

curl https://pets.contoso.com/api/pets

{{- end }}

# Blue-Green (path rewrite)

curl https://pets.contoso.com/bg/api/pets    tls:  app: sample-app```



# A/B Testing (header-based)      mode: SIMPLE

curl -H "X-User-Group: alpha" https://pets.contoso.com/api/pets  # vai para variant-a

curl -H "X-User-Group: beta" https://pets.contoso.com/api/pets   # vai para variant-b      credentialName: {{ .Values.network.gateway.tls.secretName }}  version: "1.0.0"



# JWT Authentication (substitua <TOKEN> por JWT válido)```

curl -H "Authorization: Bearer <TOKEN>" https://pets.contoso.com/api/pets

```  environment: dev## 🤝 Contribuição



## 🎯 Por que Esta Abordagem?### **VirtualService com Canary**



### ✅ Vantagens```yaml  namespace: sample-app



- **Unificado**: Todos os recursos Istio em um único ambiente demospec:

- **Completo**: Cobre segurança, tráfego, observabilidade e egress

- **Prático**: Manifestos prontos para aplicar (sem renderização)  http:  labels:### Como Contribuir

- **Educativo**: Demonstra best practices e padrões reais

- **Automatizado**: CI/CD completo com validação e deploy  - name: primary-routing



### 🎓 Casos de Uso    route:    managed_by: istio-blueprints



- **Treinamento**: Laboratório hands-on de Istio no AKS    - destination:

- **POC**: Prova de conceito para adoção de Service Mesh

- **Base de Conhecimento**: Referência de configurações Istio        host: {{ .Values.service.host }}    cost_center: platform-team1. Fork do repositório

- **Starter Kit**: Base para novos projetos com Istio

        subset: primary

## 🤝 Contribuição

      weight: {{ .Values.network.virtualservice.routing.primary.weight }}  annotations:2. Criar branch para feature: `git checkout -b feature/nova-funcionalidade`

1. Fork do projeto

2. Criar feature branch: `git checkout -b feature/nova-funcionalidade`{{- if gt .Values.network.virtualservice.routing.canary.weight 0 }}

3. Commit: `git commit -am 'Adiciona nova funcionalidade'`

4. Push: `git push origin feature/nova-funcionalidade`    - destination:    owner: platform-team@contoso.com3. Commit das mudanças: `git commit -am 'Adiciona nova funcionalidade'`

5. Pull Request

        host: {{ .Values.service.host }}

### Padrões de Código

        subset: canary```4. Push para branch: `git push origin feature/nova-funcionalidade`

- Manifestos devem ser válidos segundo CRDs Istio/Kubernetes

- Documentar mudanças no CHANGELOG.md (quando criado)      weight: {{ .Values.network.virtualservice.routing.canary.weight }}

- Incluir exemplos de uso no docs/USAGE.md

- Testar localmente com `kubectl apply --dry-run=client`{{- end }}5. Abrir Pull Request



## 📄 Licença```



Este projeto está licenciado sob a [MIT License](LICENSE).### `config/values/traffic.yaml`



## 🏷️ Tags## 🤖 **CI/CD com GitHub Actions**



`istio` `aks` `kubernetes` `azure` `service-mesh` `demo-lab` `ci-cd` `devops` `microservices` `security` `observability`### Padrões de Código



---### **Workflow Automático**



**Criado com ❤️ para facilitar a adoção do Istio Managed Add-on no AKS**Configura gateways, virtual services e destination rules reutilizáveis.


- **Pull Request**: Deploy automático no staging

- **Merge to Main**: Deploy automático na production- Templates devem ser 100% parametrizáveis

- **Validação**: Lint YAML + Validação de sintaxe

- **Verificação**: Health check pós-deploy```yaml- Usar variáveis com nomes descritivos



### **Configuração Necessária**traffic:- Documentar todas as variáveis no schema.yaml



1. **Secrets GitHub**:  gateways:- Incluir exemplos nos overlays

   - `AZURE_CREDENTIALS`

   - `AKS_RESOURCE_GROUP`    - name: sample-app-gateway- Testar em múltiplos ambientes

   - `AKS_CLUSTER_NAME_STAGING`

   - `AKS_CLUSTER_NAME_PROD`      namespace: aks-istio-ingress



2. **Environments**:      selector: aks-istio-ingressgateway-external### Adicionando Novos Templates

   - `staging` (auto-deploy)

   - `production` (manual approval)      servers:



## 📖 **Documentação**        - port: 4431. Criar template em diretório apropriado



- 📚 [**Guia de Uso**](docs/USAGE.md) - Como usar os templates          name: https2. Usar sintaxe `${VARIABLE_NAME}` para parametrização

- 🔄 [**CI/CD Setup**](docs/CICD.md) - Configuração GitHub Actions

          protocol: HTTPS3. Documentar variáveis em schema.yaml

## 🔧 **Comandos Úteis**

          hosts:4. Adicionar configuração em values.yaml

### **Renderização**

```bash            - sample.contoso.com5. Criar testes nos overlays

# Testar renderização

python scripts/helm_render.py -t templates -v templates/values.yaml -o test-output          tls:6. Atualizar deploy-parametrized.sh se necessário



# Validar YAML            mode: SIMPLE

yamllint templates/

            credential_name: sample-app-tls## 📚 Referências

# Dry-run no cluster

kubectl apply --dry-run=client -f manifests/staging/  virtual_services:

```

    - name: sample-app- [Istio Documentation](https://istio.io/latest/docs/)

### **Deployment**

```bash      namespace: sample-app- [AKS Istio Add-on](https://docs.microsoft.com/en-us/azure/aks/istio-about)

# Deploy staging

kubectl apply -f manifests/staging/      gateways:- [Kubernetes Documentation](https://kubernetes.io/docs/)



# Verificar recursos        - sample-app-gateway- [Azure Kubernetes Service](https://docs.microsoft.com/en-us/azure/aks/)

kubectl get gateway,virtualservice,destinationrule,peerauthentication -n pets-staging

      hosts:

# Health check

kubectl describe virtualservice -n pets-staging        - sample.contoso.com## 📄 Licença

```

      http:

## 🎯 **Por que esta Abordagem?**

        - name: primary-routingEste projeto está licenciado sob a MIT License - veja o arquivo [LICENSE](LICENSE) para detalhes.

### ✅ **Vantagens**

          match:

- **Familiar**: Sintaxe Helm que desenvolvedores já conhecem

- **Leve**: Zero overhead do Tiller/Helm            - uri:---

- **Flexível**: Customização total do processo de renderização

- **Rápido**: Renderização direta sem dependências externas                prefix: /

- **Controlável**: Versionamento completo de valores e templates

          route:## 🏷️ Tags

### 🆚 **vs Helm Tradicional**

            - destination:

| Aspecto | Helm | Esta Solução |

|---------|------|--------------|                host: sample-app.primary.svc.cluster.local`istio` `aks` `kubernetes` `azure` `service-mesh` `templates` `ci-cd` `devops` `microservices` `parametrizable`

| Dependências | Helm CLI, Charts | Python + Jinja2 |

| Sintaxe | `{{ .Values.x }}` | `{{ .Values.x }}` ✅ |                port: 80

| Debugging | helm template | Renderização direta ✅ |

| CI/CD | Complexo | Simples ✅ |                subset: primary**Criado com ❤️ para máxima reutilização em múltiplas aplicações e esteiras de CI/CD**

| Customização | Limitada | Total ✅ |              weight: 90

            - destination:

## 🤝 **Contribuição**                host: sample-app.canary.svc.cluster.local

                port: 80

1. Fork do projeto                subset: canary

2. Criar feature branch: `git checkout -b feature/nova-funcionalidade`              weight: 10

3. Commit: `git commit -am 'Adiciona nova funcionalidade'````

4. Push: `git push origin feature/nova-funcionalidade`

5. Pull Request### `config/values/security.yaml`



### **Adicionando Templates**Inclui políticas padrão de mTLS e autorização.



1. Criar template em `/templates````yaml

2. Usar sintaxe `{{ .Values.xxx }}`security:

3. Adicionar configuração em `values*.yaml`  peer_authentications:

4. Testar renderização    - name: default-mtls

5. Atualizar documentação      namespace: sample-app

      mtls:

## 📄 **Licença**        mode: STRICT

  authorization_policies:

Este projeto está licenciado sob a [MIT License](LICENSE).    - name: sample-app-deny-external

      namespace: sample-app

## 🏷️ **Tags**      action: DENY

      rules:

`istio` `aks` `kubernetes` `azure` `service-mesh` `templates` `ci-cd` `devops` `jinja2` `helm-alternative`        - from:

            - source:

---                notPrincipals:

                  - cluster.local/ns/aks-istio-ingress/sa/istio-ingressgateway

**Criado com ❤️ para máxima reutilização e simplicidade em ambientes empresariais.**          to:
            - operation:
                hosts:
                  - sample-app.sample-app.svc.cluster.local
```

### `config/values/workloads.yaml`

Define workloads que precisam de objetos HPA.

```yaml
workloads:
  - name: sample-app
    namespace: sample-app
    autoscaling:
      enabled: true
      target:
        api_version: apps/v1
        kind: Deployment
        name: sample-app
      min_replicas: 2
      max_replicas: 6
      metrics:
        - type: Resource
          resource:
            name: cpu
            target:
              type: Utilization
              averageUtilization: 70
        - type: Resource
          resource:
            name: memory
            target:
              type: Utilization
              averageUtilization: 80
```

## Overlays de ambiente

Arquivos em `config/environments` podem sobrescrever qualquer chave. Eles são mesclados após os valores base.

Exemplo (`config/environments/prod.yaml`):

```yaml
global:
  environment: prod
  namespace: sample-app-prod
  annotations:
    deployment-window: "24x7"
traffic:
  virtual_services:
    - name: sample-app
      namespace: sample-app-prod
      gateways:
        - sample-app-gateway
      hosts:
        - sample.contoso.com
      http:
        - name: weighted-canary
          match:
            - uri:
                prefix: /
          route:
            - destination:
                host: sample-app.primary.svc.cluster.local
                port: 80
                subset: primary
              weight: 95
            - destination:
                host: sample-app.canary.svc.cluster.local
                port: 80
                subset: canary
              weight: 5
```

## Como renderizar os manifests

1. Certifique-se de estar na raiz do repositório.
2. Instale as dependências (`pip install -r requirements.txt`).
3. Execute o renderizador apontando para o ambiente desejado:

```powershell
python scripts/render.py --environment config/environments/prod.yaml --output-dir generated/prod
```

O script automaticamente carrega todos os arquivos YAML dentro de `config/values`. Use `-v` para fornecer arquivos adicionais ou `-m` para renderizar apenas módulos específicos:

```powershell
python scripts/render.py -m traffic -m security -e config/environments/staging.yaml -o generated/staging
```

Os manifests renderizados ficam em `generated/<ambiente>/...` com a mesma hierarquia dos templates.

## Aplicação no cluster

Depois de renderizar, aplique os manifests normalmente:

```powershell
kubectl apply -f generated/prod/templates/modules/traffic/gateways.yaml
kubectl apply -f generated/prod/templates/modules/traffic/virtualservices.yaml
kubectl apply -f generated/prod/templates/modules/workloads/hpa.yaml
```

Dica: utilize labels e anotações geradas pelos macros para rastrear deployments (`istio-templates.io/category`, `istio-templates.io/component`).

## Integração com CI/CD

- Adicione um passo de pipeline que executa `python scripts/render.py` e faz upload dos manifests como artefato.
- Utilize um segundo passo (ou job) com credenciais de cluster para aplicar os manifests renderizados.
- Para Pull Requests, execute o renderizador em modo `--strict` e valide as saídas com `kubectl apply --dry-run=client`.

## 🧪 Validação e Testes

### Validação Completa de Todos os Ambientes

```bash
# Validar todos os ambientes (production, staging, default)
python scripts/validate_templates.py -t templates
```

Este script automaticamente:
- ✅ Descobre todos os arquivos `values*.yaml`
- ✅ Renderiza templates para cada ambiente
- ✅ Valida sintaxe YAML dos manifests gerados
- ✅ Exibe resumo completo de sucesso/falha

### Validação Individual

```bash
# Validar apenas staging com modo strict
python scripts/helm_render.py \
  -t templates \
  -v templates/values-staging.yaml \
  -o /tmp/test \
  --strict

# Lint YAML dos arquivos de valores
yamllint templates/values*.yaml
```

### Checklist Antes de Commit

- [ ] `yamllint templates/values*.yaml` - sem erros
- [ ] `python scripts/validate_templates.py -t templates` - todos ambientes passaram
- [ ] Templates renderizados com `--strict` para todos os ambientes

Para mais detalhes, veja [Guia de Validação](docs/VALIDATION.md).

## Próximos passos sugeridos

- Expandir `templates/modules/workloads` com recursos adicionais (por exemplo, PodDisruptionBudget).
- Automatizar a validação YAML com `yamllint` ou `kubeval` após a renderização.
- Atualizar os workflows do GitHub Actions para usar o renderizador em vez dos antigos scripts Helm/envsubst.

---

Mantemos o foco em simplificar a adoção de Istio no AKS com máxima governança e reutilização. Contribuições são bem-vindas!

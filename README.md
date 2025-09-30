# 🚀 Istio Templates para AKS# Istio Templates para AKS com Jinja2yq --version



> **Estratégia Helm sem Helm** - Templates familiares com `{{ .Values.xxx }}` processados por renderizador Python customizado.envsubst --version



[![Deploy](https://github.com/ricardo2009/istio-aks-templates/actions/workflows/deploy.yml/badge.svg)](https://github.com/ricardo2009/istio-aks-templates/actions/workflows/deploy.yml)Este repositório fornece um conjunto de templates Istio modulares renderizados com Jinja2. O objetivo é substituir o uso de Helm/envsubst por uma abordagem 100% declarativa, reutilizável e fácil de automatizar em pipelines CI/CD no Azure Kubernetes Service (AKS) com o add-on Istio.az --version

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

istio-templates/

## 🎯 **Visão Geral**

## Visão geralenvsubst < traffic-management/gateway.yaml > processed-gateway.yaml

Este repositório fornece templates Istio **modulares** e **reutilizáveis** para Azure Kubernetes Service (AKS), utilizando sintaxe familiar do Helm sem a dependência do Helm.

envsubst < traffic-management/virtualservice.yaml > processed-virtualservice.yaml

### ✨ **Características**

- **Modularidade**: templates organizados por domínios (`traffic`, `security`, `workloads`).env | grep -E "(APP_NAME|SERVICE_HOST|NAMESPACE)"

- 🎨 **Sintaxe Helm**: `{{ .Values.app.name }}`, condicionais, loops

- 🔄 **Zero Dependência**: Sem Helm, apenas Python + Jinja2- **Reuso**: macros compartilhadas para metadados, rótulos e métricas.envsubst < template.yaml

- 🌍 **Multi-ambiente**: Dev, Staging, Production

- 🤖 **CI/CD Ready**: GitHub Actions otimizado- **Configuração declarativa**: valores versionados em `config/values` e overlays por ambiente em `config/environments`.yq e '.' processed-manifest.yaml

- 🔒 **Seguro**: mTLS, PeerAuthentication, políticas de segurança

- 📊 **Observável**: Labels e anotações padronizadas- **Renderização determinística**: script Python que combina valores + templates e gera manifests prontos para aplicar com `kubectl`.# peer-authentication.yaml



## 🚀 **Quick Start**apiVersion: security.istio.io/v1beta1



### **1. Instalação**## Estrutura de diretórioskind: PeerAuthentication



```bashmetadata:

git clone https://github.com/ricardo2009/istio-aks-templates.git

cd istio-aks-templates```  name: ${PA_NAME}

pip install -r requirements.txt

```.  namespace: ${NAMESPACE}



### **2. Renderizar Templates**├── config/spec:



```bash│   ├── environments/         # Overrides por ambiente (dev, staging, prod)  mtls:

# Ambiente staging

python scripts/helm_render.py -t templates -v templates/values-staging.yaml -o manifests/staging│   └── values/               # Configuração base modular    mode: ${MTLS_MODE}  # STRICT para prod, PERMISSIVE para dev



# Ambiente production├── docs/                     # Documentação complementar```

python scripts/helm_render.py -t templates -v templates/values-production.yaml -o manifests/production

```├── scripts/



### **3. Deploy no AKS**│   └── render.py             # Renderizador oficial (Jinja2)### Políticas de Autorização



```bash├── templates/

kubectl apply -f manifests/staging/

```│   ├── _shared/              # Macros utilitárias```yaml



## 📁 **Estrutura do Projeto**│   └── modules/# authorization-policy.yaml



```│       ├── security/         # PeerAuthentication, AuthorizationPolicy, ...apiVersion: security.istio.io/v1beta1

istio-aks-templates/

├── .github/workflows/           # CI/CD GitHub Actions│       ├── traffic/          # Gateway, VirtualService, DestinationRulekind: AuthorizationPolicy

│   └── deploy.yml              # Workflow principal

├── templates/                   # Templates Helm-style│       └── workloads/        # HorizontalPodAutoscaler (HPA)metadata:

│   ├── values.yaml             # Valores padrão

│   ├── values-staging.yaml     # Configuração staging└── requirements.txt          # Dependências Python necessárias  name: ${AUTH_POLICY_NAME}

│   ├── values-production.yaml  # Configuração production

│   ├── gateway.yaml            # Template Gateway```spec:

│   ├── virtualservice.yaml     # Template VirtualService

│   ├── destinationrule.yaml    # Template DestinationRule  action: ${AUTH_ACTION}  # ALLOW/DENY

│   └── peerauthentication.yaml # Template PeerAuthentication

├── manifests/                   # Output renderizado (gitignored)## Pré-requisitos  rules:

│   ├── staging/                # Manifests staging

│   └── production/             # Manifests production  - from:

├── scripts/

│   └── helm_render.py          # Renderizador principal- Python 3.9+    - source:

├── docs/                       # Documentação

│   ├── USAGE.md               # Guia de uso- Pip (para instalar as dependências)        principals: ["cluster.local/ns/${NAMESPACE}/sa/${SERVICE_ACCOUNT}"]

│   └── CICD.md                # Configuração CI/CD

└── README.md                   # Este arquivo- Kubectl configurado para o cluster AKS (deploy manual ou via pipeline)```

```

- Azure CLI (opcional, apenas se for provisionar/gerenciar o cluster)

## 🔧 **Configuração por Ambiente**

## 📊 Observabilidade

### **Staging** (`values-staging.yaml`)

- Namespace: `pets-staging`Instale as dependências Python:

- mTLS: `PERMISSIVE` (desenvolvimento)

- Routing: 90% primary, 10% canary### Métricas Automáticas

- Domain: `pets-staging.contoso.com`

```powershell

### **Production** (`values-production.yaml`)

- Namespace: `pets-prod`python -m pip install -r requirements.txt```bash

- mTLS: `STRICT` (máxima segurança)

- Routing: 95% primary, 5% canary```# Verificar métricas do Prometheus

- Domain: `pets.contoso.com`

kubectl port-forward -n aks-istio-system svc/prometheus 9090:9090

## 🎨 **Exemplos de Templates**

## Configuração de valores

### **Gateway com TLS**

```yaml# Grafana (se instalado)

apiVersion: networking.istio.io/v1beta1

kind: GatewayOs valores são separados em arquivos temáticos para facilitar a manutenção.kubectl port-forward -n aks-istio-system svc/grafana 3000:3000

metadata:

  name: {{ .Values.network.gateway.name }}```

  namespace: {{ .Values.network.gateway.namespace }}

spec:### `config/values/global.yaml`

  selector:

    istio: aks-istio-ingressgateway-external### Tracing com Jaeger

  servers:

  - port:Define metadados padrão usados por todos os manifests.

      number: 443

      name: https```bash

      protocol: HTTPS

    hosts:```yaml# Acessar Jaeger UI

{{- range .Values.network.gateway.hosts }}

    - {{ . }}global:kubectl port-forward -n aks-istio-system svc/jaeger-query 16686:16686

{{- end }}

    tls:  app: sample-app```

      mode: SIMPLE

      credentialName: {{ .Values.network.gateway.tls.secretName }}  version: "1.0.0"

```

  environment: dev## 🤝 Contribuição

### **VirtualService com Canary**

```yaml  namespace: sample-app

spec:

  http:  labels:### Como Contribuir

  - name: primary-routing

    route:    managed_by: istio-blueprints

    - destination:

        host: {{ .Values.service.host }}    cost_center: platform-team1. Fork do repositório

        subset: primary

      weight: {{ .Values.network.virtualservice.routing.primary.weight }}  annotations:2. Criar branch para feature: `git checkout -b feature/nova-funcionalidade`

{{- if gt .Values.network.virtualservice.routing.canary.weight 0 }}

    - destination:    owner: platform-team@contoso.com3. Commit das mudanças: `git commit -am 'Adiciona nova funcionalidade'`

        host: {{ .Values.service.host }}

        subset: canary```4. Push para branch: `git push origin feature/nova-funcionalidade`

      weight: {{ .Values.network.virtualservice.routing.canary.weight }}

{{- end }}5. Abrir Pull Request

```

### `config/values/traffic.yaml`

## 🤖 **CI/CD com GitHub Actions**

### Padrões de Código

### **Workflow Automático**

Configura gateways, virtual services e destination rules reutilizáveis.

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

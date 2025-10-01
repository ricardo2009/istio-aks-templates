# 🔄 CI/CD com GitHub Actions - Demo Lab# 🔄 CI/CD com GitHub Actions



## 🎯 Visão Geral do Workflow## 🎯 **Workflow Automatizado**



O repositório utiliza GitHub Actions para **validação automatizada e deploy contínuo** do laboratório Istio no ambiente demo.O repositório inclui um workflow GitHub Actions otimizado para deployment em múltiplos ambientes.



---## 📋 **Configuração Necessária**



## 📋 Workflow Unificado### **1. Secrets do GitHub**



### Arquivo: `.github/workflows/deploy.yml`Configure os seguintes secrets no seu repositório GitHub:



O workflow executa em **dois jobs**:```bash

# Azure credentials (Service Principal)

1. **`validate`**: Valida sintaxe YAML e estrutura dos manifestosAZURE_CREDENTIALS

2. **`deploy-demo`**: Sincroniza TLS e aplica manifestos no cluster AKS

# Resource groups

### TriggersAKS_RESOURCE_GROUP



```yaml# Clusters AKS

on:AKS_CLUSTER_NAME_STAGING

  push:AKS_CLUSTER_NAME_PROD

    branches: [main]```

    paths:

      - 'manifests/demo/**'### **2. Environments GitHub**

      - 'scripts/**'

      - '.github/workflows/**'Crie os environments no GitHub:

  pull_request:- `staging` - Para deploys automáticos de PRs

    branches: [main]- `production` - Para deploys do branch main (com approval)

    paths:

      - 'manifests/demo/**'## 🚀 **Fluxo de Trabalho**

      - 'scripts/**'

  workflow_dispatch:  # Permite execução manual### **Pull Request → Staging**

```

1. **Trigger**: Push em PR com mudanças em `templates/` ou `scripts/`

---2. **Validação**: Lint YAML + Sintaxe dos templates

3. **Deploy**: Renderiza com `values-staging.yaml` e aplica no AKS staging

## 🔧 Configuração Necessária4. **Verificação**: Valida resources Istio no cluster



### 1. GitHub Secrets### **Merge to Main → Production**



Configure os seguintes secrets no repositório (Settings → Secrets and variables → Actions):1. **Trigger**: Push no branch `main`

2. **Validação**: Mesma validação do staging

| Secret | Descrição | Como Obter |3. **Deploy**: Renderiza com `values-production.yaml` e aplica no AKS production

|--------|-----------|------------|4. **Verificação**: Health check completo

| `AZURE_CREDENTIALS` | Service Principal JSON | `az ad sp create-for-rbac --name "gh-istio-demo" --role contributor --scopes /subscriptions/<SUB_ID>/resourceGroups/<RG> --sdk-auth` |

| `AKS_RESOURCE_GROUP` | Nome do Resource Group | Ex: `rg-aks-labs` |## 🔧 **Customização do Workflow**

| `AKS_CLUSTER_NAME` | Nome do cluster AKS | Ex: `aks-labs` |

| `AZURE_KEYVAULT_NAME` | Nome do Key Vault (opcional) | Ex: `kv-aks-labs-secrets` |### **Adicionar Validações**



**Exemplo de `AZURE_CREDENTIALS`**:```yaml

```json- name: Validate Istio manifests

{  run: |

  "clientId": "<GUID>",    istioctl analyze manifests/staging/

  "clientSecret": "<SECRET>",```

  "subscriptionId": "<GUID>",

  "tenantId": "<GUID>",### **Adicionar Testes**

  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",

  "resourceManagerEndpointUrl": "https://management.azure.com/",```yaml

  "activeDirectoryGraphResourceId": "https://graph.windows.net/",- name: Run integration tests

  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",  run: |

  "galleryEndpointUrl": "https://gallery.azure.com/",    kubectl apply -f manifests/staging/

  "managementEndpointUrl": "https://management.core.windows.net/"    sleep 30

}    curl -f https://pets-staging.contoso.com/health

``````



### 2. GitHub Environment (Opcional)### **Adicionar Notifications**



Crie environment `demo` para adicionar **approval gate**:```yaml

- name: Notify Slack

1. Settings → Environments → New environment  uses: 8398a7/action-slack@v3

2. Nome: `demo`  with:

3. Ativar **Required reviewers** (adicione usuários/times)    status: ${{ job.status }}

4. Ativar **Wait timer** se quiser delay antes do deploy    webhook_url: ${{ secrets.SLACK_WEBHOOK }}

```

---

## 📊 **Monitoramento**

## 🚀 Fluxo do Workflow

### **Artifacts**

### Job 1: Validate

O workflow gera artifacts com os manifests renderizados:

```yaml- Retenção: 30 dias

validate:- Download: Via GitHub Actions UI

  runs-on: ubuntu-latest

  steps:### **Logs**

    - uses: actions/checkout@v4

    Monitore os logs para:

    - name: Set up Python- ✅ Renderização bem-sucedida

      uses: actions/setup-python@v5- ✅ Deploy sem erros

      with:- ✅ Verificação dos resources

        python-version: '3.11'

    ## 🔒 **Segurança**

    - name: Install dependencies

      run: pip install yamllint pyyaml### **Service Principal**

    

    - name: Lint YAML manifestsUse um Service Principal com mínimos privilégios:

      run: yamllint -d '{extends: default, rules: {line-length: {max: 200}}}' manifests/demo/

    ```bash

    - name: Validate manifests structure# Criar SP

      run: python scripts/validate_templates.py -m manifests/demoaz ad sp create-for-rbac --name "istio-templates-ci" \

```  --role contributor \

  --scopes /subscriptions/{subscription-id}/resourceGroups/{rg-name}

**O que faz**:

- ✅ Verifica sintaxe YAML com `yamllint`# Output para AZURE_CREDENTIALS

- ✅ Valida estrutura Kubernetes/Istio (apiVersion, kind, metadata){

- ✅ Executa em **todos os pushes e PRs**  "clientId": "xxx",

  "clientSecret": "xxx",

### Job 2: Deploy Demo  "subscriptionId": "xxx",

  "tenantId": "xxx"

```yaml}

deploy-demo:```

  needs: validate

  runs-on: ubuntu-latest### **RBAC Kubernetes**

  environment: demo  # Requer approval se configurado

  steps:Configure RBAC adequado para o Service Principal no AKS.

    - name: Azure Login

      uses: azure/login@v2## 🎯 **Best Practices**

      with:

        creds: ${{ secrets.AZURE_CREDENTIALS }}1. **Ambientes Isolados**: Staging e Production em clusters separados

    2. **Approval Gates**: Environment protection rules para Production

    - name: Get AKS credentials3. **Rollback Strategy**: Mantenha manifests anteriores para rollback

      run: |4. **Monitoring**: Configure alertas para falhas de deployment

        az aks get-credentials \5. **Security**: Scan dos manifests com ferramentas de segurança

          --resource-group ${{ secrets.AKS_RESOURCE_GROUP }} \

          --name ${{ secrets.AKS_CLUSTER_NAME }} \## 🔍 **Troubleshooting**

          --overwrite-existing

    ### **Falha na Renderização**

    - name: Sync TLS Secret (optional)- Verificar sintaxe dos templates

      run: |- Validar arquivo de values

        python scripts/sync_tls_secret.py \

          --keyvault-name ${{ secrets.AZURE_KEYVAULT_NAME }} \### **Falha no Deploy**

          --cert-name pets-demo-tls \- Verificar conectividade AKS

          --namespace pets- Validar permissões RBAC

    - Confirmar namespace existe

    - name: Create namespace

      run: |### **Resources não Aplicados**

        kubectl create namespace pets --dry-run=client -o yaml | kubectl apply -f -- Verificar logs do workflow

        kubectl label namespace pets istio.io/rev=asm-1-23 --overwrite- Validar manifests renderizados

    - Testar kubectl apply local
    - name: Apply Istio manifests
      run: kubectl apply -f manifests/demo/
    
    - name: Verify deployment
      run: |
        kubectl get gateway,vs,dr,pa,ra,ap -n pets
        kubectl wait --for=condition=ready pod -l app=pets -n pets --timeout=300s
```

**O que faz**:
- 🔐 Autentica no Azure
- ☸️ Configura `kubectl` para o cluster
- 🔑 Sincroniza certificado TLS do Key Vault (opcional)
- 📦 Cria namespace `pets` com label Istio
- 🚀 Aplica todos os manifestos demo
- ✅ Verifica status dos recursos

---

## 🧪 Teste Local do Workflow

### Simular CI Localmente

```bash
# Executar script de teste
bash scripts/test_ci_workflow.sh
```

**O que o script faz**:
1. Instala dependências Python
2. Executa lint YAML nos manifestos
3. Valida estrutura dos manifestos
4. Simula exatamente o job `validate` do GitHub Actions

### Dry-run Manual

```powershell
# Validar manifestos
python scripts/validate_templates.py -m manifests/demo

# Lint YAML
yamllint manifests/demo/

# Dry-run no cluster
kubectl apply --dry-run=client -f manifests/demo/

# Validar com istioctl
istioctl analyze -n pets
```

---

## 📊 Monitoramento do Workflow

### Visualizar Execuções

1. Acesse: `https://github.com/<OWNER>/<REPO>/actions`
2. Clique no workflow "Deploy Istio Demo Lab"
3. Veja execuções recentes com status (✅ Success, ❌ Failed, 🔄 In Progress)

### Logs Detalhados

```yaml
# Em cada step, os logs mostram:
- Comandos executados
- Output completo (stdout/stderr)
- Duração de cada passo
```

**Exemplo de log de sucesso**:
```
✅ Lint YAML manifests
   yamllint -d '{...}' manifests/demo/
   (sem output = sem erros)

✅ Validate manifests structure
   🚀 Iniciando validação de manifestos Istio Demo Lab
   📋 Manifestos encontrados: 11
   🔍 Validando: gateway.yaml
     ✓ Sintaxe YAML válida
     ✓ Estrutura válida
   ...
   🎉 Todos os manifestos foram validados com sucesso!
```

---

## 🔒 Segurança

### Service Principal com Least Privilege

```bash
# Criar SP apenas com acesso ao RG específico
az ad sp create-for-rbac \
  --name "gh-istio-demo-ci" \
  --role "Azure Kubernetes Service Cluster User Role" \
  --scopes /subscriptions/<SUB_ID>/resourceGroups/<RG>/providers/Microsoft.ContainerService/managedClusters/<AKS_NAME> \
  --sdk-auth

# Adicionar permissão para Key Vault (se necessário)
az keyvault set-policy \
  --name kv-aks-labs-secrets \
  --spn <CLIENT_ID> \
  --secret-permissions get list \
  --certificate-permissions get list
```

### Proteção de Secrets

- ❌ **NUNCA** commitar secrets no código
- ✅ Usar GitHub Secrets para credenciais
- ✅ Rotar secrets regularmente (a cada 90 dias)
- ✅ Usar Managed Identity quando possível (Azure-hosted runners)

---

## 🎨 Customizações

### Adicionar Validação com istioctl

```yaml
- name: Analyze Istio config
  run: |
    curl -L https://istio.io/downloadIstio | sh -
    export PATH=$PWD/istio-*/bin:$PATH
    istioctl analyze -n pets
```

### Adicionar Testes de Integração

```yaml
- name: Integration tests
  run: |
    kubectl apply -f manifests/demo/
    sleep 30
    
    # Testar endpoint público
    GATEWAY_IP=$(kubectl get svc -n aks-istio-ingress \
      aks-istio-ingressgateway-external \
      -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    curl -f http://$GATEWAY_IP/api/pets || exit 1
```

### Adicionar Notificações Slack

```yaml
- name: Notify Slack on failure
  if: failure()
  uses: 8398a7/action-slack@v3
  with:
    status: failure
    text: 'Deploy demo falhou! 🚨'
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

### Adicionar Deploy Progressivo

```yaml
# Aumentar canary gradualmente
- name: Progressive canary
  run: |
    # Iniciar com 10%
    kubectl patch vs pets-routes -n pets --type merge -p '{"spec":{"http":[{"route":[{"weight":90},{"weight":10}]}]}}'
    sleep 300
    
    # Aumentar para 50%
    kubectl patch vs pets-routes -n pets --type merge -p '{"spec":{"http":[{"route":[{"weight":50},{"weight":50}]}]}}'
    sleep 300
    
    # 100% canary
    kubectl patch vs pets-routes -n pets --type merge -p '{"spec":{"http":[{"route":[{"weight":0},{"weight":100}]}]}}'
```

---

## 📈 Artifacts e Logs

### Download de Artifacts

```yaml
- name: Upload manifests
  uses: actions/upload-artifact@v4
  with:
    name: istio-manifests
    path: manifests/demo/
    retention-days: 30
```

**Como baixar**:
1. Acesse a execução do workflow
2. Role até "Artifacts"
3. Clique em "istio-manifests" para download

### Logs Persistentes

```yaml
- name: Collect logs on failure
  if: failure()
  run: |
    kubectl logs -n aks-istio-ingress -l app=aks-istio-ingressgateway-external > gateway-logs.txt
    kubectl get events -n pets --sort-by='.lastTimestamp' > events.txt
    
- name: Upload logs
  if: failure()
  uses: actions/upload-artifact@v4
  with:
    name: debug-logs
    path: |
      gateway-logs.txt
      events.txt
```

---

## 🔄 GitOps com ArgoCD/Flux (Futuro)

### Integração com ArgoCD

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: istio-demo-lab
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<OWNER>/<REPO>
    targetRevision: main
    path: manifests/demo
  destination:
    server: https://kubernetes.default.svc
    namespace: pets
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Integração com Flux

```bash
# Bootstrap Flux
flux bootstrap github \
  --owner=<OWNER> \
  --repository=<REPO> \
  --path=clusters/demo \
  --personal

# Criar Kustomization
flux create kustomization istio-demo \
  --source=GitRepository/flux-system \
  --path="./manifests/demo" \
  --prune=true \
  --interval=5m
```

---

## 🤝 Troubleshooting do Workflow

### Problema: Workflow não é triggered

**Causa**: Paths do trigger não incluem arquivos modificados

**Solução**:
```yaml
on:
  push:
    branches: [main]
    # Remover paths para trigger em QUALQUER push
```

### Problema: Azure Login falha

**Causa**: `AZURE_CREDENTIALS` inválido ou expirado

**Solução**:
```bash
# Recriar Service Principal
az ad sp create-for-rbac --name "gh-istio-demo" --role contributor --scopes /subscriptions/<SUB_ID> --sdk-auth

# Atualizar secret no GitHub
```

### Problema: kubectl não encontra cluster

**Causa**: Credenciais AKS não configuradas

**Solução**:
```yaml
- name: Get AKS credentials
  run: |
    az aks get-credentials \
      --resource-group ${{ secrets.AKS_RESOURCE_GROUP }} \
      --name ${{ secrets.AKS_CLUSTER_NAME }} \
      --overwrite-existing
```

---

## 📚 Recursos Adicionais

- [GitHub Actions Docs](https://docs.github.com/actions)
- [Azure Login Action](https://github.com/Azure/login)
- [Kubectl Tool Installer](https://github.com/Azure/setup-kubectl)
- [GitOps com ArgoCD](https://argo-cd.readthedocs.io/)

---

**🎉 Com este workflow, você tem CI/CD completo para o laboratório Istio demo!**

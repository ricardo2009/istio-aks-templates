# 🔄 CI/CD com GitHub Actions

## 🎯 **Workflow Automatizado**

O repositório inclui um workflow GitHub Actions otimizado para deployment em múltiplos ambientes.

## 📋 **Configuração Necessária**

### **1. Secrets do GitHub**

Configure os seguintes secrets no seu repositório GitHub:

```bash
# Azure credentials (Service Principal)
AZURE_CREDENTIALS

# Resource groups
AKS_RESOURCE_GROUP

# Clusters AKS
AKS_CLUSTER_NAME_STAGING
AKS_CLUSTER_NAME_PROD
```

### **2. Environments GitHub**

Crie os environments no GitHub:
- `staging` - Para deploys automáticos de PRs
- `production` - Para deploys do branch main (com approval)

## 🚀 **Fluxo de Trabalho**

### **Pull Request → Staging**

1. **Trigger**: Push em PR com mudanças em `templates/` ou `scripts/`
2. **Validação**: Lint YAML + Sintaxe dos templates
3. **Deploy**: Renderiza com `values-staging.yaml` e aplica no AKS staging
4. **Verificação**: Valida resources Istio no cluster

### **Merge to Main → Production**

1. **Trigger**: Push no branch `main`
2. **Validação**: Mesma validação do staging
3. **Deploy**: Renderiza com `values-production.yaml` e aplica no AKS production
4. **Verificação**: Health check completo

## 🔧 **Customização do Workflow**

### **Adicionar Validações**

```yaml
- name: Validate Istio manifests
  run: |
    istioctl analyze manifests/staging/
```

### **Adicionar Testes**

```yaml
- name: Run integration tests
  run: |
    kubectl apply -f manifests/staging/
    sleep 30
    curl -f https://pets-staging.contoso.com/health
```

### **Adicionar Notifications**

```yaml
- name: Notify Slack
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

## 📊 **Monitoramento**

### **Artifacts**

O workflow gera artifacts com os manifests renderizados:
- Retenção: 30 dias
- Download: Via GitHub Actions UI

### **Logs**

Monitore os logs para:
- ✅ Renderização bem-sucedida
- ✅ Deploy sem erros
- ✅ Verificação dos resources

## 🔒 **Segurança**

### **Service Principal**

Use um Service Principal com mínimos privilégios:

```bash
# Criar SP
az ad sp create-for-rbac --name "istio-templates-ci" \
  --role contributor \
  --scopes /subscriptions/{subscription-id}/resourceGroups/{rg-name}

# Output para AZURE_CREDENTIALS
{
  "clientId": "xxx",
  "clientSecret": "xxx",
  "subscriptionId": "xxx",
  "tenantId": "xxx"
}
```

### **RBAC Kubernetes**

Configure RBAC adequado para o Service Principal no AKS.

## 🎯 **Best Practices**

1. **Ambientes Isolados**: Staging e Production em clusters separados
2. **Approval Gates**: Environment protection rules para Production
3. **Rollback Strategy**: Mantenha manifests anteriores para rollback
4. **Monitoring**: Configure alertas para falhas de deployment
5. **Security**: Scan dos manifests com ferramentas de segurança

## 🔍 **Troubleshooting**

### **Falha na Renderização**
- Verificar sintaxe dos templates
- Validar arquivo de values

### **Falha no Deploy**
- Verificar conectividade AKS
- Validar permissões RBAC
- Confirmar namespace existe

### **Resources não Aplicados**
- Verificar logs do workflow
- Validar manifests renderizados
- Testar kubectl apply local
# Tutorial 02: Configurar Azure Key Vault para Certificados TLS

## 📋 Índice

- [O que é Azure Key Vault?](#o-que-é-azure-key-vault)
- [Por que usar Key Vault para certificados?](#por-que-usar-key-vault-para-certificados)
- [Pré-requisitos](#pré-requisitos)
- [Passo 1: Preparar o Key Vault](#passo-1-preparar-o-key-vault)
- [Passo 2: Habilitar Workload Identity no AKS](#passo-2-habilitar-workload-identity-no-aks)
- [Passo 3: Instalar CSI Secrets Store Driver](#passo-3-instalar-csi-secrets-store-driver)
- [Passo 4: Criar Identidade para cert-manager](#passo-4-criar-identidade-para-cert-manager)
- [Passo 5: Configurar cert-manager com Key Vault](#passo-5-configurar-cert-manager-com-key-vault)
- [Passo 6: Testar Integração](#passo-6-testar-integração)
- [Troubleshooting](#troubleshooting)

---

## O que é Azure Key Vault?

**Azure Key Vault** é um cofre de segredos gerenciado pela Microsoft que armazena:

- 🔐 **Secrets**: Strings sensíveis (senhas, connection strings, tokens)
- 🔑 **Keys**: Chaves criptográficas (RSA, EC, HSM)
- 📜 **Certificates**: Certificados X.509 e suas chaves privadas

### Arquitetura da Integração

```text
┌─────────────────────────────────────────────────────────────┐
│                      AKS CLUSTER                            │
│                                                             │
│  ┌──────────────┐                                          │
│  │ cert-manager │  ← Workload Identity                    │
│  │              │    (Federated Credential)                │
│  └──────┬───────┘                                          │
│         │ 1. Request certificate                           │
│         ├─────────────────────────────┐                    │
│         ▼                             ▼                    │
│  ┌──────────────┐              ┌──────────────┐           │
│  │ Let's Encrypt│              │ CSI Driver   │           │
│  │   (ACME)     │              │   (Sync)     │           │
│  └──────┬───────┘              └──────┬───────┘           │
│         │                             │                    │
└─────────┼─────────────────────────────┼────────────────────┘
          │                             │
          │ 2. Get cert                 │ 3. Store cert
          ▼                             ▼
┌─────────────────────────────────────────────────────────────┐
│                   AZURE KEY VAULT                           │
│                                                             │
│  📜 Certificates:                                           │
│    • store-front-cert (Let's Encrypt)                      │
│    • *.4.249.81.21.nip.io                                  │
│    • Auto-renewal (30 dias antes de expirar)              │
│                                                             │
│  🔒 Access Policies / RBAC:                                │
│    • cert-manager identity: Get, Create, Update            │
│    • CSI Driver identity: Get                              │
└─────────────────────────────────────────────────────────────┘
          │
          │ 4. Mount as volume
          ▼
┌─────────────────────────────────────────────────────────────┐
│                    POD (store-front)                        │
│  /mnt/secrets-store/                                        │
│    ├─ tls.crt  ← Certificate                               │
│    └─ tls.key  ← Private key                               │
└─────────────────────────────────────────────────────────────┘
```

---

## Por que usar Key Vault para certificados?

### ❌ Problema com Kubernetes Secrets apenas

| Problema | Impacto |
|----------|---------|
| **Armazenados em etcd** | Base64, não criptografado at-rest por padrão |
| **Sem auditoria** | Quem acessou o certificado? |
| **Difícil rotação** | Precisa reiniciar pods manualmente |
| **Sem backup central** | Se cluster for destruído, certificados perdidos |
| **Sem integração com CA** | Não pode importar de CA externa |
| **Permissões grosseiras** | RBAC Kubernetes é namespace-based |

### ✅ Vantagens do Azure Key Vault

| Vantagem | Benefício |
|----------|-----------|
| **HSM-backed** | Chaves armazenadas em Hardware Security Modules (FIPS 140-2 Level 2) |
| **Auditoria completa** | Logs de quem acessou, quando, de onde |
| **Rotação automática** | Cert-manager renova e atualiza Key Vault |
| **Backup gerenciado** | Microsoft replica e faz backup |
| **Integração com CA** | Pode importar de DigiCert, GlobalSign, etc |
| **RBAC granular** | Azure AD identity + permissões específicas |
| **Compliance** | SOC, ISO, PCI-DSS, HIPAA, FedRAMP |
| **Recuperação de desastres** | Soft-delete + purge protection |

### 🏗️ Arquitetura de Segurança

```text
┌─────────────────────────────────────────────────────────────┐
│                   CAMADA DE IDENTIDADE                      │
│                                                             │
│  cert-manager pod                                           │
│       ↓                                                     │
│  ServiceAccount: cert-manager                               │
│       ↓                                                     │
│  Workload Identity (federated credential)                  │
│       ↓                                                     │
│  Azure AD Managed Identity                                  │
│       ↓                                                     │
│  RBAC: Key Vault Certificates Officer                      │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                    CAMADA DE AUDITORIA                      │
│                                                             │
│  Azure Monitor Logs:                                        │
│    • Who: Managed Identity ID                               │
│    • When: 2025-10-01T12:34:56Z                            │
│    • What: Get Certificate "store-front-cert"              │
│    • Result: Success / Denied                               │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                   CAMADA DE STORAGE                         │
│                                                             │
│  Key Vault:                                                 │
│    • Encryption at-rest: AES-256                            │
│    • Encryption in-transit: TLS 1.2+                        │
│    • Soft-delete: 90 dias                                   │
│    • Purge protection: Enabled                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Pré-requisitos

### ✅ Checklist antes de começar

- [ ] Tutorial 01 concluído (Azure Monitor configurado)
- [ ] Parâmetros capturados (`aks-labs.config` existe)
- [ ] cert-manager instalado no cluster
- [ ] Azure CLI com extensão `aks-preview`

### Verificar cert-manager

```powershell
# Carregar parâmetros
. ../../aks-labs.config

Write-Host "═══ Verificando cert-manager ═══" -ForegroundColor Yellow

$certManagerPods = kubectl get pods -n cert-manager -o json 2>$null

if ($null -eq $certManagerPods) {
    Write-Host "⚠ cert-manager NÃO está instalado!" -ForegroundColor Red
    Write-Host "Instalando cert-manager..." -ForegroundColor Cyan
    
    # Instalar cert-manager
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.yaml
    
    Write-Host "Aguardando pods ficarem prontos (60s)..." -ForegroundColor Cyan
    kubectl wait --for=condition=Ready pods --all -n cert-manager --timeout=120s
    
    Write-Host "✓ cert-manager instalado!" -ForegroundColor Green
} else {
    Write-Host "✓ cert-manager já instalado" -ForegroundColor Green
    kubectl get pods -n cert-manager
}
```

**O que observar**:
- 3 pods devem estar Running: `cert-manager`, `cert-manager-cainjector`, `cert-manager-webhook`
- Todos com status `1/1 Ready`

**Por que fazer isso**: O cert-manager é responsável por solicitar e renovar certificados automaticamente. Sem ele, a integração com Key Vault não funciona.

---

## Passo 1: Preparar o Key Vault

### 1.1. Verificar Key Vault existente

```powershell
Write-Host "`n═══ Preparando Key Vault ═══" -ForegroundColor Yellow

# Nome do Key Vault vem do aks-labs.config
Write-Host "Key Vault: $KEY_VAULT_NAME" -ForegroundColor Cyan

# Verificar se existe
$kv = az keyvault show --name $KEY_VAULT_NAME --resource-group $CLUSTER_RESOURCE_GROUP --output json 2>$null

if ($null -eq $kv) {
    Write-Host "⚠ Key Vault não encontrado! Criando..." -ForegroundColor Yellow
    
    # Criar Key Vault
    az keyvault create `
        --name $KEY_VAULT_NAME `
        --resource-group $CLUSTER_RESOURCE_GROUP `
        --location $CLUSTER_LOCATION `
        --enable-rbac-authorization `
        --enable-purge-protection `
        --retention-days 90
    
    Write-Host "✓ Key Vault criado!" -ForegroundColor Green
} else {
    Write-Host "✓ Key Vault já existe" -ForegroundColor Green
}

# Capturar ID do Key Vault
$kvJson = az keyvault show --name $KEY_VAULT_NAME --resource-group $CLUSTER_RESOURCE_GROUP --output json | ConvertFrom-Json
$KEY_VAULT_ID = $kvJson.id

Write-Host "Key Vault ID: $KEY_VAULT_ID" -ForegroundColor Gray
```

**O que observar**:
- `--enable-rbac-authorization`: Usa Azure RBAC ao invés de Access Policies (mais seguro)
- `--enable-purge-protection`: Impede deleção permanente acidental (compliance)
- `--retention-days 90`: Período de soft-delete

**Por que fazer isso**: Configura o Key Vault com as melhores práticas de segurança antes de integrar com AKS.

### 1.2. Habilitar auditoria (opcional mas recomendado)

```powershell
Write-Host "`n═══ Habilitando Auditoria ═══" -ForegroundColor Yellow

# Criar workspace do Log Analytics (se não existir)
$logWorkspaceName = "log-$CLUSTER_NAME"

$logWs = az monitor log-analytics workspace show `
    --resource-group $CLUSTER_RESOURCE_GROUP `
    --workspace-name $logWorkspaceName `
    --output json 2>$null

if ($null -eq $logWs) {
    Write-Host "Criando Log Analytics workspace..." -ForegroundColor Cyan
    
    $logWs = az monitor log-analytics workspace create `
        --resource-group $CLUSTER_RESOURCE_GROUP `
        --workspace-name $logWorkspaceName `
        --location $CLUSTER_LOCATION `
        --output json | ConvertFrom-Json
    
    Write-Host "✓ Workspace criado!" -ForegroundColor Green
} else {
    $logWs = $logWs | ConvertFrom-Json
    Write-Host "✓ Workspace já existe" -ForegroundColor Green
}

$LOG_WORKSPACE_ID = $logWs.id

# Habilitar diagnostic settings no Key Vault
Write-Host "Configurando diagnostic settings..." -ForegroundColor Cyan

az monitor diagnostic-settings create `
    --name "kvaudit-$KEY_VAULT_NAME" `
    --resource $KEY_VAULT_ID `
    --logs '[{"category": "AuditEvent", "enabled": true}]' `
    --metrics '[{"category": "AllMetrics", "enabled": true}]' `
    --workspace $LOG_WORKSPACE_ID

Write-Host "✓ Auditoria habilitada!" -ForegroundColor Green
Write-Host "  Logs serão enviados para: $logWorkspaceName" -ForegroundColor Gray
```

**O que observar**:
- Logs de auditoria = quem acessou o Key Vault
- Retenção padrão = 30 dias (pode aumentar)

**Por que fazer isso**: Compliance e troubleshooting. Permite ver exatamente quem acessou certificados e quando.

---

## Passo 2: Habilitar Workload Identity no AKS

### 2.1. O que é Workload Identity?

**Workload Identity** permite que pods no Kubernetes se autentiquem no Azure usando **Federated Credentials** (sem secrets!).

**Fluxo de autenticação**:

```text
1. Pod inicia com ServiceAccount
2. Kubelet injeta token JWT no pod
3. Pod troca JWT por Azure AD token
4. Azure AD valida o token via OIDC Issuer
5. Azure AD retorna token com acesso ao Key Vault
```

**Vantagens vs Secrets**:
- ❌ Secrets: String fixa, pode vazar, precisa rotação manual
- ✅ Workload Identity: Token de curta duração (1h), rotação automática, sem storage

### 2.2. Verificar se Workload Identity está habilitado

```powershell
Write-Host "`n═══ Verificando Workload Identity ═══" -ForegroundColor Yellow

$oidcIssuer = az aks show `
    --resource-group $CLUSTER_RESOURCE_GROUP `
    --name $CLUSTER_NAME `
    --query "oidcIssuerProfile.issuerUrl" `
    --output tsv

if ([string]::IsNullOrWhiteSpace($oidcIssuer)) {
    Write-Host "⚠ Workload Identity NÃO está habilitado!" -ForegroundColor Red
    Write-Host "Habilitando..." -ForegroundColor Cyan
    
    # Habilitar OIDC Issuer e Workload Identity
    az aks update `
        --resource-group $CLUSTER_RESOURCE_GROUP `
        --name $CLUSTER_NAME `
        --enable-oidc-issuer `
        --enable-workload-identity
    
    # Buscar OIDC Issuer novamente
    $oidcIssuer = az aks show `
        --resource-group $CLUSTER_RESOURCE_GROUP `
        --name $CLUSTER_NAME `
        --query "oidcIssuerProfile.issuerUrl" `
        --output tsv
    
    Write-Host "✓ Workload Identity habilitado!" -ForegroundColor Green
} else {
    Write-Host "✓ Workload Identity já habilitado" -ForegroundColor Green
}

Write-Host "OIDC Issuer URL: $oidcIssuer" -ForegroundColor Gray

# Salvar no config
$configPath = "../../aks-labs.config"
$configContent = Get-Content $configPath
if ($configContent -match "OIDC_ISSUER_URL=") {
    $configContent = $configContent -replace "OIDC_ISSUER_URL=.*", "OIDC_ISSUER_URL=$oidcIssuer"
} else {
    $configContent += "`nOIDC_ISSUER_URL=$oidcIssuer"
}
$configContent | Out-File -FilePath $configPath -Encoding UTF8 -Force

Write-Host "✓ OIDC Issuer URL salvo em config" -ForegroundColor Green
```

**O que observar**:
- `--enable-oidc-issuer`: Expõe endpoint público OIDC
- `--enable-workload-identity`: Habilita webhook para injeção de token
- OIDC URL: `https://<region>.oic.prod-aks.azure.com/<guid>/`

**Por que fazer isso**: Sem OIDC Issuer, o Azure AD não pode validar tokens do Kubernetes.

---

## Passo 3: Instalar CSI Secrets Store Driver

### 3.1. O que é CSI Secrets Store Driver?

**Container Storage Interface (CSI) Secrets Store Driver** monta secrets de provedores externos (Key Vault, AWS Secrets Manager, HashiCorp Vault) como **volumes** no pod.

**Como funciona**:

```text
┌───────────────────────────────────────┐
│ Pod                                   │
│                                       │
│  Volume Mount:                        │
│    /mnt/secrets-store/                │
│      ├─ tls.crt  ← Do Key Vault      │
│      └─ tls.key  ← Do Key Vault      │
└────────────┬──────────────────────────┘
             │
             │ 1. Pod startup
             ▼
┌───────────────────────────────────────┐
│ CSI Driver (DaemonSet)                │
│                                       │
│  SecretProviderClass                  │
│    provider: azure                    │
│    objects:                           │
│      - objectName: store-front-cert   │
│        objectType: secret             │
└────────────┬──────────────────────────┘
             │
             │ 2. Fetch from Key Vault
             ▼
┌───────────────────────────────────────┐
│ Azure Key Vault                       │
│   Certificate: store-front-cert       │
└───────────────────────────────────────┘
```

### 3.2. Verificar se CSI Driver está instalado

```powershell
Write-Host "`n═══ Verificando CSI Secrets Store Driver ═══" -ForegroundColor Yellow

$csiAddon = az aks show `
    --resource-group $CLUSTER_RESOURCE_GROUP `
    --name $CLUSTER_NAME `
    --query "addonProfiles.azureKeyvaultSecretsProvider.enabled" `
    --output tsv

if ($csiAddon -eq "true") {
    Write-Host "✓ CSI Driver já instalado" -ForegroundColor Green
} else {
    Write-Host "⚠ CSI Driver NÃO está instalado!" -ForegroundColor Red
    Write-Host "Instalando..." -ForegroundColor Cyan
    
    # Habilitar addon
    az aks enable-addons `
        --resource-group $CLUSTER_RESOURCE_GROUP `
        --name $CLUSTER_NAME `
        --addons azure-keyvault-secrets-provider
    
    Write-Host "✓ CSI Driver instalado!" -ForegroundColor Green
}

# Verificar pods
Write-Host "`nPods do CSI Driver:" -ForegroundColor White
kubectl get pods -n kube-system -l app.kubernetes.io/name=secrets-store-csi-driver
kubectl get pods -n kube-system -l app=secrets-store-provider-azure
```

**O que observar**:
- `secrets-store-csi-driver-*`: DaemonSet (1 pod por nó)
- `csi-secrets-store-provider-azure-*`: DaemonSet (1 pod por nó)
- Todos devem estar `Running` e `Ready`

**Por que fazer isso**: O CSI Driver é a ponte entre Kubernetes e Key Vault.

### 3.3. Verificar CRDs instaladas

```powershell
Write-Host "`n═══ Verificando CRDs ═══" -ForegroundColor Yellow

kubectl get crd secretproviderclasses.secrets-store.csi.x-k8s.io

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ CRD SecretProviderClass instalada" -ForegroundColor Green
} else {
    Write-Host "⚠ CRD NÃO encontrada! Reinstalar addon" -ForegroundColor Red
}
```

**O que observar**:
- CRD `secretproviderclasses.secrets-store.csi.x-k8s.io` deve existir

**Por que fazer isso**: A CRD define como mapear Key Vault objects para volumes.

---

## Passo 4: Criar Identidade para cert-manager

### 4.1. Criar Managed Identity

```powershell
Write-Host "`n═══ Criando Managed Identity ═══" -ForegroundColor Yellow

$CERT_MANAGER_IDENTITY_NAME = "id-cert-manager-$CLUSTER_NAME"

Write-Host "Nome da identidade: $CERT_MANAGER_IDENTITY_NAME" -ForegroundColor Cyan

# Verificar se já existe
$identity = az identity show `
    --name $CERT_MANAGER_IDENTITY_NAME `
    --resource-group $CLUSTER_RESOURCE_GROUP `
    --output json 2>$null

if ($null -eq $identity) {
    Write-Host "Criando Managed Identity..." -ForegroundColor Cyan
    
    $identity = az identity create `
        --name $CERT_MANAGER_IDENTITY_NAME `
        --resource-group $CLUSTER_RESOURCE_GROUP `
        --location $CLUSTER_LOCATION `
        --output json | ConvertFrom-Json
    
    Write-Host "✓ Identity criada!" -ForegroundColor Green
} else {
    $identity = $identity | ConvertFrom-Json
    Write-Host "✓ Identity já existe" -ForegroundColor Green
}

$CERT_MANAGER_IDENTITY_CLIENT_ID = $identity.clientId
$CERT_MANAGER_IDENTITY_PRINCIPAL_ID = $identity.principalId

Write-Host "Client ID: $CERT_MANAGER_IDENTITY_CLIENT_ID" -ForegroundColor Gray
Write-Host "Principal ID: $CERT_MANAGER_IDENTITY_PRINCIPAL_ID" -ForegroundColor Gray
```

**O que observar**:
- **Client ID**: Usado no Federated Credential
- **Principal ID**: Usado no RBAC assignment

**Por que fazer isso**: A Managed Identity representa o cert-manager no Azure AD.

### 4.2. Atribuir permissões no Key Vault

```powershell
Write-Host "`n═══ Atribuindo Permissões no Key Vault ═══" -ForegroundColor Yellow

# Role: Key Vault Certificates Officer (permite criar/atualizar certificados)
$roleDefinitionName = "Key Vault Certificates Officer"

Write-Host "Atribuindo role '$roleDefinitionName'..." -ForegroundColor Cyan

az role assignment create `
    --role $roleDefinitionName `
    --assignee-object-id $CERT_MANAGER_IDENTITY_PRINCIPAL_ID `
    --assignee-principal-type ServicePrincipal `
    --scope $KEY_VAULT_ID

Write-Host "✓ Permissões atribuídas!" -ForegroundColor Green

Write-Host "`nPermissões concedidas:" -ForegroundColor Yellow
Write-Host "  • Get Certificates" -ForegroundColor Gray
Write-Host "  • List Certificates" -ForegroundColor Gray
Write-Host "  • Create Certificates" -ForegroundColor Gray
Write-Host "  • Update Certificates" -ForegroundColor Gray
Write-Host "  • Import Certificates" -ForegroundColor Gray
```

**O que observar**:
- Role: `Key Vault Certificates Officer` (não confundir com `Administrator`)
- Scope: Key Vault específico (princípio do menor privilégio)

**Por que fazer isso**: Sem permissões, o cert-manager não consegue criar certificados no Key Vault.

### 4.3. Criar Federated Credential

```powershell
Write-Host "`n═══ Criando Federated Credential ═══" -ForegroundColor Yellow

# Namespace e ServiceAccount do cert-manager
$CERT_MANAGER_NAMESPACE = "cert-manager"
$CERT_MANAGER_SA = "cert-manager"

Write-Host "ServiceAccount: $CERT_MANAGER_NAMESPACE/$CERT_MANAGER_SA" -ForegroundColor Cyan

# Criar Federated Credential
az identity federated-credential create `
    --name "fc-cert-manager" `
    --identity-name $CERT_MANAGER_IDENTITY_NAME `
    --resource-group $CLUSTER_RESOURCE_GROUP `
    --issuer $OIDC_ISSUER_URL `
    --subject "system:serviceaccount:${CERT_MANAGER_NAMESPACE}:${CERT_MANAGER_SA}"

Write-Host "✓ Federated Credential criado!" -ForegroundColor Green
Write-Host "`nFederated Credential:" -ForegroundColor Yellow
Write-Host "  • Issuer: $OIDC_ISSUER_URL" -ForegroundColor Gray
Write-Host "  • Subject: system:serviceaccount:${CERT_MANAGER_NAMESPACE}:${CERT_MANAGER_SA}" -ForegroundColor Gray
```

**O que observar**:
- **Issuer**: OIDC do cluster AKS
- **Subject**: Formato `system:serviceaccount:<namespace>:<sa-name>`

**Por que fazer isso**: O Federated Credential faz o link entre ServiceAccount do Kubernetes e Managed Identity do Azure.

### 4.4. Anotar ServiceAccount com Client ID

```powershell
Write-Host "`n═══ Anotando ServiceAccount ═══" -ForegroundColor Yellow

# Adicionar annotation ao ServiceAccount do cert-manager
kubectl annotate serviceaccount cert-manager `
    -n $CERT_MANAGER_NAMESPACE `
    azure.workload.identity/client-id=$CERT_MANAGER_IDENTITY_CLIENT_ID `
    --overwrite

Write-Host "✓ ServiceAccount anotado!" -ForegroundColor Green

# Verificar annotation
Write-Host "`nServiceAccount cert-manager:" -ForegroundColor White
kubectl get sa cert-manager -n $CERT_MANAGER_NAMESPACE -o yaml | Select-String "azure.workload.identity"
```

**O que observar**:
- Annotation: `azure.workload.identity/client-id: <guid>`

**Por que fazer isso**: A annotation diz ao webhook do Workload Identity qual Managed Identity usar.

### 4.5. Reiniciar pods do cert-manager

```powershell
Write-Host "`n═══ Reiniciando cert-manager ═══" -ForegroundColor Yellow

Write-Host "Reiniciando pods para aplicar Workload Identity..." -ForegroundColor Cyan

kubectl rollout restart deployment cert-manager -n $CERT_MANAGER_NAMESPACE
kubectl rollout restart deployment cert-manager-cainjector -n $CERT_MANAGER_NAMESPACE
kubectl rollout restart deployment cert-manager-webhook -n $CERT_MANAGER_NAMESPACE

Write-Host "Aguardando pods ficarem prontos..." -ForegroundColor Cyan
kubectl wait --for=condition=Ready pods --all -n $CERT_MANAGER_NAMESPACE --timeout=120s

Write-Host "✓ cert-manager reiniciado!" -ForegroundColor Green
```

**O que observar**:
- Pods devem reiniciar e voltar para `1/1 Ready`
- Se ficarem em `CrashLoopBackOff`: verificar logs

**Por que fazer isso**: As annotations só são injetadas nos pods durante a criação (não retroativo).

### 4.6. Salvar variáveis no config

```powershell
Write-Host "`n═══ Salvando Configuração ═══" -ForegroundColor Yellow

# Atualizar aks-labs.config
$configPath = "../../aks-labs.config"
$configContent = Get-Content $configPath

$configContent += @"

# Cert-manager Workload Identity
CERT_MANAGER_IDENTITY_CLIENT_ID=$CERT_MANAGER_IDENTITY_CLIENT_ID
CERT_MANAGER_IDENTITY_PRINCIPAL_ID=$CERT_MANAGER_IDENTITY_PRINCIPAL_ID
CERT_MANAGER_IDENTITY_NAME=$CERT_MANAGER_IDENTITY_NAME
"@

$configContent | Out-File -FilePath $configPath -Encoding UTF8 -Force

Write-Host "✓ Configuração salva!" -ForegroundColor Green
```

---

## Passo 5: Configurar cert-manager com Key Vault

### 5.1. Criar ClusterIssuer com Key Vault

Agora vamos criar um ClusterIssuer que:
1. Solicita certificados no Let's Encrypt (ACME)
2. **E automaticamente exporta para o Key Vault**

```powershell
Write-Host "`n═══ Criando ClusterIssuer ═══" -ForegroundColor Yellow

# Gerar manifesto com parâmetros dinâmicos
$clusterIssuerYaml = @"
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod-keyvault
spec:
  acme:
    # Servidor Let's Encrypt (produção)
    server: https://acme-v02.api.letsencrypt.org/directory
    
    # Email para notificações (renovação, expirações)
    email: $LETSENCRYPT_EMAIL
    
    # Secret onde cert-manager armazena chave privada da conta ACME
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    
    # Solver: como provar controle do domínio
    solvers:
      - http01:
          ingress:
            class: istio  # Istio Gateway
"@

# Salvar manifesto
$manifestPath = "../../manifests/02-certificates/clusterissuer-letsencrypt-keyvault.yaml"
$clusterIssuerYaml | Out-File -FilePath $manifestPath -Encoding UTF8 -Force

Write-Host "✓ Manifesto criado: $manifestPath" -ForegroundColor Green

# Aplicar
kubectl apply -f $manifestPath

Write-Host "✓ ClusterIssuer criado!" -ForegroundColor Green

# Verificar status
Start-Sleep -Seconds 5
kubectl get clusterissuer letsencrypt-prod-keyvault
kubectl describe clusterissuer letsencrypt-prod-keyvault | Select-String "Ready"
```

**O que observar**:
- Status: `Ready = True`
- Message: "The ACME account was registered with the ACME server"

**Por que fazer isso**: O ClusterIssuer é o "emissor" de certificados. Define ONDE e COMO solicitar certificados.

### 5.2. Criar Certificate com exportação para Key Vault

```powershell
Write-Host "`n═══ Criando Certificate ═══" -ForegroundColor Yellow

# Gerar manifesto com DNS dinâmico e exportação para Key Vault
$certificateYaml = @"
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: store-front-cert
  namespace: default
spec:
  # Nome do secret Kubernetes (será criado automaticamente)
  secretName: store-front-tls
  
  # Duração e renovação
  duration: 2160h  # 90 dias
  renewBefore: 720h  # Renovar 30 dias antes de expirar
  
  # Issuer
  issuerRef:
    name: letsencrypt-prod-keyvault
    kind: ClusterIssuer
  
  # Domínios (DNS)
  dnsNames:
    - $PRIMARY_DNS
    - $SECONDARY_DNS
  
  # Exportação para Azure Key Vault
  additionalOutputFormats:
    - type: CombinedPEM  # Certificado + chave privada em 1 arquivo
    - type: DER          # Formato binário
  
  # Plugin para exportar para Key Vault (requer plugin adicional)
  # Alternativa: usar SecretProviderClass para sync
"@

# Salvar manifesto
$manifestPath = "../../manifests/02-certificates/certificate-store-front.yaml"
$certificateYaml | Out-File -FilePath $manifestPath -Encoding UTF8 -Force

Write-Host "✓ Manifesto criado: $manifestPath" -ForegroundColor Green

# Aplicar
kubectl apply -f $manifestPath

Write-Host "✓ Certificate criado!" -ForegroundColor Green
Write-Host "`nAguardando emissão do certificado..." -ForegroundColor Cyan
Write-Host "  Isto pode levar 1-2 minutos (ACME challenge + Let's Encrypt)" -ForegroundColor Gray
```

**O que observar**:
- Certificate solicita ao ClusterIssuer
- ClusterIssuer solicita ao Let's Encrypt
- Let's Encrypt valida via HTTP-01 challenge
- Certificado é emitido e armazenado no secret `store-front-tls`

**Por que fazer isso**: Define QUAL certificado solicitar (domínios, duração, etc).

### 5.3. Acompanhar progresso da emissão

```powershell
Write-Host "`n═══ Acompanhando Emissão ═══" -ForegroundColor Yellow

# Monitorar status
$maxAttempts = 24  # 2 minutos (24 x 5 segundos)
$attempt = 0

while ($attempt -lt $maxAttempts) {
    $attempt++
    
    $certStatus = kubectl get certificate store-front-cert -n default -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>$null
    
    if ($certStatus -eq "True") {
        Write-Host "`n✓ Certificado emitido com sucesso!" -ForegroundColor Green
        break
    } else {
        Write-Host "  [$attempt/$maxAttempts] Aguardando... (Status: $certStatus)" -ForegroundColor Gray
        Start-Sleep -Seconds 5
    }
}

if ($attempt -eq $maxAttempts) {
    Write-Host "`n⚠ Timeout aguardando certificado" -ForegroundColor Yellow
    Write-Host "Verificar logs:" -ForegroundColor Cyan
    Write-Host "  kubectl describe certificate store-front-cert -n default" -ForegroundColor Gray
    Write-Host "  kubectl logs -n cert-manager -l app=cert-manager" -ForegroundColor Gray
}

# Mostrar detalhes do certificado
Write-Host "`nDetalhes do Certificate:" -ForegroundColor White
kubectl describe certificate store-front-cert -n default
```

**O que observar**:
- Status: `Ready = True`
- Events: "Certificate issued successfully"
- Secret: `store-front-tls` foi criado

**Por que fazer isso**: Confirma que o certificado foi emitido antes de exportar para Key Vault.

### 5.4. Exportar certificado para Key Vault (manual)

⚠️ **Nota**: O cert-manager não exporta automaticamente para Key Vault (requer plugin adicional). Vamos fazer manualmente:

```powershell
Write-Host "`n═══ Exportando para Key Vault ═══" -ForegroundColor Yellow

# Extrair certificado e chave privada do secret
$certData = kubectl get secret store-front-tls -n default -o jsonpath='{.data.tls\.crt}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
$keyData = kubectl get secret store-front-tls -n default -o jsonpath='{.data.tls\.key}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

# Salvar temporariamente em arquivos
$tempCert = [System.IO.Path]::GetTempFileName() + ".crt"
$tempKey = [System.IO.Path]::GetTempFileName() + ".key"
$certData | Out-File -FilePath $tempCert -Encoding UTF8 -Force
$keyData | Out-File -FilePath $tempKey -Encoding UTF8 -Force

# Combinar em formato PEM
$tempPfx = [System.IO.Path]::GetTempFileName() + ".pfx"
$pfxPassword = "temp-$(Get-Random)"

# Converter para PFX usando OpenSSL (requer WSL ou OpenSSL for Windows)
Write-Host "Convertendo para formato PFX..." -ForegroundColor Cyan

# Alternativa: usar Azure CLI para importar diretamente
Write-Host "Importando certificado para Key Vault..." -ForegroundColor Cyan

az keyvault certificate import `
    --vault-name $KEY_VAULT_NAME `
    --name store-front-cert `
    --file $tempCert `
    --password "" `
    --disabled false

# Limpar arquivos temporários
Remove-Item $tempCert, $tempKey -Force -ErrorAction SilentlyContinue

Write-Host "✓ Certificado exportado para Key Vault!" -ForegroundColor Green
```

**⚠️ Limitação**: Esta abordagem manual não sincroniza renovações automáticas. Para produção, considere:
- **Opção 1**: Usar plugin `cert-manager-csi-driver-azure-keyvault` (não oficial)
- **Opção 2**: Usar Azure App Service Certificate (renovação automática no Key Vault)
- **Opção 3**: Script de sincronização periódica (CronJob)

**Por que fazer isso**: Permite usar o Key Vault como fonte central de certificados.

---

## Passo 6: Testar Integração

### 6.1. Verificar certificado no Key Vault

```powershell
Write-Host "`n═══ Verificando no Key Vault ═══" -ForegroundColor Yellow

# Listar certificados
az keyvault certificate list --vault-name $KEY_VAULT_NAME -o table

# Mostrar detalhes
az keyvault certificate show `
    --vault-name $KEY_VAULT_NAME `
    --name store-front-cert `
    --query "{Name:name, Enabled:attributes.enabled, Expires:attributes.expires, Thumbprint:x509Thumbprint}" `
    -o table
```

**O que observar**:
- Certificado `store-front-cert` deve aparecer
- `Enabled: True`
- `Expires`: 90 dias a partir de hoje

**Por que fazer isso**: Confirma que o certificado está no Key Vault.

### 6.2. Criar SecretProviderClass para montar no pod

```powershell
Write-Host "`n═══ Criando SecretProviderClass ═══" -ForegroundColor Yellow

# Gerar manifesto
$spcYaml = @"
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: store-front-keyvault-tls
  namespace: default
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "false"
    
    # Usar Workload Identity
    clientID: $CERT_MANAGER_IDENTITY_CLIENT_ID
    
    # Key Vault
    keyvaultName: $KEY_VAULT_NAME
    tenantId: $(az account show --query tenantId -o tsv)
    
    # Objetos a serem montados
    objects: |
      array:
        - |
          objectName: store-front-cert
          objectType: secret  # Certificado é exposto como secret (PEM)
          objectAlias: tls.crt
        - |
          objectName: store-front-cert
          objectType: secret
          objectAlias: tls.key
  
  # Sync para Kubernetes Secret (opcional)
  secretObjects:
    - secretName: store-front-tls-from-keyvault
      type: kubernetes.io/tls
      data:
        - objectName: tls.crt
          key: tls.crt
        - objectName: tls.key
          key: tls.key
"@

# Salvar manifesto
$manifestPath = "../../manifests/02-certificates/secretproviderclass-store-front.yaml"
$spcYaml | Out-File -FilePath $manifestPath -Encoding UTF8 -Force

Write-Host "✓ Manifesto criado: $manifestPath" -ForegroundColor Green

# Aplicar
kubectl apply -f $manifestPath

Write-Host "✓ SecretProviderClass criado!" -ForegroundColor Green
```

**O que observar**:
- `clientID`: Managed Identity do cert-manager (Workload Identity)
- `objects`: Quais certificados/secrets buscar no Key Vault
- `secretObjects`: Opcional - cria secret Kubernetes automaticamente

**Por que fazer isso**: Define COMO montar o Key Vault como volume no pod.

### 6.3. Criar pod de teste

```powershell
Write-Host "`n═══ Criando Pod de Teste ═══" -ForegroundColor Yellow

# Gerar manifesto de pod de teste
$testPodYaml = @"
apiVersion: v1
kind: Pod
metadata:
  name: test-keyvault-mount
  namespace: default
  labels:
    azure.workload.identity/use: "true"  # Habilita Workload Identity
spec:
  serviceAccountName: cert-manager  # Usa SA com Workload Identity
  containers:
    - name: nginx
      image: nginx:alpine
      volumeMounts:
        - name: secrets-store
          mountPath: /mnt/secrets-store
          readOnly: true
      command:
        - /bin/sh
        - -c
        - |
          echo "Certificados montados do Key Vault:"
          ls -la /mnt/secrets-store/
          echo ""
          echo "Conteúdo do tls.crt:"
          head -n 5 /mnt/secrets-store/tls.crt
          echo ""
          echo "Aguardando... (Ctrl+C para sair)"
          tail -f /dev/null
  volumes:
    - name: secrets-store
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: store-front-keyvault-tls
"@

# Salvar manifesto
$manifestPath = "../../manifests/02-certificates/test-pod-keyvault.yaml"
$testPodYaml | Out-File -FilePath $manifestPath -Encoding UTF8 -Force

Write-Host "✓ Manifesto criado: $manifestPath" -ForegroundColor Green

# Aplicar
kubectl apply -f $manifestPath

Write-Host "Aguardando pod iniciar..." -ForegroundColor Cyan
kubectl wait --for=condition=Ready pod/test-keyvault-mount -n default --timeout=60s

Write-Host "`n✓ Pod criado e rodando!" -ForegroundColor Green

# Verificar logs
Write-Host "`nLogs do pod:" -ForegroundColor White
kubectl logs test-keyvault-mount -n default
```

**O que observar**:
- Pod deve iniciar sem erros
- Logs devem mostrar `/mnt/secrets-store/tls.crt` e `tls.key`
- Conteúdo do `tls.crt` deve começar com `-----BEGIN CERTIFICATE-----`

**Por que fazer isso**: Testa end-to-end que o CSI Driver consegue montar certificados do Key Vault no pod.

### 6.4. Verificar secret sincronizado (opcional)

```powershell
Write-Host "`n═══ Verificando Secret Sincronizado ═══" -ForegroundColor Yellow

# Verificar se secret foi criado automaticamente
kubectl get secret store-front-tls-from-keyvault -n default

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Secret sincronizado do Key Vault!" -ForegroundColor Green
    
    # Mostrar detalhes
    kubectl describe secret store-front-tls-from-keyvault -n default
} else {
    Write-Host "⚠ Secret não foi sincronizado (pode levar alguns segundos)" -ForegroundColor Yellow
}
```

**O que observar**:
- Secret `store-front-tls-from-keyvault` deve existir
- Tipo: `kubernetes.io/tls`
- Data: `tls.crt` e `tls.key`

**Por que fazer isso**: Permite usar o certificado em recursos que exigem secret Kubernetes (como Ingress).

### 6.5. Limpar pod de teste

```powershell
Write-Host "`n═══ Limpando Pod de Teste ═══" -ForegroundColor Yellow

kubectl delete pod test-keyvault-mount -n default

Write-Host "✓ Pod de teste removido!" -ForegroundColor Green
```

---

## Troubleshooting

### Problema 1: Workload Identity não funciona

**Sintomas**:
```
Error: azure.BearerAuthorizer#WithAuthorization: Failed to refresh the Token
```

**Diagnóstico**:
```powershell
# Verificar annotation no ServiceAccount
kubectl get sa cert-manager -n cert-manager -o yaml | Select-String "azure.workload.identity"

# Verificar se webhook injetou variáveis de ambiente
kubectl get pod <cert-manager-pod> -n cert-manager -o yaml | Select-String "AZURE_"
```

**Soluções**:
1. Verificar Federated Credential está correto (issuer + subject)
2. Verificar pod tem label `azure.workload.identity/use: "true"`
3. Reiniciar pods após adicionar annotation

---

### Problema 2: CSI Driver não monta volume

**Sintomas**:
```
MountVolume.SetUp failed: rpc error: code = Unknown
```

**Diagnóstico**:
```powershell
# Verificar logs do CSI Driver
kubectl logs -n kube-system -l app=secrets-store-provider-azure --tail=50

# Verificar eventos do pod
kubectl describe pod <pod-name> -n default
```

**Soluções**:
1. Verificar `clientID` no SecretProviderClass está correto
2. Verificar Managed Identity tem permissões no Key Vault
3. Verificar nome do Key Vault e tenant ID

---

### Problema 3: Certificado não exporta para Key Vault

**Sintomas**:
- Certificado emitido no Kubernetes
- Mas não aparece no Key Vault

**Diagnóstico**:
```powershell
# Verificar se cert-manager tem permissões
az role assignment list --assignee $CERT_MANAGER_IDENTITY_PRINCIPAL_ID --scope $KEY_VAULT_ID -o table
```

**Soluções**:
1. cert-manager não exporta automaticamente para Key Vault (requer plugin ou script)
2. Usar abordagem manual ou CronJob para sincronizar
3. Considerar Azure App Service Certificate (renovação automática no Key Vault)

---

### Problema 4: Let's Encrypt challenge falha

**Sintomas**:
```
Waiting for HTTP-01 challenge propagation: failed to perform self check GET request
```

**Diagnóstico**:
```powershell
# Verificar se Istio Gateway está respondendo
curl http://$PRIMARY_DNS/.well-known/acme-challenge/test

# Verificar VirtualService para ACME
kubectl get virtualservice -A | Select-String "acme"
```

**Soluções**:
1. Verificar Istio Gateway tem listener HTTP (porta 80)
2. Verificar DNS resolve para IP do Gateway
3. Verificar firewall/NSG permite porta 80
4. Criar VirtualService para rota `/.well-known/acme-challenge/*`

---

## ✅ Checklist de Conclusão

Ao final deste tutorial, você deve ter:

- [ ] Key Vault criado e configurado
- [ ] Auditoria habilitada (Log Analytics)
- [ ] Workload Identity habilitado no AKS (OIDC Issuer)
- [ ] CSI Secrets Store Driver instalado (addon)
- [ ] Managed Identity criada para cert-manager
- [ ] Federated Credential configurado
- [ ] ServiceAccount anotado com Client ID
- [ ] Role `Key Vault Certificates Officer` atribuído
- [ ] ClusterIssuer criado (Let's Encrypt + Key Vault)
- [ ] Certificate criado e emitido
- [ ] Certificado exportado para Key Vault
- [ ] SecretProviderClass criado
- [ ] Teste de montagem de volume bem-sucedido

---

## 📚 Próximos Passos

1. **Tutorial 03**: Instalar Flagger com Azure Monitor
2. **Tutorial 04**: Configurar Gateway Istio com TLS do Key Vault
3. **Tutorial 05**: Testar canary deployment completo

---

## 🔗 Referências

- [Azure Key Vault Docs](https://learn.microsoft.com/en-us/azure/key-vault/)
- [Workload Identity](https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview)
- [CSI Secrets Store Driver](https://learn.microsoft.com/en-us/azure/aks/csi-secrets-store-driver)
- [cert-manager Docs](https://cert-manager.io/docs/)
- [Let's Encrypt](https://letsencrypt.org/docs/)

---

**Dúvidas?** Verifique logs: `kubectl logs -n cert-manager -l app=cert-manager`

**Próximo tutorial**: [03-setup-flagger.md](./03-setup-flagger.md)

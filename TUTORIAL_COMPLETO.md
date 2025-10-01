# 🎓 Tutorial Completo - Laboratório Istio no AKS

## 📚 Índice
1. [Pré-requisitos](#pré-requisitos)
2. [Fase 1: Setup do Cluster AKS](#fase-1-setup-do-cluster-aks)
3. [Fase 2: Habilitar Istio Service Mesh](#fase-2-habilitar-istio-service-mesh)
4. [Fase 3: Configurar Ingress Gateway Externo](#fase-3-configurar-ingress-gateway-externo)
5. [Fase 4: Deploy da Aplicação](#fase-4-deploy-da-aplicação)
6. [Fase 5: Configurar Traffic Management](#fase-5-configurar-traffic-management)
7. [Fase 6: Implementar Segurança](#fase-6-implementar-segurança)
8. [Fase 7: Validar Todas as Estratégias](#fase-7-validar-todas-as-estratégias)
9. [Fase 8: Automação com Flagger](#fase-8-automação-com-flagger)
10. [Fase 9: Certificados TLS Automáticos](#fase-9-certificados-tls-automáticos)
11. [Troubleshooting](#troubleshooting)

---

## Pré-requisitos

### Ferramentas Necessárias
- ✅ Azure CLI instalado ([Download](https://learn.microsoft.com/cli/azure/install-azure-cli))
- ✅ kubectl instalado ([Download](https://kubernetes.io/docs/tasks/tools/))
- ✅ PowerShell 5.1 ou superior
- ✅ Git (opcional para clonar repositório)

### Validar Instalação
```powershell
# Verificar Azure CLI
az --version

# Verificar kubectl
kubectl version --client

# Verificar PowerShell
$PSVersionTable.PSVersion
```

**Output Esperado:**
```
azure-cli                         2.xx.x
kubectl version: v1.30.x
Major  Minor  Build  Revision
-----  -----  -----  --------
5      1      xxxxx  xxxx
```

### Login no Azure
```bash
az login
az account set --subscription "<YOUR_SUBSCRIPTION_ID>"
```

**Validar:**
```bash
az account show --query "{name:name, id:id, state:state}" -o table
```

**Output Esperado:**
```
Name                    Id                                      State
----------------------  --------------------------------------  -------
Your Subscription       xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx    Enabled
```

---

## Fase 1: Setup do Cluster AKS

### 1.1: Definir Variáveis
```bash
RESOURCE_GROUP="rg-aks-labs"
CLUSTER_NAME="aks-labs"
LOCATION="westus3"
NODE_COUNT=3
NODE_SIZE="Standard_D2s_v5"
```

### 1.2: Criar Resource Group
```bash
az group create --name $RESOURCE_GROUP --location $LOCATION
```

**Validar:**
```bash
az group show --name $RESOURCE_GROUP --query "{name:name, location:location, provisioningState:properties.provisioningState}" -o table
```

**Output Esperado:**
```
Name          Location    ProvisioningState
------------  ----------  -------------------
rg-aks-labs   westus3     Succeeded
```

### 1.3: Criar Cluster AKS
```bash
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --location $LOCATION \
  --node-count $NODE_COUNT \
  --node-vm-size $NODE_SIZE \
  --network-plugin azure \
  --network-plugin-mode overlay \
  --pod-cidr 10.244.0.0/16 \
  --enable-managed-identity \
  --generate-ssh-keys
```

⏱️ **Tempo estimado:** 5-10 minutos

**Validar durante criação:**
```bash
az aks list -g $RESOURCE_GROUP -o table
```

**Output Esperado (durante criação):**
```
Name       Location    ResourceGroup    KubernetesVersion    ProvisioningState
---------  ----------  ---------------  -------------------  -------------------
aks-labs   westus3     rg-aks-labs      1.32.7               Creating
```

### 1.4: Conectar ao Cluster
```bash
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --overwrite-existing
```

**Validar conexão:**
```bash
kubectl get nodes -o wide
```

**Output Esperado:**
```
NAME                                STATUS   ROLES   AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
aks-nodepool1-xxxxxx-vmss000000     Ready    <none>  5m    v1.32.7   10.224.0.4    <none>        Ubuntu 22.04.5 LTS   5.15.0-1074-azure   containerd://1.7.x
aks-nodepool1-xxxxxx-vmss000001     Ready    <none>  5m    v1.32.7   10.224.0.5    <none>        Ubuntu 22.04.5 LTS   5.15.0-1074-azure   containerd://1.7.x
aks-nodepool1-xxxxxx-vmss000002     Ready    <none>  5m    v1.32.7   10.224.0.6    <none>        Ubuntu 22.04.5 LTS   5.15.0-1074-azure   containerd://1.7.x
```

**Verificar recursos do cluster:**
```bash
kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory
```

**Output Esperado:**
```
NAME                                CPU   MEMORY
aks-nodepool1-xxxxxx-vmss000000     2     7101656Ki
aks-nodepool1-xxxxxx-vmss000001     2     7101656Ki
aks-nodepool1-xxxxxx-vmss000002     2     7101656Ki
```

---

## Fase 2: Habilitar Istio Service Mesh

### 2.1: Habilitar Istio Managed Add-on
```bash
az aks mesh enable --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
```

⏱️ **Tempo estimado:** 3-5 minutos

**Validar durante habilitação:**
```bash
az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query "serviceMeshProfile.mode" -o tsv
```

**Output Esperado:**
```
Istio
```

### 2.2: Validar Pods do Istio Control Plane
```bash
kubectl get pods -n aks-istio-system
```

**Output Esperado:**
```
NAME                                    READY   STATUS    RESTARTS   AGE
istiod-asm-1-25-xxxxxxxxxx-xxxxx        1/1     Running   0          3m
istiod-asm-1-25-xxxxxxxxxx-xxxxx        1/1     Running   0          3m
```

### 2.3: Verificar Revisão do Istio
```bash
kubectl get deployment -n aks-istio-system -o wide
```

**Output Esperado:**
```
NAME              READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES                                            SELECTOR
istiod-asm-1-25   2/2     2            2           3m    discovery    mcr.microsoft.com/oss/istio/pilot:1.25.x-distroless   istio.io/rev=asm-1-25
```

📝 **Nota:** A revisão `asm-1-25` será usada para label dos namespaces.

### 2.4: Validar Services do Control Plane
```bash
kubectl get svc -n aks-istio-system
```

**Output Esperado:**
```
NAME                    TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)                                 AGE
istiod-asm-1-25         ClusterIP   10.0.xxx.xxx   <none>        15010/TCP,15012/TCP,443/TCP,15014/TCP   3m
```

---

## Fase 3: Configurar Ingress Gateway Externo

### 3.1: Habilitar External Ingress Gateway
```bash
az aks mesh enable-ingress-gateway \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --ingress-gateway-type external
```

⏱️ **Tempo estimado:** 2-3 minutos

### 3.2: Validar Namespace do Ingress
```bash
kubectl get namespace aks-istio-ingress
```

**Output Esperado:**
```
NAME                STATUS   AGE
aks-istio-ingress   Active   2m
```

### 3.3: Validar Service do Ingress Gateway
```bash
kubectl get svc -n aks-istio-ingress
```

**Output Esperado (aguardar External-IP):**
```
NAME                                TYPE           CLUSTER-IP    EXTERNAL-IP     PORT(S)                                      AGE
aks-istio-ingressgateway-external   LoadBalancer   10.0.23.68    <pending>       15021:32567/TCP,80:30691/TCP,443:30840/TCP   1m
```

⏱️ **Aguardar External-IP ser alocado (1-2 minutos):**
```bash
kubectl get svc -n aks-istio-ingress -w
```

**Output Final Esperado:**
```
NAME                                TYPE           CLUSTER-IP    EXTERNAL-IP     PORT(S)                                      AGE
aks-istio-ingressgateway-external   LoadBalancer   10.0.23.68    4.249.81.21     15021:32567/TCP,80:30691/TCP,443:30840/TCP   3m
```

### 3.4: Validar Pods do Ingress Gateway
```bash
kubectl get pods -n aks-istio-ingress -o wide
```

**Output Esperado:**
```
NAME                                                READY   STATUS    RESTARTS   AGE   IP            NODE
aks-istio-ingressgateway-external-xxxxxxxxx-xxxxx   1/1     Running   0          3m    10.244.0.x    aks-nodepool1-xxxxxx-vmss000000
aks-istio-ingressgateway-external-xxxxxxxxx-xxxxx   1/1     Running   0          3m    10.244.1.x    aks-nodepool1-xxxxxx-vmss000001
```

### 3.5: Salvar External IP
```powershell
$EXTERNAL_IP = (kubectl get svc -n aks-istio-ingress aks-istio-ingressgateway-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
Write-Host "External IP: $EXTERNAL_IP" -ForegroundColor Green
```

### 3.6: Testar Conectividade (Deve retornar erro - normal, sem app ainda)
```powershell
try {
    Invoke-WebRequest -Uri "http://$EXTERNAL_IP/" -TimeoutSec 5
} catch {
    Write-Host "Erro esperado: $($_.Exception.Message)" -ForegroundColor Yellow
}
```

**Output Esperado:**
```
Erro esperado: Invoke-WebRequest : The remote server returned an error: (404) Not Found.
```

---

## Fase 4: Deploy da Aplicação

### 4.1: Criar Namespace com Istio Injection
```bash
kubectl create namespace pets
kubectl label namespace pets istio.io/rev=asm-1-25
```

**Validar label:**
```bash
kubectl get namespace pets --show-labels
```

**Output Esperado:**
```
NAME   STATUS   AGE   LABELS
pets   Active   10s   istio.io/rev=asm-1-25,kubernetes.io/metadata.name=pets
```

### 4.2: Criar ServiceAccount
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: store-front
  namespace: pets
EOF
```

**Validar:**
```bash
kubectl get serviceaccount -n pets
```

**Output Esperado:**
```
NAME          SECRETS   AGE
default       0         1m
store-front   0         10s
```

### 4.3: Deploy da Aplicação Store-Front
```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: store-front
  namespace: pets
spec:
  replicas: 2
  selector:
    matchLabels:
      app: store-front
  template:
    metadata:
      labels:
        app: store-front
        version: v1
    spec:
      serviceAccountName: store-front
      containers:
      - name: store-front
        image: ghcr.io/azure-samples/aks-store-demo/store-front:latest
        ports:
        - containerPort: 8080
          name: http
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 256Mi
        env:
        - name: VUE_APP_PRODUCT_SERVICE_URL
          value: "http://product-service:3002"
        - name: VUE_APP_ORDER_SERVICE_URL
          value: "http://order-service:3000"
EOF
```

### 4.4: Validar Pods (aguardar 2/2 READY - inclui istio-proxy sidecar)
```bash
kubectl get pods -n pets -l app=store-front -w
```

**Output Esperado (aguardar):**
```
NAME                           READY   STATUS              RESTARTS   AGE
store-front-7f55f477cb-xxxxx   0/2     ContainerCreating   0          10s
store-front-7f55f477cb-xxxxx   1/2     Running             0          30s
store-front-7f55f477cb-xxxxx   2/2     Running             0          35s
store-front-7f55f477cb-xxxxx   2/2     Running             0          40s
```

**Validar sidecar injection:**
```bash
kubectl get pods -n pets -l app=store-front -o jsonpath='{.items[0].spec.containers[*].name}'
```

**Output Esperado:**
```
store-front istio-proxy
```

### 4.5: Criar Service
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: store-front
  namespace: pets
spec:
  type: ClusterIP
  selector:
    app: store-front
  ports:
  - name: http
    port: 80
    targetPort: 8080
EOF
```

**Validar:**
```bash
kubectl get svc -n pets store-front
```

**Output Esperado:**
```
NAME          TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
store-front   ClusterIP   10.0.xxx.xxx   <none>        80/TCP    10s
```

### 4.6: Validar Endpoints
```bash
kubectl get endpoints -n pets store-front
```

**Output Esperado:**
```
NAME          ENDPOINTS                       AGE
store-front   10.244.0.x:8080,10.244.1.x:8080 1m
```

---

## Fase 5: Configurar Traffic Management

### 5.1: Criar Gateway Resource
```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: pets-gateway
  namespace: aks-istio-ingress
spec:
  selector:
    istio: aks-istio-ingressgateway-external
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - "*"
    tls:
      mode: SIMPLE
      credentialName: store-front-tls
EOF
```

**Validar:**
```bash
kubectl get gateway -n aks-istio-ingress
```

**Output Esperado:**
```
NAME           AGE
pets-gateway   10s
```

**Validar configuração:**
```bash
kubectl get gateway -n aks-istio-ingress pets-gateway -o yaml | grep -A5 "selector:"
```

**Output Esperado:**
```yaml
  selector:
    istio: aks-istio-ingressgateway-external
```

### 5.2: Criar VirtualService com 3 Estratégias
```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: store-front
  namespace: pets
spec:
  hosts:
  - "*"
  gateways:
  - aks-istio-ingress/pets-gateway
  http:
  # Route 1: A/B Testing - Beta Group
  - name: ab-test-beta
    match:
    - headers:
        x-user-group:
          exact: beta
    route:
    - destination:
        host: store-front
        port:
          number: 80
        subset: v1
      weight: 100
      headers:
        response:
          add:
            x-strategy: ab-test-beta
  # Route 2: A/B Testing - Alpha Group
  - name: ab-test-alpha
    match:
    - headers:
        x-user-group:
          exact: alpha
    route:
    - destination:
        host: store-front
        port:
          number: 80
        subset: v1
      weight: 100
      headers:
        response:
          add:
            x-strategy: ab-test-alpha
  # Route 3: Blue-Green - Admin Path
  - name: blue-green
    match:
    - uri:
        prefix: /admin
    rewrite:
      uri: /
    route:
    - destination:
        host: store-front
        port:
          number: 80
        subset: v1
      weight: 100
      headers:
        response:
          add:
            x-strategy: blue-green
  # Route 4: Canary - Default Traffic
  - name: canary-primary
    route:
    - destination:
        host: store-front
        port:
          number: 80
        subset: v1
      weight: 90
      headers:
        response:
          add:
            x-strategy: canary-primary
    - destination:
        host: store-front
        port:
          number: 80
        subset: v1
      weight: 10
      headers:
        response:
          add:
            x-strategy: canary-test
EOF
```

**Validar:**
```bash
kubectl get virtualservice -n pets
```

**Output Esperado:**
```
NAME          GATEWAYS                          HOSTS   AGE
store-front   ["aks-istio-ingress/pets-gateway"]   ["*"]   10s
```

**Validar rotas:**
```bash
kubectl get virtualservice -n pets store-front -o jsonpath='{.spec.http[*].name}' | tr ' ' '\n'
```

**Output Esperado:**
```
ab-test-beta
ab-test-alpha
blue-green
canary-primary
```

### 5.3: Criar DestinationRule
```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: store-front
  namespace: pets
spec:
  host: store-front
  trafficPolicy:
    loadBalancer:
      simple: LEAST_REQUEST
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 50
        http2MaxRequests: 100
        maxRequestsPerConnection: 2
    outlierDetection:
      consecutiveErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
      minHealthPercent: 40
  subsets:
  - name: v1
    labels:
      version: v1
EOF
```

**Validar:**
```bash
kubectl get destinationrule -n pets
```

**Output Esperado:**
```
NAME          HOST          AGE
store-front   store-front   10s
```

**Validar subset:**
```bash
kubectl get destinationrule -n pets store-front -o jsonpath='{.spec.subsets[*].name}'
```

**Output Esperado:**
```
v1
```

### 5.4: Aguardar Propagação da Configuração
```bash
sleep 10
```

### 5.5: Teste HTTP Básico (deve funcionar agora)
```powershell
$EXTERNAL_IP = (kubectl get svc -n aks-istio-ingress aks-istio-ingressgateway-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
$response = Invoke-WebRequest -Uri "http://$EXTERNAL_IP/"
Write-Host "Status: $($response.StatusCode) $($response.StatusDescription)" -ForegroundColor Green
Write-Host "Strategy Header: $($response.Headers['x-strategy'])" -ForegroundColor Cyan
```

**Output Esperado:**
```
Status: 200 OK
Strategy Header: canary-primary
```

---

## Fase 6: Implementar Segurança

### 6.1: Habilitar mTLS STRICT Mode
```bash
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: pets
spec:
  mtls:
    mode: STRICT
EOF
```

**Validar:**
```bash
kubectl get peerauthentication -n pets
```

**Output Esperado:**
```
NAME      MODE     AGE
default   STRICT   10s
```

### 6.2: Configurar JWT Authentication
```bash
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: jwt-auth
  namespace: pets
spec:
  selector:
    matchLabels:
      app: store-front
  jwtRules:
  - issuer: "https://sts.windows.net/<AZURE_AD_TENANT_ID>/"
    jwksUri: "https://login.microsoftonline.com/<AZURE_AD_TENANT_ID>/discovery/v2.0/keys"
EOF
```

**Validar:**
```bash
kubectl get requestauthentication -n pets
```

**Output Esperado:**
```
NAME       AGE
jwt-auth   10s
```

### 6.3: Criar AuthorizationPolicy - Permitir Ingress Gateway
```bash
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: store-front-allow-ingress
  namespace: pets
spec:
  selector:
    matchLabels:
      app: store-front
  action: ALLOW
  rules:
  # Rule 1: Permitir tráfego do Ingress Gateway
  - from:
    - source:
        namespaces: ["aks-istio-ingress"]
  # Rule 2: Permitir tráfego interno do mesh (opcional)
  - from:
    - source:
        principals: ["cluster.local/ns/pets/sa/*"]
EOF
```

**Validar:**
```bash
kubectl get authorizationpolicy -n pets
```

**Output Esperado:**
```
NAME                         AGE
store-front-allow-ingress    10s
```

### 6.4: Testar Acesso Após AuthorizationPolicy
```powershell
$response = Invoke-WebRequest -Uri "http://$EXTERNAL_IP/"
Write-Host "Status: $($response.StatusCode)" -ForegroundColor Green
```

**Output Esperado:**
```
Status: 200
```

✅ Se retornar **200 OK**, AuthorizationPolicy está permitindo corretamente.  
❌ Se retornar **403 Forbidden**, revisar rules da policy.

### 6.5: Configurar Egress Control - ServiceEntry
```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: external-catfacts-api
  namespace: pets
spec:
  hosts:
  - api.catfacts.ninja
  ports:
  - number: 443
    name: https
    protocol: HTTPS
  location: MESH_EXTERNAL
  resolution: DNS
EOF
```

**Validar:**
```bash
kubectl get serviceentry -n pets
```

**Output Esperado:**
```
NAME                     HOSTS                  LOCATION        RESOLUTION   AGE
external-catfacts-api    ["api.catfacts.ninja"]   MESH_EXTERNAL   DNS          10s
```

### 6.6: Configurar Sidecar para Restringir Egress
```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: Sidecar
metadata:
  name: default
  namespace: pets
spec:
  egress:
  - hosts:
    - "./*"
    - "aks-istio-ingress/*"
    - "aks-istio-system/*"
    - "istio-system/*"
  outboundTrafficPolicy:
    mode: REGISTRY_ONLY
EOF
```

**Validar:**
```bash
kubectl get sidecar -n pets
```

**Output Esperado:**
```
NAME      AGE
default   10s
```

### 6.7: Testar Egress Control
```bash
# Teste 1: Acesso permitido (via ServiceEntry)
kubectl exec -n pets deploy/store-front -c store-front -- curl -I https://api.catfacts.ninja/fact --max-time 5
```

**Output Esperado:**
```
HTTP/2 200
date: Wed, 01 Oct 2025 12:00:00 GMT
content-type: application/json
```

```bash
# Teste 2: Acesso bloqueado (sem ServiceEntry)
kubectl exec -n pets deploy/store-front -c store-front -- curl -I https://www.google.com --max-time 5
```

**Output Esperado:**
```
curl: (28) Connection timed out after 5001 milliseconds
command terminated with exit code 28
```

✅ **Egress control funcionando corretamente!**

---

## Fase 7: Validar Todas as Estratégias

### 7.1: Teste Canary Deployment (Weight-based)
```powershell
Write-Host "`n=== TESTE CANARY (90/10) ===" -ForegroundColor Yellow
$canaryPrimary = 0
$canaryTest = 0

for ($i=1; $i -le 100; $i++) {
    $response = Invoke-WebRequest -Uri "http://$EXTERNAL_IP/" -UseBasicParsing
    $strategy = $response.Headers['x-strategy']
    
    if ($strategy -eq 'canary-primary') { $canaryPrimary++ }
    if ($strategy -eq 'canary-test') { $canaryTest++ }
    
    if ($i % 10 -eq 0) {
        Write-Host "Request $i - Primary: $canaryPrimary | Test: $canaryTest" -ForegroundColor Cyan
    }
}

Write-Host "`nDistribuição Final:" -ForegroundColor Green
Write-Host "  Canary Primary: $canaryPrimary%" -ForegroundColor Green
Write-Host "  Canary Test: $canaryTest%" -ForegroundColor Green
```

**Output Esperado:**
```
=== TESTE CANARY (90/10) ===
Request 10 - Primary: 9 | Test: 1
Request 20 - Primary: 18 | Test: 2
...
Request 100 - Primary: 90 | Test: 10

Distribuição Final:
  Canary Primary: 90%
  Canary Test: 10%
```

### 7.2: Teste A/B Testing (Header-based)
```powershell
Write-Host "`n=== TESTE A/B TESTING ===" -ForegroundColor Yellow

# Grupo Beta
Write-Host "`nGrupo BETA:" -ForegroundColor Cyan
for ($i=1; $i -le 10; $i++) {
    $response = Invoke-WebRequest -Uri "http://$EXTERNAL_IP/" -Headers @{"x-user-group"="beta"} -UseBasicParsing
    $strategy = $response.Headers['x-strategy']
    Write-Host "  Request $i - Strategy: $strategy" -ForegroundColor Green
}

# Grupo Alpha
Write-Host "`nGrupo ALPHA:" -ForegroundColor Cyan
for ($i=1; $i -le 10; $i++) {
    $response = Invoke-WebRequest -Uri "http://$EXTERNAL_IP/" -Headers @{"x-user-group"="alpha"} -UseBasicParsing
    $strategy = $response.Headers['x-strategy']
    Write-Host "  Request $i - Strategy: $strategy" -ForegroundColor Green
}
```

**Output Esperado:**
```
=== TESTE A/B TESTING ===

Grupo BETA:
  Request 1 - Strategy: ab-test-beta
  Request 2 - Strategy: ab-test-beta
  ...
  Request 10 - Strategy: ab-test-beta

Grupo ALPHA:
  Request 1 - Strategy: ab-test-alpha
  Request 2 - Strategy: ab-test-alpha
  ...
  Request 10 - Strategy: ab-test-alpha
```

### 7.3: Teste Blue-Green (Path-based)
```powershell
Write-Host "`n=== TESTE BLUE-GREEN ===" -ForegroundColor Yellow

Write-Host "`nPath /admin (blue-green):" -ForegroundColor Cyan
for ($i=1; $i -le 10; $i++) {
    $response = Invoke-WebRequest -Uri "http://$EXTERNAL_IP/admin" -UseBasicParsing
    $strategy = $response.Headers['x-strategy']
    Write-Host "  Request $i - Strategy: $strategy" -ForegroundColor Green
}

Write-Host "`nPath / (canary):" -ForegroundColor Cyan
for ($i=1; $i -le 10; $i++) {
    $response = Invoke-WebRequest -Uri "http://$EXTERNAL_IP/" -UseBasicParsing
    $strategy = $response.Headers['x-strategy']
    Write-Host "  Request $i - Strategy: $strategy" -ForegroundColor Green
}
```

**Output Esperado:**
```
=== TESTE BLUE-GREEN ===

Path /admin (blue-green):
  Request 1 - Strategy: blue-green
  Request 2 - Strategy: blue-green
  ...
  Request 10 - Strategy: blue-green

Path / (canary):
  Request 1 - Strategy: canary-primary
  Request 2 - Strategy: canary-primary
  ...
  Request 10 - Strategy: canary-primary
```

### 7.4: Teste Consolidado Final
```powershell
Write-Host "`n=== TESTE CONSOLIDADO FINAL ===" -ForegroundColor Yellow

# 1. Cluster Health
Write-Host "`n1. Cluster Nodes:" -ForegroundColor Cyan
kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,VERSION:.status.nodeInfo.kubeletVersion

# 2. Ingress Gateway
Write-Host "`n2. Ingress Gateway Service:" -ForegroundColor Cyan
kubectl get svc -n aks-istio-ingress aks-istio-ingressgateway-external

# 3. Application Pods
Write-Host "`n3. Application Pods:" -ForegroundColor Cyan
kubectl get pods -n pets -l app=store-front -o custom-columns=NAME:.metadata.name,READY:.status.containerStatuses[*].ready,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount

# 4. Istio Configuration
Write-Host "`n4. Istio Configuration:" -ForegroundColor Cyan
kubectl get gateway,virtualservice,destinationrule -n pets -o wide

# 5. Security
Write-Host "`n5. Security Configuration:" -ForegroundColor Cyan
kubectl get peerauthentication,requestauthentication,authorizationpolicy -n pets

# 6. HTTP Test
Write-Host "`n6. HTTP Connectivity Test:" -ForegroundColor Cyan
$response = Invoke-WebRequest -Uri "http://$EXTERNAL_IP/" -UseBasicParsing
Write-Host "  Status: $($response.StatusCode) $($response.StatusDescription)" -ForegroundColor Green
Write-Host "  Strategy: $($response.Headers['x-strategy'])" -ForegroundColor Green
Write-Host "  Content-Length: $($response.Headers['Content-Length']) bytes" -ForegroundColor Green
```

**Output Esperado:**
```
=== TESTE CONSOLIDADO FINAL ===

1. Cluster Nodes:
NAME                                STATUS   VERSION
aks-nodepool1-xxxxxx-vmss000000     Ready    v1.32.7
aks-nodepool1-xxxxxx-vmss000001     Ready    v1.32.7
aks-nodepool1-xxxxxx-vmss000002     Ready    v1.32.7

2. Ingress Gateway Service:
NAME                                TYPE           CLUSTER-IP    EXTERNAL-IP   PORT(S)                                      AGE
aks-istio-ingressgateway-external   LoadBalancer   10.0.23.68    4.249.81.21   15021:32567/TCP,80:30691/TCP,443:30840/TCP   45m

3. Application Pods:
NAME                           READY      STATUS    RESTARTS
store-front-7f55f477cb-xxxxx   true,true  Running   0
store-front-7f55f477cb-xxxxx   true,true  Running   0

4. Istio Configuration:
NAME                                              AGE
gateway.networking.istio.io/pets-gateway          45m

NAME                                              GATEWAYS                           HOSTS   AGE
virtualservice.networking.istio.io/store-front    ["aks-istio-ingress/pets-gateway"]   ["*"]   45m

NAME                                              HOST          AGE
destinationrule.networking.istio.io/store-front   store-front   45m

5. Security Configuration:
NAME                                                MODE     AGE
peerauthentication.security.istio.io/default        STRICT   30m

NAME                                                AGE
requestauthentication.security.istio.io/jwt-auth    30m

NAME                                                AGE
authorizationpolicy.security.istio.io/store-front-allow-ingress   30m

6. HTTP Connectivity Test:
  Status: 200 OK
  Strategy: canary-primary
  Content-Length: 12345 bytes
```

✅ **TODAS AS VALIDAÇÕES PASSARAM - LABORATÓRIO 100% FUNCIONAL!**

---

## Fase 8: Automação com Flagger

📝 **Esta fase implementa Progressive Delivery com rollback automático.**

### 8.1: Instalar Flagger
```bash
# Adicionar Helm repo do Flagger
kubectl apply -f https://raw.githubusercontent.com/fluxcd/flagger/main/artifacts/flagger/crd.yaml

# Instalar Flagger para Istio
kubectl apply -k github.com/fluxcd/flagger//kustomize/istio
```

**Validar instalação:**
```bash
kubectl get pods -n istio-system -l app.kubernetes.io/name=flagger
```

**Output Esperado:**
```
NAME                       READY   STATUS    RESTARTS   AGE
flagger-xxxxxxxxxx-xxxxx   1/1     Running   0          30s
```

### 8.2: Instalar Prometheus (requerido pelo Flagger)
```bash
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.25/samples/addons/prometheus.yaml
```

**Validar:**
```bash
kubectl get svc -n istio-system prometheus
```

**Output Esperado:**
```
NAME         TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
prometheus   ClusterIP   10.0.xxx.xxx   <none>        9090/TCP   30s
```

### 8.3: Criar Canary Resource para Automação
```bash
cat <<EOF | kubectl apply -f -
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: store-front
  namespace: pets
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: store-front
  progressDeadlineSeconds: 60
  service:
    port: 80
    targetPort: 8080
  analysis:
    interval: 30s
    threshold: 5
    maxWeight: 50
    stepWeight: 10
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 1m
    - name: request-duration
      thresholdRange:
        max: 500
      interval: 1m
  webhooks:
  - name: load-test
    url: http://flagger-loadtester/
    timeout: 5s
    metadata:
      type: cmd
      cmd: "hey -z 1m -q 10 -c 2 http://store-front-canary/"
EOF
```

**Validar:**
```bash
kubectl get canary -n pets
```

**Output Esperado:**
```
NAME          STATUS        WEIGHT   LASTTRANSITIONTIME
store-front   Initialized   0        2025-01-10T12:00:00Z
```

### 8.4: Trigger Automated Canary Deployment
```bash
# Atualizar a versão da aplicação (trigger canary)
kubectl set image deployment/store-front -n pets \
  store-front=ghcr.io/azure-samples/aks-store-demo/store-front:1.1.0
```

### 8.5: Observar Progressão Automática
```bash
watch kubectl get canary -n pets
```

**Output Esperado (progressão ao longo do tempo):**
```
NAME          STATUS       WEIGHT   LASTTRANSITIONTIME
store-front   Progressing  0        2025-01-10T12:00:00Z
store-front   Progressing  10       2025-01-10T12:00:30Z
store-front   Progressing  25       2025-01-10T12:01:00Z
store-front   Progressing  50       2025-01-10T12:01:30Z
store-front   Promoting    50       2025-01-10T12:02:00Z
store-front   Finalising   0        2025-01-10T12:02:30Z
store-front   Succeeded    0        2025-01-10T12:03:00Z
```

### 8.6: Ver Eventos do Canary
```bash
kubectl describe canary -n pets store-front
```

**Output Esperado:**
```
Events:
  Normal   Synced  3m   flagger  Initialization done! store-front.pets
  Normal   Synced  2m   flagger  New revision detected! Scaling up store-front.pets
  Normal   Synced  2m   flagger  Starting canary analysis for store-front.pets
  Normal   Synced  2m   flagger  Advance store-front.pets canary weight 10
  Normal   Synced  1m   flagger  Advance store-front.pets canary weight 25
  Normal   Synced  1m   flagger  Advance store-front.pets canary weight 50
  Normal   Synced  30s  flagger  Promotion completed! store-front.pets
```

### 8.7: Testar Rollback Automático (Simular Falha)
```bash
# Deploy com erro intencional (imagem inexistente)
kubectl set image deployment/store-front -n pets \
  store-front=ghcr.io/azure-samples/aks-store-demo/store-front:broken-version
```

**Observar rollback:**
```bash
watch kubectl get canary -n pets
```

**Output Esperado:**
```
NAME          STATUS       WEIGHT   LASTTRANSITIONTIME
store-front   Progressing  10       2025-01-10T12:05:00Z
store-front   Failed       0        2025-01-10T12:05:30Z
```

**Ver eventos de falha:**
```bash
kubectl describe canary -n pets store-front
```

**Output Esperado:**
```
Events:
  Warning  Synced  1m  flagger  Halt advancement no values found for istio metric request-success-rate
  Warning  Synced  1m  flagger  Rolling back store-front.pets failed checks threshold reached 5
  Warning  Synced  1m  flagger  Canary failed! Scaling down store-front.pets
```

✅ **Flagger detectou falha e fez rollback automático!**

---

## Fase 9: Certificados TLS Automáticos

📝 **Esta fase implementa gestão automática de certificados com Let's Encrypt.**

### 9.1: Instalar cert-manager
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml
```

⏱️ **Tempo estimado:** 1-2 minutos

**Validar instalação:**
```bash
kubectl get pods -n cert-manager
```

**Output Esperado:**
```
NAME                                       READY   STATUS    RESTARTS   AGE
cert-manager-xxxxxxxxxx-xxxxx              1/1     Running   0          1m
cert-manager-cainjector-xxxxxxxxxx-xxxxx   1/1     Running   0          1m
cert-manager-webhook-xxxxxxxxxx-xxxxx      1/1     Running   0          1m
```

### 9.2: Criar ClusterIssuer (Let's Encrypt Staging)
```bash
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: istio
EOF
```

**Validar:**
```bash
kubectl get clusterissuer
```

**Output Esperado:**
```
NAME                  READY   AGE
letsencrypt-staging   True    10s
```

### 9.3: Criar Certificate Resource
```bash
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: store-front-cert
  namespace: aks-istio-ingress
spec:
  secretName: store-front-tls
  issuerRef:
    name: letsencrypt-staging
    kind: ClusterIssuer
  dnsNames:
  - $EXTERNAL_IP.nip.io
EOF
```

📝 **Nota:** Usando nip.io para DNS wildcard apontando para o External IP.

**Validar criação:**
```bash
kubectl get certificate -n aks-istio-ingress
```

**Output Esperado:**
```
NAME               READY   SECRET             AGE
store-front-cert   True    store-front-tls    30s
```

### 9.4: Verificar Secret Criado
```bash
kubectl get secret -n aks-istio-ingress store-front-tls
```

**Output Esperado:**
```
NAME               TYPE                DATA   AGE
store-front-tls    kubernetes.io/tls   2      30s
```

### 9.5: Atualizar Gateway para Usar TLS
```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: pets-gateway
  namespace: aks-istio-ingress
spec:
  selector:
    istio: aks-istio-ingressgateway-external
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
    tls:
      httpsRedirect: true
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - "*"
    tls:
      mode: SIMPLE
      credentialName: store-front-tls
EOF
```

### 9.6: Testar HTTPS
```powershell
# Teste HTTPS (aceitar certificado self-signed staging)
$response = Invoke-WebRequest -Uri "https://$EXTERNAL_IP.nip.io/" -SkipCertificateCheck
Write-Host "Status: $($response.StatusCode)" -ForegroundColor Green
Write-Host "TLS Enabled: HTTPS funcionando!" -ForegroundColor Green
```

**Output Esperado:**
```
Status: 200
TLS Enabled: HTTPS funcionando!
```

### 9.7: Verificar Renovação Automática
```bash
# Cert-manager renova automaticamente 30 dias antes do expiry
kubectl describe certificate -n aks-istio-ingress store-front-cert
```

**Output Esperado:**
```
Status:
  Conditions:
    Last Transition Time:  2025-01-10T12:00:00Z
    Message:               Certificate is up to date and has not expired
    Reason:                Ready
    Status:                True
    Type:                  Ready
  Not After:               2025-04-10T12:00:00Z
  Not Before:              2025-01-10T12:00:00Z
  Renewal Time:            2025-03-11T12:00:00Z
```

✅ **Certificado TLS configurado com renovação automática!**

---

## Troubleshooting

### Problema 1: Pods com CrashLoopBackOff
**Sintoma:**
```bash
kubectl get pods -n pets
NAME                           READY   STATUS             RESTARTS   AGE
store-front-xxxxx              0/2     CrashLoopBackOff   3          2m
```

**Diagnóstico:**
```bash
# Ver logs do container principal
kubectl logs -n pets -l app=store-front -c store-front --tail=50

# Ver logs do istio-proxy sidecar
kubectl logs -n pets -l app=store-front -c istio-proxy --tail=50

# Ver eventos do pod
kubectl describe pod -n pets -l app=store-front
```

**Soluções:**
- Verificar resource limits (aumentar memory se OOMKilled)
- Verificar variáveis de ambiente da aplicação
- Verificar health checks (liveness/readiness probes)

### Problema 2: Ingress Gateway sem External IP
**Sintoma:**
```bash
kubectl get svc -n aks-istio-ingress
NAME                                TYPE           EXTERNAL-IP   PORT(S)
aks-istio-ingressgateway-external   LoadBalancer   <pending>     80:30691/TCP
```

**Diagnóstico:**
```bash
# Ver eventos do service
kubectl describe svc -n aks-istio-ingress aks-istio-ingressgateway-external

# Ver quota do cluster
az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query "networkProfile"
```

**Soluções:**
- Aguardar 2-3 minutos (provisionamento de LoadBalancer)
- Verificar quota de Public IPs na subscription
- Verificar se cluster tem acesso à Azure LB

### Problema 3: HTTP 404 Not Found
**Sintoma:**
```powershell
Invoke-WebRequest -Uri "http://$EXTERNAL_IP/"
# Retorna: 404 Not Found
```

**Diagnóstico:**
```bash
# Verificar se Gateway resource foi criado
kubectl get gateway -A

# Verificar selector do Gateway
kubectl get gateway -n aks-istio-ingress pets-gateway -o yaml | grep -A2 "selector:"

# Verificar VirtualService
kubectl get virtualservice -n pets store-front -o yaml
```

**Soluções:**
- Verificar se VirtualService referencia o Gateway correto (namespace-qualified)
- Verificar selector do Gateway: `istio: aks-istio-ingressgateway-external`
- Verificar se pods da aplicação estão Running (2/2)

### Problema 4: HTTP 403 RBAC Denied
**Sintoma:**
```powershell
Invoke-WebRequest -Uri "http://$EXTERNAL_IP/"
# Retorna: 403 Forbidden - RBAC: access denied
```

**Diagnóstico:**
```bash
# Ver AuthorizationPolicy
kubectl get authorizationpolicy -n pets

# Ver logs do istio-proxy
kubectl logs -n pets -l app=store-front -c istio-proxy | grep -i "RBAC"
```

**Soluções:**
- Adicionar rule permitindo namespace `aks-istio-ingress` na AuthorizationPolicy
- Remover temporariamente AuthorizationPolicy para validar:
  ```bash
  kubectl delete authorizationpolicy -n pets --all
  ```

### Problema 5: Sidecar Não Injetado
**Sintoma:**
```bash
kubectl get pods -n pets
NAME                           READY   STATUS    RESTARTS   AGE
store-front-xxxxx              1/1     Running   0          2m
```
(Deveria ser 2/2 com istio-proxy)

**Diagnóstico:**
```bash
# Verificar label do namespace
kubectl get namespace pets --show-labels
```

**Soluções:**
- Adicionar label ao namespace:
  ```bash
  kubectl label namespace pets istio.io/rev=asm-1-25
  ```
- Recriar os pods:
  ```bash
  kubectl rollout restart deployment/store-front -n pets
  ```

### Problema 6: Flagger Canary Stuck
**Sintoma:**
```bash
kubectl get canary -n pets
NAME          STATUS       WEIGHT   
store-front   Progressing  10
# Fica travado em 10% por muito tempo
```

**Diagnóstico:**
```bash
# Ver eventos do Canary
kubectl describe canary -n pets store-front

# Ver logs do Flagger
kubectl logs -n istio-system -l app.kubernetes.io/name=flagger
```

**Soluções:**
- Verificar se Prometheus está funcionando
- Verificar métricas no Prometheus:
  ```bash
  kubectl port-forward -n istio-system svc/prometheus 9090:9090
  # Abrir http://localhost:9090
  ```
- Ajustar thresholds no Canary resource

### Problema 7: Certificate Not Ready
**Sintoma:**
```bash
kubectl get certificate -n aks-istio-ingress
NAME               READY   
store-front-cert   False
```

**Diagnóstico:**
```bash
# Ver detalhes do Certificate
kubectl describe certificate -n aks-istio-ingress store-front-cert

# Ver logs do cert-manager
kubectl logs -n cert-manager -l app=cert-manager
```

**Soluções:**
- Verificar DNS resolution (usar nip.io para testes)
- Verificar challenge HTTP-01:
  ```bash
  kubectl get challenge -A
  ```
- Usar ClusterIssuer staging primeiro (limits mais altos)

---

## 📚 Referências

- [AKS Istio Documentation](https://learn.microsoft.com/azure/aks/istio-about)
- [Istio Traffic Management](https://istio.io/latest/docs/concepts/traffic-management/)
- [Flagger Progressive Delivery](https://docs.flagger.app/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [AKS Store Demo](https://github.com/Azure-Samples/aks-store-demo)

---

**🎉 Parabéns! Você completou o laboratório Istio no AKS com Progressive Delivery e TLS Automation!**

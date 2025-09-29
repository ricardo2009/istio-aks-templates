# 📖 Como Usar os Templates Istio

## 🎯 Visão Geral

Este repositório utiliza a **estratégia Helm sem Helm** - templates com sintaxe familiar `{{ .Values.xxx }}` processados por um renderizador Python customizado.

## 🚀 Uso Básico

### 1. **Renderizar Templates**

```bash
# Ambiente padrão
python scripts/helm_render.py -t templates -v templates/values.yaml -o manifests/default

# Staging
python scripts/helm_render.py -t templates -v templates/values-staging.yaml -o manifests/staging

# Produção
python scripts/helm_render.py -t templates -v templates/values-production.yaml -o manifests/production
```

### 2. **Aplicar no Cluster**

```bash
# Aplicar manifests renderizados
kubectl apply -f manifests/staging/

# Verificar deployment
kubectl get gateway,virtualservice,destinationrule,peerauthentication -n pets-staging
```

## 📋 **Estrutura de Valores**

### **values.yaml (Base)**
Configurações padrão para desenvolvimento e testes locais.

### **values-staging.yaml**
- Namespace: `pets-staging`
- mTLS: `PERMISSIVE`
- Routing: 90% primary, 10% canary
- Domínio: `pets-staging.contoso.com`

### **values-production.yaml**
- Namespace: `pets-prod`
- mTLS: `STRICT`
- Routing: 95% primary, 5% canary
- Domínio: `pets.contoso.com`

## 🔧 **Customização**

### **Adicionando Novos Templates**

1. Criar arquivo `.yaml` em `/templates`
2. Usar sintaxe Helm: `{{ .Values.app.name }}`
3. Testar renderização:
   ```bash
   python scripts/helm_render.py -t templates -v templates/values.yaml -o test-output
   ```

### **Criando Novos Ambientes**

1. Copiar `values.yaml` → `values-AMBIENTE.yaml`
2. Modificar configurações específicas
3. Renderizar e testar

## 🎨 **Exemplos de Uso**

### **Template com Condicional**
```yaml
{{- if .Values.security.mtls.enabled }}
spec:
  mtls:
    mode: {{ .Values.security.mtls.mode }}
{{- end }}
```

### **Template com Loop**
```yaml
hosts:
{{- range .Values.network.gateway.hosts }}
- {{ . }}
{{- end }}
```

### **Template com Função**
```yaml
metadata:
  name: {{ .Values.app.name }}-{{ .Values.metadata.labels.environment }}
```

## 🔍 **Debugging**

### **Verificar Sintaxe**
```bash
python scripts/helm_render.py -t templates -v templates/values.yaml -o /tmp/debug
```

### **Validar YAML**
```bash
yamllint templates/
kubectl apply --dry-run=client -f manifests/staging/
```

### **Testar no Cluster**
```bash
kubectl apply -f manifests/staging/
kubectl describe gateway -n pets-staging
kubectl describe virtualservice -n pets-staging
```

## 📚 **Recursos Avançados**

- ✅ Sintaxe Helm completa
- ✅ Condicionais e loops
- ✅ Múltiplos ambientes
- ✅ Validação automática
- ✅ CI/CD integrado
- ✅ Zero dependência do Helm
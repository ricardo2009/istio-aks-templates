# 🔧 TROUBLESHOOTING - LABORATÓRIO ISTIO AKS

## ❌ Erro: "Failed to parse string as JSON"

### **Problema**
```
Failed to parse string as JSON:
@/tmp/root-ca-policy.json
Error detail: Expecting value: line 1 column 1 (char 0)
```

### **Causa**
O Azure CLI não consegue interpretar a sintaxe `@arquivo.json` em algumas versões ou configurações.

### **✅ Solução**
Este erro foi **corrigido** na versão mais recente do script. A correção substitui:

**❌ Sintaxe problemática:**
```bash
az keyvault certificate create --policy @"$policy_file"
```

**✅ Sintaxe corrigida:**
```bash
az keyvault certificate create --policy "$(cat "$policy_file")"
```

### **🔍 Verificação**
Execute o script de verificação de dependências:
```bash
./lab/scripts/check-dependencies.sh
```

---

## ❌ Erro: "VaultNameNotValid"

### **Problema**
```
The vault name 'kv-istio-lab-certs-1759424802' is invalid. 
A vault's name must be between 3-24 alphanumeric characters.
```

### **Causa**
O nome gerado para o Key Vault excede 24 caracteres ou contém caracteres inválidos.

### **✅ Solução**
Este erro foi **corrigido** na versão mais recente do script. A correção substitui:

**❌ Nome muito longo (26 caracteres):**
```bash
KEY_VAULT_NAME="kv-istio-lab-certs-$(date +%s)"  # 26 chars
```

**✅ Nome correto (12 caracteres):**
```bash
KEY_VAULT_NAME="kvistio$(date +%s | tail -c 6)"  # 12 chars
```

### **Regras do Azure Key Vault**
- ✅ 3-24 caracteres alfanuméricos
- ✅ Deve começar com letra
- ✅ Deve terminar com letra ou dígito
- ✅ Sem hífens consecutivos

---

## ❌ Erro: "No such file or directory: '/tmp/istio-root-ca-key.pem'"

### **Problema**
```
[Errno 2] No such file or directory: '/tmp/istio-root-ca-key.pem'
```

### **Causa**
O comando `openssl genrsa` falhou silenciosamente ou não tem permissões para criar o arquivo.

### **✅ Solução**
Este erro foi **corrigido** na versão mais recente do script com verificações robustas:

**🔍 Verificações Adicionadas:**
- ✅ Verifica se OpenSSL está instalado
- ✅ Verifica permissões de escrita em `/tmp`
- ✅ Mostra comando sendo executado (debug)
- ✅ Verifica se comando falhou
- ✅ Verifica se arquivo foi criado e não está vazio
- ✅ Mostra tamanho do arquivo gerado

**🛠️ Instalação Manual do OpenSSL:**
```bash
sudo apt-get update
sudo apt-get install -y openssl
```

**🧪 Teste Manual:**
```bash
openssl genrsa -out "/tmp/test-key.pem" 2048
ls -la /tmp/test-key.pem
rm -f /tmp/test-key.pem
```

---

## ❌ Erro: "command not found"

### **Dependências Necessárias**
- ✅ Azure CLI (`az`)
- ✅ kubectl
- ✅ jq (JSON processor)
- ✅ OpenSSL
- ✅ curl
- ✅ git

### **✅ Instalação Rápida**
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y jq openssl curl git

# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# kubectl
az aks install-cli
```

---

## ❌ Erro: "Conditional Access"

### **Problema**
```
AADSTS53003: Access has been blocked by Conditional Access policies
```

### **✅ Solução**
1. **Use um ambiente autorizado** (sua máquina local)
2. **Ou configure exceção** para o IP do ambiente de execução
3. **Ou use Azure Cloud Shell** que já tem acesso autorizado

---

## ❌ Erro: "Insufficient quota"

### **Problema**
```
Operation could not be completed as it results in exceeding approved quota
```

### **✅ Solução**
1. **Verificar quota atual:**
```bash
az vm list-usage --location westus3 --output table
```

2. **Solicitar aumento de quota** no portal Azure
3. **Ou usar VMs menores** (já configurado no script: Standard_D2s_v3)

---

## ❌ Erro: "GitHub push protection"

### **Problema**
```
Push cannot contain secrets
```

### **✅ Solução**
Os segredos foram removidos do código. Use variáveis de ambiente:

```bash
export AZURE_CLIENT_ID="seu-client-id"
export AZURE_CLIENT_SECRET="seu-client-secret"
export AZURE_TENANT_ID="seu-tenant-id"
```

---

## 🆘 **SUPORTE ADICIONAL**

### **Logs Detalhados**
Todos os scripts geram logs detalhados em `/tmp/`:
- `/tmp/infrastructure-validation-report.json`
- `/tmp/istio-test-results/`
- `/tmp/lab-access.sh`
- `/tmp/lab-cleanup.sh`

### **Validação Completa**
Execute a validação completa:
```bash
./lab/scripts/01-validate-infrastructure.sh
```

### **Limpeza e Recomeço**
Se algo der errado, limpe tudo e recomece:
```bash
./lab/scripts/00-cleanup-all.sh
./lab/scripts/00-provision-complete-lab.sh
```

---

## 📞 **CONTATO**

Se o problema persistir:
1. ✅ Verifique os logs em `/tmp/`
2. ✅ Execute `check-dependencies.sh`
3. ✅ Consulte este guia de troubleshooting
4. ✅ Abra uma issue no repositório GitHub

**🎯 99% dos problemas são resolvidos com as soluções acima!**

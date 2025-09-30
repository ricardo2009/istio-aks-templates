# 🧪 Guia de Validação e Testes

## 📋 Visão Geral

Este documento descreve como validar e testar os templates Istio antes de fazer deploy.

## 🚀 Quick Start - Validação Completa

Para validar todos os templates de uma vez:

```bash
# Validar todos os ambientes
python scripts/validate_templates.py -t templates
```

Este script irá:
1. Descobrir todos os arquivos `values*.yaml`
2. Renderizar templates para cada ambiente
3. Validar a sintaxe YAML dos manifests gerados
4. Exibir um resumo completo

## 🔧 Validação Individual por Ambiente

### 1. Validar Ambiente Padrão

```bash
python scripts/helm_render.py \
  -t templates \
  -v templates/values.yaml \
  -o /tmp/manifests/default \
  --strict
```

### 2. Validar Staging

```bash
python scripts/helm_render.py \
  -t templates \
  -v templates/values-staging.yaml \
  -o /tmp/manifests/staging \
  --strict
```

### 3. Validar Production

```bash
python scripts/helm_render.py \
  -t templates \
  -v templates/values-production.yaml \
  -o /tmp/manifests/production \
  --strict
```

## 📝 Validação de YAML

### Validar Sintaxe dos Arquivos de Valores

```bash
yamllint templates/values*.yaml
```

### Validar Todos os Templates (exceto manifests gerados)

```bash
yamllint templates/
```

## ✅ Checklist de Validação

Antes de fazer commit ou deploy, execute:

- [ ] **Lint YAML**: `yamllint templates/values*.yaml`
- [ ] **Validação completa**: `python scripts/validate_templates.py -t templates`
- [ ] **Renderização strict**: Teste com `--strict` para todos os ambientes
- [ ] **Sintaxe YAML**: Verifique que todos os manifests gerados são YAML válido

## 🔍 Troubleshooting

### Erro: "Template não encontrado"

**Causa**: Diretório de templates incorreto ou não existe

**Solução**:
```bash
# Verificar se o diretório existe
ls -la templates/

# Usar caminho absoluto
python scripts/helm_render.py -t $(pwd)/templates -v $(pwd)/templates/values.yaml -o /tmp/output
```

### Erro: "Undefined variable"

**Causa**: Variável usada no template não está definida em values.yaml

**Solução**:
1. Verifique o arquivo values.yaml
2. Adicione a variável faltante ou
3. Use modo não-strict (remova `--strict`)

### Erro: "YAML syntax error"

**Causa**: Template gerou YAML inválido

**Solução**:
1. Verifique a indentação no template
2. Verifique se há caracteres especiais não escapados
3. Use `yamllint` para identificar o problema específico:
   ```bash
   yamllint /tmp/manifests/staging/
   ```

### Templates não estão sendo renderizados

**Causa**: Arquivos values-*.yaml sendo processados como templates

**Solução**: Certifique-se de usar a versão atualizada do `helm_render.py` que ignora arquivos que começam com `values`

## 🧪 Testes Automatizados

### GitHub Actions

O workflow `.github/workflows/deploy.yml` executa automaticamente:

1. **Validação de YAML**: Lint de todos os arquivos values
2. **Validação completa**: Executa `validate_templates.py`
3. **Renderização de teste**: Testa todos os ambientes com `--strict`
4. **Upload de artifacts**: Salva manifests renderizados para análise

### Executar Localmente

Simule o workflow do GitHub Actions localmente:

```bash
# 1. Install dependencies
pip install -r requirements.txt
pip install yamllint

# 2. Lint YAML
yamllint templates/values*.yaml

# 3. Validate all environments
python scripts/validate_templates.py -t templates

# 4. Test rendering with strict mode
python scripts/helm_render.py -t templates -v templates/values.yaml -o /tmp/test --strict
python scripts/helm_render.py -t templates -v templates/values-staging.yaml -o /tmp/test --strict
python scripts/helm_render.py -t templates -v templates/values-production.yaml -o /tmp/test --strict
```

## 📊 Interpretando Resultados

### Saída do validate_templates.py

```
✅ Ambiente values-production validado com sucesso!
```
→ Todos os templates foram renderizados e a sintaxe YAML está correta

```
❌ Ambiente values-staging contém erros de sintaxe YAML
```
→ Verifique os erros específicos listados acima desta mensagem

### Saída do helm_render.py

```
✓ Renderizado: /tmp/output/gateway.yaml
```
→ Template renderizado com sucesso

```
⊘ Ignorado (arquivo de valores): values.yaml
```
→ Arquivo de valores ignorado (comportamento esperado)

```
✗ Erro ao renderizar template.yaml: undefined variable 'foo'
```
→ Variável não definida - adicione ao values.yaml ou remova `--strict`

```
📊 Resumo: 4 templates renderizados, 0 erros
```
→ Resumo final - deve ter 0 erros para sucesso

## 🎯 Best Practices

1. **Sempre use `--strict`** durante desenvolvimento para detectar variáveis não definidas
2. **Execute validação completa** antes de cada commit
3. **Verifique os artifacts** no GitHub Actions para ver os manifests gerados
4. **Teste localmente** antes de abrir Pull Request
5. **Valide sintaxe YAML** dos arquivos de valores regularmente

## 🔗 Recursos Adicionais

- [Documentação de Uso](USAGE.md)
- [Configuração CI/CD](CICD.md)
- [GitHub Actions Workflow](.github/workflows/deploy.yml)

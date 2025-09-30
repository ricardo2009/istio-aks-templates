# 🔧 Scripts de Renderização e Validação

Este diretório contém os scripts para renderização de templates Istio e validação de ambientes.

## 📋 Scripts Disponíveis

### 1. `helm_render.py` - Renderizador de Templates

Renderiza templates Helm-style usando Jinja2 sem precisar do Helm instalado.

**Uso básico:**
```bash
python scripts/helm_render.py -t templates -v templates/values.yaml -o manifests/output
```

**Opções:**
- `-t, --templates-dir`: Diretório contendo templates (default: `generated/templates/helm`)
- `-v, --values`: Arquivo values.yaml (default: `generated/templates/helm/values.yaml`)
- `-o, --output-dir`: Diretório de saída (default: `generated/manifests`)
- `-n, --release-name`: Nome do release (default: `istio-demo`)
- `--namespace`: Namespace padrão (default: `default`)
- `--strict`: Falhar se variáveis não definidas

**Exemplos:**

Renderizar para staging:
```bash
python scripts/helm_render.py \
  -t templates \
  -v templates/values-staging.yaml \
  -o manifests/staging
```

Renderizar com modo strict (recomendado para CI/CD):
```bash
python scripts/helm_render.py \
  -t templates \
  -v templates/values-production.yaml \
  -o manifests/production \
  --strict
```

**Comportamento:**
- ✅ Renderiza todos os arquivos `.yaml` no diretório de templates
- ⊘ Ignora automaticamente arquivos `values*.yaml`
- ✓ Converte sintaxe Helm (`{{ .Values.xxx }}`) para Jinja2
- 📊 Exibe resumo com contagem de templates renderizados e erros
- ❌ Retorna código de saída 1 se houver erros

### 2. `validate_templates.py` - Validador de Ambientes

Valida que todos os templates podem ser renderizados para todos os ambientes.

**Uso básico:**
```bash
python scripts/validate_templates.py -t templates
```

**Opções:**
- `-t, --templates-dir`: Diretório contendo templates (default: `templates`)

**O que faz:**
1. 🔍 Descobre todos os arquivos `values*.yaml`
2. 🔧 Renderiza templates para cada ambiente em modo `--strict`
3. 📝 Valida sintaxe YAML de cada manifest gerado
4. 📊 Exibe resumo completo de sucesso/falha

**Exemplo de saída:**
```
============================================================
📊 RESUMO DA VALIDAÇÃO
============================================================
  values-production    ✅ PASSOU
  values-staging       ✅ PASSOU
  values               ✅ PASSOU
============================================================

🎉 Todos os ambientes foram validados com sucesso!
```

## 🚀 Fluxo de Trabalho Recomendado

### Durante Desenvolvimento

1. Editar templates ou valores
2. Validar imediatamente:
   ```bash
   python scripts/validate_templates.py -t templates
   ```
3. Verificar manifests gerados:
   ```bash
   python scripts/helm_render.py -t templates -v templates/values.yaml -o /tmp/test --strict
   cat /tmp/test/*.yaml
   ```

### Antes de Commit

```bash
# 1. Lint YAML dos valores
yamllint templates/values*.yaml

# 2. Validação completa
python scripts/validate_templates.py -t templates

# 3. Se tudo passar, commit
git add .
git commit -m "Update templates"
```

### Em CI/CD (GitHub Actions)

O workflow automaticamente:
1. Executa `validate_templates.py`
2. Testa renderização de todos os ambientes com `--strict`
3. Faz upload dos artifacts para análise

## 🔧 Conversão de Sintaxe Helm

O `helm_render.py` automaticamente converte:

| Helm | Jinja2 |
|------|--------|
| `{{ .Values.app.name }}` | `{{ values.app.name }}` |
| `{{ .Chart.name }}` | `{{ chart.name }}` |
| `{{ .Release.name }}` | `{{ release.name }}` |

## ⚠️ Limitações

- Templates devem usar sintaxe Helm (`{{ .Values.xxx }}`)
- Não suporta funções complexas do Helm (use Jinja2 filters)
- Arquivos que começam com `values` são sempre ignorados na renderização

## 🐛 Troubleshooting

### Script não encontra templates

**Solução:** Use caminho absoluto ou certifique-se de executar do diretório raiz:
```bash
cd /path/to/istio-aks-templates
python scripts/helm_render.py -t templates -v templates/values.yaml -o /tmp/out
```

### Erro "undefined variable"

**Causa:** Variável usada no template não existe em values.yaml

**Soluções:**
1. Adicione a variável ao values.yaml
2. Remova `--strict` para usar valores padrão vazios (não recomendado)
3. Use condicionais no template: `{% if values.foo %}{{ values.foo }}{% endif %}`

### Templates renderizam values-*.yaml

**Causa:** Versão antiga do script

**Solução:** Certifique-se de usar a versão mais recente que ignora arquivos `values*.yaml`

## 📚 Documentação Adicional

- [Guia de Validação](../docs/VALIDATION.md) - Guia completo de validação e testes
- [Guia de Uso](../docs/USAGE.md) - Como usar os templates
- [CI/CD](../docs/CICD.md) - Configuração de GitHub Actions

## 🤝 Contribuindo

Ao adicionar novos scripts:
1. Documente opções e comportamento
2. Adicione help text (`--help`)
3. Retorne códigos de saída apropriados (0 = sucesso, 1 = erro)
4. Adicione exemplos neste README

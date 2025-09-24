# 🔄 Migration Guide - Repository Reorganization

Este documento descreve as mudanças de reorganização do repositório para melhor estrutura e manutenibilidade.

## 📅 Data da Migração
**24 de Setembro de 2025**

## 🎯 Objetivos da Reorganização

1. **Eliminar Redundâncias**: Remover scripts e arquivos duplicados
2. **Estrutura Limpa**: Organizar melhor os arquivos na raiz
3. **Manutenibilidade**: Facilitar manutenção e contribuições
4. **Padrões Modernos**: Focar em GitHub Actions ao invés de scripts manuais

## 📁 Mudanças Estruturais

### ✅ Arquivos Mantidos na Raiz
```
/
├── README.md                    # Documentação principal
├── values.yaml                  # Configuração base
├── schema.yaml                  # Schema de validação
├── .gitignore                   # Configuração Git
├── .yamllint.yml                # Configuração de linting
├── .env.example                 # Template de configuração
├── WORKFLOWS_DOCUMENTATION.md   # Documentação dos workflows
```

### 📁 Novos Diretórios Criados
- `docs/` - Documentação adicional e referências
- `examples/` - Exemplos de uso e configurações

### 🔄 Arquivos Movidos

| Arquivo Original | Novo Local | Motivo |
|------------------|------------|--------|
| `deploy-istio-templates.yml` | `.github/workflows/` | Workflow duplicado |
| `azure-pipelines.yml` | `docs/azure-pipelines-reference.yml` | Referência histórica |

### 🗑️ Arquivos Removidos

| Arquivo Removido | Motivo | Substituto |
|------------------|--------|------------|
| `apply.sh` | Redundante | `scripts/preprocess-templates.sh` |
| `deploy-parametrized.sh` | Redundante | GitHub Actions workflows |
| `validate.sh` | Redundante | `.github/workflows/validate-test-templates.yml` |

## 🚀 Como Usar Após a Migração

### Para Deployment
**ANTES:**
```bash
./apply.sh prod
```

**AGORA:**
```bash
# Via GitHub Actions (recomendado)
gh workflow run deploy-istio-templates.yml -f environment=prod

# Via script direto (se necessário)
./scripts/preprocess-templates.sh prod myapp myapp-prod
```

### Para Validação
**ANTES:**
```bash
./validate.sh
```

**AGORA:**
```bash
# Via GitHub Actions (automático nos PRs)
gh workflow run validate-test-templates.yml

# Validação local usando o preprocessor
./scripts/preprocess-templates.sh dev myapp myapp-dev --validate-only
```

## 📊 Benefícios da Reorganização

### ✅ Vantagens
- **Raiz Limpa**: Apenas arquivos essenciais na raiz
- **Sem Duplicação**: Uma única fonte de verdade para cada funcionalidade  
- **GitHub Actions First**: Foco em CI/CD moderno
- **Melhor Documentação**: Estrutura organizacional clara
- **Manutenibilidade**: Mais fácil de manter e contribuir

### 🔧 Funcionalidades Consolidadas
- **Template Processing**: Centralizado no `preprocess-templates.sh`
- **Validation**: Integrado nos workflows do GitHub Actions
- **Deployment**: Workflows automatizados com aprovações
- **Testing**: Suite completa de testes automatizados

## 🆘 Troubleshooting

### Se você tinha scripts personalizados baseados nos arquivos removidos:

1. **apply.sh**: Migre para usar `scripts/preprocess-templates.sh` ou workflows
2. **deploy-parametrized.sh**: Use o workflow `deploy-istio-templates.yml`
3. **validate.sh**: Use o workflow `validate-test-templates.yml`

### Para recuperar funcionalidades específicas:
```bash
# Ver histórico do Git para referência
git log --oneline --follow -- apply.sh

# Ou consulte a documentação atualizada
cat README.md
cat WORKFLOWS_DOCUMENTATION.md
```

## 📚 Documentação Adicional

- **[README.md](../README.md)**: Guia principal de uso
- **[WORKFLOWS_DOCUMENTATION.md](../WORKFLOWS_DOCUMENTATION.md)**: Documentação completa dos workflows
- **[azure-pipelines-reference.yml](./azure-pipelines-reference.yml)**: Referência histórica do Azure DevOps

## 🤝 Contribuindo

Com a nova estrutura, contribuições ficaram mais organizadas:

1. **Templates**: Modifique em `templates/`
2. **Configuração**: Ajuste `values.yaml` e overlays
3. **Scripts**: Melhorias no `scripts/preprocess-templates.sh`
4. **Workflows**: Otimizações nos arquivos `.github/workflows/`
5. **Documentação**: Adicione em `docs/` ou `examples/`

---

> 💡 **Dica**: Esta migração seguiu as melhores práticas de organização de repositórios open-source, tornando o projeto mais profissional e fácil de manter.
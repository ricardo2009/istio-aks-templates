#!/usr/bin/env python3
"""Script de validação para manifestos Istio Demo Lab.

Este script valida a sintaxe YAML e estrutura dos manifestos.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import yaml


def validate_yaml_syntax(file_path: Path) -> tuple[bool, str]:
    """Valida a sintaxe YAML de um arquivo."""
    try:
        with file_path.open('r', encoding='utf-8') as f:
            content = yaml.safe_load(f)
            if content is None:
                return False, "Arquivo vazio ou inválido"
            if not isinstance(content, dict):
                return False, "Conteúdo deve ser um objeto YAML"
        return True, "OK"
    except yaml.YAMLError as e:
        return False, str(e)


def validate_istio_manifest(file_path: Path) -> tuple[bool, str]:
    """Valida estrutura básica de um manifest Istio/Kubernetes."""
    try:
        with file_path.open('r', encoding='utf-8') as f:
            content = yaml.safe_load(f)
        
        required_fields = ['apiVersion', 'kind', 'metadata']
        missing = [field for field in required_fields if field not in content]
        
        if missing:
            return False, f"Campos obrigatórios ausentes: {', '.join(missing)}"
        
        return True, "OK"
    except Exception as e:
        return False, str(e)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Valida manifestos Istio Demo Lab"
    )
    parser.add_argument(
        "--manifests-dir",
        "-m",
        type=Path,
        default=Path("manifests/demo"),
        help="Diretório contendo os manifestos"
    )
    
    args = parser.parse_args()
    manifests_dir = args.manifests_dir.resolve()
    
    if not manifests_dir.exists():
        print(f"❌ Diretório de manifestos não encontrado: {manifests_dir}")
        sys.exit(1)
    
    print("=" * 60)
    print("🚀 Iniciando validação de manifestos Istio Demo Lab")
    print("=" * 60)
    
    # Descobre arquivos YAML
    yaml_files = sorted(manifests_dir.glob("*.yaml"))
    
    if not yaml_files:
        print(f"❌ Nenhum arquivo YAML encontrado em {manifests_dir}")
        sys.exit(1)
    
    print(f"\n📋 Manifestos encontrados: {len(yaml_files)}")
    
    # Valida cada arquivo
    all_passed = True
    for yaml_file in yaml_files:
        print(f"\n🔍 Validando: {yaml_file.name}")
        
        # Valida sintaxe YAML
        is_valid, error = validate_yaml_syntax(yaml_file)
        if not is_valid:
            print(f"  ❌ Sintaxe YAML inválida: {error}")
            all_passed = False
            continue
        print(f"  ✓ Sintaxe YAML válida")
        
        # Valida estrutura Istio/K8s
        is_valid, error = validate_istio_manifest(yaml_file)
        if not is_valid:
            print(f"  ❌ Estrutura inválida: {error}")
            all_passed = False
            continue
        print(f"  ✓ Estrutura válida")
    
    # Resumo final
    print("\n" + "=" * 60)
    if all_passed:
        print("🎉 Todos os manifestos foram validados com sucesso!")
        print("=" * 60)
        sys.exit(0)
    else:
        print("❌ Alguns manifestos falharam na validação")
        print("=" * 60)
        sys.exit(1)


if __name__ == "__main__":
    main()

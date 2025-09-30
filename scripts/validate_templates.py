#!/usr/bin/env python3
"""Script de validação para templates Istio.

Este script valida que todos os templates podem ser renderizados corretamente
para todos os ambientes configurados.
"""
from __future__ import annotations

import argparse
import sys
import tempfile
from pathlib import Path
from typing import List

import yaml


def validate_yaml_syntax(file_path: Path) -> tuple[bool, str]:
    """Valida a sintaxe YAML de um arquivo."""
    try:
        with file_path.open('r', encoding='utf-8') as f:
            yaml.safe_load(f)
        return True, "OK"
    except yaml.YAMLError as e:
        return False, str(e)


def render_environment(templates_dir: Path, values_file: Path, env_name: str) -> bool:
    """Renderiza templates para um ambiente específico."""
    import subprocess
    
    print(f"\n{'=' * 60}")
    print(f"🔍 Validando ambiente: {env_name}")
    print(f"{'=' * 60}")
    
    # Cria diretório temporário para output
    with tempfile.TemporaryDirectory() as tmpdir:
        output_dir = Path(tmpdir) / env_name
        
        # Executa o renderizador
        cmd = [
            sys.executable,
            str(templates_dir.parent / "scripts" / "helm_render.py"),
            "-t", str(templates_dir),
            "-v", str(values_file),
            "-o", str(output_dir),
            "--strict"
        ]
        
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=False
            )
            
            print(result.stdout)
            
            if result.returncode != 0:
                print(f"❌ Erro ao renderizar {env_name}")
                if result.stderr:
                    print(f"Stderr: {result.stderr}")
                return False
            
            # Valida sintaxe YAML de cada arquivo renderizado
            yaml_files = list(output_dir.glob("*.yaml"))
            if not yaml_files:
                print(f"⚠️  Nenhum arquivo YAML gerado para {env_name}")
                return False
            
            print(f"\n📝 Validando sintaxe YAML dos manifests gerados...")
            all_valid = True
            for yaml_file in sorted(yaml_files):
                is_valid, error = validate_yaml_syntax(yaml_file)
                if is_valid:
                    print(f"  ✓ {yaml_file.name}")
                else:
                    print(f"  ✗ {yaml_file.name}: {error}")
                    all_valid = False
            
            if all_valid:
                print(f"\n✅ Ambiente {env_name} validado com sucesso!")
                return True
            else:
                print(f"\n❌ Ambiente {env_name} contém erros de sintaxe YAML")
                return False
                
        except Exception as e:
            print(f"❌ Exceção ao processar {env_name}: {e}")
            return False


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Valida templates Istio para todos os ambientes"
    )
    parser.add_argument(
        "--templates-dir",
        "-t",
        type=Path,
        default=Path("templates"),
        help="Diretório contendo os templates"
    )
    
    args = parser.parse_args()
    templates_dir = args.templates_dir.resolve()
    
    if not templates_dir.exists():
        print(f"❌ Diretório de templates não encontrado: {templates_dir}")
        sys.exit(1)
    
    print("=" * 60)
    print("🚀 Iniciando validação de templates Istio")
    print("=" * 60)
    
    # Descobre arquivos de valores
    values_files = sorted(templates_dir.glob("values*.yaml"))
    
    if not values_files:
        print(f"❌ Nenhum arquivo de valores encontrado em {templates_dir}")
        sys.exit(1)
    
    print(f"\n📋 Arquivos de valores encontrados:")
    for vf in values_files:
        print(f"  • {vf.name}")
    
    # Valida cada ambiente
    results = {}
    for values_file in values_files:
        env_name = values_file.stem  # Remove .yaml extension
        success = render_environment(templates_dir, values_file, env_name)
        results[env_name] = success
    
    # Resumo final
    print("\n" + "=" * 60)
    print("📊 RESUMO DA VALIDAÇÃO")
    print("=" * 60)
    
    all_passed = True
    for env_name, success in results.items():
        status = "✅ PASSOU" if success else "❌ FALHOU"
        print(f"  {env_name:20s} {status}")
        if not success:
            all_passed = False
    
    print("=" * 60)
    
    if all_passed:
        print("\n🎉 Todos os ambientes foram validados com sucesso!")
        sys.exit(0)
    else:
        print("\n❌ Alguns ambientes falharam na validação")
        sys.exit(1)


if __name__ == "__main__":
    main()

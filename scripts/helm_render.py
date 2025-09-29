#!/usr/bin/env python3
"""Renderizador que simula 'helm template' sem precisar do Helm.

Este script usa a estratégia do Helm (templates + values.yaml) mas com
um renderizador customizado usando Jinja2.
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path
from typing import Any, Dict

import yaml
from jinja2 import Environment, BaseLoader, StrictUndefined


class HelmTemplateLoader(BaseLoader):
    """Loader customizado que converte sintaxe Helm para Jinja2."""
    
    def __init__(self, templates_dir: Path):
        self.templates_dir = templates_dir
    
    def get_source(self, environment: Environment, template: str) -> tuple[str, str, callable]:
        path = self.templates_dir / template
        if not path.exists():
            raise FileNotFoundError(f"Template não encontrado: {path}")
        
        # Lê o conteúdo do template
        source = path.read_text(encoding="utf-8")
        
        # Converte sintaxe Helm para Jinja2
        # {{ .Values.xxx }} -> {{ values.xxx }}
        source = re.sub(r'\{\{\s*\.Values\.([^}]+)\s*\}\}', r'{{ values.\1 }}', source)
        
        # {{ .Chart.xxx }} -> {{ chart.xxx }} (caso necessário)
        source = re.sub(r'\{\{\s*\.Chart\.([^}]+)\s*\}\}', r'{{ chart.\1 }}', source)
        
        # {{ .Release.xxx }} -> {{ release.xxx }} (caso necessário)
        source = re.sub(r'\{\{\s*\.Release\.([^}]+)\s*\}\}', r'{{ release.\1 }}', source)
        
        mtime = path.stat().st_mtime
        
        def uptodate() -> bool:
            try:
                return path.stat().st_mtime == mtime
            except OSError:
                return False
        
        return source, str(path), uptodate


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Renderizador estilo Helm sem Helm")
    parser.add_argument(
        "--templates-dir",
        "-t",
        default=Path("generated/templates/helm"),
        type=Path,
        help="Diretório contendo os templates Helm",
    )
    parser.add_argument(
        "--values",
        "-v",
        default=Path("generated/templates/helm/values.yaml"),
        type=Path,
        help="Arquivo values.yaml",
    )
    parser.add_argument(
        "--output-dir",
        "-o",
        default=Path("generated/manifests"),
        type=Path,
        help="Diretório de saída para os manifests",
    )
    parser.add_argument(
        "--release-name",
        "-n",
        default="istio-demo",
        help="Nome do release (simulação)",
    )
    parser.add_argument(
        "--namespace",
        default="default",
        help="Namespace padrão",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Falhar se variáveis não definidas",
    )
    return parser.parse_args()


def load_values(values_file: Path) -> Dict[str, Any]:
    """Carrega arquivo values.yaml."""
    if not values_file.exists():
        return {}
    
    with values_file.open("r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def create_render_context(values: Dict[str, Any], release_name: str, namespace: str) -> Dict[str, Any]:
    """Cria contexto para renderização (simula objetos Helm)."""
    return {
        "values": values,
        "chart": {
            "name": "istio-templates",
            "version": "1.0.0",
        },
        "release": {
            "name": release_name,
            "namespace": namespace,
        },
    }


def render_templates(args: argparse.Namespace) -> None:
    """Renderiza todos os templates no diretório."""
    values = load_values(args.values)
    context = create_render_context(values, args.release_name, args.namespace)
    
    # Configura ambiente Jinja2
    loader = HelmTemplateLoader(args.templates_dir)
    env_kwargs = {
        "loader": loader,
        "trim_blocks": True,
        "lstrip_blocks": True,
    }
    if args.strict:
        env_kwargs["undefined"] = StrictUndefined
    
    env = Environment(**env_kwargs)
    
    # Cria diretório de saída
    args.output_dir.mkdir(parents=True, exist_ok=True)
    
    # Renderiza cada template
    template_files = list(args.templates_dir.glob("*.yaml"))
    if not template_files:
        print(f"Nenhum template encontrado em: {args.templates_dir}")
        return
    
    for template_path in sorted(template_files):
        # Pula o arquivo values.yaml
        if template_path.name == "values.yaml":
            continue
            
        template_name = template_path.name
        
        try:
            template = env.get_template(template_name)
            rendered = template.render(**context)
            
            # Remove linhas vazias excessivas para otimizar performance
            lines = rendered.strip().split('\n')
            cleaned_lines = []
            prev_empty = False
            
            for line in lines:
                is_empty = not line.strip()
                if is_empty and prev_empty:
                    continue  # Pula linhas vazias consecutivas
                cleaned_lines.append(line)
                prev_empty = is_empty
            
            rendered = '\n'.join(cleaned_lines)
            
            if rendered.strip():  # Só salva se não estiver vazio
                output_path = args.output_dir / template_name
                output_path.write_text(rendered + '\n', encoding="utf-8")
                print(f"✓ Renderizado: {output_path}")
            else:
                print(f"⚠ Template vazio: {template_name}")
                
        except Exception as e:
            print(f"✗ Erro ao renderizar {template_name}: {e}")


def main() -> None:
    args = parse_args()
    
    if not args.templates_dir.exists():
        print(f"Erro: Diretório de templates não encontrado: {args.templates_dir}")
        return
    
    if not args.values.exists():
        print(f"Aviso: Arquivo values não encontrado: {args.values}")
        print("Continuando com valores padrão...")
    
    render_templates(args)
    print(f"\n📁 Manifests gerados em: {args.output_dir}")


if __name__ == "__main__":
    main()
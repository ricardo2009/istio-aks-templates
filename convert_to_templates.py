#!/usr/bin/env python3
import os
import re
import yaml
from pathlib import Path

print('=== Script de Conversão para Templates Jinja2 ===')
print('Analisando scripts/ e templates/...')

# Criar diretórios
Path('templates_jinja2').mkdir(exist_ok=True)
Path('scripts_parametrizados').mkdir(exist_ok=True)

files_found = []
for root, dirs, files in os.walk('.'):
    if any(x in root for x in ['scripts', 'templates']):
        for f in files:
            if f.endswith(('.yaml', '.yml', '.sh', '.py')):
                files_found.append(os.path.join(root, f))

print(f'Encontrados {len(files_found)} arquivos')
for f in files_found[:20]:
    print(f'  - {f}')

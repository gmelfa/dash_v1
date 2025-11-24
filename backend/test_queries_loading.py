#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Script de teste para validar carregamento de queries"""

from app import load_queries, load_queries_categorized

print("=" * 60)
print("TESTE: Carregamento de Queries")
print("=" * 60)

# Teste 1: Formato antigo (array)
print("\n1️⃣ Teste Formato Antigo (Flat Array)")
print("-" * 60)
queries = load_queries()
print(f"✓ Total de queries carregadas: {len(queries)}")
if queries:
    print(f"✓ Primeira query ID: {queries[0].get('id', 'N/A')}")
    print(f"✓ Primeira query Título: {queries[0].get('title', 'N/A')}")
    if 'category_name' in queries[0]:
        print(f"✓ Categoria: {queries[0]['category_name']}")
else:
    print("⚠️ Nenhuma query encontrada")

# Teste 2: Formato categorizado
print("\n2️⃣ Teste Formato Categorizado")
print("-" * 60)
categorized = load_queries_categorized()
categories = categorized.get('categories', [])
print(f"✓ Total de categorias: {len(categories)}")

if categories:
    total_queries = sum(len(cat.get('queries', [])) for cat in categories)
    print(f"✓ Total de queries em todas categorias: {total_queries}")
    
    print("\n📋 Categorias Disponíveis:")
    for i, cat in enumerate(categories, 1):
        queries_count = len(cat.get('queries', []))
        icon = cat.get('icon', '')
        name = cat.get('name', 'Sem Nome')
        print(f"   {i}. {icon} {name} ({queries_count} queries)")
else:
    print("⚠️ Nenhuma categoria encontrada")

print("\n" + "=" * 60)
print("✅ Testes concluídos!")
print("=" * 60)

#!/usr/bin/env python
import json
import os
from export import export_batch

# Testar o carregamento das queries
try:
    queries_file = os.path.join(os.path.dirname(__file__), 'queries.json')
    print(f"Arquivo: {queries_file}")
    print(f"Existe: {os.path.exists(queries_file)}")
    
    with open(queries_file, 'r', encoding='utf-8') as f:
        all_queries = json.load(f)
    
    print(f"Queries carregadas: {len(all_queries)}")
    for q in all_queries:
        print(f"  - {q['id']}: {q['title']}")
        
except Exception as e:
    print(f"Erro ao carregar queries: {e}")
    import traceback
    traceback.print_exc()

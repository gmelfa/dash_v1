"""
Script para verificar comentários no banco de dados
"""
import sqlite3
from datetime import datetime

db_path = 'instance/dashboard.db'

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

print("=" * 80)
print("COMENTÁRIOS NO BANCO DE DADOS")
print("=" * 80)

cursor.execute("""
    SELECT 
        c.id,
        c.query_id,
        c.content,
        c.status,
        u.username,
        c.created_at
    FROM comment c
    LEFT JOIN user u ON c.user_id = u.id
    ORDER BY c.query_id, c.created_at
""")

comments = cursor.fetchall()

if not comments:
    print("Nenhum comentário encontrado ainda.")
else:
    current_query = None
    for comment_id, query_id, content, status, username, created_at in comments:
        if query_id != current_query:
            print(f"\n{'─' * 80}")
            print(f"📊 QUERY: {query_id}")
            print(f"{'─' * 80}")
            current_query = query_id
        
        print(f"\nID: {comment_id}")
        print(f"Autor: {username}")
        print(f"Status: {status}")
        print(f"Data: {created_at}")
        print(f"Comentário: {content[:100]}{'...' if len(content) > 100 else ''}")

print(f"\n{'=' * 80}")
print(f"TOTAL: {len(comments)} comentário(s)")
print(f"{'=' * 80}")

conn.close()

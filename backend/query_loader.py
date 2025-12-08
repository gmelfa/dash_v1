"""
Query Loader Module - Sistema de Gerenciamento de Queries com Cache SQLite

Este módulo fornece um sistema escalável para gerenciar queries SQL armazenadas
em arquivos organizados por categoria, com cache SQLite para performance otimizada.

Funcionalidades:
- Carregamento automático de queries de arquivos .sql
- Cache SQLite em memória para acesso rápido
- Hot reload (detecção automática de mudanças)
- Busca e filtragem por categoria
- Extração de metadados de comentários SQL
"""

import os
import sqlite3
import hashlib
import re
from dataclasses import dataclass, asdict
from typing import List, Optional, Dict, Any
from datetime import datetime
from pathlib import Path


@dataclass
class QueryMetadata:
    """Metadados de uma query SQL"""
    id: str
    category: str
    name: str
    description: str
    sql_content: str
    file_path: str
    file_hash: str
    tags: List[str]
    order: int
    created_at: str
    updated_at: str
    
    def to_dict(self) -> Dict[str, Any]:
        """Converte para dicionário"""
        return asdict(self)


class QueryLoader:
    """
    Gerenciador de queries com cache SQLite
    
    Carrega queries de arquivos .sql organizados em pastas e mantém
    um cache SQLite para acesso rápido.
    """
    
    def __init__(self, queries_dir: str = 'queries', db_path: str = ':memory:'):
        """
        Inicializa o QueryLoader
        
        Args:
            queries_dir: Diretório raiz das queries (relativo ao backend)
            db_path: Caminho do banco SQLite (':memory:' para in-memory)
        """
        self.base_dir = os.path.dirname(os.path.abspath(__file__))
        self.queries_dir = os.path.join(self.base_dir, queries_dir)
        self.db_path = db_path
        self.conn = None
        self._file_timestamps = {}  # Cache de timestamps para hot reload
        
        # Criar diretório de queries se não existir
        os.makedirs(self.queries_dir, exist_ok=True)
        
        # Inicializar banco de dados
        self._init_database()
    
    def _init_database(self):
        """Inicializa o banco de dados SQLite"""
        self.conn = sqlite3.connect(self.db_path, check_same_thread=False)
        self.conn.row_factory = sqlite3.Row  # Permite acesso por nome de coluna
        
        cursor = self.conn.cursor()
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS queries (
                id TEXT PRIMARY KEY,
                category TEXT NOT NULL,
                name TEXT NOT NULL,
                description TEXT,
                sql_content TEXT NOT NULL,
                file_path TEXT NOT NULL,
                file_hash TEXT NOT NULL,
                tags TEXT,
                query_order INTEGER DEFAULT 999,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
        ''')
        
        # Criar índices para busca rápida
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_category ON queries(category)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_name ON queries(name)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_order ON queries(query_order)')
        
        self.conn.commit()
    
    def _calculate_file_hash(self, file_path: str) -> str:
        """Calcula hash MD5 de um arquivo"""
        hash_md5 = hashlib.md5()
        with open(file_path, 'rb') as f:
            for chunk in iter(lambda: f.read(4096), b""):
                hash_md5.update(chunk)
        return hash_md5.hexdigest()
    
    def _extract_metadata(self, file_path: str, category: str) -> Optional[QueryMetadata]:
        """
        Extrai metadados de um arquivo SQL
        
        Procura por comentários especiais no formato:
        -- @id: query_id
        -- @name: Nome da Query
        -- @description: Descrição
        -- @tags: tag1, tag2, tag3
        """
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Extrair metadados dos comentários
            metadata = {
                'id': None,
                'name': None,
                'description': '',
                'tags': [],
                'order': 999
            }
            
            # Regex para capturar metadados
            id_match = re.search(r'--\s*@id:\s*(.+)', content)
            name_match = re.search(r'--\s*@name:\s*(.+)', content)
            desc_match = re.search(r'--\s*@description:\s*(.+)', content)
            tags_match = re.search(r'--\s*@tags:\s*(.+)', content)
            order_match = re.search(r'--\s*@order:\s*(\d+)', content)
            
            if id_match:
                metadata['id'] = id_match.group(1).strip()
            if name_match:
                metadata['name'] = name_match.group(1).strip()
            if desc_match:
                metadata['description'] = desc_match.group(1).strip()
            if tags_match:
                tags_str = tags_match.group(1).strip()
                metadata['tags'] = [t.strip() for t in tags_str.split(',')]
            if order_match:
                metadata['order'] = int(order_match.group(1).strip())
            
            # Se não tiver @id, usar nome do arquivo
            if not metadata['id']:
                file_name = os.path.splitext(os.path.basename(file_path))[0]
                metadata['id'] = file_name
            
            # Se não tiver @name, usar ID formatado
            if not metadata['name']:
                metadata['name'] = metadata['id'].replace('_', ' ').title()
            
            # Criar ID completo com categoria
            full_id = f"{category}/{metadata['id']}"
            
            # Calcular hash do arquivo
            file_hash = self._calculate_file_hash(file_path)
            
            # Timestamps
            now = datetime.now().isoformat()
            
            return QueryMetadata(
                id=full_id,
                category=category,
                name=metadata['name'],
                description=metadata['description'],
                sql_content=content,
                file_path=file_path,
                file_hash=file_hash,
                tags=metadata['tags'],
                order=metadata['order'],
                created_at=now,
                updated_at=now
            )
        
        except Exception as e:
            print(f"Erro ao extrair metadados de {file_path}: {e}")
            return None
    
    def _scan_queries_directory(self) -> List[QueryMetadata]:
        """Varre o diretório de queries e retorna lista de metadados"""
        queries = []
        
        # Verificar se diretório existe
        if not os.path.exists(self.queries_dir):
            print(f"Diretório de queries não encontrado: {self.queries_dir}")
            return queries
        
        # Varrer recursivamente procurando arquivos .sql
        for root, dirs, files in os.walk(self.queries_dir):
            for file in files:
                if file.endswith('.sql'):
                    file_path = os.path.join(root, file)
                    
                    # Determinar categoria pelo diretório
                    rel_path = os.path.relpath(root, self.queries_dir)
                    category = rel_path if rel_path != '.' else 'geral'
                    
                    # Extrair metadados
                    metadata = self._extract_metadata(file_path, category)
                    if metadata:
                        queries.append(metadata)
                        # Armazenar timestamp para hot reload
                        self._file_timestamps[file_path] = os.path.getmtime(file_path)
        
        return queries
    
    def load_all_queries(self, force_reload: bool = False) -> int:
        """
        Carrega todas as queries do diretório para o cache SQLite
        
        Args:
            force_reload: Se True, recarrega mesmo que não haja mudanças
        
        Returns:
            Número de queries carregadas
        """
        queries = self._scan_queries_directory()
        
        cursor = self.conn.cursor()
        loaded_count = 0
        
        for query in queries:
            # Verificar se query já existe no cache
            cursor.execute('SELECT file_hash FROM queries WHERE id = ?', (query.id,))
            existing = cursor.fetchone()
            
            # Inserir ou atualizar se hash mudou ou force_reload
            if not existing or existing['file_hash'] != query.file_hash or force_reload:
                cursor.execute('''
                    INSERT OR REPLACE INTO queries 
                    (id, category, name, description, sql_content, file_path, file_hash, tags, query_order, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    query.id,
                    query.category,
                    query.name,
                    query.description,
                    query.sql_content,
                    query.file_path,
                    query.file_hash,
                    ','.join(query.tags),
                    query.order,
                    query.created_at,
                    query.updated_at
                ))
                loaded_count += 1
        
        self.conn.commit()
        print(f"[OK] Carregadas {loaded_count} queries no cache SQLite")
        return loaded_count
    
    def get_query(self, query_id: str) -> Optional[Dict[str, Any]]:
        """
        Busca uma query por ID
        
        Args:
            query_id: ID da query (ex: 'financeiro/resultado_10_2025')
        
        Returns:
            Dicionário com dados da query ou None se não encontrada
        """
        cursor = self.conn.cursor()
        cursor.execute('SELECT * FROM queries WHERE id = ?', (query_id,))
        row = cursor.fetchone()
        
        if row:
            return dict(row)
        return None
    
    def list_queries(self, category: Optional[str] = None) -> List[Dict[str, Any]]:
        """
        Lista todas as queries, opcionalmente filtradas por categoria
        
        Args:
            category: Categoria para filtrar (None = todas)
        
        Returns:
            Lista de dicionários com dados das queries
        """
        cursor = self.conn.cursor()
        
        if category:
            cursor.execute('SELECT * FROM queries WHERE category = ? ORDER BY query_order, name', (category,))
        else:
            cursor.execute('SELECT * FROM queries ORDER BY query_order, category, name')
        
        rows = cursor.fetchall()
        return [dict(row) for row in rows]
    
    def get_categories(self) -> List[Dict[str, Any]]:
        """
        Retorna lista de categorias com contagem de queries
        
        Returns:
            Lista de dicionários com 'category' e 'count'
        """
        cursor = self.conn.cursor()
        cursor.execute('''
            SELECT category, COUNT(*) as count 
            FROM queries 
            GROUP BY category 
            ORDER BY category
        ''')
        
        rows = cursor.fetchall()
        return [dict(row) for row in rows]
    
    def search_queries(self, search_term: str) -> List[Dict[str, Any]]:
        """
        Busca queries por termo (nome ou descrição)
        
        Args:
            search_term: Termo de busca
        
        Returns:
            Lista de queries que correspondem ao termo
        """
        cursor = self.conn.cursor()
        search_pattern = f'%{search_term}%'
        
        cursor.execute('''
            SELECT * FROM queries 
            WHERE name LIKE ? OR description LIKE ? OR tags LIKE ?
            ORDER BY name
        ''', (search_pattern, search_pattern, search_pattern))
        
        rows = cursor.fetchall()
        return [dict(row) for row in rows]
    
    def check_for_updates(self) -> List[str]:
        """
        Verifica se algum arquivo foi modificado (hot reload)
        
        Returns:
            Lista de IDs de queries que foram modificadas
        """
        modified_queries = []
        
        for file_path, old_timestamp in self._file_timestamps.items():
            if os.path.exists(file_path):
                current_timestamp = os.path.getmtime(file_path)
                if current_timestamp > old_timestamp:
                    # Arquivo foi modificado
                    rel_path = os.path.relpath(os.path.dirname(file_path), self.queries_dir)
                    category = rel_path if rel_path != '.' else 'geral'
                    
                    metadata = self._extract_metadata(file_path, category)
                    if metadata:
                        modified_queries.append(metadata.id)
                        
                        # Atualizar no banco
                        cursor = self.conn.cursor()
                        cursor.execute('''
                            UPDATE queries 
                            SET sql_content = ?, file_hash = ?, updated_at = ?
                            WHERE id = ?
                        ''', (metadata.sql_content, metadata.file_hash, metadata.updated_at, metadata.id))
                        self.conn.commit()
                        
                        # Atualizar timestamp
                        self._file_timestamps[file_path] = current_timestamp
        
        return modified_queries
    
    def get_stats(self) -> Dict[str, Any]:
        """
        Retorna estatísticas do sistema de queries
        
        Returns:
            Dicionário com estatísticas
        """
        cursor = self.conn.cursor()
        
        # Total de queries
        cursor.execute('SELECT COUNT(*) as total FROM queries')
        total = cursor.fetchone()['total']
        
        # Queries por categoria
        cursor.execute('''
            SELECT category, COUNT(*) as count 
            FROM queries 
            GROUP BY category
        ''')
        by_category = {row['category']: row['count'] for row in cursor.fetchall()}
        
        # Última atualização
        cursor.execute('SELECT MAX(updated_at) as last_update FROM queries')
        last_update = cursor.fetchone()['last_update']
        
        return {
            'total_queries': total,
            'queries_by_category': by_category,
            'last_update': last_update,
            'queries_directory': self.queries_dir
        }
    
    def close(self):
        """Fecha a conexão com o banco de dados"""
        if self.conn:
            self.conn.close()

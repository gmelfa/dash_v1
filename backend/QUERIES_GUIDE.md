# Guia de Gerenciamento de Queries

## 📁 Estrutura do Sistema

O sistema de queries foi projetado para ser escalável e fácil de manter. Todas as queries são armazenadas no arquivo `queries.json`.

## 📝 Formato de uma Query

```json
{
  "id": "query_001",              // ID único (obrigatório)
  "title": "Nome da Query",       // Título exibido no frontend (obrigatório)
  "description": "Descrição",     // Descrição detalhada (opcional)
  "category": "Categoria",        // Categoria para agrupamento (opcional)
  "query": "SELECT * FROM...",    // SQL da query (obrigatório)
  "active": true,                 // Se a query está ativa (opcional, padrão: true)
  "created_at": "2025-11-19"     // Data de criação (opcional)
}
```

## 🔧 Como Adicionar Queries

### Método 1: Editar o arquivo JSON diretamente

Abra `backend/queries.json` e adicione novas queries no array:

```json
[
  {
    "id": "vendas_001",
    "title": "Vendas por Região",
    "description": "Relatório de vendas agrupadas por região",
    "category": "Vendas",
    "query": "SELECT regiao, SUM(valor) as total FROM vendas GROUP BY regiao",
    "active": true,
    "created_at": "2025-11-19"
  },
  {
    "id": "vendas_002",
    "title": "Top 10 Produtos",
    "description": "Os 10 produtos mais vendidos",
    "category": "Vendas",
    "query": "SELECT produto, COUNT(*) as vendas FROM vendas GROUP BY produto ORDER BY vendas DESC LIMIT 10",
    "active": true,
    "created_at": "2025-11-19"
  }
]
```

### Método 2: Usar a API

**Adicionar nova query:**
```bash
POST http://localhost:5000/api/queries
Content-Type: application/json

{
  "id": "vendas_003",
  "title": "Vendas Mensal",
  "description": "Vendas por mês",
  "category": "Vendas",
  "query": "SELECT MONTH(data) as mes, SUM(valor) FROM vendas GROUP BY MONTH(data)"
}
```

**Atualizar query existente:**
```bash
PUT http://localhost:5000/api/queries/vendas_003
Content-Type: application/json

{
  "title": "Vendas Mensais Atualizadas",
  "active": false
}
```

**Deletar query:**
```bash
DELETE http://localhost:5000/api/queries/vendas_003
```

## 🎯 Endpoints Disponíveis

### Listar todas as queries
```
GET /api/queries
GET /api/queries?active_only=true                    // Apenas ativas
GET /api/queries?group_by_category=true              // Agrupadas por categoria
```

### Obter query específica
```
GET /api/queries/{query_id}
```

### Executar query
```
POST /api/queries/{query_id}/execute
```

### Adicionar query
```
POST /api/queries
```

### Atualizar query
```
PUT /api/queries/{query_id}
```

### Deletar query
```
DELETE /api/queries/{query_id}
```

## 💡 Recomendações para Organização

### Convenção de IDs (para 100+ queries):

```
{categoria}_{numero}_{subcategoria}

Exemplos:
- vendas_001_regiao
- vendas_002_produto
- vendas_003_periodo
- estoque_001_geral
- estoque_002_baixo
- financeiro_001_receitas
- financeiro_002_despesas
```

### Categorias Sugeridas:

- **Vendas**: Relatórios de vendas
- **Estoque**: Controle de estoque
- **Financeiro**: Receitas, despesas, fluxo de caixa
- **Clientes**: Análises de clientes
- **Produtos**: Análises de produtos
- **RH**: Recursos humanos
- **Operacional**: Operações diárias
- **Estratégico**: Análises estratégicas

### Exemplo de queries.json bem organizado:

```json
[
  {
    "id": "vendas_001_por_regiao",
    "title": "Vendas por Região",
    "description": "Total de vendas agrupadas por região geográfica",
    "category": "Vendas",
    "query": "SELECT * FROM sua_view_vendas_regiao",
    "active": true,
    "created_at": "2025-11-19"
  },
  {
    "id": "vendas_002_top_produtos",
    "title": "Top 10 Produtos Mais Vendidos",
    "description": "Ranking dos produtos com maior volume de vendas",
    "category": "Vendas",
    "query": "SELECT * FROM sua_view_top_produtos",
    "active": true,
    "created_at": "2025-11-19"
  },
  {
    "id": "estoque_001_baixo",
    "title": "Produtos com Estoque Baixo",
    "description": "Produtos que estão abaixo do nível mínimo de estoque",
    "category": "Estoque",
    "query": "SELECT * FROM sua_view_estoque_baixo",
    "active": true,
    "created_at": "2025-11-19"
  }
]
```

## 🚀 Próximos Passos

1. Me envie a primeira query completa
2. Eu vou formatá-la e adicioná-la ao sistema
3. Você pode testar executando-a pelo frontend
4. Depois podemos adicionar as demais queries

Quando você tiver as 100+ queries, podemos:
- Importar de um CSV/Excel
- Criar script de migração em lote
- Adicionar busca e filtros no frontend

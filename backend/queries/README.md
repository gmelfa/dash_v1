# Queries Directory

Este diretório contém todas as queries SQL do sistema, organizadas por categoria.

## Estrutura

```
queries/
├── financeiro/          # Queries de análises financeiras
├── diretorias/          # Queries de diretorias corporativas
└── README.md           # Este arquivo
```

## Como Adicionar uma Nova Query

### 1. Escolha a Categoria

Crie ou escolha uma pasta de categoria apropriada. Exemplos:
- `financeiro/` - Análises financeiras, resultados, ROL, EBITDA
- `diretorias/` - Despesas e análises de diretorias
- `operacional/` - Métricas operacionais
- `estrategico/` - Análises estratégicas

### 2. Crie o Arquivo SQL

Crie um arquivo `.sql` com nome descritivo (use snake_case):
- ✅ Bom: `resultado_10_2025.sql`, `analise_custos_q1.sql`
- ❌ Ruim: `query1.sql`, `temp.sql`

### 3. Adicione Metadados no Cabeçalho

**Obrigatório:** Adicione comentários especiais no topo do arquivo:

```sql
-- @id: nome_unico_da_query
-- @name: Nome Legível da Query
-- @description: Descrição detalhada do que a query faz
-- @category: categoria
-- @tags: tag1, tag2, tag3

-- Sua query SQL aqui
SELECT ...
```

**Campos:**
- `@id`: Identificador único (será prefixado com a categoria automaticamente)
- `@name`: Nome amigável exibido na interface
- `@description`: Descrição do propósito da query
- `@category`: Categoria (nome da pasta)
- `@tags`: Tags separadas por vírgula para busca

**Exemplo Completo:**

```sql
-- @id: resultado_mensal_2025
-- @name: Resultado Mensal 2025
-- @description: Análise mensal de resultados financeiros consolidados
-- @category: financeiro
-- @tags: financeiro, mensal, 2025, resultado

WITH dados_mensais AS (
  SELECT 
    MONTH(data) as mes,
    SUM(valor) as total
  FROM financeiro.prd.f_resultado
  WHERE YEAR(data) = 2025
  GROUP BY MONTH(data)
)
SELECT * FROM dados_mensais
ORDER BY mes
```

### 4. Sistema Carrega Automaticamente

Após salvar o arquivo:
1. O sistema detecta automaticamente o novo arquivo
2. Extrai os metadados do cabeçalho
3. Adiciona ao cache SQLite
4. Query fica disponível na API imediatamente

## Convenções de Nomenclatura

### Arquivos
- Use `snake_case` (letras minúsculas com underscores)
- Seja descritivo: `analise_roi_trimestral.sql` é melhor que `query3.sql`
- Evite caracteres especiais e acentos

### IDs de Queries
- Serão automaticamente prefixados com a categoria
- Exemplo: arquivo `resultado_10_2025.sql` na pasta `financeiro/` vira ID `financeiro/resultado_10_2025`
- Use IDs únicos e descritivos

### Categorias (Pastas)
- Use nomes simples e claros
- Evite subcategorias profundas (máximo 1 nível)
- Exemplos: `financeiro`, `diretorias`, `operacional`, `rh`

## Boas Práticas

### 1. Documente sua Query
Adicione comentários explicando a lógica:

```sql
-- @id: exemplo
-- @name: Exemplo
-- @description: Query de exemplo
-- @category: financeiro
-- @tags: exemplo

-- ==========================================================
-- 1. FONTE DE DADOS
-- ==========================================================
WITH fonte AS (
  -- Busca dados da tabela principal
  SELECT * FROM tabela
  WHERE condicao = true
),

-- ==========================================================
-- 2. TRANSFORMAÇÕES
-- ==========================================================
transformado AS (
  -- Aplica transformações necessárias
  SELECT coluna1, SUM(coluna2) as total
  FROM fonte
  GROUP BY coluna1
)

-- Resultado final
SELECT * FROM transformado
```

### 2. Use CTEs (Common Table Expressions)
- Facilita leitura e manutenção
- Separe lógica em blocos nomeados
- Adicione comentários explicativos

### 3. Teste Antes de Commitar
```bash
# Teste a query no Databricks primeiro
# Depois adicione ao sistema
```

### 4. Mantenha Queries Focadas
- Uma query = um propósito específico
- Evite queries gigantes que fazem múltiplas coisas
- Se necessário, crie queries separadas

## Ferramentas de Linha de Comando

### Listar Queries
```bash
python query_cli.py list
python query_cli.py list --category financeiro
```

### Buscar Queries
```bash
python query_cli.py search "resultado"
```

### Recarregar Cache
```bash
python query_cli.py reload
```

### Ver Estatísticas
```bash
python query_cli.py stats
```

## Hot Reload

O sistema detecta automaticamente mudanças nos arquivos:
- Edite qualquer arquivo `.sql`
- Salve o arquivo
- Aguarde ~2 segundos
- Query atualizada estará disponível automaticamente

## Troubleshooting

### Query não aparece na lista
1. Verifique se o arquivo tem extensão `.sql`
2. Confirme que os metadados estão corretos
3. Execute `python query_cli.py reload`

### Erro ao carregar query
1. Verifique sintaxe SQL
2. Confirme que metadados estão no formato correto
3. Veja logs do servidor para detalhes

### Performance lenta
1. Otimize a query SQL (índices, filtros)
2. Considere adicionar cache de resultados
3. Revise plano de execução no Databricks

## Suporte

Para dúvidas ou problemas:
1. Consulte a documentação do sistema
2. Verifique exemplos nas queries existentes
3. Entre em contato com a equipe de desenvolvimento

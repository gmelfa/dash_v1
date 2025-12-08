# Instruções para Implementar Novo Batch Export

## Passo 1: Backend

1. Abra `backend/app.py`
2. Adicione no topo (com os outros imports):
```python
from export_batch_images import export_batch_bp
```

3. Adicione após a linha onde registra outros blueprints (procure por `app.register_blueprint`):
```python
app.register_blueprint(export_batch_bp)
```

4. Salve o arquivo
5. Reinicie o backend (`python app.py`)

## Passo 2: Frontend

1. Abra `frontend/src/App.jsx`
2. Localize a função `exportMultipleQueriesPPT` (deve estar por volta da linha 131)
3. Substitua TODA a função pela versão do arquivo `batch_export_function.js`
4. Salve o arquivo
5. O frontend deve recarregar automaticamente

## Passo 3: Testar

1. Selecione 2-3 queries no modo de exportação em lote
2. Clique em "Exportar"
3. Aguarde o processamento (vai mostrar alertas de progresso)
4. Verifique se o PowerPoint foi baixado
5. Abra o PowerPoint e verifique:
   - Slide de capa está presente
   - Cada query tem seu slide com imagem da tabela
   - Imagens não são editáveis

## Notas Importantes

- O processo será mais lento (precisa executar cada query e capturar screenshot)
- Para 100 queries, pode levar 5-10 minutos
- Alertas mostrarão o progresso
- Se alguma query falhar, as outras continuarão

## Arquivos Criados

- `backend/export_batch_images.py` - Novo endpoint de batch export
- `frontend/batch_export_function.js` - Nova função JavaScript

## Se Algo Der Errado

- Verifique o console do navegador (F12)
- Verifique os logs do backend
- Restaure os arquivos originais com `git restore`

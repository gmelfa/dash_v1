import { useMemo } from 'react'
import {
  useReactTable,
  getCoreRowModel,
  getSortedRowModel,
  getFilteredRowModel,
  flexRender,
} from '@tanstack/react-table'
import './database.css'

function Database({ columns, data }) {
  const visibleColumnsNames = useMemo(() => {
    // Remove sort_order, id e limita a 19 colunas para evitar quebra de layout
    const cleanCols = columns.filter(col =>
      col !== 'sort_order' &&
      col !== 'sort_order ' &&
      col !== 'id'
    );
    return cleanCols.slice(0, 19);
  }, [columns]);

  const tableColumns = useMemo(
    () =>
      visibleColumnsNames.map((col, index) => {
        const isTextColumn = index === 0

        // Separadores de Grupo
        const isTableStart = index === 1 || index === 5 || index === 9 || index === 13 || index === 15 || index === 17

        // Lógica atualizada para pegar "Var" com ou sem ponto
        const isVariation = col.includes('Var')
        const isVariationPct = col.includes('Var %') || (isVariation && col.includes('%'))
        const isPercentage = col.includes('%') || isVariationPct

        return {
          accessorKey: col,
          header: () => {
            // 1. Separa o texto principal do que está entre parênteses
            // Ex: "ALUNOS (10M24 R)" -> "(10M24 R)" em cima e "ALUNOS" embaixo
            const parts = col.split(' (')
            if (parts.length === 2 && parts[1].endsWith(')')) {
              const mainText = parts[0]
              const subText = '(' + parts[1]

              return (
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', lineHeight: '1.1' }}>
                  <span style={{ fontSize: '0.85em', opacity: 0.9, marginBottom: '2px', whiteSpace: 'nowrap' }}>{subText}</span>
                  <span style={{ whiteSpace: 'nowrap' }}>{mainText}</span>
                </div>
              )
            }

            // 2. Lógica para colunas de Variação (Var) - Case Insensitive
            // Ex: "Var Alunos" -> "Var" em cima e "Alunos" embaixo
            if (col.toLowerCase().startsWith('var ')) {
              let mainText = '';
              let subText = '';

              // Normalizar prefixo para exibição
              // Se quiser manter o case original do prefixo, usar substring. 
              // Aqui vou forçar "VAR" ou "VAR %" conforme pedido, ou manter "Var" se preferir.
              // O usuário pediu "VAR em cima", então vou forçar UpperCase no subText se for Var simples

              const isPercent = col.toLowerCase().startsWith('var % ') || col.includes('%');

              if (isPercent) {
                subText = 'VAR %';
                // Remove "Var % " ou "VAR % " do início
                mainText = col.replace(/var % /i, '').replace(/var %/i, '');
              } else {
                subText = 'VAR';
                mainText = col.replace(/var /i, '');
              }

              return (
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', lineHeight: '1.1' }}>
                  <span style={{ fontSize: '0.85em', opacity: 0.9, marginBottom: '2px', whiteSpace: 'nowrap' }}>{subText}</span>
                  <span style={{ whiteSpace: 'nowrap' }}>{mainText}</span>
                </div>
              )
            }

            return col
          },
          cell: (info) => {
            const value = info.getValue()
            // Se for nulo, retorna traço
            if (value === null || value === undefined || value === '') return '-'

            const numValue = typeof value === 'number' ? value : parseFloat(String(value).replace(/,/g, ''))

            if (!isNaN(numValue)) {
              let displayValue = numValue;
              let suffix = '';
              let minFrac = 0;
              let maxFrac = 0;

              if (isPercentage) {
                // Porcentagem
                displayValue = numValue;
                suffix = '%';
                minFrac = 1;
                maxFrac = 1;
              } else {
                // Valores já vêm formatados das queries (já divididos por 1000 quando necessário)
                displayValue = numValue;
              }

              const formatted = displayValue.toLocaleString('pt-BR', {
                minimumFractionDigits: minFrac,
                maximumFractionDigits: maxFrac,
              })

              return <span>{formatted}{suffix}</span>
            }
            return value
          },
          meta: {
            className: `
                ${isTableStart ? 'table-separator' : ''} 
                ${isTextColumn ? 'text-left' : (index >= 13 ? 'text-center' : 'text-right')}
            `
          }
        }
      }),
    [visibleColumnsNames]
  )

  const table = useReactTable({
    data,
    columns: tableColumns,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    initialState: { columnFilters: [] },
  })

  const filteredRows = table.getRowModel().rows.filter((row) => {
    const vertical = row.original.Vertical || row.original.vertical || row.original.Diretoria || ''
    return vertical !== 'Maple Bear Escolas Próprias'
  })

  return (
    <div className="data-table-container">
      <div className="table-wrapper">
        <table className="data-table">
          <thead>
            <tr>
              {table.getHeaderGroups()[0].headers.map((header) => (
                <th key={header.id} className={header.column.columnDef.meta?.className || ''}>
                  {flexRender(header.column.columnDef.header, header.getContext())}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {filteredRows.map((row) => {
              const vertical = row.original.Vertical || row.original.vertical || row.original.Diretoria || ''
              const isSubtotal = vertical.includes('Operações') || vertical.includes('Total') || vertical.includes('Corporativas')
              return (
                <tr key={row.id} className={isSubtotal ? 'subtotal-row' : ''}>
                  {row.getVisibleCells().map((cell) => (
                    <td key={cell.id} className={cell.column.columnDef.meta?.className || ''}>
                      {flexRender(cell.column.columnDef.cell, cell.getContext())}
                    </td>
                  ))}
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>
    </div>
  )
}

export default Database
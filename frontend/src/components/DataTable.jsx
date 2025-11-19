import { useMemo } from 'react'
import {
  useReactTable,
  getCoreRowModel,
  getSortedRowModel,
  getFilteredRowModel,
  flexRender,
} from '@tanstack/react-table'
import './DataTable.css'

function DataTable({ columns, data }) {
  const tableColumns = useMemo(
    () =>
      columns.map((col, index) => {
        // Remover período entre parênteses (ex: "(10M24 R)" -> "")
        const cleanHeader = col.replace(/\s*\([^)]*\)/g, '').trim()
        
        // Identificar colunas que iniciam cada grupo de tabela
        // Coluna 1 (índice 0): Vertical - sem borda
        // Coluna 2 (índice 1): Alunos (10M24 R) - com borda (primeira tabela, após Vertical)
        // Coluna 6 (índice 5): Alunos (10M25 F) - com borda (segunda tabela, 4 colunas por período)
        // Coluna 10 (índice 9): Alunos (10M25 R) - com borda (terceira tabela, 4 colunas por período)
        const isTableStart = index === 1 || index === 5 || index === 9
        
        return {
          accessorKey: col,
          header: cleanHeader,
          cell: (info) => {
            const value = info.getValue()
            // Verificar se é coluna de %Ebtida ou Alunos
            const isPercentageColumn = col.includes('%Ebtida')
            const isAlunosColumn = col.includes('Alunos')
            
            // Formatar números com separador de milhares usando ponto
            // Verificar se é número ou string numérica
            if (value !== null && value !== undefined && value !== '') {
              const numValue = typeof value === 'number' ? value : parseFloat(String(value).replace(/,/g, ''))
              if (!isNaN(numValue)) {
                // Dividir por mil e arredondar, exceto colunas Alunos e %Ebtida
                const displayValue = (isPercentageColumn || isAlunosColumn) ? numValue : Math.round(numValue / 1000)
                const formatted = displayValue.toLocaleString('de-DE')
                return isPercentageColumn ? `${formatted}%` : formatted
              }
            }
            return value
          },
          meta: {
            className: isTableStart ? 'table-separator' : ''
          }
        }
      }),
    [columns]
  )

  const table = useReactTable({
    data,
    columns: tableColumns,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    initialState: {
      columnFilters: [],
    },
  })

  // Filtrar dados para remover "Maple Bear Escolas Próprias"
  const filteredRows = table.getRowModel().rows.filter((row) => {
    const vertical = row.original.Vertical || row.original.vertical || ''
    return vertical !== 'Maple Bear Escolas Próprias'
  })

  return (
    <div className="data-table-container">
      <div className="table-wrapper">
        <table className="data-table">
          <thead>
            {/* Linha de cabeçalho com os períodos */}
            <tr className="period-header">
              <th rowSpan="2" className="vertical-header">Vertical</th>
              <th colSpan="4" className="period-group table-separator">10M24 R</th>
              <th colSpan="4" className="period-group table-separator">10M25 F</th>
              <th colSpan="4" className="period-group table-separator">10M25 R</th>
            </tr>
            {/* Linha de cabeçalho com os nomes das colunas */}
            {table.getHeaderGroups().map((headerGroup) => (
              <tr key={headerGroup.id}>
                {headerGroup.headers.map((header, index) => {
                  // Pular a primeira coluna (Vertical) pois já foi renderizada com rowSpan
                  if (index === 0) return null
                  
                  return (
                    <th key={header.id} className={header.column.columnDef.meta?.className || ''}>
                      {header.isPlaceholder ? null : (
                        <div>
                          {flexRender(
                            header.column.columnDef.header,
                            header.getContext()
                          )}
                        </div>
                      )}
                    </th>
                  )
                })}
              </tr>
            ))}
          </thead>
          <tbody>
            {filteredRows.map((row) => {
              // Identificar linhas de subtotal
              const vertical = row.original.Vertical || row.original.vertical || ''
              const isSubtotal = vertical.includes('Operações Premium') || 
                                 vertical.includes('Total Estratégico') || 
                                 vertical.includes('Total Op. Premium')
              
              return (
                <tr key={row.id} className={isSubtotal ? 'subtotal-row' : ''}>
                  {row.getVisibleCells().map((cell) => (
                    <td key={cell.id} className={cell.column.columnDef.meta?.className || ''}>
                      {flexRender(
                        cell.column.columnDef.cell,
                        cell.getContext()
                      )}
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

export default DataTable

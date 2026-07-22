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
        const isTableStart = index === 1 || index === 5 || index === 9 || index === 13 || index === 15 || index === 17

        // Detecção Automática de Porcentagem
        const isPercentage = col.includes('%') || col.toLowerCase().includes('pct')

        // [CORREÇÃO] Detecção da coluna de Alunos
        const isAlunos = col.toLowerCase().includes('alunos')

        return {
          id: col,
          // accessorFn (não accessorKey) — accessorKey trata "." no nome da coluna
          // como separador de caminho aninhado (ex: "Var.|26 x Bgt" virava
          // row["Var"]["|26 x Bgt"]), retornando undefined pra qualquer nome
          // de coluna com ponto
          accessorFn: (row) => row[col],
          header: () => {
            // --- REGRA MESTRA: SEPARADOR PIPE (|) ---
            if (col.includes('|')) {
              const parts = col.split('|')
              const topText = parts[0].replace('Pct', '%')
              const bottomText = parts.slice(1).join(' ')

              return (
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', lineHeight: '1.1' }}>
                  <span style={{ fontSize: '0.85em', opacity: 0.9, marginBottom: '2px', whiteSpace: 'nowrap' }}>{topText}</span>
                  <span style={{ whiteSpace: 'nowrap' }}>{bottomText}</span>
                </div>
              )
            }

            // --- REGRA LEGADA 1: Texto entre parênteses ---
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

            // --- REGRA LEGADA 2: Colunas Var antigas ---
            if (col.toLowerCase().startsWith('var')) {
              const isPercent = col.includes('%') || col.toLowerCase().includes('pct');
              const subText = isPercent ? 'VAR %' : 'VAR';
              const mainText = col
                .replace(/^var\s*%\s*/i, '')
                .replace(/^var\s+/i, '')
                .trim();

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
            if (value === null || value === undefined || value === '') return '-'

            // Coluna de descrição é sempre texto — nunca tentar formatar como número
            // (ex: "13º Salário" não pode virar "13" só porque começa com dígito)
            if (isTextColumn) return value

            const numValue = typeof value === 'number' ? value : parseFloat(String(value).replace(/,/g, ''))

            const firstColKey = visibleColumnsNames[0];
            const firstColValue = String(info.row.original[firstColKey] || '').toLowerCase();
            const isMargemRow = firstColValue.includes('margem');

            if (!isNaN(numValue)) {
              let displayValue = numValue;
              let suffix = '';
              let minFrac = 0;
              let maxFrac = 0;

              // Lógica de Formatação Numérica
              if (isPercentage) {
                displayValue = numValue;
                suffix = '%';
                minFrac = 1;
                maxFrac = 1;
              } else if (isMargemRow) {
                displayValue = numValue;
                suffix = '%';
                minFrac = 1;
                maxFrac = 1;
              } else {
                // Para financeiro e outros inteiros (incluindo Alunos agora)
                displayValue = numValue;
                minFrac = 0;
                maxFrac = 0;
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

              // Detecta linhas de cabeçalho de seção (Histórico, Forecast, Realizado)
              const firstColValue = String(row.original[visibleColumnsNames[0]] || '')
              const isSectionHeader = firstColValue.startsWith('Histórico') || firstColValue.startsWith('Forecast') || firstColValue === 'Realizado' || firstColValue.startsWith('Variação')

              let rowClass = ''
              if (isSectionHeader) rowClass = 'section-header-row'
              else if (isSubtotal) rowClass = 'subtotal-row'

              return (
                <tr key={row.id} className={rowClass}>
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
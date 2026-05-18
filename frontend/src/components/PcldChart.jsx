import {
  ComposedChart, Bar, Line, XAxis, YAxis, CartesianGrid,
  Tooltip, Legend, ReferenceLine, ResponsiveContainer, LabelList
} from 'recharts'

const MESES_ABREV = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez']

function formatVal(v) {
  if (v == null) return ''
  return v.toLocaleString('pt-BR')
}

export default function PcldChart({ data, anoAtual, anoAnterior }) {
  if (!data || data.length === 0) return null

  const chartData = data.map(row => ({
    mes: MESES_ABREV[(row.mes ?? 1) - 1],
    [`${anoAnterior}R`]: row.val_ant_r ?? 0,
    [`${anoAtual}F`]:    row.val_atu_f ?? 0,
    [`${anoAtual}R`]:    row.val_atu_r ?? null,
  }))

  const keyAntR = `${anoAnterior}R`
  const keyAtuF = `${anoAtual}F`
  const keyAtuR = `${anoAtual}R`

  return (
    <div style={{ width: '100%', marginTop: 32 }}>
      <ResponsiveContainer width="100%" height={340}>
        <ComposedChart data={chartData} margin={{ top: 24, right: 24, left: 16, bottom: 8 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" vertical={false} />
          <XAxis dataKey="mes" tick={{ fontSize: 12, fill: '#64748b' }} axisLine={false} tickLine={false} />
          <YAxis tick={{ fontSize: 11, fill: '#64748b' }} axisLine={false} tickLine={false}
            tickFormatter={v => v.toLocaleString('pt-BR')} />
          <Tooltip
            formatter={(value, name) => [value != null ? value.toLocaleString('pt-BR') : '–', name]}
            contentStyle={{ fontSize: 12, borderRadius: 6, border: '1px solid #e2e8f0' }}
          />
          <Legend wrapperStyle={{ fontSize: 12, paddingTop: 8 }} />
          <ReferenceLine y={0} stroke="#94a3b8" strokeWidth={1} />

          {/* Barras: Resultado ano atual (só meses realizados) */}
          <Bar dataKey={keyAtuR} fill="#334155" radius={[3, 3, 0, 0]} maxBarSize={48}>
            <LabelList dataKey={keyAtuR} position="top"
              formatter={v => v != null ? v.toLocaleString('pt-BR') : ''}
              style={{ fontSize: 10, fill: '#334155' }} />
          </Bar>

          {/* Linha: Resultado ano anterior */}
          <Line dataKey={keyAntR} stroke="#dc2626" strokeWidth={2} dot={{ r: 3, fill: '#dc2626' }}
            type="monotone" connectNulls>
            <LabelList dataKey={keyAntR} position="top"
              formatter={formatVal}
              style={{ fontSize: 9, fill: '#dc2626' }} />
          </Line>

          {/* Linha: Forecast ano atual */}
          <Line dataKey={keyAtuF} stroke="#94a3b8" strokeWidth={1.5}
            strokeDasharray="4 3" dot={{ r: 3, fill: '#94a3b8' }}
            type="monotone" connectNulls>
            <LabelList dataKey={keyAtuF} position="top"
              formatter={formatVal}
              style={{ fontSize: 9, fill: '#94a3b8' }} />
          </Line>
        </ComposedChart>
      </ResponsiveContainer>
    </div>
  )
}

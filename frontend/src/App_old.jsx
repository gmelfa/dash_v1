import { useState, useEffect } from 'react'
import axios from 'axios'
import './App.css'
import DataTable from './components/DataTable'

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000/api'

function App() {
  const [tableData, setTableData] = useState(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const [savedQueries, setSavedQueries] = useState([])
  const [selectedQuery, setSelectedQuery] = useState(null)
  const [loadingQueries, setLoadingQueries] = useState(true)
  const [isSidebarOpen, setIsSidebarOpen] = useState(true)

  // Carregar queries salvas ao montar o componente
  useEffect(() => {
    loadSavedQueries()
  }, [])

  const loadSavedQueries = async () => {
    try {
      setLoadingQueries(true)
      const response = await axios.get(`${API_URL}/queries?active_only=true`)
      setSavedQueries(response.data.queries)
    } catch (err) {
      console.error('Erro ao carregar queries:', err)
    } finally {
      setLoadingQueries(false)
    }
  }

  const executeSavedQuery = async (queryId) => {
    setLoading(true)
    setError(null)
    setTableData(null)
    
    try {
      const response = await axios.post(`${API_URL}/queries/${queryId}/execute`)
      setTableData(response.data)
      setSelectedQuery(queryId)
    } catch (err) {
      setError(err.response?.data?.error || 'Erro ao executar a query')
      console.error('Erro:', err)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="app">
      <header className="app-header">
        <div className="header-content">
          <button 
            className="sidebar-toggle" 
            onClick={() => setIsSidebarOpen(!isSidebarOpen)}
            title={isSidebarOpen ? "Ocultar sumário" : "Mostrar sumário"}
          >
            {isSidebarOpen ? '◀' : '▶'}
          </button>
          <h1>Dashboard Databricks</h1>
        </div>
      </header>

      <main className="app-main">
        <div className={`queries-grid ${isSidebarOpen ? '' : 'sidebar-closed'}`}>
          {/* Lista de Queries Salvas */}
          <aside className={`saved-queries-panel ${isSidebarOpen ? 'open' : 'closed'}`}>
            <h2>Sumário</h2>
            {loadingQueries ? (
              <p className="loading-text">Carregando queries...</p>
            ) : savedQueries.length === 0 ? (
              <p className="empty-text">Nenhuma query disponível</p>
            ) : (
              <div className="queries-list">
                {savedQueries.map((q, index) => (
                  <button
                    key={q.id}
                    onClick={() => executeSavedQuery(q.id)}
                    className={`query-item ${selectedQuery === q.id ? 'active' : ''}`}
                    disabled={loading}
                  >
                    <span className="query-number">{index + 1}.</span>
                    <span className="query-item-title">{q.title}</span>
                  </button>
                ))}
              </div>
            )}
          </aside>

          {/* Área de Resultados */}
          <div className="main-content">
            {error && (
              <div className="error-message">
                <strong>Erro:</strong> {error}
              </div>
            )}

            {loading && (
              <div className="loading-section">
                <p>Executando query...</p>
              </div>
            )}

            {tableData && (
              <div className="results-section">
                <div className="results-header">
                  <div>
                    <h2>{tableData.title || 'Resultados'}</h2>
                  </div>
                  <span className="row-count">
                    {tableData.rowCount} linha(s) retornada(s)
                  </span>
                </div>
                
                <DataTable 
                  columns={tableData.columns} 
                  data={tableData.data}
                />
              </div>
            )}
          </div>
        </div>
      </main>
    </div>
  )
}

export default App

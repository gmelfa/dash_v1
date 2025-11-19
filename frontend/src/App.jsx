import { useState, useEffect } from 'react'
import axios from 'axios'
import { AuthProvider, useAuth } from './contexts/AuthContext'
import Login from './components/Auth/Login'
import Register from './components/Auth/Register'
import DataTable from './components/DataTable'
import CommentsSection from './components/Comments/CommentsSection'
import './App.css'

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000'

function AppContent() {
  const { user, loading: authLoading, logout } = useAuth()
  const [showAuth, setShowAuth] = useState('login')
  const [tableData, setTableData] = useState(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const [savedQueries, setSavedQueries] = useState([])
  const [selectedQuery, setSelectedQuery] = useState(null)
  const [loadingQueries, setLoadingQueries] = useState(true)
  const [isSidebarOpen, setIsSidebarOpen] = useState(true)
  const [selectedQueriesForExport, setSelectedQueriesForExport] = useState(new Set())
  const [isExportMode, setIsExportMode] = useState(false)

  // Carregar queries salvas ao montar o componente
  useEffect(() => {
    loadSavedQueries()
  }, [])

  const loadSavedQueries = async () => {
    try {
      setLoadingQueries(true)
      const response = await axios.get(`${API_URL}/api/queries?active_only=true`)
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
      const response = await axios.post(`${API_URL}/api/queries/${queryId}/execute`)
      setTableData(response.data)
      setSelectedQuery(queryId)
    } catch (err) {
      setError(err.response?.data?.error || 'Erro ao executar a query')
      console.error('Erro:', err)
    } finally {
      setLoading(false)
    }
  }

  const showCoverPage = () => {
    setTableData(null)
    setSelectedQuery('cover')
    setError(null)
  }

  const exportDevelopmentPPT = async () => {
    if (!tableData || !selectedQuery) {
      alert('Selecione uma query primeiro')
      return
    }

    try {
      // Capturar screenshot da tabela
      const html2canvas = (await import('html2canvas')).default
      const tableElement = document.querySelector('.data-table-container')
      
      if (!tableElement) {
        alert('Tabela não encontrada')
        return
      }

      const canvas = await html2canvas(tableElement, {
        scale: 2,
        backgroundColor: '#ffffff',
        logging: false
      })

      // Converter para blob
      const blob = await new Promise(resolve => {
        canvas.toBlob(resolve, 'image/png')
      })

      // Criar FormData
      const formData = new FormData()
      formData.append('query_id', selectedQuery)
      formData.append('query_title', tableData.title)
      formData.append('table_image', blob, 'table.png')

      // Enviar para backend
      const response = await axios.post(
        `${API_URL}/api/export/pptx/development`,
        formData,
        {
          responseType: 'blob',
          withCredentials: true
        }
      )

      // Download do arquivo
      const url = window.URL.createObjectURL(new Blob([response.data]))
      const link = document.createElement('a')
      link.href = url
      link.setAttribute('download', `${selectedQuery}_development.pptx`)
      document.body.appendChild(link)
      link.click()
      link.remove()
    } catch (err) {
      console.error('Erro ao exportar:', err)
    }
  }

  const toggleQuerySelection = (queryId) => {
    const newSelected = new Set(selectedQueriesForExport)
    if (newSelected.has(queryId)) {
      newSelected.delete(queryId)
    } else {
      newSelected.add(queryId)
    }
    setSelectedQueriesForExport(newSelected)
  }

  const exportMultipleQueriesPPT = async () => {
    if (selectedQueriesForExport.size === 0) {
      alert('Selecione pelo menos uma query para exportar')
      return
    }

    try {
      setLoading(true)
      const queryIds = Array.from(selectedQueriesForExport)
      
      console.log('Enviando requisição de batch export:', queryIds)
      
      const response = await axios.post(
        `${API_URL}/api/export/pptx/batch`,
        { query_ids: queryIds },
        {
          responseType: 'blob',
          withCredentials: true
        }
      )

      console.log('Resposta recebida:', response.status, response.headers['content-type'])

      // Download do arquivo
      const url = window.URL.createObjectURL(new Blob([response.data]))
      const link = document.createElement('a')
      link.href = url
      link.setAttribute('download', `export_batch_${new Date().getTime()}.pptx`)
      document.body.appendChild(link)
      link.click()
      link.remove()

      console.log('Download iniciado com sucesso')

      // Limpar seleção
      setSelectedQueriesForExport(new Set())
      setIsExportMode(false)
    } catch (err) {
      console.error('Erro detalhado ao exportar lote:', err)
      console.error('Response:', err.response)
      console.error('Status:', err.response?.status)
      console.error('Data:', err.response?.data)
      
      // Se a resposta é um blob de erro, vamos ler
      if (err.response?.data instanceof Blob) {
        const text = await err.response.data.text()
        console.error('Erro do servidor:', text)
        alert(`Erro ao exportar: ${text}`)
      } else {
        alert(`Erro ao exportar múltiplas tabelas: ${err.message}`)
      }
    } finally {
      setLoading(false)
    }
  }

  // Mostrar tela de login/registro se não estiver autenticado
  if (authLoading) {
    return (
      <div className="loading-screen">
        <div className="spinner"></div>
        <p>Carregando...</p>
      </div>
    )
  }

  if (!user) {
    return showAuth === 'login' ? (
      <Login
        onSwitchToRegister={() => setShowAuth('register')}
        onLoginSuccess={() => setShowAuth('login')}
      />
    ) : (
      <Register onSwitchToLogin={() => setShowAuth('login')} />
    )
  }

  return (
    <div className="app">
      <header className="app-header">
        <h1>Dashboard Databricks</h1>
        <div className="header-actions">
          <div className="user-info">
            <span className="welcome-message">Olá, {user.username}!</span>
            {user.is_admin && <span className="admin-badge">Admin</span>}
            <button onClick={logout} className="btn-logout">Sair</button>
          </div>
        </div>
      </header>

      <div className={`main-container ${isSidebarOpen ? 'sidebar-open' : 'sidebar-closed'}`}>
        {/* Botão de toggle quando sidebar está fechado */}
        {!isSidebarOpen && (
          <button
            className="sidebar-toggle-btn-floating"
            onClick={() => setIsSidebarOpen(true)}
            title="Expandir sumário"
          >
            ▶
          </button>
        )}
        
        <aside className={`sidebar ${isSidebarOpen ? 'open' : 'closed'}`}>
          <div className="sidebar-header">
            <h2>Sumário</h2>
            <div className="sidebar-controls">
              {isSidebarOpen && (
                <>
                  <button
                    className={`btn-export-mode ${isExportMode ? 'active' : ''}`}
                    onClick={() => {
                      setIsExportMode(!isExportMode)
                      if (!isExportMode) {
                        setSelectedQueriesForExport(new Set())
                      }
                    }}
                    title="Modo de exportação em lote"
                  >
                    📦
                  </button>
                  <button
                    className="sidebar-toggle-btn"
                    onClick={() => setIsSidebarOpen(false)}
                    title="Recolher"
                  >
                    ◀
                  </button>
                </>
              )}
            </div>
          </div>
          
          {isExportMode && (
            <div className="batch-export-controls">
              <div className="batch-info">
                {selectedQueriesForExport.size > 0 && (
                  <p>{selectedQueriesForExport.size} selecionada(s)</p>
                )}
              </div>
              <button
                onClick={() => {
                  setSelectedQueriesForExport(new Set(savedQueries.map(q => q.id)))
                }}
                className="btn-select-all"
              >
                Selecionar Todas
              </button>
              <button
                onClick={() => setSelectedQueriesForExport(new Set())}
                className="btn-clear-selection"
              >
                Limpar Seleção
              </button>
              <button
                onClick={exportMultipleQueriesPPT}
                disabled={selectedQueriesForExport.size === 0 || loading}
                className="btn-export-batch"
              >
                {loading ? 'Exportando...' : `Exportar (${selectedQueriesForExport.size})`}
              </button>
            </div>
          )}

          {loadingQueries ? (
            <div className="loading-queries">Carregando queries...</div>
          ) : (
            <ul className="query-list">
              <li
                key="cover"
                className={selectedQuery === 'cover' ? 'active' : ''}
                onClick={showCoverPage}
              >
                <span className="query-number">📄</span>
                <div className="query-info">
                  <div className="query-title">Capa - Business Review</div>
                  <div className="query-description">Página inicial do relatório</div>
                </div>
              </li>
              {savedQueries.map((query, index) => (
                <li
                  key={query.id}
                  className={`${selectedQuery === query.id ? 'active' : ''} ${isExportMode ? 'selectable' : ''}`}
                  onClick={() => {
                    if (isExportMode) {
                      toggleQuerySelection(query.id)
                    } else {
                      executeSavedQuery(query.id)
                    }
                  }}
                >
                  {isExportMode && (
                    <input
                      type="checkbox"
                      checked={selectedQueriesForExport.has(query.id)}
                      onChange={() => toggleQuerySelection(query.id)}
                      onClick={(e) => e.stopPropagation()}
                    />
                  )}
                  <span className="query-number">{isExportMode ? '' : `${index + 1}.`}</span>
                  <div className="query-info">
                    <div className="query-title">{query.title}</div>
                    {query.description && (
                      <div className="query-description">{query.description}</div>
                    )}
                  </div>
                </li>
              ))}
            </ul>
          )}
        </aside>

        <main className="main-content">
          {(!tableData && !loading && !error) || selectedQuery === 'cover' ? (
            <div className="cover-page">
              <div className="cover-header">
                <div className="cover-logo">
                  <div className="logo-text-grupo">GRUPO</div>
                  <div className="logo-text-seb">SEB</div>
                </div>
                <div className="confidencial-badge">Confidencial</div>
              </div>
              
              <div className="cover-content">
                <h1 className="cover-title">Business Review</h1>
                <h2 className="cover-subtitle">Finanças</h2>
                <h2 className="cover-subtitle">Resultado 10/2025 + Rolling Fcst</h2>
                <p className="cover-date">19 de novembro de 2025</p>
              </div>
            </div>
          ) : null}

          {loading && (
            <div className="loading-section">
              <div className="spinner"></div>
              <p>Executando query...</p>
            </div>
          )}

          {error && (
            <div className="error-message">
              <strong>Erro:</strong> {error}
            </div>
          )}

          {tableData && !loading && (
            <div className="results-section">
              <div className="results-header">
                <div>
                  <h2>{tableData.title}</h2>
                  {tableData.description && <p>{tableData.description}</p>}
                  <span className="row-count">{tableData.rowCount} linhas</span>
                </div>
                <div className="export-buttons">
                  <button onClick={exportDevelopmentPPT} className="btn-export-ppt">
                    📊 Exportar PPT
                  </button>
                </div>
              </div>
              
              <DataTable columns={tableData.columns} data={tableData.data} />
              
              <CommentsSection queryId={selectedQuery} />
            </div>
          )}
        </main>
      </div>
    </div>
  )
}

function App() {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  )
}

export default App

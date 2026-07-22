import { useState, useEffect } from 'react'
import axios from 'axios'
import { AuthProvider, useAuth } from './contexts/AuthContext'
import Login from './components/Auth/Login'
import Register from './components/Auth/Register'
import DataTable from './components/DataTable'
import CommentsSection from './components/Comments/CommentsSection'
import PcldChart from './components/PcldChart'
import './App.css'

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000'

const MESES = ['Janeiro','Fevereiro','Março','Abril','Maio','Junho',
               'Julho','Agosto','Setembro','Outubro','Novembro','Dezembro']

function useTheme() {
  const [theme, setThemeState] = useState(() => localStorage.getItem('theme') || 'light')

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme)
    localStorage.setItem('theme', theme)
  }, [theme])

  return [theme, setThemeState]
}

function getDefaultPeriod() {
  const now = new Date()
  const mes = now.getMonth() === 0 ? 12 : now.getMonth()          // getMonth() retorna 0-11
  const ano = now.getMonth() === 0 ? now.getFullYear() - 1 : now.getFullYear()
  return { mes, ano }
}

function CreateUserInline({ onCreateUser, allUsers, currentUserId, onToggleAdmin, onResetPassword }) {
  const [showForm, setShowForm] = useState(false)
  const [form, setForm] = useState({ username: '', email: '', password: '', is_admin: false })
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const [resetUserId, setResetUserId] = useState(null)
  const [resetPassword, setResetPasswordValue] = useState('')
  const [resetError, setResetError] = useState('')
  const [resetLoading, setResetLoading] = useState(false)

  const handleResetSubmit = async (e) => {
    e.preventDefault()
    setResetLoading(true)
    setResetError('')
    const err = await onResetPassword(resetUserId, resetPassword)
    setResetLoading(false)
    if (err) {
      setResetError(err)
    } else {
      setResetUserId(null)
      setResetPasswordValue('')
    }
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setLoading(true)
    setError('')
    const err = await onCreateUser(form)
    setLoading(false)
    if (err) {
      setError(err)
    } else {
      setForm({ username: '', email: '', password: '', is_admin: false })
      setShowForm(false)
    }
  }

  return (
    <>
      <button className="btn-new-user" onClick={() => setShowForm(v => !v)}>
        {showForm ? '✕ Cancelar' : 'Criar'}
      </button>

      {showForm && (
        <form className="create-user-form" onSubmit={handleSubmit}>
          {error && <p className="create-user-error">{error}</p>}
          <input
            type="text"
            placeholder="Usuário"
            value={form.username}
            onChange={e => setForm(f => ({ ...f, username: e.target.value }))}
            required
          />
          <input
            placeholder="Email"
            type="email"
            value={form.email}
            onChange={e => setForm(f => ({ ...f, email: e.target.value }))}
            required
          />
          <input
            placeholder="Senha"
            type="password"
            value={form.password}
            onChange={e => setForm(f => ({ ...f, password: e.target.value }))}
            required
          />
          <label className="create-user-admin-check">
            <input
              type="checkbox"
              checked={form.is_admin}
              onChange={e => setForm(f => ({ ...f, is_admin: e.target.checked }))}
            />
            Perfil admin
          </label>
          <button type="submit" className="btn-approve" disabled={loading}>
            {loading ? 'Criando...' : 'Criar'}
          </button>
        </form>
      )}

      <div className="user-list">
        {allUsers.length === 0 ? (
          <p className="pending-users-empty">Nenhum usuário ativo.</p>
        ) : (
          allUsers.map(u => (
            <div key={u.id} className="pending-user-row">
              <div className="pending-user-info">
                <span className="pending-user-name">
                  {u.username}
                  {u.is_admin && <span className="admin-tag">admin</span>}
                </span>
                <span className="pending-user-email">{u.email}</span>
              </div>
              <div style={{ display: 'flex', gap: '4px' }}>
                <button
                  className="btn-toggle-admin"
                  onClick={() => { setResetUserId(u.id); setResetPasswordValue(''); setResetError('') }}
                  title="Redefinir senha"
                >
                  🔑
                </button>
                {u.id !== currentUserId && (
                  <button
                    className={`btn-toggle-admin ${u.is_admin ? 'is-admin' : ''}`}
                    onClick={() => onToggleAdmin(u.id)}
                    title={u.is_admin ? 'Remover admin' : 'Tornar admin'}
                  >
                    ★
                  </button>
                )}
              </div>
              {resetUserId === u.id && (
                <form className="create-user-form" onSubmit={handleResetSubmit} style={{ marginTop: '8px' }}>
                  {resetError && <p className="create-user-error">{resetError}</p>}
                  <input
                    type="password"
                    placeholder="Nova senha"
                    value={resetPassword}
                    onChange={e => setResetPasswordValue(e.target.value)}
                    required
                    minLength={6}
                  />
                  <div style={{ display: 'flex', gap: '4px' }}>
                    <button type="submit" className="btn-approve" disabled={resetLoading}>
                      {resetLoading ? 'Salvando...' : 'Salvar'}
                    </button>
                    <button type="button" className="btn-clear-selection" onClick={() => setResetUserId(null)}>
                      Cancelar
                    </button>
                  </div>
                </form>
              )}
            </div>
          ))
        )}
      </div>
    </>
  )
}

function AppContent() {
  const { user, loading: authLoading, logout } = useAuth()
  const [theme, setTheme] = useTheme()
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
  const [expandedCategories, setExpandedCategories] = useState(new Set())
  const [exportProgress, setExportProgress] = useState(null)
  const [allUsers, setAllUsers] = useState([])
  const [showPendingPanel, setShowPendingPanel] = useState(false)
  const { mes: defaultMes, ano: defaultAno } = getDefaultPeriod()
  const [selectedMes, setSelectedMes] = useState(defaultMes)
  const [selectedAno, setSelectedAno] = useState(defaultAno)

  useEffect(() => {
    loadSavedQueries()
    if (user?.is_admin) loadAllUsers()
  }, [user])

  const loadAllUsers = async () => {
    try {
      const res = await axios.get(`${API_URL}/api/auth/users`, { withCredentials: true })
      setAllUsers(res.data.users.filter(u => u.is_approved))
    } catch (err) {
      console.error('Erro ao carregar usuários:', err)
    }
  }

  const handleToggleAdmin = async (userId) => {
    try {
      await axios.post(`${API_URL}/api/auth/users/${userId}/toggle-admin`, {}, { withCredentials: true })
      loadAllUsers()
    } catch (err) {
      console.error('Erro ao alterar admin:', err)
    }
  }

  const handleCreateUser = async (formData) => {
    try {
      await axios.post(`${API_URL}/api/auth/admin/create-user`, formData, { withCredentials: true })
      loadAllUsers()
      return null
    } catch (err) {
      return err.response?.data?.error || 'Erro ao criar usuário'
    }
  }

  const handleResetPassword = async (userId, password) => {
    try {
      await axios.post(`${API_URL}/api/auth/users/${userId}/reset-password`, { password }, { withCredentials: true })
      return null
    } catch (err) {
      return err.response?.data?.error || 'Erro ao redefinir senha'
    }
  }

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

  const executeSavedQuery = async (queryId, mes = selectedMes, ano = selectedAno) => {
    setLoading(true)
    setError(null)
    setTableData(null)

    try {
      const response = await axios.post(
        `${API_URL}/api/queries/${queryId}/execute`,
        { mes_selecionado: mes, ano_selecionado: ano },
        { withCredentials: true }
      )
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
    if (selectedQueriesForExport.size === 0) return

    const queryIds = Array.from(selectedQueriesForExport)
    const failed = []

    const progress = (current, total, currentTitle) =>
      setExportProgress({ current, total, currentTitle, failed: [] })

    try {
      const html2canvas = (await import('html2canvas')).default
      const queryDataArray = []

      // --- PASSO 1: CAPTURAR A CAPA ---
      progress(0, queryIds.length + 1, 'Capa')
      try {
        setLoading(false)
        setSelectedQuery('cover')
        setTableData(null)

        let coverElement = null
        let attempts = 0
        while (attempts < 20) {
          await new Promise(resolve => setTimeout(resolve, 500))
          coverElement = document.querySelector('.cover-page')
          if (coverElement) break
          attempts++
        }

        if (coverElement) {
          await new Promise(resolve => setTimeout(resolve, 500))
          const canvas = await html2canvas(coverElement, {
            scale: 2,
            backgroundColor: '#ffffff',
            logging: false,
            useCORS: true,
            windowWidth: 1600,
            windowHeight: 1200
          })
          const blob = await new Promise(resolve => canvas.toBlob(resolve, 'image/png'))
          queryDataArray.push({ query_id: 'cover', query_title: 'Capa', image_blob: blob, is_cover: true })
        } else {
          failed.push('Capa')
        }
      } catch (err) {
        failed.push('Capa')
        console.error('Erro ao capturar capa:', err)
      }

      // --- PASSO 2: PROCESSAR QUERIES ---
      for (let idx = 0; idx < queryIds.length; idx++) {
        const queryId = queryIds[idx]

        try {
          setLoading(true)
          setTableData(null)

          const queryResponse = await axios.post(
            `${API_URL}/api/queries/${queryId}/execute`,
            { mes_selecionado: selectedMes, ano_selecionado: selectedAno },
            { withCredentials: true, timeout: 600000 }
          )
          const data = queryResponse.data

          progress(idx + 1, queryIds.length + 1, data.title || queryId)

          setSelectedQuery(queryId)
          setLoading(false)
          setTableData(data)

          let tableElement = null
          let attempts = 0
          while (attempts < 1200) {
            await new Promise(resolve => setTimeout(resolve, 500))
            tableElement = document.querySelector('.data-table-container')
            if (tableElement && tableElement.querySelector('table')) break
            attempts++
          }

          if (!tableElement || !tableElement.querySelector('table')) {
            failed.push(data.title || queryId)
            continue
          }

          await new Promise(resolve => setTimeout(resolve, 1000))

          const originalTable = tableElement.querySelector('table')
          const cloneContainer = document.createElement('div')
          cloneContainer.style.cssText = 'position:fixed;top:-10000px;left:0;width:fit-content;height:auto;z-index:-1;background:white;padding:20px'
          cloneContainer.appendChild(originalTable.cloneNode(true))
          document.body.appendChild(cloneContainer)

          const canvas = await html2canvas(cloneContainer, {
            scale: 3,
            backgroundColor: '#ffffff',
            logging: false,
            windowWidth: cloneContainer.scrollWidth + 100,
            windowHeight: cloneContainer.scrollHeight + 100
          })
          document.body.removeChild(cloneContainer)

          const blob = await new Promise(resolve => canvas.toBlob(resolve, 'image/png'))
          queryDataArray.push({ query_id: queryId, query_title: data.title, image_blob: blob, is_cover: false })

          setTableData(null)
          await new Promise(resolve => setTimeout(resolve, 200))

        } catch (err) {
          const label = savedQueries.find(q => q.id === queryId)?.title || queryId
          failed.push(label)
          console.error(`Erro na query ${queryId}:`, err)
        }
      }

      if (queryDataArray.length === 0) {
        setExportProgress({ current: 0, total: 0, currentTitle: '', failed, done: true, error: 'Nenhum slide foi gerado.' })
        return
      }

      setExportProgress({ current: queryIds.length + 1, total: queryIds.length + 1, currentTitle: 'Gerando PowerPoint...', failed: [] })
      setLoading(true)

      const formData = new FormData()
      formData.append('query_count', queryDataArray.length)
      formData.append('mes_selecionado', selectedMes)
      formData.append('ano_selecionado', selectedAno)
      queryDataArray.forEach((item, index) => {
        formData.append(`query_id_${index}`, item.query_id)
        formData.append(`query_title_${index}`, item.query_title)
        formData.append(`table_image_${index}`, item.image_blob, `slide_${index}.png`)
      })

      const response = await axios.post(
        `${API_URL}/api/export/pptx/batch-images`,
        formData,
        { responseType: 'blob', withCredentials: true, headers: { 'Content-Type': 'multipart/form-data' } }
      )

      const url = window.URL.createObjectURL(new Blob([response.data]))
      const link = document.createElement('a')
      link.href = url
      link.setAttribute('download', `export_batch_${new Date().getTime()}.pptx`)
      document.body.appendChild(link)
      link.click()
      link.remove()

      setExportProgress({ done: true, slides: queryDataArray.length, failed })
      setSelectedQueriesForExport(new Set())

    } catch (err) {
      console.error('Erro geral:', err)
      setExportProgress({ done: true, slides: 0, failed, error: err.message })
    } finally {
      setLoading(false)
    }
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
        <h1 className="app-title-link" onClick={showCoverPage} title="Ir para a capa">Dashboard Databricks</h1>

        <div className="sidebar-header-controls">
          {user?.is_admin && (
            <button
              className={`btn-export-mode ${showPendingPanel ? 'active' : ''}`}
              onClick={() => {
                if (!isSidebarOpen) setIsSidebarOpen(true)
                setShowPendingPanel(v => !v)
              }}
              title="Usuários aguardando aprovação"
              style={{ position: 'relative' }}
            >
              👤
            </button>
          )}
          <button
            className={`btn-export-mode ${isExportMode ? 'active' : ''}`}
            onClick={() => {
              if (!isSidebarOpen) setIsSidebarOpen(true)
              setIsExportMode(!isExportMode)
              if (!isExportMode) setSelectedQueriesForExport(new Set())
            }}
            title="Modo de exportação em lote"
          >
            📦
          </button>
          <button
            className="sidebar-toggle-btn"
            onClick={() => setIsSidebarOpen(v => !v)}
            title={isSidebarOpen ? 'Recolher sumário' : 'Expandir sumário'}
          >
            {isSidebarOpen ? '◀' : '▶'}
          </button>
        </div>

        <div className="period-selector">
          <label>Período:</label>
          <select
            value={selectedMes}
            onChange={e => {
              const newMes = Number(e.target.value)
              setSelectedMes(newMes)
              if (selectedQuery && selectedQuery !== 'cover') executeSavedQuery(selectedQuery, newMes, selectedAno)
              else setTableData(null)
            }}
          >
            {MESES.map((nome, i) => (
              <option key={i + 1} value={i + 1}>{nome}</option>
            ))}
          </select>
          <select
            value={selectedAno}
            onChange={e => {
              const newAno = Number(e.target.value)
              setSelectedAno(newAno)
              if (selectedQuery && selectedQuery !== 'cover') executeSavedQuery(selectedQuery, selectedMes, newAno)
              else setTableData(null)
            }}
          >
            {[2023, 2024, 2025, 2026, 2027].map(a => (
              <option key={a} value={a}>{a}</option>
            ))}
          </select>
        </div>

        <div className="header-actions">
          <div className="theme-selector">
            <button
              className={`theme-btn theme-btn-light ${theme === 'light' ? 'active' : ''}`}
              onClick={() => setTheme('light')}
              title="Claro"
            />
            <button
              className={`theme-btn theme-btn-dark ${theme === 'dark-gray' ? 'active' : ''}`}
              onClick={() => setTheme('dark-gray')}
              title="Escuro"
            />
            <button
              className={`theme-btn theme-btn-slate ${theme === 'slate' ? 'active' : ''}`}
              onClick={() => setTheme('slate')}
              title="Slate"
            />
          </div>
          <div className="user-info">
            <span className="welcome-message">Olá, {user.username}!</span>
            {user.is_admin && <span className="admin-badge">Admin</span>}
            <button onClick={logout} className="btn-logout">Sair</button>
          </div>
        </div>
      </header>

      <div className={`main-container ${isSidebarOpen ? 'sidebar-open' : 'sidebar-closed'}`}>
        <aside className={`sidebar ${isSidebarOpen ? 'open' : 'closed'}`}>
          <div className="sidebar-header">
            <h2>Sumário</h2>
          </div>

          {showPendingPanel && user?.is_admin && (
            <div className="pending-users-panel">
              <CreateUserInline onCreateUser={handleCreateUser} allUsers={allUsers} currentUserId={user?.id} onToggleAdmin={handleToggleAdmin} onResetPassword={handleResetPassword} />
            </div>
          )}

          {isExportMode && (
            <div className="batch-export-controls">
              {exportProgress && !exportProgress.done ? (
                <div className="export-progress">
                  <div className="export-progress-label">
                    {exportProgress.currentTitle}
                  </div>
                  <div className="export-progress-bar-track">
                    <div
                      className="export-progress-bar-fill"
                      style={{ width: `${Math.round((exportProgress.current / (exportProgress.total || 1)) * 100)}%` }}
                    />
                  </div>
                  <div className="export-progress-count">
                    {exportProgress.current} / {exportProgress.total}
                  </div>
                </div>
              ) : exportProgress?.done ? (
                <div className="export-done">
                  {exportProgress.error ? (
                    <p className="export-error">Erro: {exportProgress.error}</p>
                  ) : (
                    <p className="export-success">✓ {exportProgress.slides} slides gerados</p>
                  )}
                  {exportProgress.failed?.length > 0 && (
                    <div className="export-failed">
                      <p>Falhou ({exportProgress.failed.length}):</p>
                      <ul>{exportProgress.failed.map((f, i) => <li key={i}>{f}</li>)}</ul>
                    </div>
                  )}
                  <button className="btn-clear-selection" onClick={() => { setExportProgress(null); setIsExportMode(false) }}>
                    Fechar
                  </button>
                </div>
              ) : (
                <>
                  <div className="batch-info">
                    {selectedQueriesForExport.size > 0 && (
                      <p>{selectedQueriesForExport.size} selecionada(s)</p>
                    )}
                  </div>
                  <button onClick={() => setSelectedQueriesForExport(new Set(savedQueries.map(q => q.id)))} className="btn-select-all">
                    Selecionar Todas
                  </button>
                  <button onClick={() => setSelectedQueriesForExport(new Set())} className="btn-clear-selection">
                    Limpar Seleção
                  </button>
                  <button
                    onClick={exportMultipleQueriesPPT}
                    disabled={selectedQueriesForExport.size === 0 || loading}
                    className="btn-export-batch"
                  >
                    {`Exportar (${selectedQueriesForExport.size})`}
                  </button>
                </>
              )}
            </div>
          )}

          {loadingQueries ? (
            <div className="loading-queries">Carregando queries...</div>
          ) : (
            <ul className="query-list">
              {Object.entries(
                savedQueries.reduce((groups, query) => {
                  const cat = query.category || 'Outros'
                  if (!groups[cat]) groups[cat] = []
                  groups[cat].push(query)
                  return groups
                }, {})
              ).map(([category, queries]) => {
                const isExpanded = expandedCategories.has(category)
                const toggleCategory = () => {
                  setExpandedCategories(prev => {
                    const next = new Set(prev)
                    if (next.has(category)) next.delete(category)
                    else next.add(category)
                    return next
                  })
                }
                return (
                  <li key={category} className="query-group">
                    <div className="query-group-header" onClick={toggleCategory}>
                      <span className="query-group-arrow">{isExpanded ? '▾' : '▸'}</span>
                      <span className="query-group-name">{category}</span>
                      <span className="query-group-count">{queries.length}</span>
                    </div>
                    {isExpanded && (
                      <ul className="query-group-list">
                        {queries.map((query, index) => (
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
                  </li>
                )
              })}
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
                <h2 className="cover-subtitle">
                  Resultado {String(selectedMes).padStart(2, '0')}/{selectedAno} + Rolling Fcst
                </h2>
                <p className="cover-date">
                  {new Date().toLocaleDateString('pt-BR', { day: 'numeric', month: 'long', year: 'numeric' })}
                </p>
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
            // AQUI ESTÁ A CORREÇÃO DE LAYOUT
            // flexDirection: 'column' garante que:
            // 1. O Cabeçalho (Título) fique em cima
            // 2. A Tabela fique no meio
            // 3. Os Comentários fiquem embaixo
            <div className="results-section" style={{ display: 'flex', flexDirection: 'column', width: '100%', alignItems: 'stretch' }}>

              {/* CABEÇALHO */}
              <div className="results-header" style={{ width: '100%', display: 'flex', justifyContent: 'space-between', marginBottom: '20px' }}>
                <div>
                  <h2>{tableData.title}</h2>
                  {tableData.description && <p>{tableData.description}</p>}
                  {!tableData.isCombo && <span className="row-count">{tableData.rowCount} linhas</span>}
                </div>
                <div className="export-buttons">
                  <button onClick={exportDevelopmentPPT} className="btn-export-ppt">
                    📊 Exportar PPT
                  </button>
                </div>
              </div>

              {/* CONTEÚDO VERTICAL: TABELA + GRÁFICO + COMENTÁRIOS */}
              <div style={{ display: 'flex', flexDirection: 'column', width: '100%', gap: '30px' }}>
                <div className="table-wrapper-full" style={{ width: '100%' }}>
                  {tableData.isCombo ? (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '40px' }}>
                      {tableData.tables.map((t, idx) => (
                        <div key={idx}>
                          <h3 style={{ marginBottom: '10px' }}>{t.title}</h3>
                          <DataTable columns={t.columns} data={t.data} />
                        </div>
                      ))}
                    </div>
                  ) : (
                    <DataTable columns={tableData.columns} data={tableData.data} />
                  )}
                </div>

                {tableData.chartData && (
                  <div className="data-table-container" style={{ width: '100%' }}>
                    <PcldChart
                      data={tableData.chartData}
                      anoAtual={selectedAno}
                      anoAnterior={selectedAno - 1}
                    />
                  </div>
                )}

                <div className="comments-wrapper-full" style={{ width: '100%' }}>
                  <CommentsSection queryId={selectedQuery} />
                </div>
              </div>

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
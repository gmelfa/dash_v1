import { useState } from 'react'
import axios from 'axios'
import './Comments.css'

function CommentForm({ queryId, onCommentAdded }) {
  const [content, setContent] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000'

  const MAX_CHARS = 500

  const handleSubmit = async (e) => {
    e.preventDefault()

    if (!content.trim()) {
      setError('O comentário não pode estar vazio')
      return
    }

    if (content.trim().length > MAX_CHARS) {
      setError(`Comentário não pode ter mais de ${MAX_CHARS} caracteres`)
      return
    }

    setLoading(true)
    setError('')

    try {
      const response = await axios.post(
        `${API_URL}/api/comments/`,
        { query_id: queryId, content: content.trim() },
        { withCredentials: true }
      )

      onCommentAdded(response.data.comment)
      setContent('')
    } catch (err) {
      setError(err.response?.data?.error || 'Erro ao adicionar comentário')
    } finally {
      setLoading(false)
    }
  }

  return (
    <form className="comment-form" onSubmit={handleSubmit}>
      {error && <div className="error-message">{error}</div>}
      
      <textarea
        value={content}
        onChange={(e) => setContent(e.target.value)}
        placeholder="Adicione um comentário sobre esta tabela..."
        rows="3"
        maxLength={MAX_CHARS}
        disabled={loading}
      />
      <div className="char-counter" style={{ color: content.length > MAX_CHARS * 0.9 ? '#dc2626' : 'var(--text-secondary)' }}>
        {content.length}/{MAX_CHARS}
      </div>

      <button type="submit" disabled={loading || !content.trim() || content.length > MAX_CHARS}>
        {loading ? 'Enviando...' : 'Comentar'}
      </button>
    </form>
  )
}

export default CommentForm

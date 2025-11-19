import { useState } from 'react'
import axios from 'axios'
import './Comments.css'

function CommentForm({ queryId, onCommentAdded }) {
  const [content, setContent] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000'

  const handleSubmit = async (e) => {
    e.preventDefault()
    
    if (!content.trim()) {
      setError('O comentário não pode estar vazio')
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
        disabled={loading}
      />
      
      <button type="submit" disabled={loading || !content.trim()}>
        {loading ? 'Enviando...' : 'Comentar'}
      </button>
    </form>
  )
}

export default CommentForm

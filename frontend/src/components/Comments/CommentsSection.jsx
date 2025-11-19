import { useState, useEffect } from 'react'
import { useAuth } from '../../contexts/AuthContext'
import CommentForm from './CommentForm'
import CommentList from './CommentList'
import axios from 'axios'
import './Comments.css'

function CommentsSection({ queryId }) {
  const { user } = useAuth()
  const [comments, setComments] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000'

  useEffect(() => {
    if (queryId) {
      fetchComments()
    }
  }, [queryId])

  const fetchComments = async () => {
    try {
      setLoading(true)
      const response = await axios.get(
        `${API_URL}/api/comments/query/${queryId}`
      )
      setComments(response.data.comments)
      setError('')
    } catch (err) {
      setError('Erro ao carregar comentários')
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  const handleCommentAdded = (newComment) => {
    setComments([newComment, ...comments])
  }

  const handleCommentDeleted = (commentId) => {
    setComments(comments.filter(c => c.id !== commentId))
  }

  const handleCommentUpdated = (updatedComment) => {
    setComments(comments.map(c => 
      c.id === updatedComment.id ? updatedComment : c
    ))
  }

  if (!queryId) {
    return null
  }

  return (
    <div className="comments-section">
      <div className="comments-header">
        <h3>Comentários</h3>
        <span className="comments-count">{comments.length}</span>
      </div>

      {user && (
        <CommentForm 
          queryId={queryId} 
          onCommentAdded={handleCommentAdded}
        />
      )}

      {!user && (
        <div className="login-prompt">
          <p>Faça login para adicionar comentários</p>
        </div>
      )}

      {error && <div className="error-message">{error}</div>}

      {loading ? (
        <div className="loading">Carregando comentários...</div>
      ) : (
        <CommentList 
          comments={comments}
          currentUser={user}
          onCommentDeleted={handleCommentDeleted}
          onCommentUpdated={handleCommentUpdated}
        />
      )}
    </div>
  )
}

export default CommentsSection

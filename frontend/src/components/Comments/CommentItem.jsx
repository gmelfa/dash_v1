import { useState } from 'react'
import axios from 'axios'
import './Comments.css'

function CommentItem({ comment, currentUser, onDeleted, onUpdated }) {
  const [isEditing, setIsEditing] = useState(false)
  const [editedContent, setEditedContent] = useState(comment.content)
  const [editedFinalContent, setEditedFinalContent] = useState(comment.edited_content || '')
  const [loading, setLoading] = useState(false)

  const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000'

  const canEdit = currentUser && (
    currentUser.id === comment.user_id || currentUser.is_admin
  )

  const canDelete = currentUser && (
    currentUser.id === comment.user_id || currentUser.is_admin
  )

  const isAdmin = currentUser?.is_admin

  const handleDelete = async () => {
    if (!confirm('Tem certeza que deseja deletar este comentário?')) return

    setLoading(true)
    try {
      await axios.delete(`${API_URL}/api/comments/${comment.id}`, {
        withCredentials: true
      })
      onDeleted(comment.id)
    } catch (err) {
      alert('Erro ao deletar comentário')
    } finally {
      setLoading(false)
    }
  }

  const handleUpdate = async () => {
    setLoading(true)
    try {
      const updateData = isAdmin ? {
        content: editedContent,
        edited_content: editedFinalContent || null
      } : {
        content: editedContent
      }

      const response = await axios.put(
        `${API_URL}/api/comments/${comment.id}`,
        updateData,
        { withCredentials: true }
      )

      onUpdated(response.data.comment)
      setIsEditing(false)
    } catch (err) {
      alert('Erro ao atualizar comentário')
    } finally {
      setLoading(false)
    }
  }

  const handleStatusChange = async (newStatus) => {
    setLoading(true)
    try {
      const response = await axios.put(
        `${API_URL}/api/comments/${comment.id}`,
        { status: newStatus },
        { withCredentials: true }
      )
      onUpdated(response.data.comment)
    } catch (err) {
      alert('Erro ao atualizar status')
    } finally {
      setLoading(false)
    }
  }

  const getStatusBadge = () => {
    const statusColors = {
      pending: '#f59e0b',
      approved: '#10b981',
      rejected: '#ef4444'
    }

    const statusLabels = {
      pending: 'Pendente',
      approved: 'Aprovado',
      rejected: 'Rejeitado'
    }

    return (
      <span 
        className="status-badge" 
        style={{ backgroundColor: statusColors[comment.status] }}
      >
        {statusLabels[comment.status]}
      </span>
    )
  }

  const formatDate = (dateString) => {
    const date = new Date(dateString)
    return date.toLocaleString('pt-BR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    })
  }

  return (
    <div className={`comment-item ${comment.status}`}>
      <div className="comment-header">
        <div className="comment-author">
          <span className="username">{comment.username}</span>
          <span className="date">{formatDate(comment.created_at)}</span>
        </div>
        <div className="comment-actions">
          {getStatusBadge()}
          {canEdit && !isEditing && (
            <button onClick={() => setIsEditing(true)} className="btn-edit">
              Editar
            </button>
          )}
          {canDelete && (
            <button onClick={handleDelete} className="btn-delete" disabled={loading}>
              Deletar
            </button>
          )}
        </div>
      </div>

      <div className="comment-body">
        {isEditing ? (
          <div className="edit-form">
            <label>Conteúdo Original:</label>
            <textarea
              value={editedContent}
              onChange={(e) => setEditedContent(e.target.value)}
              rows="3"
            />

            {isAdmin && (
              <>
                <label>Versão Editada (para apresentação final):</label>
                <textarea
                  value={editedFinalContent}
                  onChange={(e) => setEditedFinalContent(e.target.value)}
                  rows="3"
                  placeholder="Deixe vazio para usar o conteúdo original"
                />
              </>
            )}

            <div className="edit-actions">
              <button onClick={handleUpdate} disabled={loading} className="btn-save">
                Salvar
              </button>
              <button onClick={() => setIsEditing(false)} className="btn-cancel">
                Cancelar
              </button>
            </div>
          </div>
        ) : (
          <>
            <p className="comment-content">{comment.content}</p>
            
            {comment.edited_content && (
              <div className="edited-version">
                <strong>Versão Final:</strong>
                <p>{comment.edited_content}</p>
                <small>Editado por {comment.edited_by_username} em {formatDate(comment.edited_at)}</small>
              </div>
            )}
          </>
        )}
      </div>

      {isAdmin && !isEditing && (
        <div className="admin-actions">
          <button
            onClick={() => handleStatusChange('approved')}
            className="btn-approve-icon"
            disabled={loading || comment.status === 'approved'}
            title="Aprovar"
          />
          <button
            onClick={() => handleStatusChange('rejected')}
            className="btn-reject-icon"
            disabled={loading || comment.status === 'rejected'}
            title="Rejeitar"
          />
        </div>
      )}
    </div>
  )
}

export default CommentItem

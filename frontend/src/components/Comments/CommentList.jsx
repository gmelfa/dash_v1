import { useState } from 'react'
import CommentItem from './CommentItem'
import './Comments.css'

function CommentList({ comments, currentUser, onCommentDeleted, onCommentUpdated }) {
  const [filter, setFilter] = useState('all') // all, pending, approved, rejected

  const filteredComments = comments.filter(comment => {
    if (filter === 'all') return true
    return comment.status === filter
  })

  if (comments.length === 0) {
    return (
      <div className="no-comments">
        <p>Nenhum comentário ainda. Seja o primeiro a comentar!</p>
      </div>
    )
  }

  return (
    <div className="comment-list">
      {currentUser?.is_admin && (
        <div className="comment-filters">
          <button
            className={filter === 'all' ? 'active' : ''}
            onClick={() => setFilter('all')}
          >
            Todos ({comments.length})
          </button>
          <button
            className={filter === 'pending' ? 'active' : ''}
            onClick={() => setFilter('pending')}
          >
            Pendentes ({comments.filter(c => c.status === 'pending').length})
          </button>
          <button
            className={filter === 'approved' ? 'active' : ''}
            onClick={() => setFilter('approved')}
          >
            Aprovados ({comments.filter(c => c.status === 'approved').length})
          </button>
          <button
            className={filter === 'rejected' ? 'active' : ''}
            onClick={() => setFilter('rejected')}
          >
            Rejeitados ({comments.filter(c => c.status === 'rejected').length})
          </button>
        </div>
      )}

      <div className="comments-container">
        {filteredComments.map(comment => (
          <CommentItem
            key={comment.id}
            comment={comment}
            currentUser={currentUser}
            onDeleted={onCommentDeleted}
            onUpdated={onCommentUpdated}
          />
        ))}
      </div>

      {filteredComments.length === 0 && filter !== 'all' && (
        <div className="no-comments">
          <p>Nenhum comentário {filter === 'pending' ? 'pendente' : filter === 'approved' ? 'aprovado' : 'rejeitado'}</p>
        </div>
      )}
    </div>
  )
}

export default CommentList

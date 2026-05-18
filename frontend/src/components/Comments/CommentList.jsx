import { useState } from 'react'
import CommentItem from './CommentItem'
import './Comments.css'

function CommentList({ comments, currentUser, onCommentDeleted, onCommentUpdated }) {
  const [filter, setFilter] = useState('all')

  const isAdmin = currentUser?.is_admin
  const myComments = comments.filter(c => c.user_id === currentUser?.id)

  const filteredComments = comments.filter(comment => {
    if (isAdmin) {
      if (filter === 'all') return true
      return comment.status === filter
    }
    // Usuário comum: vê todos os comentários aprovados + os próprios em qualquer status
    if (filter === 'mine') return comment.user_id === currentUser?.id
    return comment.status === 'approved' || comment.user_id === currentUser?.id
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
      {isAdmin ? (
        <div className="comment-filters">
          {[
            { key: 'all', label: 'Todos', count: comments.length },
            { key: 'pending', label: 'Pendentes', count: comments.filter(c => c.status === 'pending').length },
            { key: 'approved', label: 'Aprovados', count: comments.filter(c => c.status === 'approved').length },
            { key: 'rejected', label: 'Rejeitados', count: comments.filter(c => c.status === 'rejected').length },
          ].map(({ key, label, count }) => (
            <button key={key} className={filter === key ? 'active' : ''} onClick={() => setFilter(key)}>
              {label} ({count})
            </button>
          ))}
        </div>
      ) : myComments.length > 0 && (
        <div className="comment-filters">
          <button className={filter === 'all' ? 'active' : ''} onClick={() => setFilter('all')}>
            Todos
          </button>
          <button className={filter === 'mine' ? 'active' : ''} onClick={() => setFilter('mine')}>
            Meus ({myComments.length})
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

import { useState } from 'react'
import { useAuth } from '../../contexts/AuthContext'
import './Auth.css'

function Register({ onSwitchToLogin }) {
  const { register } = useAuth()
  const [username, setUsername] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [error, setError] = useState('')
  const [success, setSuccess] = useState(false)
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')

    if (password !== confirmPassword) {
      setError('As senhas não coincidem')
      return
    }

    if (password.length < 6) {
      setError('A senha deve ter pelo menos 6 caracteres')
      return
    }

    setLoading(true)
    const result = await register(username, email, password)
    setLoading(false)

    if (result.success) {
      setSuccess(true)
      setTimeout(() => {
        onSwitchToLogin()
      }, 2000)
    } else {
      setError(result.error)
    }
  }

  if (success) {
    return (
      <div className="auth-container">
        <div className="auth-box">
          <h2>Cadastro realizado!</h2>
          <p className="success-message">
            Sua conta foi criada com sucesso. Redirecionando para o login...
          </p>
        </div>
      </div>
    )
  }

  return (
    <div className="auth-container">
      <div className="auth-box">
        <h2>Registrar</h2>
        <form onSubmit={handleSubmit}>
          {error && <div className="error-message">{error}</div>}
          
          <div className="form-group">
            <label>Usuário</label>
            <input
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              placeholder="Digite um nome de usuário"
              required
            />
          </div>

          <div className="form-group">
            <label>Email</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="Digite seu email"
              required
            />
          </div>

          <div className="form-group">
            <label>Senha</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Digite uma senha (mín. 6 caracteres)"
              required
            />
          </div>

          <div className="form-group">
            <label>Confirmar Senha</label>
            <input
              type="password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              placeholder="Confirme sua senha"
              required
            />
          </div>

          <button type="submit" className="btn-primary" disabled={loading}>
            {loading ? 'Registrando...' : 'Registrar'}
          </button>
        </form>

        <p className="auth-switch">
          Já tem conta?{' '}
          <span onClick={onSwitchToLogin}>Faça login</span>
        </p>
      </div>
    </div>
  )
}

export default Register

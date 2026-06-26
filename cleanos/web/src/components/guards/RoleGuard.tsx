import { Navigate, useLocation } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'
import type { Role } from '../../lib/collections'
import { Spinner } from '../ui/Spinner'

interface RoleGuardProps {
  allowedRoles: Role[]
  children: React.ReactNode
}

/**
 * Protege rotas por papel.
 * - Não autenticado → /login (preserva a rota de origem em state.from)
 * - Papel não autorizado → redireciona para o ambiente correto do papel atual
 */
export function RoleGuard({ allowedRoles, children }: RoleGuardProps) {
  const { user, role, isLoading } = useAuth()
  const location = useLocation()

  if (isLoading) {
    return (
      <div className="clx-full-spinner">
        <Spinner size={32} />
      </div>
    )
  }

  if (!user) {
    return <Navigate to="/login" state={{ from: location }} replace />
  }

  if (role && !allowedRoles.includes(role)) {
    // Redireciona para o ambiente correto sem expor rotas não autorizadas
    const target = role === 'profissional' ? '/app' : '/painel'
    return <Navigate to={target} replace />
  }

  return <>{children}</>
}

import { NavLink, Outlet, useNavigate } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'
import {
  IconServices,
  IconMap,
  IconPerfil,
} from '../../components/ui/Icon'

interface BottomNavItem {
  to: string
  label: string
  icon: React.ReactNode
}

const NAV_ITEMS: BottomNavItem[] = [
  { to: '/app',       label: 'Serviços', icon: <IconServices size={22} /> },
  { to: '/app/mapa',  label: 'Mapa',     icon: <IconMap size={22} /> },
  { to: '/app/perfil',label: 'Perfil',   icon: <IconPerfil size={22} /> },
]

export default function AppLayout() {
  const { logout } = useAuth()
  const navigate = useNavigate()

  const handleLogout = () => {
    logout()
    navigate('/login', { replace: true })
  }

  // handleLogout é passado para a página de Perfil via contexto ou prop drilling
  // — neste scaffold, o Perfil tem acesso via useAuth + useNavigate diretamente.
  void handleLogout // evita warning de "declared but never used" no scaffold

  return (
    <div className="profapp-root">
      {/* Conteúdo da rota atual */}
      <main className="profapp-content">
        <Outlet />
      </main>

      {/* Navegação inferior */}
      <nav className="profapp-bottom-nav" aria-label="Navegação do app">
        {NAV_ITEMS.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.to === '/app'}
            className={({ isActive }) =>
              `profapp-nav-item${isActive ? ' active' : ''}`
            }
          >
            {item.icon}
            <span>{item.label}</span>
          </NavLink>
        ))}
      </nav>
    </div>
  )
}

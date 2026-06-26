import { useState } from 'react'
import { NavLink, Outlet, useNavigate } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'
import { Logo } from '../../components/ui/Logo'
import {
  IconDashboard,
  IconClientes,
  IconOrdens,
  IconAgenda,
  IconFinanceiro,
  IconUsuarios,
  IconLogOut,
  IconMenu,
  IconX,
} from '../../components/ui/Icon'

interface NavItem {
  to: string
  label: string
  icon: React.ReactNode
}

const NAV_ITEMS: NavItem[] = [
  { to: '/painel',           label: 'Dashboard',         icon: <IconDashboard /> },
  { to: '/painel/clientes',  label: 'Clientes',          icon: <IconClientes /> },
  { to: '/painel/ordens',    label: 'Ordens de Serviço', icon: <IconOrdens /> },
  { to: '/painel/agenda',    label: 'Agenda',            icon: <IconAgenda /> },
  { to: '/painel/financeiro',label: 'Financeiro',        icon: <IconFinanceiro /> },
  { to: '/painel/usuarios',  label: 'Usuários',          icon: <IconUsuarios /> },
]

const PAGE_TITLES: Record<string, string> = {
  '/painel':            'Dashboard',
  '/painel/clientes':   'Clientes',
  '/painel/ordens':     'Ordens de Serviço',
  '/painel/agenda':     'Agenda',
  '/painel/financeiro': 'Financeiro',
  '/painel/usuarios':   'Usuários',
}

export default function PainelLayout() {
  const { user, role, logout } = useAuth()
  const navigate = useNavigate()
  const [sidebarOpen, setSidebarOpen] = useState(false)

  const currentTitle =
    PAGE_TITLES[window.location.pathname] ?? 'Painel'

  const handleLogout = () => {
    logout()
    navigate('/login', { replace: true })
  }

  const closeSidebar = () => setSidebarOpen(false)

  const avatarInitial = user?.name
    ? user.name.charAt(0).toUpperCase()
    : 'U'

  return (
    <div className="painel-root">
      {/* Overlay para mobile */}
      <div
        className={`painel-sidebar-overlay${sidebarOpen ? ' open' : ''}`}
        onClick={closeSidebar}
        aria-hidden="true"
      />

      {/* Sidebar */}
      <aside className={`painel-sidebar${sidebarOpen ? ' open' : ''}`}>
        <div className="painel-sidebar-header">
          <Logo size={32} showText showSub={false} />
          {/* Botão fechar em mobile */}
          <button
            className="painel-menu-toggle"
            onClick={closeSidebar}
            aria-label="Fechar menu"
            style={{ display: 'inline-flex' }}
          >
            <IconX size={18} />
          </button>
        </div>

        <nav className="painel-nav" aria-label="Menu principal">
          {NAV_ITEMS.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.to === '/painel'}
              className={({ isActive }) =>
                `painel-nav-item${isActive ? ' active' : ''}`
              }
              onClick={closeSidebar}
            >
              <span className="painel-nav-icon">{item.icon}</span>
              {item.label}
            </NavLink>
          ))}
        </nav>

        <div className="painel-sidebar-footer">
          <div className="painel-user-info">
            <div className="painel-user-avatar" aria-hidden="true">
              {avatarInitial}
            </div>
            <div className="painel-user-name">
              <strong title={user?.name}>{user?.name ?? 'Usuário'}</strong>
              <span className="painel-user-role">{role}</span>
            </div>
            <button
              className="painel-logout-btn"
              onClick={handleLogout}
              title="Sair"
              aria-label="Sair do sistema"
            >
              <IconLogOut size={16} />
            </button>
          </div>
        </div>
      </aside>

      {/* Área principal */}
      <div className="painel-main">
        {/* Topbar */}
        <header className="painel-topbar">
          <div className="painel-topbar-left">
            <button
              className="painel-menu-toggle"
              onClick={() => setSidebarOpen(true)}
              aria-label="Abrir menu"
              aria-expanded={sidebarOpen}
            >
              <IconMenu size={20} />
            </button>
            <h1 className="painel-page-title">{currentTitle}</h1>
          </div>
          <div className="painel-topbar-right">
            <span
              style={{
                fontSize: '0.8rem',
                color: 'var(--clx-ink-3)',
                fontWeight: 500,
              }}
            >
              {user?.email}
            </span>
          </div>
        </header>

        {/* Conteúdo da rota atual */}
        <main className="painel-content">
          <Outlet />
        </main>
      </div>
    </div>
  )
}

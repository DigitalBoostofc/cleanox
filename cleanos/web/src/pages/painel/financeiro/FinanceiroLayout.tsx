/**
 * FinanceiroLayout — shell do módulo Financeiro.
 * Sub-nav horizontal (abas) para as sub-rotas + <Outlet/>. Fundo off-white.
 * O título "Financeiro" já é exibido pela topbar do PainelLayout.
 */

import { NavLink, Outlet } from 'react-router-dom'

interface SubNavItem {
  to: string
  label: string
  end?: boolean
}

const SUB_NAV: SubNavItem[] = [
  { to: '/painel/financeiro', label: 'Visão geral', end: true },
  { to: '/painel/financeiro/lancamentos', label: 'Lançamentos' },
  { to: '/painel/financeiro/contas', label: 'Contas a pagar/receber' },
  { to: '/painel/financeiro/categorias', label: 'Categorias' },
  { to: '/painel/financeiro/relatorios', label: 'Relatórios' },
  { to: '/painel/financeiro/limites', label: 'Limites' },
  { to: '/painel/financeiro/carteiras', label: 'Carteiras' },
]

export default function FinanceiroLayout() {
  return (
    <div className="fin-module">
      <nav className="fin-subnav" aria-label="Seções do financeiro">
        {SUB_NAV.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.end}
            className={({ isActive }) => `fin-subnav-item${isActive ? ' active' : ''}`}
          >
            {item.label}
          </NavLink>
        ))}
      </nav>

      <div className="fin-module-body">
        <Outlet />
      </div>
    </div>
  )
}

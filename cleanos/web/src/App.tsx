import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { useAuth } from './contexts/AuthContext'
import { AuthProvider } from './contexts/AuthContext'
import { ThemeProvider } from './contexts/ThemeContext'
import { RoleGuard } from './components/guards/RoleGuard'
import { Spinner } from './components/ui/Spinner'

import Login from './pages/Login'
import PainelLayout from './pages/painel/PainelLayout'
import Dashboard from './pages/painel/Dashboard'
import Clientes from './pages/painel/Clientes'
import OrdensServico from './pages/painel/OrdensServico'
import OSExecucaoPage from './pages/painel/OSExecucaoPage'
import Agenda from './pages/painel/Agenda'
import Financeiro from './pages/painel/Financeiro'
import Usuarios from './pages/painel/Usuarios'
import Conta from './pages/painel/Conta'
import WhatsAppAdmin from './pages/painel/WhatsApp'
import Avaliacoes from './pages/painel/Avaliacoes'
import ServicosListPage from './pages/painel/servicos/ServicosListPage'
import ServicoEditorPage from './pages/painel/servicos/ServicoEditorPage'

import AppLayout from './pages/app/AppLayout'
import MeusServicos from './pages/app/MeusServicos'
import Mapa from './pages/app/Mapa'
import Perfil from './pages/app/Perfil'

/** Redireciona / para o ambiente correto conforme o papel do usuário. */
function RootRedirect() {
  const { user, role, isLoading } = useAuth()

  if (isLoading) {
    return (
      <div className="clx-full-spinner">
        <Spinner size={32} />
      </div>
    )
  }

  if (!user) return <Navigate to="/login" replace />
  return <Navigate to={role === 'profissional' ? '/app' : '/painel'} replace />
}

function AppRoutes() {
  return (
    <Routes>
      {/* Página de login */}
      <Route path="/login" element={<Login />} />

      {/* Painel (admin / gerente) */}
      <Route
        path="/painel"
        element={
          <RoleGuard allowedRoles={['admin', 'gerente']}>
            <PainelLayout />
          </RoleGuard>
        }
      >
        <Route index element={<Dashboard />} />
        <Route path="clientes"  element={<Clientes />} />
        <Route path="ordens"    element={<OrdensServico />} />
        <Route path="ordens/:osId/execucao" element={<OSExecucaoPage />} />
        <Route path="agenda"    element={<Agenda />} />
        <Route path="financeiro"element={<Financeiro />} />
        <Route path="usuarios"    element={<Usuarios />} />
        <Route path="avaliacoes" element={<Avaliacoes />} />
        <Route path="servicos"        element={<ServicosListPage />} />
        <Route path="servicos/novo"   element={<ServicoEditorPage />} />
        <Route path="servicos/:id"    element={<ServicoEditorPage />} />
        <Route path="conta"      element={<Conta />} />
        <Route
          path="whatsapp"
          element={
            <RoleGuard allowedRoles={['admin']}>
              <WhatsAppAdmin />
            </RoleGuard>
          }
        />
      </Route>

      {/* App do profissional */}
      <Route
        path="/app"
        element={
          <RoleGuard allowedRoles={['profissional']}>
            <AppLayout />
          </RoleGuard>
        }
      >
        <Route index element={<MeusServicos />} />
        <Route path="mapa"   element={<Mapa />} />
        <Route path="perfil" element={<Perfil />} />
      </Route>

      {/* Raiz e 404 → redirect inteligente */}
      <Route path="/" element={<RootRedirect />} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}

export default function App() {
  return (
    <ThemeProvider>
      <AuthProvider>
        <BrowserRouter>
          <AppRoutes />
        </BrowserRouter>
      </AuthProvider>
    </ThemeProvider>
  )
}

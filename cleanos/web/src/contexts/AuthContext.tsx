import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from 'react'
import type { ReactNode } from 'react'
import { ClientResponseError } from 'pocketbase'
import { pb } from '../lib/pb'
import type { User, Role } from '../lib/collections'

/* ---- Estado de autenticação ---- */
interface AuthState {
  user: User | null
  role: Role | null
  /** true somente durante a chamada de login() */
  isLoading: boolean
}

/* ---- API pública do contexto ---- */
export interface AuthContextValue extends AuthState {
  login(email: string, password: string): Promise<void>
  logout(): void
}

/* ---- Helpers ---- */
function modelToUser(): User | null {
  if (!pb.authStore.isValid || !pb.authStore.model) return null
  // O authStore.model é tipado como Record<string, unknown> no SDK.
  // Fazemos o cast para User com segurança: o backend garante a forma.
  return pb.authStore.model as unknown as User
}

function userToRole(user: User | null): Role | null {
  return user?.role ?? null
}

/* ---- Contexto ---- */
const AuthContext = createContext<AuthContextValue | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>(() => {
    const user = modelToUser()
    return { user, role: userToRole(user), isLoading: false }
  })

  // Mantém o estado sincronizado com o authStore (ex.: refresh automático do token)
  useEffect(() => {
    const unsub = pb.authStore.onChange(() => {
      const user = modelToUser()
      setState({ user, role: userToRole(user), isLoading: false })
    })
    return unsub
  }, [])

  const login = useCallback(async (email: string, password: string) => {
    setState((s) => ({ ...s, isLoading: true }))
    try {
      const auth = await pb
        .collection('users')
        .authWithPassword<User>(email, password)
      setState({
        user: auth.record,
        role: userToRole(auth.record),
        isLoading: false,
      })
    } catch (err) {
      setState((s) => ({ ...s, isLoading: false }))
      if (err instanceof ClientResponseError) {
        if (err.status === 400 || err.status === 401) {
          throw new Error('E-mail ou senha inválidos.')
        }
        if (err.status === 0) {
          throw new Error('Não foi possível conectar ao servidor. Verifique sua internet.')
        }
      }
      throw new Error('Ocorreu um erro inesperado. Tente novamente.')
    }
  }, [])

  const logout = useCallback(() => {
    pb.authStore.clear()
    setState({ user: null, role: null, isLoading: false })
    // Purga todo o Cache Storage para não deixar dados sensíveis no dispositivo (LGPD)
    if ('caches' in window) {
      caches.keys().then((keys) => Promise.all(keys.map((k) => caches.delete(k)))).catch(() => {})
    }
  }, [])

  const value = useMemo<AuthContextValue>(
    () => ({ ...state, login, logout }),
    [state, login, logout],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

/* ---- Hook público ---- */
export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth deve ser usado dentro de <AuthProvider>')
  return ctx
}

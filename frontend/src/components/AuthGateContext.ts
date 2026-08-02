import { createContext, useContext } from 'react'
import type { useAuth } from '../hooks/useAuth'

export type AuthGateContextValue = {
  status: ReturnType<typeof useAuth>['status']
  isLoginOpen: boolean
  openLogin: () => void
  closeLogin: () => void
  logout: () => Promise<void>
}

export const AuthGateContext = createContext<AuthGateContextValue | null>(null)

export function useAuthGate() {
  const auth = useContext(AuthGateContext)
  if (!auth) {
    throw new Error('useAuthGate must be used within AuthGate')
  }
  return auth
}

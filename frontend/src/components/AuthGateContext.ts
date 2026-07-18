import { createContext } from 'react'
import type { useAuth } from '../hooks/useAuth'

export type AuthGateContextValue = {
  status: ReturnType<typeof useAuth>['status']
  isLoginOpen: boolean
  openLogin: () => void
  closeLogin: () => void
}

export const AuthGateContext = createContext<AuthGateContextValue | null>(null)

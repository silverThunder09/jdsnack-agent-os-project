export type AuthUser = {
  id: string
  email: string
  displayName: string | null
}

export type AuthSession = {
  authenticated: boolean
  user: AuthUser | null
}

export type AuthStatus = 'loading' | 'authenticated' | 'unauthenticated' | 'error'

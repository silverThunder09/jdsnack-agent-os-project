import { useEffect, useState } from 'react'
import { fetchAuthSession, startGoogleLogin } from '../services/auth'
import type { AuthSession, AuthStatus } from '../types/auth'

type AuthState = {
  status: AuthStatus
  session: AuthSession | null
  message: string
}

function callbackState(): AuthState | null {
  const params = new URLSearchParams(window.location.search)
  const auth = params.get('auth')
  if (auth === 'success') {
    return {
      status: 'loading',
      session: null,
      message: '',
    }
  }
  if (auth === 'error') {
    return {
      status: 'error',
      session: null,
      message: 'Google 로그인에 실패했습니다. 다시 시도해주세요.',
    }
  }
  return null
}

export function useAuth() {
  const [state, setState] = useState<AuthState>(() =>
    callbackState() ?? { status: 'loading', session: null, message: '' },
  )

  useEffect(() => {
    if (state.status !== 'loading') {
      return
    }

    let cancelled = false
    fetchAuthSession()
      .then((session) => {
        if (!cancelled) {
          setState({
            status: session.authenticated ? 'authenticated' : 'unauthenticated',
            session,
            message: '',
          })
        }
      })
      .catch((error: unknown) => {
        if (!cancelled) {
          setState({
            status: 'error',
            session: null,
            message: error instanceof Error ? error.message : '로그인 상태를 확인하지 못했습니다.',
          })
        }
      })

    return () => {
      cancelled = true
    }
  }, [state.status, state.session?.user])

  return {
    ...state,
    startGoogleLogin,
  }
}

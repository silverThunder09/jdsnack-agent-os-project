import type { ApiResponse } from '../types/diagnosis'
import type { AuthSession } from '../types/auth'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? ''

export async function fetchAuthSession(): Promise<AuthSession> {
  const response = await fetch(`${API_BASE_URL}/api/auth/session`, {
    method: 'GET',
    credentials: 'include',
    headers: { Accept: 'application/json' },
  })

  const payload = (await response.json()) as ApiResponse<AuthSession>
  if (!response.ok || !payload.success || !payload.data) {
    throw new Error(payload.error?.message ?? '로그인 상태를 확인하지 못했습니다.')
  }

  return payload.data
}

export function startGoogleLogin(): void {
  window.location.assign(`${API_BASE_URL}/api/auth/google/start`)
}

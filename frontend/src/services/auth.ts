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

export async function logout(): Promise<void> {
  const response = await fetch(`${API_BASE_URL}/api/auth/logout`, {
    method: 'POST',
    credentials: 'include',
    headers: { Accept: 'application/json' },
  })

  // 로그아웃 엔드포인트는 보호 대상이라 세션이 이미 만료됐으면 401이 온다.
  // 사용자 입장에서는 이미 로그아웃된 상태이므로 성공과 동일하게 취급한다.
  if (response.ok || response.status === 401) {
    return
  }

  throw new Error('로그아웃하지 못했습니다. 잠시 후 다시 시도해주세요.')
}

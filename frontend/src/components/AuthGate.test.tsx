import { cleanup, render, screen } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { AuthGate } from './AuthGate'

function sessionPayload(authenticated: boolean) {
  return {
    ok: true,
    json: async () => ({
      success: true,
      data: {
        authenticated,
        user: authenticated
          ? { id: 'user-1', email: 'user@example.com', displayName: '테스트 사용자' }
          : null,
      },
    }),
  } as Response
}

describe('AuthGate', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn())
    window.history.replaceState({}, '', '/')
  })

  afterEach(() => {
    cleanup()
    vi.unstubAllGlobals()
    window.history.replaceState({}, '', '/')
  })

  it('비로그인 사용자는 Google 로그인 CTA를 보고 보호 화면은 보지 않는다', async () => {
    vi.mocked(globalThis.fetch).mockResolvedValue(sessionPayload(false))

    render(
      <AuthGate>
        <p>보호 화면</p>
      </AuthGate>,
    )

    expect(await screen.findByRole('button', { name: 'Google로 로그인' })).toBeInTheDocument()
    expect(screen.queryByText('보호 화면')).not.toBeInTheDocument()
  })

  it('인증된 사용자는 보호 화면을 본다', async () => {
    vi.mocked(globalThis.fetch).mockResolvedValue(sessionPayload(true))

    render(
      <AuthGate>
        <p>보호 화면</p>
      </AuthGate>,
    )

    expect(await screen.findByText('보호 화면')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Google로 로그인' })).not.toBeInTheDocument()
  })

  it('OAuth 성공 callback은 보호 화면으로 진입시킨다', () => {
    window.history.replaceState({}, '', '/?auth=success')

    render(
      <AuthGate>
        <p>보호 화면</p>
      </AuthGate>,
    )

    expect(screen.getByText('보호 화면')).toBeInTheDocument()
    expect(globalThis.fetch).not.toHaveBeenCalled()
  })
})

import { cleanup, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
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

  it('비로그인 사용자는 메인 화면 위에서 Google 로그인 모달을 본다', async () => {
    vi.mocked(globalThis.fetch).mockResolvedValue(sessionPayload(false))

    render(
      <AuthGate>
        <p>보호 화면</p>
      </AuthGate>,
    )

    expect(await screen.findByRole('dialog', { name: 'Google 로그인' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Google로 시작하기' })).toBeInTheDocument()
    expect(screen.getByText('보호 화면')).toBeInTheDocument()
  })

  it('로그인 모달을 닫으면 우측 상단 로그인 버튼으로 다시 열 수 있다', async () => {
    const user = userEvent.setup()
    vi.mocked(globalThis.fetch).mockResolvedValue(sessionPayload(false))

    render(
      <AuthGate>
        <p>보호 화면</p>
      </AuthGate>,
    )

    await user.click(await screen.findByRole('button', { name: '로그인 창 닫기' }))
    expect(screen.queryByRole('dialog', { name: 'Google 로그인' })).not.toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: '로그인' }))
    expect(screen.getByRole('dialog', { name: 'Google 로그인' })).toBeInTheDocument()
  })

  it('인증된 사용자는 보호 화면을 본다', async () => {
    vi.mocked(globalThis.fetch).mockResolvedValue(sessionPayload(true))

    render(
      <AuthGate>
        <p>보호 화면</p>
      </AuthGate>,
    )

    expect(screen.getByText('보호 화면')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Google로 시작하기' })).not.toBeInTheDocument()
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

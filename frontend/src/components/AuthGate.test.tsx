import { cleanup, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { AuthGate, AuthLoginAction } from './AuthGate'

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

  it('비로그인 사용자는 홈 화면과 로그인 CTA를 보고 모달은 닫혀 있다', async () => {
    vi.mocked(globalThis.fetch).mockResolvedValue(sessionPayload(false))

    render(
      <AuthGate>
        <AuthLoginAction />
        <p>보호 화면</p>
      </AuthGate>,
    )

    expect(await screen.findByRole('button', { name: '로그인' })).toBeInTheDocument()
    expect(screen.queryByRole('dialog', { name: 'Google 로그인' })).not.toBeInTheDocument()
    expect(screen.getByText('보호 화면')).toBeInTheDocument()
  })

  it('우측 상단 로그인 버튼을 누르면 모달을 열고 닫을 수 있다', async () => {
    const user = userEvent.setup()
    vi.mocked(globalThis.fetch).mockResolvedValue(sessionPayload(false))

    render(
      <AuthGate>
        <AuthLoginAction />
        <p>보호 화면</p>
      </AuthGate>,
    )

    await user.click(screen.getByRole('button', { name: '로그인' }))
    expect(screen.getByRole('dialog', { name: 'Google 로그인' })).toBeInTheDocument()
    expect(screen.getByRole('heading', { name: '합격을 위한 분석을 시작해보세요' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Google로 시작하기' })).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: '로그인 창 닫기' }))
    expect(screen.queryByRole('dialog', { name: 'Google 로그인' })).not.toBeInTheDocument()
  })

  it('인증된 사용자는 보호 화면을 본다', async () => {
    vi.mocked(globalThis.fetch).mockResolvedValue(sessionPayload(true))

    render(
      <AuthGate>
        <AuthLoginAction />
        <p>보호 화면</p>
      </AuthGate>,
    )

    expect(screen.getByText('보호 화면')).toBeInTheDocument()
    await waitFor(() => expect(screen.queryByRole('button', { name: '로그인' })).not.toBeInTheDocument())
  })

  it('OAuth 성공 callback은 보호 화면으로 진입시킨다', () => {
    window.history.replaceState({}, '', '/?auth=success')

    render(
      <AuthGate>
        <AuthLoginAction />
        <p>보호 화면</p>
      </AuthGate>,
    )

    expect(screen.getByText('보호 화면')).toBeInTheDocument()
    expect(globalThis.fetch).not.toHaveBeenCalled()
  })
})

import { cleanup, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import App from './App'

const validResumeText =
  '백엔드와 프론트엔드를 함께 다루며 프로젝트를 설계하고 운영한 경험이 있습니다. 사용자 흐름을 개선하고 테스트 자동화를 정리했습니다.'

describe('App', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn())
    window.localStorage.clear()
  })

  afterEach(() => {
    cleanup()
    vi.unstubAllGlobals()
  })

  it('빈 입력 요청은 클라이언트에서 바로 막는다', async () => {
    const user = userEvent.setup()

    render(<App />)

    await user.click(screen.getByRole('button', { name: '진단 요청' }))

    expect(screen.getByRole('alert')).toHaveTextContent(
      '이력서 내용을 입력해주세요.',
    )
    expect(globalThis.fetch).not.toHaveBeenCalled()
  })

  it('정상 입력 요청은 준비중 안내를 표시한다', async () => {
    const user = userEvent.setup()
    vi.mocked(globalThis.fetch).mockResolvedValue({
      json: async () => ({
        success: false,
        error: {
          code: 'AI_ANALYSIS_NOT_ENABLED',
          message:
            'AI 분석 기능은 준비 중입니다. 현재는 이력서 입력 검증만 가능합니다.',
        },
        timestamp: '2026-05-22T10:00:00.000+09:00',
      }),
    } as Response)

    render(<App />)

    await user.type(
      screen.getByRole('textbox', { name: '이력서 내용' }),
      validResumeText,
    )
    await user.click(screen.getByRole('button', { name: '진단 요청' }))

    expect(
      await screen.findByText(
        'AI 분석 기능은 준비 중입니다. 현재는 이력서 입력 검증만 가능합니다.',
      ),
    ).toBeInTheDocument()
    expect(globalThis.fetch).toHaveBeenCalledTimes(1)
  })

  it('네트워크 오류면 연결 안내를 표시한다', async () => {
    const user = userEvent.setup()
    vi.mocked(globalThis.fetch).mockRejectedValue(new Error('network down'))

    render(<App />)

    await user.type(
      screen.getByRole('textbox', { name: '이력서 내용' }),
      validResumeText,
    )
    await user.click(screen.getByRole('button', { name: '진단 요청' }))

    expect(
      await screen.findByText('네트워크 연결을 확인해주세요.'),
    ).toBeInTheDocument()
  })

  it('저장된 이력서를 다시 불러온다', () => {
    window.localStorage.setItem('jdsnack.resume-text', validResumeText)

    render(<App />)

    expect(screen.getByRole('textbox', { name: '이력서 내용' })).toHaveValue(
      validResumeText,
    )
  })
})

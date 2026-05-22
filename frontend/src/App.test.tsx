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
        success: true,
        data: {
          score: 82,
          summary:
            '풀스택 경험은 분명하지만 프로젝트 성과를 수치로 더 드러내면 설득력이 커집니다.',
          strengths: ['백엔드와 프론트엔드를 함께 설계한 경험이 보입니다.'],
          improvements: ['성과 지표를 숫자로 보강해 주세요.'],
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

    expect(await screen.findByText('82점')).toBeInTheDocument()
    expect(
      screen.getByText(
        '풀스택 경험은 분명하지만 프로젝트 성과를 수치로 더 드러내면 설득력이 커집니다.',
      ),
    ).toBeInTheDocument()
    expect(globalThis.fetch).toHaveBeenCalledTimes(1)
  })

  it('stub 모드 응답은 준비중 안내를 표시한다', async () => {
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

  it('pdf 모드에서 파일 업로드 요청을 보낸다', async () => {
    const user = userEvent.setup()
    vi.mocked(globalThis.fetch).mockResolvedValue({
      json: async () => ({
        success: true,
        data: {
          score: 78,
          summary: '백엔드 중심 경험은 분명하지만 성과 수치가 더 필요합니다.',
          strengths: ['Spring Boot API 구현 경험이 보입니다.'],
          improvements: ['프로젝트 결과를 수치로 보강해 주세요.'],
        },
        timestamp: '2026-05-22T10:00:00.000+09:00',
      }),
    } as Response)

    render(<App />)

    await user.click(screen.getByRole('tab', { name: 'PDF' }))
    const input = screen.getByLabelText('PDF 이력서 파일')
    const file = new File(['dummy pdf'], 'resume.pdf', {
      type: 'application/pdf',
    })

    await user.upload(input, file)
    await user.click(screen.getByRole('button', { name: '진단 요청' }))

    expect(await screen.findByText('78점')).toBeInTheDocument()
    expect(globalThis.fetch).toHaveBeenCalledWith(
      expect.stringContaining('/api/diagnose/file'),
      expect.objectContaining({
        method: 'POST',
        body: expect.any(FormData),
      }),
    )
  })

  it('docx 모드에서 파일이 없으면 클라이언트에서 막는다', async () => {
    const user = userEvent.setup()

    render(<App />)

    await user.click(screen.getByRole('tab', { name: 'DOCX' }))
    await user.click(screen.getByRole('button', { name: '진단 요청' }))

    expect(screen.getByRole('alert')).toHaveTextContent(
      'DOCX 파일을 선택해주세요.',
    )
    expect(globalThis.fetch).not.toHaveBeenCalled()
  })

  it('저장된 이력서를 다시 불러온다', () => {
    window.localStorage.setItem('jdsnack.resume-text', validResumeText)

    render(<App />)

    expect(screen.getByRole('textbox', { name: '이력서 내용' })).toHaveValue(
      validResumeText,
    )
  })
})

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
          sourceText: validResumeText,
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
    expect(screen.getByText('분석 기준 원문 보기')).toBeInTheDocument()
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
          sourceText: validResumeText,
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

  it('Gemini 요청 실패 오류를 화면에 보여준다', async () => {
    const user = userEvent.setup()
    vi.mocked(globalThis.fetch).mockResolvedValue({
      json: async () => ({
        success: false,
        error: {
          code: 'GEMINI_API_REQUEST_FAILED',
          message: 'Gemini AI 분석 요청에 실패했습니다. 잠시 후 다시 시도해주세요.',
        },
        timestamp: '2026-05-23T10:00:00.000+09:00',
      }),
    } as Response)

    render(<App />)

    await user.type(
      screen.getByRole('textbox', { name: '이력서 내용' }),
      validResumeText,
    )
    await user.click(screen.getByRole('button', { name: '진단 요청' }))

    expect(
      await screen.findByText('로컬 AI 분석을 완료하지 못했습니다'),
    ).toBeInTheDocument()
    expect(
      screen.getByText('Gemini AI 분석 요청에 실패했습니다. 잠시 후 다시 시도해주세요.'),
    ).toBeInTheDocument()
  })

  it('JD 비교에서 Gemini 요청 실패 오류를 화면에 보여준다', async () => {
    const user = userEvent.setup()
    vi.mocked(globalThis.fetch)
      .mockResolvedValueOnce({
        json: async () => ({
          success: true,
          data: {
            score: 84,
            summary: '백엔드 중심 경험은 분명하지만 성과 수치가 더 필요합니다.',
            strengths: ['Spring Boot API 구현 경험이 보입니다.'],
            improvements: ['프로젝트 결과를 수치로 보강해 주세요.'],
            sourceText: validResumeText,
          },
          timestamp: '2026-05-23T10:00:00.000+09:00',
        }),
      } as Response)
      .mockResolvedValueOnce({
        json: async () => ({
          success: false,
          error: {
            code: 'GEMINI_API_REQUEST_FAILED',
            message: 'Gemini AI 분석 요청에 실패했습니다. 잠시 후 다시 시도해주세요.',
          },
          timestamp: '2026-05-23T10:00:00.000+09:00',
        }),
      } as Response)

    render(<App />)

    await user.type(
      screen.getByRole('textbox', { name: '이력서 내용' }),
      validResumeText,
    )
    await user.click(screen.getByRole('button', { name: '진단 요청' }))
    await screen.findByText('백엔드 중심 경험은 분명하지만 성과 수치가 더 필요합니다.')

    await user.type(
      screen.getByRole('textbox', { name: 'JD 내용' }),
      'Spring Boot 기반 REST API 개발과 운영 경험, 테스트 자동화, 배포 경험을 요구합니다.',
    )
    await user.type(
      screen.getByRole('textbox', { name: 'JD 링크' }),
      'https://example.com/jobs/backend',
    )
    await user.click(screen.getByRole('button', { name: 'JD 비교 미리보기' }))

    expect(
      await screen.findByText('JD AI 매칭을 완료하지 못했습니다'),
    ).toBeInTheDocument()
    expect(
      screen.getByText('Gemini AI 분석 요청에 실패했습니다. 잠시 후 다시 시도해주세요.'),
    ).toBeInTheDocument()
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

  it('지원하지 않는 파일 형식 오류를 화면에 보여준다', async () => {
    const user = userEvent.setup()
    vi.mocked(globalThis.fetch).mockResolvedValue({
      json: async () => ({
        success: false,
        error: {
          code: 'UNSUPPORTED_FILE_TYPE',
          message: 'PDF 또는 DOCX 파일만 업로드할 수 있습니다.',
        },
        timestamp: '2026-05-23T10:00:00.000+09:00',
      }),
    } as Response)

    render(<App />)

    await user.click(screen.getByRole('tab', { name: 'PDF' }))
    const input = screen.getByLabelText('PDF 이력서 파일')
    const file = new File(['dummy txt'], 'resume.pdf', {
      type: 'application/pdf',
    })

    await user.upload(input, file)
    await user.click(screen.getByRole('button', { name: '진단 요청' }))

    expect(await screen.findByText('파일 확인이 필요합니다')).toBeInTheDocument()
    expect(
      screen.getByText('PDF 또는 DOCX 파일만 업로드할 수 있습니다.'),
    ).toBeInTheDocument()
  })

  it('JD 링크 형식 오류는 클라이언트에서 바로 막는다', async () => {
    const user = userEvent.setup()

    render(<App />)

    await user.type(screen.getByRole('textbox', { name: '이력서 내용' }), validResumeText)
    await user.type(screen.getByLabelText('JD 내용'), 'a'.repeat(80))
    await user.type(screen.getByLabelText('JD 링크'), 'not-a-url')
    await user.click(screen.getByRole('button', { name: 'JD 비교 미리보기' }))

    expect(screen.getByRole('alert')).toHaveTextContent(
      '올바른 JD 링크 형식을 입력해주세요.',
    )
    expect(globalThis.fetch).not.toHaveBeenCalled()
  })

  it('JD 비교 미리보기 요청은 결과 카드를 보여준다', async () => {
    const user = userEvent.setup()
    vi.mocked(globalThis.fetch).mockResolvedValue({
      json: async () => ({
        success: true,
        data: {
          matchingScore: 76,
          summary:
            'Spring Boot와 테스트 자동화 키워드는 잘 맞지만 배포 경험 근거를 더 드러내면 좋습니다.',
          strengths: ['Spring Boot 관련 표현이 JD와 겹칩니다.'],
          gaps: ['배포 관련 경험 또는 성과 근거가 이력서에서 약하게 보입니다.'],
          suggestions: ['배포 경험이 있다면 프로젝트 맥락, 사용 기술, 결과를 함께 적어 보세요.'],
        },
        timestamp: '2026-05-23T10:00:00.000+09:00',
      }),
    } as Response)

    render(<App />)

    await user.type(screen.getByRole('textbox', { name: '이력서 내용' }), validResumeText)
    await user.type(screen.getByLabelText('JD 내용'), 'b'.repeat(100))
    await user.type(
      screen.getByLabelText('JD 링크'),
      'https://example.com/jobs/backend',
    )
    await user.click(screen.getByRole('button', { name: 'JD 비교 미리보기' }))

    expect(await screen.findByText('JD 매칭 미리보기 점수')).toBeInTheDocument()
    expect(screen.getByText('76점')).toBeInTheDocument()
    expect(globalThis.fetch).toHaveBeenCalledWith(
      expect.stringContaining('/api/match/preview'),
      expect.objectContaining({
        method: 'POST',
      }),
    )
  })

  it('JD 링크 자동 불러오기는 textarea를 채운다', async () => {
    const user = userEvent.setup()
    vi.mocked(globalThis.fetch).mockResolvedValue({
      json: async () => ({
        success: true,
        data: {
          jdText:
            '백엔드 API 설계와 운영을 담당합니다. Spring Boot와 MySQL 경험이 필요합니다.',
          sourceUrl: 'https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=1',
          title: '백엔드 엔지니어 채용',
          fetchMode: 'static-html',
          sourceSite: 'saramin',
        },
        timestamp: '2026-05-25T10:00:00.000+09:00',
      }),
    } as Response)

    render(<App />)

    await user.type(
      screen.getByLabelText('JD 링크'),
      'https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=1',
    )
    await user.click(screen.getByRole('button', { name: '링크로 JD 불러오기' }))

    expect(await screen.findByText('JD 본문을 불러왔습니다')).toBeInTheDocument()
    expect(screen.getByLabelText('JD 내용')).toHaveValue(
      '백엔드 API 설계와 운영을 담당합니다. Spring Boot와 MySQL 경험이 필요합니다.',
    )
    expect(globalThis.fetch).toHaveBeenCalledWith(
      expect.stringContaining('/api/jd/fetch'),
      expect.objectContaining({
        method: 'POST',
      }),
    )
  })

  it('JD 링크 자동 불러오기 실패 시 직접 붙여넣기 안내를 보여준다', async () => {
    const user = userEvent.setup()
    vi.mocked(globalThis.fetch).mockResolvedValue({
      json: async () => ({
        success: false,
        error: {
          code: 'JD_FETCH_UNSUPPORTED_SOURCE',
          message: '지원하지 않는 JD 소스입니다.',
        },
        timestamp: '2026-05-25T10:00:00.000+09:00',
      }),
    } as Response)

    render(<App />)

    await user.type(
      screen.getByLabelText('JD 링크'),
      'https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=1',
    )
    await user.click(screen.getByRole('button', { name: '링크로 JD 불러오기' }))

    expect(
      await screen.findByText(
        '이 링크에서는 JD 본문을 확실히 추출하지 못했습니다. JD 내용 칸에 핵심 본문을 직접 붙여넣어 주세요.',
      ),
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

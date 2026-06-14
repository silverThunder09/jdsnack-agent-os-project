import { cleanup, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import App from './App'

const validResumeText =
  '백엔드와 프론트엔드를 함께 다루며 프로젝트를 설계하고 운영한 경험이 있습니다. 사용자 흐름을 개선하고 테스트 자동화를 정리했습니다.'
const interviewJobTitle = '백엔드 개발자'
const interviewJdText =
  'Spring Boot 기반 REST API 개발과 운영 경험, MySQL, 테스트 자동화 경험을 요구합니다.'

async function expectJdInputsReady(user: ReturnType<typeof userEvent.setup>) {
  void user
  await screen.findByLabelText('주요업무')
}

async function prepareReportAndRequestInterview(
  user: ReturnType<typeof userEvent.setup>,
  interviewResponse: unknown,
) {
  vi.mocked(globalThis.fetch)
    .mockResolvedValueOnce({
      json: async () => ({
        success: true,
        data: {
          score: 82,
          summary: '이력서 분석이 완료되었습니다.',
          strengths: ['Spring Boot 경험이 보입니다.'],
          improvements: ['성과 수치를 보강해 주세요.'],
          sourceText: validResumeText,
        },
        timestamp: '2026-06-13T10:00:00.000+09:00',
      }),
    } as Response)
    .mockResolvedValueOnce({
      json: async () => ({
        success: true,
        data: {
          matchingScore: 84,
          summary: 'JD와 이력서가 잘 맞습니다.',
          strengths: ['Spring Boot 경험이 JD와 겹칩니다.'],
          gaps: ['운영 지표 근거가 약합니다.'],
          suggestions: ['장애 대응 결과를 수치로 보강해 보세요.'],
        },
        timestamp: '2026-06-13T10:00:00.000+09:00',
      }),
    } as Response)
    .mockResolvedValueOnce({
      json: async () => interviewResponse,
    } as Response)

  render(<App />)

  await user.type(
    screen.getByRole('textbox', { name: '이력서 내용' }),
    validResumeText,
  )
  await user.click(screen.getByRole('button', { name: '이력서 진단' }))
  await screen.findByLabelText('주요업무')

  await user.type(screen.getByLabelText('대상 직무'), interviewJobTitle)
  await user.type(screen.getByLabelText('주요업무'), interviewJdText)
  await user.click(screen.getByRole('button', { name: 'JD 매칭' }))
  await screen.findByText('84점')

  await user.click(screen.getByRole('button', { name: '면접 질문 생성' }))
}

async function expectInterviewInputsPreserved(user: ReturnType<typeof userEvent.setup>) {
  await user.click(screen.getByLabelText('대상 직무'))
  expect(screen.getByLabelText('대상 직무')).toHaveValue(interviewJobTitle)
  expect(screen.getByLabelText('주요업무')).toHaveValue(interviewJdText)
  expect(screen.getByRole('textbox', { name: '이력서 내용' })).toHaveValue(
    validResumeText,
  )
}

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

    await user.click(screen.getByRole('button', { name: '이력서 진단' }))

    expect(screen.getByText('이력서 내용을 입력해주세요.')).toHaveAttribute(
      'role',
      'alert',
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
    await user.click(screen.getByRole('button', { name: '이력서 진단' }))

    expect(await screen.findByLabelText('주요업무')).toBeInTheDocument()
    expect(screen.getByRole('heading', { name: 'JD' })).toBeInTheDocument()
    expect(screen.getByLabelText('주요업무')).toBeInTheDocument()
    expect(screen.getByLabelText('자격조건')).toBeInTheDocument()
    expect(screen.getByLabelText('우대사항')).toBeInTheDocument()
    expect(screen.getByLabelText('경력사항')).toBeInTheDocument()
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
    await user.click(screen.getByRole('button', { name: '이력서 진단' }))

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
    await user.click(screen.getByRole('button', { name: '이력서 진단' }))

    expect(
      await screen.findByText(/네트워크 연결을 확인해주세요/),
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
    await user.click(screen.getByRole('button', { name: '이력서 진단' }))

    expect(await screen.findByLabelText('주요업무')).toBeInTheDocument()
    expect(screen.getByRole('heading', { name: 'JD' })).toBeInTheDocument()
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
    await user.click(screen.getByRole('button', { name: '이력서 진단' }))

    expect(
      await screen.findByText('로컬 AI 분석을 완료하지 못했습니다'),
    ).toBeInTheDocument()
    expect(
      screen.getByText(/Gemini AI 분석 요청에 실패했습니다/),
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
    await user.click(screen.getByRole('button', { name: '이력서 진단' }))
    await screen.findByLabelText('주요업무')

    await user.type(
      screen.getByRole('textbox', { name: '주요업무' }),
      'Spring Boot 기반 REST API 개발과 운영 경험, 테스트 자동화, 배포 경험을 요구합니다.',
    )
    await user.type(
      screen.getByRole('textbox', { name: 'JD 링크' }),
      'https://example.com/jobs/backend',
    )
    await user.click(screen.getByRole('button', { name: 'JD 매칭' }))

    expect(
      await screen.findByText('JD AI 매칭을 완료하지 못했습니다'),
    ).toBeInTheDocument()
    expect(
      screen.getByText(/Gemini AI 분석 요청에 실패했습니다/),
    ).toBeInTheDocument()
  })

  it('docx 모드에서 파일이 없으면 클라이언트에서 막는다', async () => {
    const user = userEvent.setup()

    render(<App />)

    await user.click(screen.getByRole('tab', { name: 'DOCX' }))
    await user.click(screen.getByRole('button', { name: '이력서 진단' }))

    expect(screen.getByText('DOCX 파일을 선택해주세요.')).toHaveAttribute(
      'role',
      'alert',
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
    await user.click(screen.getByRole('button', { name: '이력서 진단' }))

    expect(await screen.findByText('파일 확인이 필요합니다')).toBeInTheDocument()
    expect(
      screen.getByText(/PDF 또는 DOCX 파일만 업로드할 수 있습니다/),
    ).toBeInTheDocument()
  })

  it('JD 링크 형식 오류는 클라이언트에서 바로 막는다', async () => {
    const user = userEvent.setup()

    render(<App />)

    await user.type(screen.getByRole('textbox', { name: '이력서 내용' }), validResumeText)
    await expectJdInputsReady(user)
    await user.type(screen.getByLabelText('주요업무'), 'a'.repeat(80))
    await user.type(screen.getByLabelText('JD 링크'), 'not-a-url')
    await user.click(screen.getByRole('button', { name: 'JD 매칭' }))

    expect(screen.getAllByRole('alert')[0]).toHaveTextContent('올바른 JD 링크 형식을 입력해주세요.')
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
    await expectJdInputsReady(user)
    await user.type(screen.getByLabelText('주요업무'), 'b'.repeat(100))
    await user.type(
      screen.getByLabelText('JD 링크'),
      'https://example.com/jobs/backend',
    )
    await user.click(screen.getByRole('button', { name: 'JD 매칭' }))

    expect(await screen.findByText('76점')).toBeInTheDocument()
    expect(screen.getByText('Gap')).toBeInTheDocument()
    expect(screen.getByText('제안')).toBeInTheDocument()
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

    await expectJdInputsReady(user)
    await user.type(
      screen.getByLabelText('JD 링크'),
      'https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=1',
    )
    await user.click(screen.getByRole('button', { name: 'JD 미리보기' }))

    expect(await screen.findByText('JD 본문을 불러왔습니다')).toBeInTheDocument()
    expect(screen.getByLabelText('주요업무')).toHaveValue(
      '백엔드 API 설계와 운영을 담당합니다. Spring Boot와 MySQL 경험이 필요합니다.',
    )
    expect(screen.getByLabelText('주요업무')).toHaveClass('jd-textarea--autofilled')
    expect(
      screen.getAllByText('자동으로 불러온 초안입니다. 필요한 부분만 다듬어 주세요.'),
    ).toHaveLength(4)
    expect(globalThis.fetch).toHaveBeenCalledWith(
      expect.stringContaining('/api/jd/fetch'),
      expect.objectContaining({
        method: 'POST',
      }),
    )
    expect(screen.getByText('JD 본문을 불러왔습니다').closest('.status-message')).toHaveAttribute(
      'aria-live',
      'polite',
    )
  })

  it('자동 불러온 JD를 수정하면 placeholder 톤이 해제된다', async () => {
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
      screen.getByRole('textbox', { name: '이력서 내용' }),
      validResumeText,
    )
    await user.click(screen.getByRole('button', { name: 'JD 매칭' }))
    await user.type(
      screen.getByLabelText('JD 링크'),
      'https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=1',
    )
    await user.click(screen.getByRole('button', { name: 'JD 미리보기' }))
    await screen.findByText('JD 본문을 불러왔습니다')

    const jdTextarea = screen.getByLabelText('주요업무')
    await user.type(jdTextarea, ' 추가 메모')

    expect(jdTextarea).not.toHaveClass('jd-textarea--autofilled')
    expect(
      screen.getByText('담당 업무, 프로젝트 범위, 역할을 입력합니다.'),
    ).toBeInTheDocument()
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

    await expectJdInputsReady(user)
    await user.type(
      screen.getByLabelText('JD 링크'),
      'https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=1',
    )
    await user.click(screen.getByRole('button', { name: 'JD 미리보기' }))

    expect(
      await screen.findByText('불러오지 못했습니다. JD 본문을 직접 붙여넣어 주세요.'),
    ).toBeInTheDocument()
    expect(screen.getAllByRole('alert')[0]).toHaveTextContent(
      '불러오지 못했습니다. JD 본문을 직접 붙여넣어 주세요.',
    )
  })

  it('자동 채움 후 사용자가 수정한 JD 본문으로 매칭을 요청한다', async () => {
    const user = userEvent.setup()
    vi.mocked(globalThis.fetch)
      .mockResolvedValueOnce({
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
      .mockResolvedValueOnce({
        json: async () => ({
          success: true,
          data: {
            matchingScore: 76,
            summary: '자동 채움 후 수정한 JD 본문으로 미리보기를 생성했습니다.',
            strengths: ['Spring Boot 관련 표현이 JD와 겹칩니다.'],
            gaps: ['배포 경험 근거가 더 필요합니다.'],
            suggestions: ['운영 경험의 성과를 더 구체적으로 적어 주세요.'],
          },
          timestamp: '2026-05-25T10:01:00.000+09:00',
        }),
      } as Response)

    render(<App />)

    await user.type(screen.getByRole('textbox', { name: '이력서 내용' }), validResumeText)
    await expectJdInputsReady(user)
    await user.type(
      screen.getByLabelText('JD 링크'),
      'https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=1',
    )
    await user.click(screen.getByRole('button', { name: 'JD 미리보기' }))
    await screen.findByText('JD 본문을 불러왔습니다')

    const jdTextarea = screen.getByLabelText('주요업무')
    await user.clear(jdTextarea)
    await user.type(
      jdTextarea,
      '수정한 JD 본문입니다. Spring Boot 기반 API 운영과 테스트 자동화 경험을 요구합니다.',
    )
    await user.click(screen.getByRole('button', { name: 'JD 매칭' }))

    expect(await screen.findByText('76점')).toBeInTheDocument()
    expect(globalThis.fetch).toHaveBeenLastCalledWith(
      expect.stringContaining('/api/match/preview'),
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({
          resumeSource: {
            type: 'TEXT',
            value: validResumeText,
          },
          jdText:
            '[주요업무]\n수정한 JD 본문입니다. Spring Boot 기반 API 운영과 테스트 자동화 경험을 요구합니다.',
          jdUrl: 'https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=1',
        }),
      }),
    )
  })

  it('JD 링크 자동 불러오기는 빈 섹션만 채운다', async () => {
    const user = userEvent.setup()
    vi.mocked(globalThis.fetch).mockResolvedValue({
      json: async () => ({
        success: true,
        data: {
          jdText: '섹션화된 JD 본문입니다.',
          sections: {
            responsibilities: '서버 API 설계와 운영을 담당합니다.',
            qualifications: 'Java와 Spring Boot 실무 경험이 필요합니다.',
            preferredQualifications: 'AWS 운영 경험을 우대합니다.',
            experience: '경력 3년 이상을 기대합니다.',
          },
          sourceUrl: 'https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=1',
          title: '백엔드 엔지니어 채용',
          fetchMode: 'static-html',
          sourceSite: 'saramin',
        },
        timestamp: '2026-05-25T10:00:00.000+09:00',
      }),
    } as Response)

    render(<App />)

    await expectJdInputsReady(user)
    await user.type(screen.getByLabelText('주요업무'), '직접 입력한 주요업무입니다.')
    await user.type(
      screen.getByLabelText('JD 링크'),
      'https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=1',
    )
    await user.click(screen.getByRole('button', { name: 'JD 미리보기' }))

    expect(await screen.findByText('JD 본문을 불러왔습니다')).toBeInTheDocument()
    expect(screen.getByLabelText('주요업무')).toHaveValue('직접 입력한 주요업무입니다.')
    expect(screen.getByLabelText('자격조건')).toHaveValue(
      'Java와 Spring Boot 실무 경험이 필요합니다.',
    )
    expect(screen.getByLabelText('우대사항')).toHaveValue('AWS 운영 경험을 우대합니다.')
    expect(screen.getByLabelText('경력사항')).toHaveValue('경력 3년 이상을 기대합니다.')
  })

  it('JD 링크 실패 후에도 기존 JD textarea 값은 유지된다', async () => {
    const user = userEvent.setup()
    vi.mocked(globalThis.fetch).mockResolvedValue({
      json: async () => ({
        success: false,
        error: {
          code: 'JD_FETCH_FAILED',
          message: 'JD 링크를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.',
        },
        timestamp: '2026-05-25T10:00:00.000+09:00',
      }),
    } as Response)

    render(<App />)

    await expectJdInputsReady(user)
    await user.type(
      screen.getByLabelText('주요업무'),
      '기존 JD 본문입니다. 주요 업무와 자격요건이 정리되어 있습니다.',
    )
    await user.type(
      screen.getByLabelText('JD 링크'),
      'https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=2',
    )
    await user.click(screen.getByRole('button', { name: 'JD 미리보기' }))

    expect(await screen.findByText('불러오지 못했습니다. JD 본문을 직접 붙여넣어 주세요.')).toBeInTheDocument()
    expect(screen.getByLabelText('주요업무')).toHaveValue(
      '기존 JD 본문입니다. 주요 업무와 자격요건이 정리되어 있습니다.',
    )
  })

  it('PDF 분석 성공 후 추출된 sourceText로 JD 매칭을 요청할 수 있다', async () => {
    const user = userEvent.setup()
    vi.mocked(globalThis.fetch)
      .mockResolvedValueOnce({
        json: async () => ({
          success: true,
          data: {
            score: 79,
            summary: '파일 이력서 분석이 완료되었습니다.',
            strengths: ['Spring Boot 경험이 보입니다.'],
            improvements: ['성과 수치를 보강해 주세요.'],
            sourceText: 'PDF에서 추출된 이력서 본문입니다. Spring Boot와 MySQL 운영 경험이 있습니다.',
          },
          timestamp: '2026-05-25T10:00:00.000+09:00',
        }),
      } as Response)
      .mockResolvedValueOnce({
        json: async () => ({
          success: true,
          data: {
            matchingScore: 81,
            summary: '추출된 이력서 본문과 JD가 잘 맞습니다.',
            strengths: ['Spring Boot 경험이 JD와 겹칩니다.'],
            gaps: ['대용량 트래픽 경험 근거가 약합니다.'],
            suggestions: ['성과와 규모를 함께 적어 보세요.'],
          },
          timestamp: '2026-05-25T10:00:00.000+09:00',
        }),
      } as Response)

    render(<App />)

    await user.click(screen.getByRole('tab', { name: 'PDF' }))
    const input = screen.getByLabelText('PDF 이력서 파일')
    const file = new File(['dummy pdf'], 'resume.pdf', {
      type: 'application/pdf',
    })

    await user.upload(input, file)
    await user.click(screen.getByRole('button', { name: '이력서 진단' }))
    await screen.findByLabelText('주요업무')

    await user.type(
      screen.getByLabelText('주요업무'),
      'Spring Boot 기반 REST API 개발과 운영 경험, MySQL, 테스트 자동화 경험을 요구합니다.',
    )
    await user.click(screen.getByRole('button', { name: 'JD 매칭' }))

    expect(await screen.findByText('81점')).toBeInTheDocument()
    expect(globalThis.fetch).toHaveBeenLastCalledWith(
      expect.stringContaining('/api/match/preview'),
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({
          resumeSource: {
            type: 'FILE',
            value: 'PDF에서 추출된 이력서 본문입니다. Spring Boot와 MySQL 운영 경험이 있습니다.',
          },
          jdText:
            '[주요업무]\nSpring Boot 기반 REST API 개발과 운영 경험, MySQL, 테스트 자동화 경험을 요구합니다.',
          jdUrl: '',
        }),
      }),
    )
  })

  it('매칭 리포트 후 모의 면접 질문을 생성한다', async () => {
    const user = userEvent.setup()
    vi.mocked(globalThis.fetch)
      .mockResolvedValueOnce({
        json: async () => ({
          success: true,
          data: {
            score: 82,
            summary: '이력서 분석이 완료되었습니다.',
            strengths: ['Spring Boot 경험이 보입니다.'],
            improvements: ['성과 수치를 보강해 주세요.'],
            sourceText: validResumeText,
          },
          timestamp: '2026-06-13T10:00:00.000+09:00',
        }),
      } as Response)
      .mockResolvedValueOnce({
        json: async () => ({
          success: true,
          data: {
            matchingScore: 84,
            summary: 'JD와 이력서가 잘 맞습니다.',
            strengths: ['Spring Boot 경험이 JD와 겹칩니다.'],
            gaps: ['운영 지표 근거가 약합니다.'],
            suggestions: ['장애 대응 결과를 수치로 보강해 보세요.'],
          },
          timestamp: '2026-06-13T10:00:00.000+09:00',
        }),
      } as Response)
      .mockResolvedValueOnce({
        json: async () => ({
          success: true,
          data: {
            questions: [
              {
                question: 'Spring Boot API 설계 경험을 설명해 주세요.',
                category: 'technical',
                keypoints: '설계 이유, 테스트 방식, 운영 결과를 함께 말하세요.',
              },
            ],
            strategy: '기술 의사결정과 검증 과정을 중심으로 답변하세요.',
            summary: '백엔드 직무 질문을 생성했습니다.',
          },
          timestamp: '2026-06-13T10:00:00.000+09:00',
        }),
      } as Response)

    render(<App />)

    await user.type(
      screen.getByRole('textbox', { name: '이력서 내용' }),
      validResumeText,
    )
    await user.click(screen.getByRole('button', { name: '이력서 진단' }))
    await screen.findByLabelText('주요업무')

    await user.type(screen.getByLabelText('대상 직무'), '백엔드 개발자')
    await user.type(
      screen.getByLabelText('주요업무'),
      'Spring Boot 기반 REST API 개발과 운영 경험, MySQL, 테스트 자동화 경험을 요구합니다.',
    )
    await user.click(screen.getByRole('button', { name: 'JD 매칭' }))
    await screen.findByText('84점')

    await user.click(screen.getByRole('button', { name: '면접 질문 생성' }))

    expect(
      await screen.findByText('Spring Boot API 설계 경험을 설명해 주세요.'),
    ).toBeInTheDocument()
    expect(
      screen.getByText('설계 이유, 테스트 방식, 운영 결과를 함께 말하세요.'),
    ).toBeInTheDocument()
    expect(globalThis.fetch).toHaveBeenLastCalledWith(
      expect.stringContaining('/api/interview/preview'),
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({
          resumeSource: {
            type: 'TEXT',
            value: validResumeText,
          },
          jobTitle: '백엔드 개발자',
          jdText:
            '[주요업무]\nSpring Boot 기반 REST API 개발과 운영 경험, MySQL, 테스트 자동화 경험을 요구합니다.',
        }),
      }),
    )
  })

  it('모의 면접 validation-error는 에러를 표시하고 입력값을 보존한다', async () => {
    const user = userEvent.setup()

    await prepareReportAndRequestInterview(user, {
      success: false,
      error: {
        code: 'TEXT_TOO_SHORT',
        message: '이력서 내용이 너무 짧습니다. 최소 50자 이상 입력해주세요.',
      },
      timestamp: '2026-06-13T10:00:00.000+09:00',
    })

    expect(
      await screen.findByText('모의 면접 질문 생성을 완료하지 못했습니다'),
    ).toBeInTheDocument()
    expect(screen.getByText(/이력서 내용이 너무 짧습니다/)).toBeInTheDocument()

    await expectInterviewInputsPreserved(user)
  })

  it('모의 면접 준비중 응답은 에러를 표시하고 입력값을 보존한다', async () => {
    const user = userEvent.setup()

    await prepareReportAndRequestInterview(user, {
      success: false,
      error: {
        code: 'MOCK_INTERVIEW_NOT_ENABLED',
        message: '면접 질문 생성 기능은 준비 중입니다.',
      },
      timestamp: '2026-06-13T10:00:00.000+09:00',
    })

    expect(
      await screen.findByText('모의 면접 질문 생성은 준비 중입니다'),
    ).toBeInTheDocument()
    expect(screen.getByText(/면접 질문 생성 기능은 준비 중입니다/)).toBeInTheDocument()

    await expectInterviewInputsPreserved(user)
  })

  it('모의 면접 Gemini 실패는 에러를 표시하고 입력값을 보존한다', async () => {
    const user = userEvent.setup()

    await prepareReportAndRequestInterview(user, {
      success: false,
      error: {
        code: 'GEMINI_API_REQUEST_FAILED',
        message: 'Gemini AI 분석 요청에 실패했습니다. 잠시 후 다시 시도해주세요.',
      },
      timestamp: '2026-06-13T10:00:00.000+09:00',
    })

    expect(
      await screen.findByText('모의 면접 질문 생성을 완료하지 못했습니다'),
    ).toBeInTheDocument()
    expect(screen.getByText(/Gemini AI 분석 요청에 실패했습니다/)).toBeInTheDocument()

    await expectInterviewInputsPreserved(user)
  })

  it('저장된 이력서를 다시 불러온다', () => {
    window.localStorage.setItem('jdsnack.resume-text', validResumeText)

    render(<App />)

    expect(screen.getByRole('textbox', { name: '이력서 내용' })).toHaveValue(
      validResumeText,
    )
  })
})

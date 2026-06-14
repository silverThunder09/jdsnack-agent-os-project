import { cleanup, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import App from './App'

const validResumeText =
  'Spring Boot 기반 서비스 설계와 운영, 테스트 자동화, 협업 개선 경험이 있습니다. 프로젝트 성과를 수치화해 전달한 경험도 있습니다.'
const validJdText =
  'Spring Boot 기반 REST API 개발과 운영 경험이 필요하며, 테스트 자동화와 협업 경험을 중요하게 봅니다.'

function mockJsonResponse(payload: unknown) {
  return {
    json: async () => payload,
  } as Response
}

describe('App shell redesign', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn())
    window.localStorage.clear()
  })

  afterEach(() => {
    cleanup()
    vi.unstubAllGlobals()
  })

  it('사이드바, 상단바, 히어로가 함께 렌더링된다', () => {
    render(<App />)

    expect(screen.getByLabelText('주요 내비게이션')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: '홈' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: '모의 면접' })).toBeInTheDocument()
    expect(screen.getAllByText('JDSnack')).toHaveLength(2)
    expect(screen.getByText('AI 기반 이력서 분석·최적화')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: '분석 시작' })).toBeInTheDocument()
  })

  it('잠금 메뉴는 비활성화되고 프로필 영역은 없다', async () => {
    render(<App />)

    const lockedItem = screen.getByRole('button', { name: '분석 내역' })
    expect(lockedItem).toBeDisabled()
    expect(screen.getByRole('button', { name: '이력서 관리' })).toBeDisabled()
    expect(screen.queryByText(/프로필|플랜|계정/)).not.toBeInTheDocument()
  })

  it('분석 시작은 진단과 매칭을 함께 실행하고 입력을 보존한다', async () => {
    const user = userEvent.setup()
    vi.mocked(globalThis.fetch)
      .mockResolvedValueOnce(
        mockJsonResponse({
          success: true,
          data: {
            score: 84,
            summary: '이력서 진단 요약입니다.',
            strengths: ['Spring Boot 경험이 잘 보입니다.'],
            improvements: ['성과 수치를 더 보강해 주세요.'],
            sourceText: validResumeText,
          },
        }),
      )
      .mockResolvedValueOnce(
        mockJsonResponse({
          success: true,
          data: {
            matchingScore: 79,
            summary: 'JD 적합도 요약입니다.',
            strengths: ['Spring Boot 운영 경험이 JD와 맞습니다.'],
            gaps: ['테스트 자동화 사례를 더 드러내면 좋습니다.'],
            suggestions: ['협업 개선 사례를 한 줄 더 보강해 보세요.'],
          },
        }),
      )

    render(<App />)

    await user.type(screen.getByRole('textbox', { name: '이력서 내용' }), validResumeText)
    await user.type(screen.getByRole('textbox', { name: '주요업무' }), validJdText)
    await user.click(screen.getByRole('button', { name: '분석 시작' }))

    expect(globalThis.fetch).toHaveBeenNthCalledWith(
      1,
      expect.stringContaining('/api/diagnose'),
      expect.objectContaining({ method: 'POST' }),
    )
    expect(globalThis.fetch).toHaveBeenNthCalledWith(
      2,
      expect.stringContaining('/api/match/preview'),
      expect.objectContaining({ method: 'POST' }),
    )

    expect(await screen.findByText('84점')).toBeInTheDocument()
    expect(await screen.findByText('79점')).toBeInTheDocument()
    expect(screen.getByRole('textbox', { name: '이력서 내용' })).toHaveValue(validResumeText)
    expect(screen.getByRole('textbox', { name: '주요업무' })).toHaveValue(validJdText)
  })

  it('요약 카드는 진단 점수와 JD 적합도만 보여준다', async () => {
    const user = userEvent.setup()
    vi.mocked(globalThis.fetch)
      .mockResolvedValueOnce(
        mockJsonResponse({
          success: true,
          data: {
            score: 81,
            summary: '진단 요약',
            strengths: ['강점'],
            improvements: ['개선'],
            sourceText: validResumeText,
          },
        }),
      )
      .mockResolvedValueOnce(
        mockJsonResponse({
          success: true,
          data: {
            matchingScore: 76,
            summary: '매칭 요약',
            strengths: ['매칭 강점'],
            gaps: ['매칭 gap'],
            suggestions: ['매칭 제안'],
          },
        }),
      )

    render(<App />)

    await user.type(screen.getByRole('textbox', { name: '이력서 내용' }), validResumeText)
    await user.type(screen.getByRole('textbox', { name: '주요업무' }), validJdText)
    await user.click(screen.getByRole('button', { name: '분석 시작' }))

    expect(await screen.findByText('이력서 진단 점수')).toBeInTheDocument()
    expect(await screen.findByText('JD 적합도')).toBeInTheDocument()
    expect(screen.queryByText('ATS')).not.toBeInTheDocument()
  })

  it('모의 면접 뷰에서 질문 목록과 전략을 보여준다', async () => {
    const user = userEvent.setup()
    vi.mocked(globalThis.fetch)
      .mockResolvedValueOnce(
        mockJsonResponse({
          success: true,
          data: {
            questions: [
              {
                question: '장애 대응 경험을 설명해 주세요.',
                category: 'experience',
                keypoints: '상황, 역할, 조치, 결과를 말해 주세요.',
              },
            ],
            strategy: '기술 선택 이유와 검증 방식을 함께 설명하세요.',
            summary: '질문 세트를 만들었습니다.',
          },
        }),
      )

    render(<App />)

    await user.type(screen.getByRole('textbox', { name: '이력서 내용' }), validResumeText)
    await user.type(screen.getByRole('textbox', { name: '주요업무' }), validJdText)
    await user.click(screen.getByRole('button', { name: '모의 면접' }))
    await user.type(screen.getByLabelText('대상 직무'), '백엔드 개발자')
    await user.click(screen.getByRole('button', { name: '면접 질문 생성' }))

    expect(await screen.findByText('장애 대응 경험을 설명해 주세요.')).toBeInTheDocument()
    expect(screen.getByText('기술 선택 이유와 검증 방식을 함께 설명하세요.')).toBeInTheDocument()
  })

  it('JD 링크 실패 시 직접 입력 안내를 alert로 보여준다', async () => {
    const user = userEvent.setup()
    vi.mocked(globalThis.fetch).mockResolvedValueOnce(
      mockJsonResponse({
        success: false,
        error: {
          code: 'JD_FETCH_UNSUPPORTED_SOURCE',
          message: '지원하지 않는 JD 소스입니다.',
        },
      }),
    )

    render(<App />)

    await user.type(
      screen.getByRole('textbox', { name: 'JD 링크' }),
      'https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=1',
    )
    await user.click(screen.getByRole('button', { name: 'JD 미리보기' }))

    const alert = await screen.findByRole('alert')
    expect(within(alert).getByText(/JD 링크에서 본문을 가져오지 못했습니다/)).toBeInTheDocument()
  })
})

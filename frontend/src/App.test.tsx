import { cleanup, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import App from './App'

const validJdText =
  'Spring Boot 기반 REST API 개발과 운영 경험이 필요하며, 테스트 자동화와 협업 경험을 중요하게 봅니다.'
const resumeSourceText =
  'Spring Boot 기반 서비스 설계와 운영, 테스트 자동화, 협업 개선 경험이 있습니다.'

function mockJsonResponse(payload: unknown) {
  return { ok: true, json: async () => payload } as Response
}

function authSessionPayload() {
  return mockJsonResponse({
    success: true,
    data: {
      authenticated: true,
      user: { id: 'user-1', email: 'user@example.com', displayName: '테스트 사용자' },
    },
  })
}

function makeResumeFile() {
  return new File([resumeSourceText], 'resume.pdf', { type: 'application/pdf' })
}

function diagnosePayload() {
  return mockJsonResponse({
    success: true,
    data: {
      score: 84,
      summary: '이력서 진단 요약입니다.',
      strengths: ['Spring Boot 경험이 잘 보입니다.'],
      improvements: ['성과 수치를 더 보강해 주세요.'],
      sourceText: resumeSourceText,
    },
  })
}

function matchPayload() {
  return mockJsonResponse({
    success: true,
    data: {
      matchingScore: 79,
      summary: 'JD 적합도 요약입니다.',
      strengths: ['Spring Boot 운영 경험이 JD와 맞습니다.'],
      gaps: ['테스트 자동화 사례를 더 드러내면 좋습니다.'],
      suggestions: ['협업 개선 사례를 한 줄 더 보강해 보세요.'],
      matchedKeywords: ['Spring Boot', 'REST API'],
      partialKeywords: [],
      missingKeywords: ['Kubernetes'],
    },
  })
}

function sentencePayload(edits = [
  {
    original: 'Spring Boot 기반 API를 개발했습니다.',
    improved: 'Spring Boot REST API를 설계하고 테스트 자동화로 배포 안정성을 높였습니다.',
    reason: 'JD 핵심 역량과 성과를 구체적으로 연결했습니다.',
  },
]) {
  return mockJsonResponse({ success: true, data: { edits } })
}

async function fillJdAndResume(user: ReturnType<typeof userEvent.setup>) {
  await user.click(screen.getByRole('tab', { name: 'JD 내용 붙여넣기' }))
  await user.type(screen.getByLabelText('JD 내용 붙여넣기'), validJdText)
  await user.upload(screen.getByLabelText('파일 선택'), makeResumeFile())
}

describe('새로운 분석 시작 페이지', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn())
    vi.mocked(globalThis.fetch).mockResolvedValueOnce(authSessionPayload())
    window.localStorage.clear()
    window.history.replaceState({}, '', '/?auth=success')
  })

  afterEach(() => {
    cleanup()
    vi.unstubAllGlobals()
    window.history.replaceState({}, '', '/')
  })

  it('셸·사이드바·새 분석 페이지가 렌더링된다', () => {
    render(<App />)

    expect(screen.getByLabelText('주요 내비게이션')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: '홈' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: '모의 면접' })).toBeInTheDocument()
    expect(screen.getByRole('heading', { name: '새로운 분석 시작' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: '분석 시작하기 →' })).toBeInTheDocument()
  })

  it('사이드바 로고는 홈으로 이동하고 상단 로고는 표시하지 않는다', async () => {
    const user = userEvent.setup()
    render(<App />)

    await user.click(screen.getByRole('button', { name: '모의 면접' }))
    expect(screen.getByRole('heading', { name: /현재 이력서와 JD 맥락/ })).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'JDSnack 홈' }))
    expect(screen.getByRole('heading', { name: '새로운 분석 시작' })).toBeInTheDocument()
    expect(screen.queryByRole('link', { name: 'JDSnack 홈' })).not.toBeInTheDocument()
  })

  it('잠금 메뉴는 비활성화되고 계정 목업 영역은 표시하지 않는다', () => {
    render(<App />)

    expect(screen.getByRole('button', { name: '분석 내역' })).toBeDisabled()
    expect(screen.getByRole('button', { name: '요금제' })).toBeDisabled()
    expect(screen.queryByText('김현준')).not.toBeInTheDocument()
    expect(screen.queryByText('hyunjun.kim@example.com')).not.toBeInTheDocument()
    expect(screen.queryByLabelText('계정 정보')).not.toBeInTheDocument()
    expect(screen.queryByText('프로 플랜')).not.toBeInTheDocument()
  })

  it('JD 탭 전환·글자수·이력서 업로드 칩이 동작한다', async () => {
    const user = userEvent.setup()
    render(<App />)

    expect(screen.getByLabelText('채용 공고 URL')).toBeInTheDocument()

    await user.click(screen.getByRole('tab', { name: 'JD 내용 붙여넣기' }))
    const jdArea = screen.getByLabelText('JD 내용 붙여넣기')
    await user.type(jdArea, '백엔드')
    expect(screen.getByText('3 / 10,000')).toBeInTheDocument()

    await user.upload(screen.getByLabelText('파일 선택'), makeResumeFile())
    expect(screen.getByText('resume.pdf')).toBeInTheDocument()
  })

  it('키워드 분석과 문장 첨삭은 선택 가능하고 준비중 태그가 표시되지 않는다', () => {
    render(<App />)

    expect(screen.getByText('JD 적합도')).toBeInTheDocument()
    expect(screen.getByText('ATS 분석')).toBeInTheDocument()
    expect(screen.getByRole('checkbox', { name: /문장 첨삭/ })).toBeEnabled()
    expect(screen.getByText('키워드 분석')).toBeInTheDocument()
    expect(screen.getAllByText('준비중')).toHaveLength(1)
    expect(screen.queryByRole('button', { name: /맞춤 첨삭/ })).not.toBeInTheDocument()
    for (const item of ['분석 내역', '이력서 관리', '템플릿', '키워드 사전', '요금제']) {
      expect(screen.getByRole('button', { name: item })).toBeDisabled()
    }
  })

  it('분석 시작하기는 JD 적합도(매칭) 결과와 준비중 패널을 보여준다', async () => {
    const user = userEvent.setup()
    vi.mocked(globalThis.fetch)
      .mockResolvedValueOnce(diagnosePayload())
      .mockResolvedValueOnce(matchPayload())
      .mockResolvedValueOnce(sentencePayload())

    render(<App />)
    await fillJdAndResume(user)
    await user.click(screen.getByRole('button', { name: '분석 시작하기 →' }))

    expect(await screen.findByText('79점')).toBeInTheDocument()
    expect(await screen.findByText('Spring Boot 운영 경험이 JD와 맞습니다.')).toBeInTheDocument()
    expect(await screen.findByText('Kubernetes')).toBeInTheDocument()
    expect(await screen.findByText('Spring Boot REST API를 설계하고 테스트 자동화로 배포 안정성을 높였습니다.')).toBeInTheDocument()
    expect(screen.getByText('해당 키워드가 없습니다.')).toBeInTheDocument()
    expect(screen.getAllByText('준비 중인 분석입니다').length).toBeGreaterThanOrEqual(1)
  })

  it('키워드만 선택해도 매칭을 호출하고 JD 적합도 패널 없이 키워드 결과를 보여준다', async () => {
    const user = userEvent.setup()
    vi.mocked(globalThis.fetch).mockResolvedValueOnce(diagnosePayload()).mockResolvedValueOnce(matchPayload())

    render(<App />)
    await fillJdAndResume(user)
    await user.click(screen.getByRole('checkbox', { name: /JD 적합도/ }))
    await user.click(screen.getByRole('checkbox', { name: /문장 첨삭/ }))
    await user.click(screen.getByRole('button', { name: '분석 시작하기 →' }))

    expect(await screen.findByRole('heading', { name: '키워드 분석' })).toBeInTheDocument()
    expect(screen.getByText('Spring Boot', { selector: 'li' })).toBeInTheDocument()
    expect(screen.queryByText('79점')).not.toBeInTheDocument()
    expect(screen.queryByRole('heading', { name: 'JD 적합도' })).not.toBeInTheDocument()
    expect(globalThis.fetch).toHaveBeenCalledTimes(3)
    expect(screen.getByRole('button', { name: '내보내기' })).toBeInTheDocument()
  })

  it('문장 첨삭만 선택하면 독립 API를 호출하고 Before→After 결과를 보여준다', async () => {
    const user = userEvent.setup()
    vi.mocked(globalThis.fetch)
      .mockResolvedValueOnce(diagnosePayload())
      .mockResolvedValueOnce(sentencePayload())

    render(<App />)
    await fillJdAndResume(user)
    await user.click(screen.getByRole('checkbox', { name: /JD 적합도/ }))
    await user.click(screen.getByRole('checkbox', { name: /키워드 분석/ }))
    await user.click(screen.getByRole('button', { name: '분석 시작하기 →' }))

    expect(await screen.findByRole('heading', { name: '문장 첨삭' })).toBeInTheDocument()
    expect(screen.getByText('Spring Boot 기반 API를 개발했습니다.')).toBeInTheDocument()
    expect(screen.getByText('Spring Boot REST API를 설계하고 테스트 자동화로 배포 안정성을 높였습니다.')).toBeInTheDocument()
    expect(screen.queryByRole('heading', { name: 'JD 적합도' })).not.toBeInTheDocument()
    expect(globalThis.fetch).toHaveBeenCalledTimes(3)
    expect(screen.getByRole('button', { name: '내보내기' })).toBeInTheDocument()
  })

  it('문장 첨삭 결과가 비어 있으면 빈 상태를 표시한다', async () => {
    const user = userEvent.setup()
    vi.mocked(globalThis.fetch)
      .mockResolvedValueOnce(diagnosePayload())
      .mockResolvedValueOnce(matchPayload())
      .mockResolvedValueOnce(sentencePayload([]))

    render(<App />)
    await fillJdAndResume(user)
    await user.click(screen.getByRole('button', { name: '분석 시작하기 →' }))

    expect(await screen.findByText('첨삭할 문장이 없습니다.')).toBeInTheDocument()
  })

  it('필수 입력이 없으면 분석 시작 버튼이 비활성화되어 실행되지 않는다', async () => {
    const user = userEvent.setup()
    render(<App />)

    // JD만 입력하고 이력서 파일은 올리지 않음
    await user.click(screen.getByRole('tab', { name: 'JD 내용 붙여넣기' }))
    await user.type(screen.getByLabelText('JD 내용 붙여넣기'), validJdText)

    expect(screen.getByRole('button', { name: '분석 시작하기 →' })).toBeDisabled()
    expect(globalThis.fetch).toHaveBeenCalledTimes(1)
  })

  it('짧은 JD는 파일이 있어도 분석 시작을 막고 업로드를 호출하지 않는다', async () => {
    const user = userEvent.setup()
    render(<App />)

    await user.click(screen.getByRole('tab', { name: 'JD 내용 붙여넣기' }))
    await user.type(screen.getByLabelText('JD 내용 붙여넣기'), '짧은 JD')
    await user.upload(screen.getByLabelText('파일 선택'), makeResumeFile())

    expect(screen.getByRole('button', { name: '분석 시작하기 →' })).toBeDisabled()
    expect(screen.getByText('JD 내용이 너무 짧습니다. 핵심 자격요건이 드러나도록 더 입력해주세요.')).toBeInTheDocument()
    expect(globalThis.fetch).toHaveBeenCalledTimes(1)
  })

  it('분석 항목을 모두 해제하면 시작 버튼과 호출을 막는다', async () => {
    const user = userEvent.setup()
    render(<App />)

    await fillJdAndResume(user)
    for (const checkbox of screen.getAllByRole('checkbox')) {
      await user.click(checkbox)
    }

    expect(screen.getByRole('button', { name: '분석 시작하기 →' })).toBeDisabled()
    expect(screen.getByText('분석 항목을 1개 이상 선택해 주세요.')).toBeInTheDocument()
    expect(globalThis.fetch).toHaveBeenCalledTimes(1)
  })

  it('분석 후 모의 면접 뷰에서 질문을 생성한다', async () => {
    const user = userEvent.setup()
    vi.mocked(globalThis.fetch)
      .mockResolvedValueOnce(diagnosePayload())
      .mockResolvedValueOnce(matchPayload())
      .mockResolvedValueOnce(sentencePayload())
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
    await fillJdAndResume(user)
    await user.click(screen.getByRole('button', { name: '분석 시작하기 →' }))
    await screen.findByText('79점')

    await user.click(screen.getByRole('button', { name: '모의 면접' }))
    await user.type(screen.getByLabelText('대상 직무'), '백엔드 개발자')
    await user.click(screen.getByRole('button', { name: '면접 질문 생성' }))

    expect(await screen.findByText('장애 대응 경험을 설명해 주세요.')).toBeInTheDocument()
    expect(screen.getByText('기술 선택 이유와 검증 방식을 함께 설명하세요.')).toBeInTheDocument()
  })

  it('결과를 마크다운으로 내보내고 인쇄할 수 있다', async () => {
    const user = userEvent.setup()
    vi.mocked(globalThis.fetch)
      .mockResolvedValueOnce(diagnosePayload())
      .mockResolvedValueOnce(matchPayload())
      .mockResolvedValueOnce(sentencePayload())
    const createObjectURL = vi.fn(() => 'blob:mock')
    URL.createObjectURL = createObjectURL
    URL.revokeObjectURL = vi.fn()
    const printSpy = vi.fn()
    window.print = printSpy

    render(<App />)
    await fillJdAndResume(user)
    await user.click(screen.getByRole('button', { name: '분석 시작하기 →' }))
    await screen.findByText('79점')

    await user.click(screen.getByRole('button', { name: '내보내기' }))
    expect(createObjectURL).toHaveBeenCalled()

    await user.click(screen.getByRole('button', { name: '인쇄' }))
    expect(printSpy).toHaveBeenCalled()
  })

  it('JD 입력은 재마운트(새로고침) 후 복원된다', async () => {
    const user = userEvent.setup()
    render(<App />)
    await user.click(screen.getByRole('tab', { name: 'JD 내용 붙여넣기' }))
    await user.type(screen.getByLabelText('JD 내용 붙여넣기'), validJdText)

    cleanup()
    render(<App />)
    await user.click(screen.getByRole('tab', { name: 'JD 내용 붙여넣기' }))
    expect(screen.getByLabelText('JD 내용 붙여넣기')).toHaveValue(validJdText)
  })

  it('입력 초기화는 JD 본문을 비운다', async () => {
    const user = userEvent.setup()
    render(<App />)
    await user.click(screen.getByRole('tab', { name: 'JD 내용 붙여넣기' }))
    await user.type(screen.getByLabelText('JD 내용 붙여넣기'), validJdText)
    await user.click(screen.getByRole('button', { name: '입력 초기화' }))
    expect(screen.getByLabelText('JD 내용 붙여넣기')).toHaveValue('')
  })
})

import type { FormEvent, ReactNode, RefObject } from 'react'
import { useEffect, useRef, useState } from 'react'
import { AppShell } from './components/AppShell'
import { DiagnoseButton } from './components/DiagnoseButton'
import { JdInputFields } from './components/JdInputFields'
import { ResumeFileInput } from './components/ResumeFileInput'
import { ResumeInput } from './components/ResumeInput'
import { ResumeModeTabs } from './components/ResumeModeTabs'
import { StatusMessage } from './components/StatusMessage'
import { useDiagnose } from './hooks/useDiagnose'
import { useInterviewPreview } from './hooks/useInterviewPreview'
import { useMatchPreview } from './hooks/useMatchPreview'
import type { JdFetchResult, JdSections, ResumeInputMode, ResultState } from './types/diagnosis'
import './App.css'

const LOCAL_STORAGE_KEY = 'jdsnack.resume-text'
const MIN_LENGTH = 50
const MAX_LENGTH = 10_000

const emptyJdSections: JdSections = {
  responsibilities: '',
  qualifications: '',
  preferredQualifications: '',
  experience: '',
}

function joinJdSections(sections: JdSections): string {
  return [
    ['주요업무', sections.responsibilities],
    ['자격조건', sections.qualifications],
    ['우대사항', sections.preferredQualifications],
    ['경력사항', sections.experience],
  ]
    .filter(([, value]) => value.trim())
    .map(([label, value]) => `[${label}]\n${value.trim()}`)
    .join('\n\n')
}

function pickSectionValue(text: string, starts: string[], stops: string[]) {
  const normalized = text.replace(/\r/g, '')
  const match = normalized.match(
    new RegExp(
      `(?:${starts.join('|')})\\s*[:：]?\\s*([\\s\\S]*?)(?=\\n\\s*(?:${stops.join('|')})\\s*[:：]?|$)`,
      'i',
    ),
  )

  return match?.[1]?.trim() ?? ''
}

function classifyJdText(jdText: string): JdSections {
  const responsibilities = pickSectionValue(
    jdText,
    ['주요\\s*업무', '담당\\s*업무', '업무\\s*내용', '직무\\s*내용'],
    ['자격\\s*요건', '자격\\s*조건', '지원\\s*자격', '우대\\s*사항', '경력\\s*사항', '근무\\s*조건'],
  )
  const qualifications = pickSectionValue(
    jdText,
    ['자격\\s*요건', '자격\\s*조건', '지원\\s*자격', '필수\\s*요건'],
    ['우대\\s*사항', '경력\\s*사항', '근무\\s*조건', '주요\\s*업무', '담당\\s*업무'],
  )
  const preferredQualifications = pickSectionValue(
    jdText,
    ['우대\\s*사항', '우대\\s*요건', '우대\\s*조건'],
    ['경력\\s*사항', '근무\\s*조건', '주요\\s*업무', '담당\\s*업무', '자격\\s*요건'],
  )
  const experience = pickSectionValue(
    jdText,
    ['경력\\s*사항', '경력\\s*요건', '경력'],
    ['우대\\s*사항', '근무\\s*조건', '주요\\s*업무', '담당\\s*업무', '자격\\s*요건'],
  )

  return {
    responsibilities: responsibilities || jdText.trim(),
    qualifications,
    preferredQualifications,
    experience,
  }
}

function mergeFetchedSections(current: JdSections, fetched: JdFetchResult): JdSections {
  const fallback = classifyJdText(fetched.jdText)
  const next = fetched.sections ?? fallback

  return {
    responsibilities: current.responsibilities.trim()
      ? current.responsibilities
      : (next.responsibilities ?? fallback.responsibilities),
    qualifications: current.qualifications.trim()
      ? current.qualifications
      : (next.qualifications ?? fallback.qualifications),
    preferredQualifications: current.preferredQualifications.trim()
      ? current.preferredQualifications
      : (next.preferredQualifications ?? fallback.preferredQualifications),
    experience: current.experience.trim()
      ? current.experience
      : (next.experience ?? fallback.experience),
  }
}

function EmptyState({ title, message }: { title: string; message: string }) {
  return <StatusMessage badge="Ready" title={title} message={message} tone="neutral" />
}

function SummaryCard({
  label,
  score,
  summary,
  description,
}: {
  label: string
  score?: number
  summary?: string
  description: string
}) {
  return (
    <article className="summary-card">
      <span>{label}</span>
      {typeof score === 'number' ? (
        <>
          <strong>{score}점</strong>
          <p>{summary}</p>
        </>
      ) : (
        <>
          <strong className="summary-card__empty">-</strong>
          <p>{description}</p>
        </>
      )}
    </article>
  )
}

function AnalysisPanel({
  badge,
  title,
  description,
  result,
  resultRef,
  successContent,
}: {
  badge: string
  title: string
  description: string
  result: ResultState
  resultRef?: RefObject<HTMLElement | null>
  successContent: ReactNode
}) {
  return (
    <section
      className="preview-panel"
      aria-live="polite"
      ref={resultRef}
      tabIndex={resultRef ? -1 : undefined}
    >
      <div className="preview-panel__header">
        <span>{badge}</span>
        <div>
          <h2>{title}</h2>
          <p>{description}</p>
        </div>
      </div>

      {result.status === 'idle' ? (
        <EmptyState title="아직 결과가 없습니다" message={description} />
      ) : null}

      {result.status === 'loading' ? (
        <StatusMessage
          badge="Processing"
          title={result.title}
          message={result.message}
          tone="active"
          withLoadingBar
        />
      ) : null}

      {result.status === 'not-enabled' ? (
        <StatusMessage
          badge="Not Enabled"
          title={result.title}
          message={result.message}
          tone="success"
        />
      ) : null}

      {result.status === 'error' ? (
        <StatusMessage badge="Action Needed" title={result.title} message={result.message} tone="danger" />
      ) : null}

      {result.status === 'success' ? successContent : null}
    </section>
  )
}

function App() {
  const [currentView, setCurrentView] = useState<'home' | 'interview'>('home')
  const [isSidebarOpen, setIsSidebarOpen] = useState(false)
  const [inputMode, setInputMode] = useState<ResumeInputMode>('text')
  const [resumeText, setResumeText] = useState(() => {
    if (typeof window === 'undefined') {
      return ''
    }

    return window.localStorage.getItem(LOCAL_STORAGE_KEY) ?? ''
  })
  const [resumeFile, setResumeFile] = useState<File | null>(null)
  const [jdSections, setJdSections] = useState<JdSections>(emptyJdSections)
  const [jdUrl, setJdUrl] = useState('')
  const [jobTitle, setJobTitle] = useState('')
  const [isJdAutofilled, setIsJdAutofilled] = useState(false)
  const resultRef = useRef<HTMLElement>(null)
  const {
    clearInlineError,
    inlineError,
    isSubmitting,
    resetResult,
    result,
    submit,
    submitFile,
  } = useDiagnose()
  const {
    clearErrors: clearJdErrors,
    fetchJd,
    isFetchingJd,
    isSubmitting: isPreviewSubmitting,
    jdFetchState,
    jdTextError,
    jdUrlError,
    resetJdFetchState,
    resetResult: resetPreviewResult,
    result: previewResult,
    submit: submitPreview,
  } = useMatchPreview()
  const {
    isSubmitting: isInterviewSubmitting,
    resetResult: resetInterviewResult,
    result: interviewResult,
    submit: submitInterview,
  } = useInterviewPreview()

  const trimmedLength = resumeText.trim().length
  const trimmedResumeText = resumeText.trim()
  const jdText = joinJdSections(jdSections)
  const hasResumeSource =
    inputMode === 'text'
      ? trimmedLength >= MIN_LENGTH && trimmedLength <= MAX_LENGTH
      : Boolean(result.status === 'success' && result.diagnosis?.sourceText)
  const canStartAnalysis =
    inputMode === 'text'
      ? trimmedLength >= MIN_LENGTH && Boolean(jdText.trim())
      : Boolean(resumeFile) && Boolean(jdText.trim())

  useEffect(() => {
    window.localStorage.setItem(LOCAL_STORAGE_KEY, resumeText)
  }, [resumeText])

  useEffect(() => {
    if (
      result.status === 'success' ||
      result.status === 'not-enabled' ||
      result.status === 'error' ||
      previewResult.status === 'success' ||
      previewResult.status === 'error'
    ) {
      resultRef.current?.focus()
    }
  }, [previewResult.status, result.status])

  const resetDownstreamResults = () => {
    if (previewResult.status !== 'idle' && previewResult.status !== 'loading') {
      resetPreviewResult()
    }
    if (interviewResult.status !== 'idle' && interviewResult.status !== 'loading') {
      resetInterviewResult()
    }
  }

  const handleResumeChange = (nextValue: string) => {
    setResumeText(nextValue)
    if (inlineError) {
      clearInlineError()
    }
    if (result.status !== 'idle' && result.status !== 'loading') {
      resetResult()
    }
    resetDownstreamResults()
  }

  const handleModeChange = (nextMode: ResumeInputMode) => {
    setInputMode(nextMode)
    setResumeFile(null)
    clearInlineError()
    if (result.status !== 'idle' && result.status !== 'loading') {
      resetResult()
    }
    resetDownstreamResults()
  }

  const handleFileChange = (nextFile: File | null) => {
    setResumeFile(nextFile)
    clearInlineError()
    if (result.status !== 'idle' && result.status !== 'loading') {
      resetResult()
    }
    resetDownstreamResults()
  }

  const handleJdSectionChange = (section: keyof JdSections, nextValue: string) => {
    setJdSections((current) => ({
      ...current,
      [section]: nextValue,
    }))
    setIsJdAutofilled(false)
    if (jdTextError || jdUrlError) {
      clearJdErrors()
    }
    if (jdFetchState.status !== 'idle') {
      resetJdFetchState()
    }
    resetDownstreamResults()
  }

  const handleJdUrlChange = (nextValue: string) => {
    setJdUrl(nextValue)
    if (jdTextError || jdUrlError) {
      clearJdErrors()
    }
    if (jdFetchState.status !== 'idle') {
      resetJdFetchState()
    }
    resetDownstreamResults()
  }

  const handleJobTitleChange = (nextValue: string) => {
    setJobTitle(nextValue)
    if (interviewResult.status !== 'idle' && interviewResult.status !== 'loading') {
      resetInterviewResult()
    }
  }

  const handleJdFetch = async () => {
    await fetchJd(jdUrl, {
      onBeforeChange: resetDownstreamResults,
      onFetched: (fetched) => {
        setJdSections((current) => mergeFetchedSections(current, fetched))
        setIsJdAutofilled(true)
      },
    })
  }

  const handleAnalysisSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()

    if (inputMode === 'text') {
      await submit(resumeText)
      await submitPreview({
        resumeSource: {
          type: 'TEXT',
          value: trimmedResumeText,
        },
        jdText,
        jdUrl: jdUrl.trim(),
      })
      return
    }

    const diagnosisOutcome = await submitFile(inputMode, resumeFile)

    if (diagnosisOutcome.ok && diagnosisOutcome.diagnosis?.sourceText) {
      await submitPreview({
        resumeSource: {
          type: 'FILE',
          value: diagnosisOutcome.diagnosis.sourceText,
        },
        jdText,
        jdUrl: jdUrl.trim(),
      })
    }
  }

  const handleInterviewSubmit = async () => {
    const resumeSource =
      inputMode === 'text'
        ? trimmedResumeText
        : result.status === 'success' && result.diagnosis?.sourceText
          ? result.diagnosis.sourceText
          : ''

    await submitInterview({
      resumeSource: {
        type: inputMode === 'text' ? 'TEXT' : 'FILE',
        value: resumeSource,
      },
      jobTitle: jobTitle.trim(),
      jdText,
    })
  }

  return (
    <AppShell
      currentView={currentView}
      isSidebarOpen={isSidebarOpen}
      onNavigate={(view) => {
        setCurrentView(view)
        setIsSidebarOpen(false)
      }}
      onToggleSidebar={() => setIsSidebarOpen((current) => !current)}
    >
      {currentView === 'home' ? (
        <section className="home-shell" aria-label="홈 분석 화면">
          <section className="hero-card">
            <p className="hero-card__eyebrow">AI 기반 이력서 분석·최적화</p>
            <h1>공고와 이력서를 연결하고, 합격 가능성을 더 선명하게 보세요.</h1>
            <p className="hero-card__copy">
              JD와 이력서를 한 번에 넣으면 진단 점수와 JD 적합도를 함께 보여줍니다. 입력값은
              그대로 유지돼 바로 다듬고 다시 실행할 수 있습니다.
            </p>
          </section>

          <form className="analysis-grid" onSubmit={handleAnalysisSubmit}>
            <section className="workspace-card" aria-label="통합 입력 영역">
              <div className="workspace-card__header">
                <div>
                  <span>Integrated Input</span>
                  <h2>한 번에 분석 준비</h2>
                </div>
                <p>JD 링크/본문과 이력서를 한 입력 흐름으로 정리합니다.</p>
              </div>

              <div className="workspace-card__body">
                <section className="input-card">
                  <div className="section-title-row">
                    <h2>채용 공고</h2>
                    <span>JD 링크 또는 직접 입력</span>
                  </div>
                  <JdInputFields
                    jdSections={jdSections}
                    jdUrl={jdUrl}
                    isJdAutofilled={isJdAutofilled}
                    jdFetchStatus={jdFetchState.status}
                    jdFetchTitle={jdFetchState.title}
                    jdFetchMessage={jdFetchState.message}
                    jdTextError={jdTextError}
                    jdUrlError={jdUrlError}
                    isFetchingJd={isFetchingJd}
                    onJdSectionChange={handleJdSectionChange}
                    onJdUrlChange={handleJdUrlChange}
                    onJdFetch={handleJdFetch}
                  />
                </section>

                <section className="input-card">
                  <div className="section-title-row">
                    <h2>이력서</h2>
                    <span>Text / PDF / DOCX</span>
                  </div>
                  <ResumeModeTabs mode={inputMode} onChange={handleModeChange} />
                  {inputMode === 'text' ? (
                    <ResumeInput
                      value={resumeText}
                      onChange={handleResumeChange}
                      minLength={MIN_LENGTH}
                      maxLength={MAX_LENGTH}
                      currentLength={trimmedLength}
                      errorMessage={inlineError}
                    />
                  ) : (
                    <ResumeFileInput
                      mode={inputMode}
                      file={resumeFile}
                      errorMessage={inlineError}
                      onChange={handleFileChange}
                    />
                  )}
                </section>
              </div>

              <div className="workspace-card__footer">
                <DiagnoseButton
                  isSubmitting={isSubmitting || isPreviewSubmitting}
                  idleLabel="분석 시작"
                  loadingLabel="분석 중..."
                  disabled={!canStartAnalysis}
                />
              </div>
            </section>

            <section className="results-card" aria-label="분석 결과 영역" ref={resultRef} tabIndex={-1}>
              <div className="results-card__header">
                <div>
                  <span>Outcome</span>
                  <h2>분석 리포트</h2>
                </div>
                <p>이력서 진단과 JD 적합도를 나란히 읽고 다음 수정 포인트를 확인하세요.</p>
              </div>

              <div className="summary-grid">
                <SummaryCard
                  label="이력서 진단 점수"
                  score={result.diagnosis?.score}
                  summary={result.diagnosis?.summary}
                  description="분석 전에는 점수 대신 입력 안내를 보여줍니다."
                />
                <SummaryCard
                  label="JD 적합도"
                  score={previewResult.matchPreview?.matchingScore}
                  summary={previewResult.matchPreview?.summary}
                  description="JD와 이력서가 함께 준비되면 적합도를 계산합니다."
                />
              </div>

              <div className="preview-grid">
                <AnalysisPanel
                  badge="Resume"
                  title="이력서 진단"
                  description="강점과 개선 포인트를 먼저 읽어보세요."
                  result={result}
                  successContent={
                    <div className="detail-list-grid">
                      <section className="detail-card">
                        <h3>강점</h3>
                        <ul>
                          {result.diagnosis?.strengths.map((item) => <li key={item}>{item}</li>)}
                        </ul>
                      </section>
                      <section className="detail-card">
                        <h3>개선</h3>
                        <ul>
                          {result.diagnosis?.improvements.map((item) => <li key={item}>{item}</li>)}
                        </ul>
                      </section>
                    </div>
                  }
                />

                <AnalysisPanel
                  badge="JD Match"
                  title="JD 매칭 프리뷰"
                  description="공고 강점과 gap, 보강 제안을 함께 확인하세요."
                  result={previewResult}
                  successContent={
                    <div className="detail-list-grid detail-list-grid--triple">
                      <section className="detail-card">
                        <h3>강점</h3>
                        <ul>
                          {previewResult.matchPreview?.strengths.map((item) => <li key={item}>{item}</li>)}
                        </ul>
                      </section>
                      <section className="detail-card">
                        <h3>Gap</h3>
                        <ul>
                          {previewResult.matchPreview?.gaps.map((item) => <li key={item}>{item}</li>)}
                        </ul>
                      </section>
                      <section className="detail-card">
                        <h3>제안</h3>
                        <ul>
                          {previewResult.matchPreview?.suggestions.map((item) => <li key={item}>{item}</li>)}
                        </ul>
                      </section>
                    </div>
                  }
                />
              </div>
            </section>
          </form>
        </section>
      ) : (
        <section className="interview-shell" aria-label="모의 면접 화면">
          <section className="hero-card hero-card--compact">
            <p className="hero-card__eyebrow">Mock Interview</p>
            <h1>현재 이력서와 JD 맥락으로 예상 질문을 빠르게 준비하세요.</h1>
            <p className="hero-card__copy">
              홈에서 준비한 이력서와 JD 본문을 그대로 이어받고, 직무명만 보강해 질문 세트를
              만듭니다.
            </p>
          </section>

          <div className="interview-layout">
            <section className="workspace-card">
              <div className="workspace-card__header">
                <div>
                  <span>Interview Input</span>
                  <h2>질문 생성 준비</h2>
                </div>
                <p>이력서와 JD 맥락은 유지되고, 대상 직무를 덧붙여 질문을 생성합니다.</p>
              </div>

              <div className="interview-form">
                <label className="resume-input-group" htmlFor="job-title">
                  <span className="resume-label">대상 직무</span>
                  <input
                    id="job-title"
                    className="jd-url-input"
                    type="text"
                    value={jobTitle}
                    placeholder="예: 백엔드 개발자"
                    onChange={(event) => handleJobTitleChange(event.target.value)}
                  />
                </label>

                <div className="context-note">
                  <h3>연결된 분석 맥락</h3>
                  <ul>
                    <li>이력서 소스: {hasResumeSource ? '준비됨' : '먼저 홈에서 분석을 실행해 주세요.'}</li>
                    <li>JD 본문: {jdText.trim() ? '준비됨' : '홈에서 JD를 입력해 주세요.'}</li>
                  </ul>
                </div>

                <button
                  className="diagnose-button"
                  type="button"
                  disabled={!hasResumeSource || isInterviewSubmitting}
                  onClick={handleInterviewSubmit}
                >
                  {isInterviewSubmitting ? '질문 생성 중...' : '면접 질문 생성'}
                </button>
              </div>
            </section>

            <AnalysisPanel
              badge="Interview"
              title="모의 면접 질문"
              description="질문 목록, 답변 전략, 요약을 한 번에 확인합니다."
              result={interviewResult}
              successContent={
                <div className="interview-result">
                  <p className="strategy-card">{interviewResult.interviewPreview?.strategy}</p>
                  <div className="question-grid">
                    {interviewResult.interviewPreview?.questions.map((question) => (
                      <article className="question-card" key={question.question}>
                        <span>{question.category}</span>
                        <h3>{question.question}</h3>
                        <p>{question.keypoints}</p>
                      </article>
                    ))}
                  </div>
                </div>
              }
            />
          </div>
        </section>
      )}
    </AppShell>
  )
}

export default App

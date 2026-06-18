import type { ChangeEvent, DragEvent, ReactNode, RefObject } from 'react'
import { useEffect, useRef, useState } from 'react'
import { AppShell } from './components/AppShell'
import { StatusMessage } from './components/StatusMessage'
import { useDiagnose } from './hooks/useDiagnose'
import { useInterviewPreview } from './hooks/useInterviewPreview'
import { useMatchPreview, validateJdText } from './hooks/useMatchPreview'
import type { MatchPreviewResult, ResultState, ResumeInputMode } from './types/diagnosis'
import './App.css'

const INPUT_STORAGE_KEY = 'jdsnack.analysis-input'

type JdTab = 'link' | 'paste'
type AnalysisPhase = 'input' | 'result'
type AnalysisOptionKey = 'jdMatch' | 'ats' | 'sentence' | 'keyword'

const JD_MAX_LENGTH = 10_000
const RESUME_REQUIRED_MESSAGE = '이력서 파일을 업로드해 주세요.'
const UNSUPPORTED_RESUME_FILE_MESSAGE = '지원하지 않는 파일 형식입니다. PDF 또는 DOCX 파일을 올려 주세요.'
const ANALYSIS_OPTION_REQUIRED_MESSAGE = '분석 항목을 1개 이상 선택해 주세요.'

const ANALYSIS_OPTIONS: {
  key: AnalysisOptionKey
  label: string
  description: string
  recommended: boolean
  enabled: boolean
}[] = [
  {
    key: 'jdMatch',
    label: 'JD 적합도',
    description: '이력서와 JD의 핵심 키워드 및 역량 적합도를 분석합니다.',
    recommended: true,
    enabled: true,
  },
  {
    key: 'ats',
    label: 'ATS 분석',
    description: 'ATS 통과 가능성과 포맷, 키워드 최적화 여부를 분석합니다.',
    recommended: true,
    enabled: false,
  },
  {
    key: 'sentence',
    label: '문장 첨삭',
    description: '문장 표현, 가독성, 문법 및 전문성 향상을 제안합니다.',
    recommended: false,
    enabled: false,
  },
  {
    key: 'keyword',
    label: '키워드 분석',
    description: '주요 키워드 누락 여부와 활용도를 분석합니다.',
    recommended: false,
    enabled: true,
  },
]

const PROGRESS_STEPS = [
  { title: '채용 공고(JD) 수집', description: '링크 또는 내용을 통해 JD를 분석합니다.' },
  { title: '이력서 파싱', description: '이력서의 경력, 스킬, 경험을 추출합니다.' },
  { title: 'AI 종합 분석', description: '적합도, ATS, 첨삭 등 항목별 분석 수행' },
  { title: '결과 제공', description: '맞춤형 인사이트와 개선안을 제공합니다.' },
]

const ACCURACY_TIPS = [
  '원본 JD 전체 내용을 제공해 주세요.',
  '최신 이력서를 업로드해 주세요.',
  '경력 및 성과는 구체적으로 작성된 이력서일수록 정확도가 높아집니다.',
]

const DEFAULT_OPTIONS: Record<AnalysisOptionKey, boolean> = {
  jdMatch: true,
  ats: true,
  sentence: true,
  keyword: true,
}

function loadSavedInput(): { jdText: string; options: Record<AnalysisOptionKey, boolean> } | null {
  if (typeof window === 'undefined') {
    return null
  }
  try {
    const raw = window.localStorage.getItem(INPUT_STORAGE_KEY)
    if (!raw) {
      return null
    }
    const parsed = JSON.parse(raw) as { jdText?: unknown; options?: unknown }
    const savedOptions = (parsed.options ?? {}) as Partial<Record<AnalysisOptionKey, boolean>>
    return {
      jdText: typeof parsed.jdText === 'string' ? parsed.jdText : '',
      options: { ...DEFAULT_OPTIONS, ...savedOptions },
    }
  } catch {
    return null
  }
}

function buildResultMarkdown(
  match: MatchPreviewResult,
  submittedOptions: Record<AnalysisOptionKey, boolean>,
): string {
  const list = (items: string[]) => (items.length ? items.map((item) => `- ${item}`).join('\n') : '- (없음)')
  const sections = ['# JDSnack 분석 결과', '']

  if (submittedOptions.jdMatch) {
    sections.push(
      `## JD 적합도 점수: ${match.matchingScore}점`,
      '',
      '### 요약',
      match.summary,
      '',
      '### 강점',
      list(match.strengths),
      '',
      '### Gap',
      list(match.gaps),
      '',
      '### 제안',
      list(match.suggestions),
      '',
    )
  }

  if (submittedOptions.keyword) {
    sections.push(
      '## 키워드 분석',
      '',
      '### 매칭 키워드',
      list(match.matchedKeywords),
      '',
      '### 부분 매칭',
      list(match.partialKeywords),
      '',
      '### 누락 키워드',
      list(match.missingKeywords),
      '',
    )
  }

  return sections.join('\n')
}

function todayStamp(): string {
  const d = new Date()
  return `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, '0')}${String(d.getDate()).padStart(2, '0')}`
}

function inferResumeMode(file: File): ResumeInputMode | null {
  const name = file.name.toLowerCase()
  if (name.endsWith('.pdf')) {
    return 'pdf'
  }
  if (name.endsWith('.docx')) {
    return 'docx'
  }
  return null
}

function formatFileSize(bytes: number): string {
  if (bytes < 1024) {
    return `${bytes} B`
  }
  if (bytes < 1024 * 1024) {
    return `${(bytes / 1024).toFixed(0)} KB`
  }
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
}

function getPrevalidationReasons({
  resumeFile,
  jdText,
  selectedOptionCount,
}: {
  resumeFile: File | null
  jdText: string
  selectedOptionCount: number
}): string[] {
  const reasons: string[] = []

  if (!resumeFile) {
    reasons.push(RESUME_REQUIRED_MESSAGE)
  } else if (!inferResumeMode(resumeFile)) {
    reasons.push(UNSUPPORTED_RESUME_FILE_MESSAGE)
  }

  const jdError = validateJdText(jdText)
  if (jdError) {
    reasons.push(jdError)
  }

  if (selectedOptionCount === 0) {
    reasons.push(ANALYSIS_OPTION_REQUIRED_MESSAGE)
  }

  return reasons
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

      {result.status === 'idle' ? <EmptyState title="아직 결과가 없습니다" message={description} /> : null}

      {result.status === 'loading' ? (
        <StatusMessage badge="Processing" title={result.title} message={result.message} tone="active" withLoadingBar />
      ) : null}

      {result.status === 'not-enabled' ? (
        <StatusMessage badge="Not Enabled" title={result.title} message={result.message} tone="success" />
      ) : null}

      {result.status === 'error' ? (
        <StatusMessage badge="Action Needed" title={result.title} message={result.message} tone="danger" />
      ) : null}

      {result.status === 'success' ? successContent : null}
    </section>
  )
}

function ComingSoonPanel({ title, description }: { title: string; description: string }) {
  return (
    <section className="preview-panel">
      <div className="preview-panel__header">
        <span>준비중</span>
        <div>
          <h2>{title}</h2>
          <p>{description}</p>
        </div>
      </div>
      <StatusMessage
        badge="Coming Soon"
        title="준비 중인 분석입니다"
        message="이 분석 항목은 현재 준비 중입니다. 곧 제공될 예정이에요."
        tone="neutral"
      />
    </section>
  )
}

function KeywordList({ items }: { items: string[] }) {
  if (items.length === 0) {
    return <p className="keyword-empty">해당 키워드가 없습니다.</p>
  }

  return (
    <ul className="keyword-list">
      {items.map((item) => (
        <li key={item}>{item}</li>
      ))}
    </ul>
  )
}

function App() {
  const [currentView, setCurrentView] = useState<'home' | 'interview'>('home')
  const [isSidebarOpen, setIsSidebarOpen] = useState(false)
  const [analysisPhase, setAnalysisPhase] = useState<AnalysisPhase>('input')
  const [jdTab, setJdTab] = useState<JdTab>('link')
  const [jdUrl, setJdUrl] = useState('')
  const [jdText, setJdText] = useState(() => loadSavedInput()?.jdText ?? '')
  const [resumeFile, setResumeFile] = useState<File | null>(null)
  const [isDragging, setIsDragging] = useState(false)
  const [options, setOptions] = useState<Record<AnalysisOptionKey, boolean>>(
    () => loadSavedInput()?.options ?? { ...DEFAULT_OPTIONS },
  )
  const [formError, setFormError] = useState('')
  const [submittedOptions, setSubmittedOptions] = useState<Record<AnalysisOptionKey, boolean>>({
    jdMatch: false,
    ats: false,
    sentence: false,
    keyword: false,
  })
  const [jobTitle, setJobTitle] = useState('')
  const resultRef = useRef<HTMLElement>(null)

  const { result: diagnoseResult, submitFile, resetResult: resetDiagnose } = useDiagnose()
  const {
    fetchJd,
    isFetchingJd,
    isSubmitting: isPreviewSubmitting,
    jdFetchState,
    resetResult: resetPreview,
    result: previewResult,
    submit: submitPreview,
  } = useMatchPreview()
  const {
    isSubmitting: isInterviewSubmitting,
    result: interviewResult,
    submit: submitInterview,
  } = useInterviewPreview()

  const trimmedJd = jdText.trim()
  const hasResumeSource = Boolean(diagnoseResult.status === 'success' && diagnoseResult.diagnosis?.sourceText)
  const selectedOptionKeys = ANALYSIS_OPTIONS.filter((option) => options[option.key]).map(
    (option) => option.key,
  )
  const prevalidationReasons = getPrevalidationReasons({
    resumeFile,
    jdText,
    selectedOptionCount: selectedOptionKeys.length,
  })
  const canStart = prevalidationReasons.length === 0

  useEffect(() => {
    if (analysisPhase === 'result') {
      resultRef.current?.focus()
    }
  }, [analysisPhase])

  useEffect(() => {
    try {
      window.localStorage.setItem(INPUT_STORAGE_KEY, JSON.stringify({ jdText, options }))
    } catch {
      // localStorage 비가용 시 무시
    }
  }, [jdText, options])

  const handleResetInput = () => {
    setJdText('')
    setJdUrl('')
    setOptions({ ...DEFAULT_OPTIONS })
    setFormError('')
    try {
      window.localStorage.removeItem(INPUT_STORAGE_KEY)
    } catch {
      // 무시
    }
  }

  const handleExportResult = () => {
    const match = previewResult.matchPreview
    if (!match) {
      return
    }
    const blob = new Blob([buildResultMarkdown(match, submittedOptions)], {
      type: 'text/markdown;charset=utf-8',
    })
    const url = URL.createObjectURL(blob)
    const anchor = document.createElement('a')
    anchor.href = url
    anchor.download = `jdsnack-분석결과-${todayStamp()}.md`
    document.body.appendChild(anchor)
    anchor.click()
    anchor.remove()
    URL.revokeObjectURL(url)
  }

  const handlePrintResult = () => {
    window.print()
  }

  const handleJdUrlChange = (value: string) => {
    setJdUrl(value)
    setFormError('')
  }

  const handleJdTextChange = (value: string) => {
    setJdText(value)
    setFormError('')
  }

  const handleJdFetch = async () => {
    await fetchJd(jdUrl, {
      onFetched: (fetched) => {
        setJdText(fetched.jdText)
      },
    })
  }

  const setFile = (file: File | null) => {
    setResumeFile(file)
    setFormError('')
  }

  const handleFileInput = (event: ChangeEvent<HTMLInputElement>) => {
    setFile(event.target.files?.[0] ?? null)
  }

  const handleDrop = (event: DragEvent<HTMLDivElement>) => {
    event.preventDefault()
    setIsDragging(false)
    const dropped = event.dataTransfer.files?.[0]
    if (dropped) {
      setFile(dropped)
    }
  }

  const toggleOption = (key: AnalysisOptionKey) => {
    setOptions((current) => ({ ...current, [key]: !current[key] }))
    setFormError('')
  }

  const handleStartAnalysis = async () => {
    if (!resumeFile) {
      setFormError(RESUME_REQUIRED_MESSAGE)
      return
    }
    const mode = inferResumeMode(resumeFile)
    if (!mode) {
      setFormError(UNSUPPORTED_RESUME_FILE_MESSAGE)
      return
    }
    const jdError = validateJdText(jdText)
    if (jdError) {
      setFormError(jdError)
      return
    }
    if (selectedOptionKeys.length === 0) {
      setFormError(ANALYSIS_OPTION_REQUIRED_MESSAGE)
      return
    }

    setFormError('')
    setSubmittedOptions({ ...options })
    resetDiagnose()
    resetPreview()
    setAnalysisPhase('result')

    if (options.jdMatch || options.keyword) {
      const outcome = await submitFile(mode, resumeFile)
      if (outcome.ok && outcome.diagnosis?.sourceText) {
        await submitPreview({
          resumeSource: { type: 'FILE', value: outcome.diagnosis.sourceText },
          jdText: trimmedJd,
          jdUrl: jdUrl.trim(),
        })
      }
    }
  }

  const handleNewAnalysis = () => {
    setAnalysisPhase('input')
    resetDiagnose()
    resetPreview()
  }

  const handleInterviewSubmit = async () => {
    const resumeSource =
      diagnoseResult.status === 'success' && diagnoseResult.diagnosis?.sourceText
        ? diagnoseResult.diagnosis.sourceText
        : ''
    await submitInterview({
      resumeSource: { type: 'FILE', value: resumeSource },
      jobTitle: jobTitle.trim(),
      jdText: trimmedJd,
    })
  }

  const renderInputView = () => (
    <section className="start-page" aria-label="새로운 분석 시작">
      <header className="start-page__head">
        <p className="start-page__eyebrow">분석 시작</p>
        <h1>새로운 분석 시작</h1>
        <p className="start-page__sub">채용 공고와 이력서를 연결하여 합격 가능성을 높이세요.</p>
      </header>

      <div className="start-layout">
        <div className="start-main">
          <section className="step-card" aria-label="채용 공고 입력">
            <h2 className="step-card__title">
              <span className="step-badge">1</span> 채용 공고 (JD) 입력
            </h2>
            <div className="jd-tabs" role="tablist" aria-label="JD 입력 방식">
              <button
                type="button"
                role="tab"
                aria-selected={jdTab === 'link'}
                className={`jd-tab${jdTab === 'link' ? ' jd-tab--active' : ''}`}
                onClick={() => setJdTab('link')}
              >
                JD 링크
              </button>
              <button
                type="button"
                role="tab"
                aria-selected={jdTab === 'paste'}
                className={`jd-tab${jdTab === 'paste' ? ' jd-tab--active' : ''}`}
                onClick={() => setJdTab('paste')}
              >
                JD 내용 붙여넣기
              </button>
            </div>

            {jdTab === 'link' ? (
              <div className="jd-link-row">
                <label className="field-label" htmlFor="jd-url">
                  채용 공고 URL
                </label>
                <div className="jd-link-controls">
                  <input
                    id="jd-url"
                    className="text-input"
                    type="url"
                    inputMode="url"
                    placeholder="https://careers.sample.com/jobs/123456"
                    value={jdUrl}
                    onChange={(event) => handleJdUrlChange(event.target.value)}
                  />
                  <button
                    type="button"
                    className="ghost-button"
                    onClick={handleJdFetch}
                    disabled={isFetchingJd || !jdUrl.trim()}
                  >
                    {isFetchingJd ? '불러오는 중...' : 'JD 불러오기'}
                  </button>
                </div>
                <p className="field-help">지원하는 사이트: 사람인 등 정적 채용 공고. 그 외 링크는 본문 붙여넣기로 진행하세요.</p>
                {jdFetchState.status !== 'idle' ? (
                  <p className={`field-help field-help--${jdFetchState.status}`} role={jdFetchState.status === 'fetch-error' ? 'alert' : undefined}>
                    {jdFetchState.message}
                  </p>
                ) : null}
              </div>
            ) : null}

            {jdTab === 'paste' ? (
              <div className="jd-paste-row">
                <label className="field-label" htmlFor="jd-text">
                  JD 내용 붙여넣기
                </label>
                <textarea
                  id="jd-text"
                  className="text-area"
                  placeholder="채용 공고의 전체 내용을 복사하여 붙여넣어 주세요."
                  value={jdText}
                  onChange={(event) => handleJdTextChange(event.target.value)}
                  rows={8}
                />
                <p className="char-count">
                  {jdText.length.toLocaleString()} / {JD_MAX_LENGTH.toLocaleString()}
                </p>
              </div>
            ) : null}

            {jdTab === 'link' && trimmedJd ? (
              <p className="field-help field-help--fetched">불러온 JD 본문이 준비되었습니다. ‘JD 내용 붙여넣기’ 탭에서 확인·수정할 수 있습니다.</p>
            ) : null}
          </section>

          <section className="step-card" aria-label="이력서 업로드">
            <h2 className="step-card__title">
              <span className="step-badge">2</span> 이력서 업로드
            </h2>
            <div
              className={`dropzone${isDragging ? ' dropzone--active' : ''}`}
              onDragOver={(event) => {
                event.preventDefault()
                setIsDragging(true)
              }}
              onDragLeave={() => setIsDragging(false)}
              onDrop={handleDrop}
            >
              <span className="dropzone__icon" aria-hidden="true">
                ⬆
              </span>
              <p className="dropzone__title">이력서 파일을 드래그하거나 클릭하여 업로드하세요</p>
              <p className="dropzone__hint">PDF, DOCX 파일을 지원합니다. (최대 10MB)</p>
              <label className="file-select-button" htmlFor="resume-file">
                파일 선택
              </label>
              <input
                id="resume-file"
                className="sr-only"
                type="file"
                accept=".pdf,.docx,application/pdf,application/vnd.openxmlformats-officedocument.wordprocessingml.document"
                onChange={handleFileInput}
              />
            </div>
            {resumeFile ? (
              <div className="file-chip">
                <div className="file-chip__info">
                  <span className="file-chip__name">{resumeFile.name}</span>
                  <span className="file-chip__meta">{formatFileSize(resumeFile.size)}</span>
                </div>
                <button type="button" className="file-chip__remove" aria-label="파일 제거" onClick={() => setFile(null)}>
                  ✕
                </button>
              </div>
            ) : null}
          </section>

          <section className="step-card" aria-label="분석 옵션 선택">
            <h2 className="step-card__title">
              <span className="step-badge">3</span> 분석 옵션 선택
            </h2>
            <p className="step-card__desc">필요한 분석 항목을 선택하세요. 선택한 항목에 따라 분석 결과가 제공됩니다.</p>
            <div className="option-grid">
              {ANALYSIS_OPTIONS.map((option) => (
                <label
                  key={option.key}
                  className={`option-card${options[option.key] ? ' option-card--checked' : ''}`}
                >
                  <input
                    type="checkbox"
                    checked={options[option.key]}
                    onChange={() => toggleOption(option.key)}
                  />
                  <span className="option-card__body">
                    <span className="option-card__title">
                      {option.label}
                      {option.recommended ? <span className="option-tag option-tag--rec">추천</span> : null}
                      {!option.enabled ? <span className="option-tag option-tag--soon">준비중</span> : null}
                    </span>
                    <span className="option-card__desc">{option.description}</span>
                  </span>
                </label>
              ))}
            </div>

            {formError ? (
              <p className="form-error" role="alert">
                {formError}
              </p>
            ) : null}
            {!canStart ? (
              <div className="gate-reasons" role="status" aria-live="polite">
                <p>분석 시작 전 확인이 필요합니다.</p>
                <ul>
                  {prevalidationReasons.map((reason) => (
                    <li key={reason}>{reason}</li>
                  ))}
                </ul>
              </div>
            ) : null}

            <div className="start-cta">
              <button
                type="button"
                className="cta-button"
                disabled={!canStart || isPreviewSubmitting}
                aria-disabled={!canStart || isPreviewSubmitting}
                onClick={handleStartAnalysis}
              >
                {isPreviewSubmitting ? '분석 중...' : '분석 시작하기 →'}
              </button>
              <button type="button" className="text-button" onClick={handleResetInput}>
                입력 초기화
              </button>
            </div>
            <p className="start-footer">🔒 입력하신 정보는 안전하게 처리되며, 분석 후 즉시 삭제됩니다.</p>
          </section>
        </div>

        <aside className="start-rail" aria-label="분석 안내">
          <section className="rail-card">
            <h3>분석이 이렇게 진행돼요</h3>
            <ol className="rail-steps">
              {PROGRESS_STEPS.map((step, index) => (
                <li key={step.title}>
                  <span className="rail-steps__num">{index + 1}</span>
                  <div>
                    <strong>{step.title}</strong>
                    <p>{step.description}</p>
                  </div>
                </li>
              ))}
            </ol>
          </section>

          <section className="rail-card">
            <h3>💡 분석 정확도를 높이는 팁</h3>
            <ul className="rail-tips">
              {ACCURACY_TIPS.map((tip) => (
                <li key={tip}>{tip}</li>
              ))}
            </ul>
          </section>

          <section className="rail-card">
            <h3>지원 가능한 파일 형식</h3>
            <div className="format-chips">
              <span className="format-chip">PDF</span>
              <span className="format-chip">DOCX</span>
            </div>
            <p className="rail-note">최대 10MB까지 업로드 가능합니다.</p>
          </section>
        </aside>
      </div>
    </section>
  )

  const renderResultView = () => (
    <section className="result-page" aria-label="분석 결과" ref={resultRef} tabIndex={-1}>
      <header className="result-page__head">
        <div>
          <p className="start-page__eyebrow">분석 결과</p>
          <h1>분석 결과</h1>
        </div>
        <div className="result-actions">
          {(submittedOptions.jdMatch || submittedOptions.keyword) && previewResult.status === 'success' ? (
            <>
              <button type="button" className="ghost-button" onClick={handleExportResult}>
                내보내기
              </button>
              <button type="button" className="ghost-button" onClick={handlePrintResult}>
                인쇄
              </button>
            </>
          ) : null}
          <button type="button" className="ghost-button" onClick={handleNewAnalysis}>
            새 분석
          </button>
        </div>
      </header>

      {submittedOptions.jdMatch ? (
        <div className="summary-grid">
          <SummaryCard
            label="JD 적합도"
            score={previewResult.matchPreview?.matchingScore}
            summary={previewResult.matchPreview?.summary}
            description="JD와 이력서 적합도를 계산하고 있습니다."
          />
        </div>
      ) : null}

      <div className="preview-grid">
        {submittedOptions.jdMatch ? (
          <AnalysisPanel
            badge="JD Match"
            title="JD 적합도"
            description="공고 강점과 gap, 보강 제안을 함께 확인하세요."
            result={previewResult}
            successContent={
              <div className="detail-list-grid detail-list-grid--triple">
                <section className="detail-card">
                  <h3>강점</h3>
                  <ul>{previewResult.matchPreview?.strengths.map((item) => <li key={item}>{item}</li>)}</ul>
                </section>
                <section className="detail-card">
                  <h3>Gap</h3>
                  <ul>{previewResult.matchPreview?.gaps.map((item) => <li key={item}>{item}</li>)}</ul>
                </section>
                <section className="detail-card">
                  <h3>제안</h3>
                  <ul>{previewResult.matchPreview?.suggestions.map((item) => <li key={item}>{item}</li>)}</ul>
                </section>
              </div>
            }
          />
        ) : null}

        {submittedOptions.ats ? <ComingSoonPanel title="ATS 분석" description="ATS 통과 가능성과 포맷 최적화." /> : null}
        {submittedOptions.sentence ? (
          <ComingSoonPanel title="문장 첨삭" description="문장 표현·가독성·문법 개선 제안." />
        ) : null}
        {submittedOptions.keyword ? (
          <AnalysisPanel
            badge="Keyword Match"
            title="키워드 분석"
            description="JD 핵심 키워드가 이력서에 얼마나 반영됐는지 확인하세요."
            result={previewResult}
            successContent={
              <div className="detail-list-grid detail-list-grid--triple" aria-label="키워드 분석 결과">
                <section className="detail-card">
                  <h3>매칭 키워드</h3>
                  <KeywordList items={previewResult.matchPreview?.matchedKeywords ?? []} />
                </section>
                <section className="detail-card">
                  <h3>부분 매칭</h3>
                  <KeywordList items={previewResult.matchPreview?.partialKeywords ?? []} />
                </section>
                <section className="detail-card">
                  <h3>누락 키워드</h3>
                  <KeywordList items={previewResult.matchPreview?.missingKeywords ?? []} />
                </section>
              </div>
            }
          />
        ) : null}
      </div>
    </section>
  )

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
        analysisPhase === 'input' ? (
          renderInputView()
        ) : (
          renderResultView()
        )
      ) : (
        <section className="interview-shell" aria-label="모의 면접 화면">
          <section className="hero-card hero-card--compact">
            <p className="hero-card__eyebrow">Mock Interview</p>
            <h1>현재 이력서와 JD 맥락으로 예상 질문을 빠르게 준비하세요.</h1>
            <p className="hero-card__copy">
              분석에서 추출한 이력서 본문과 JD를 그대로 이어받고, 직무명만 보강해 질문 세트를 만듭니다.
            </p>
          </section>

          <div className="interview-layout">
            <section className="workspace-card">
              <div className="workspace-card__header">
                <div>
                  <span>Interview Input</span>
                  <h2>질문 생성 준비</h2>
                </div>
                <p>분석 단계에서 만든 이력서·JD 맥락을 이어받아 질문을 생성합니다.</p>
              </div>

              <div className="interview-form">
                <label className="resume-input-group" htmlFor="job-title">
                  <span className="resume-label">대상 직무</span>
                  <input
                    id="job-title"
                    className="text-input"
                    type="text"
                    value={jobTitle}
                    placeholder="예: 백엔드 개발자"
                    onChange={(event) => setJobTitle(event.target.value)}
                  />
                </label>

                <div className="context-note">
                  <h3>연결된 분석 맥락</h3>
                  <ul>
                    <li>이력서 소스: {hasResumeSource ? '준비됨' : '먼저 홈에서 분석을 실행해 주세요.'}</li>
                    <li>JD 본문: {trimmedJd ? '준비됨' : '홈에서 JD를 입력해 주세요.'}</li>
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

import { useEffect, useRef, useState } from 'react'
import { ResumeFileInput } from './components/ResumeFileInput'
import { ResumeModeTabs } from './components/ResumeModeTabs'
import { DiagnoseButton } from './components/DiagnoseButton'
import { ResultPanel } from './components/ResultPanel'
import { ResumeInput } from './components/ResumeInput'
import { useDiagnose } from './hooks/useDiagnose'
import { JdInputFields } from './components/JdInputFields'
import { StatusMessage } from './components/StatusMessage'
import { useMatchPreview } from './hooks/useMatchPreview'
import type { ResumeInputMode } from './types/diagnosis'
import './App.css'

const LOCAL_STORAGE_KEY = 'jdsnack.resume-text'
const MIN_LENGTH = 50
const MAX_LENGTH = 10_000

function App() {
  const [inputMode, setInputMode] = useState<ResumeInputMode>('text')
  const [resumeText, setResumeText] = useState(() => {
    if (typeof window === 'undefined') {
      return ''
    }

    return window.localStorage.getItem(LOCAL_STORAGE_KEY) ?? ''
  })
  const [resumeFile, setResumeFile] = useState<File | null>(null)
  const [jdText, setJdText] = useState('')
  const [jdUrl, setJdUrl] = useState('')
  const [currentStep, setCurrentStep] = useState(1)
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
  const resultRef = useRef<HTMLElement>(null)
  const trimmedLength = resumeText.trim().length
  const trimmedResumeText = resumeText.trim()
  const resumeSourceForPreview =
    inputMode === 'text'
      ? trimmedResumeText
      : result.status === 'success' && result.diagnosis?.sourceText
        ? result.diagnosis.sourceText
        : ''
  const canPreviewWithCurrentSource =
    inputMode === 'text'
      ? trimmedLength >= MIN_LENGTH && trimmedLength <= MAX_LENGTH
      : Boolean(resumeSourceForPreview)
  const derivedStep =
    previewResult.status === 'success' ||
    previewResult.status === 'loading' ||
    previewResult.status === 'error'
      ? 3
      : jdText.trim() || jdUrl.trim() || result.status === 'success'
        ? 2
        : 1
  const activeStep = Math.max(currentStep, derivedStep)

  useEffect(() => {
    window.localStorage.setItem(LOCAL_STORAGE_KEY, resumeText)
  }, [resumeText])

  useEffect(() => {
    if (
      result.status === 'success' ||
      result.status === 'not-enabled' ||
      result.status === 'error'
    ) {
      resultRef.current?.focus()
    }
  }, [result.status])

  useEffect(() => {
    if (result.status === 'success') {
      setCurrentStep((step) => Math.max(step, 2))
    }
  }, [result.status])

  useEffect(() => {
    if (
      previewResult.status === 'loading' ||
      previewResult.status === 'success' ||
      previewResult.status === 'error'
    ) {
      setCurrentStep(3)
    }
  }, [previewResult.status])

  const handleResumeChange = (nextValue: string) => {
    setResumeText(nextValue)

    if (inlineError) {
      clearInlineError()
    }

    if (result.status !== 'idle' && result.status !== 'loading') {
      resetResult()
    }
  }

  const handleModeChange = (nextMode: ResumeInputMode) => {
    setInputMode(nextMode)
    setResumeFile(null)
    clearInlineError()

    if (result.status !== 'idle' && result.status !== 'loading') {
      resetResult()
    }
  }

  const handleFileChange = (nextFile: File | null) => {
    setResumeFile(nextFile)
    clearInlineError()

    if (result.status !== 'idle' && result.status !== 'loading') {
      resetResult()
    }
  }

  const handleJdTextChange = (nextValue: string) => {
    setJdText(nextValue)
    if (jdTextError || jdUrlError) {
      clearJdErrors()
    }
    if (jdFetchState.status !== 'idle') {
      resetJdFetchState()
    }
    if (previewResult.status !== 'idle' && previewResult.status !== 'loading') {
      resetPreviewResult()
    }
  }

  const handleJdUrlChange = (nextValue: string) => {
    setJdUrl(nextValue)
    if (jdTextError || jdUrlError) {
      clearJdErrors()
    }
    if (jdFetchState.status !== 'idle') {
      resetJdFetchState()
    }
    if (previewResult.status !== 'idle' && previewResult.status !== 'loading') {
      resetPreviewResult()
    }
  }

  const handleJdFetch = async () => {
    await fetchJd(jdUrl, {
      onBeforeChange: () => {
        if (previewResult.status !== 'idle' && previewResult.status !== 'loading') {
          resetPreviewResult()
        }
      },
      onFetched: (nextJdText) => {
        setJdText(nextJdText)
      },
    })
  }

  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()

    if (inputMode === 'text') {
      await submit(resumeText)
      return
    }

    await submitFile(inputMode, resumeFile)
  }

  const handleJdPreviewSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()

    await submitPreview({
      resumeSource: {
        type: inputMode === 'text' ? 'TEXT' : 'FILE',
        value: resumeSourceForPreview,
      },
      jdText,
      jdUrl: jdUrl.trim(),
    })
  }

  return (
    <div className="app-shell">
      <main className="page">
        <header className="product-header">
          <p className="product-kicker">JDSnack AI Matching</p>
          <h1>이력서와 채용공고를 한 번에 비교하세요</h1>
          <p>이력서를 준비하고, JD를 불러온 뒤, 마지막 페이지에서 AI 매칭 리포트를 확인합니다.</p>
        </header>

        <section className="stepper-card" aria-label="현재 진행 단계">
          <ol className="flow-steps">
            {['이력서 작성', 'JD 입력', 'AI 분석 리포트'].map((label, index) => {
              const stepNumber = index + 1
              const state =
                currentStep === stepNumber
                  ? 'current'
                  : activeStep > stepNumber
                    ? 'complete'
                    : 'upcoming'

              return (
                <li key={label} className={`flow-step flow-step--${state}`}>
                  <button
                    type="button"
                    className="flow-step__button"
                    onClick={() => setCurrentStep(stepNumber)}
                    disabled={stepNumber === 3 && activeStep < 3}
                  >
                    <span className="flow-step__index">{stepNumber}</span>
                    <strong>{label}</strong>
                  </button>
                </li>
              )
            })}
          </ol>
        </section>

        <section className="wizard-stage">
          {currentStep === 1 ? (
            <form className="panel input-panel wizard-panel wizard-panel--resume" onSubmit={handleSubmit}>
              <div className="panel-header">
                <div>
                  <p className="panel-eyebrow">Step 1</p>
                  <h2>이력서 작성</h2>
                  <p className="panel-description">
                    텍스트를 붙여넣거나 PDF/DOCX에서 이력서 본문을 추출합니다.
                  </p>
                </div>
                <p className="inline-counter" aria-live="polite">
                  {inputMode === 'text'
                    ? `${trimmedLength.toLocaleString()} / ${MAX_LENGTH.toLocaleString()}자`
                    : resumeFile
                      ? '파일 준비됨'
                      : '파일 필요'}
                </p>
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

              <div className="action-row action-row--right">
                <DiagnoseButton isSubmitting={isSubmitting} />
                {inputMode === 'text' && trimmedLength >= MIN_LENGTH ? (
                  <button className="ghost-button" type="button" onClick={() => setCurrentStep(2)}>
                    JD 입력으로 이동
                  </button>
                ) : null}
              </div>

              {result.status !== 'idle' && result.status !== 'success' ? (
                <div className="inline-result">
                  <ResultPanel ref={resultRef} result={result} />
                </div>
              ) : null}
            </form>
          ) : null}

          {currentStep === 2 ? (
            <section className="panel jd-panel wizard-panel wizard-panel--jd">
              <div className="panel-header">
                <div>
                  <p className="panel-eyebrow">Step 2</p>
                  <h2>JD 입력</h2>
                  <p className="panel-description">
                    JD 본문을 붙여넣거나 사람인 링크를 불러와 공고 본문을 자동 채웁니다.
                  </p>
                </div>
                <p className="inline-counter" aria-live="polite">
                  {canPreviewWithCurrentSource ? '이력서 연결됨' : '이력서 필요'}
                </p>
              </div>

              <form className="jd-form" onSubmit={handleJdPreviewSubmit}>
                <JdInputFields
                  jdText={jdText}
                  jdUrl={jdUrl}
                  jdFetchStatus={jdFetchState.status}
                  jdFetchTitle={jdFetchState.title}
                  jdFetchMessage={jdFetchState.message}
                  jdTextError={jdTextError}
                  jdUrlError={jdUrlError}
                  isFetchingJd={isFetchingJd}
                  onJdTextChange={handleJdTextChange}
                  onJdUrlChange={handleJdUrlChange}
                  onJdFetch={handleJdFetch}
                />

                <div className="action-row action-row--right jd-action-row">
                  <button className="ghost-button" type="button" onClick={() => setCurrentStep(1)}>
                    이력서 수정
                  </button>
                  <DiagnoseButton
                    isSubmitting={isPreviewSubmitting}
                    idleLabel="AI 분석 리포트 생성"
                    loadingLabel="AI 리포트 생성 중..."
                    disabled={!canPreviewWithCurrentSource}
                  />
                </div>
              </form>
            </section>
          ) : null}

          {currentStep === 3 ? (
            <div className="report-column wizard-panel wizard-panel--report">
              {previewResult.status === 'success' && previewResult.matchPreview ? (
                <section className="panel analysis-result jd-preview-result">
                  <div className="panel-header">
                    <div>
                      <p className="panel-eyebrow">Step 3</p>
                      <h2>이력서 + JD AI 분석 리포트</h2>
                      <p className="panel-description">
                        이력서와 채용공고 사이의 강점, 부족한 역량, 개선 제안을 요약했습니다.
                      </p>
                    </div>
                  </div>

                  <section className="report-hero-card">
                    <div className="analysis-score-card analysis-score-card--circle">
                      <strong>{previewResult.matchPreview.matchingScore}점</strong>
                      <span>매칭 점수</span>
                    </div>
                    <div className="report-summary-card">
                      <span className="report-summary-label">핵심 요약</span>
                      <h3>{previewResult.title}</h3>
                      <p>{previewResult.message}</p>
                    </div>
                  </section>

                  <div className="analysis-feedback-grid">
                    <section className="analysis-feedback-card analysis-feedback-card--strength">
                      <h3>강점</h3>
                      <ul>
                        {previewResult.matchPreview.strengths.map((strength) => (
                          <li key={strength}>{strength}</li>
                        ))}
                      </ul>
                    </section>

                    <section className="analysis-feedback-card analysis-feedback-card--improve">
                      <h3>보완 포인트</h3>
                      <ul>
                        {previewResult.matchPreview.gaps.map((gap) => (
                          <li key={gap}>{gap}</li>
                        ))}
                      </ul>
                    </section>
                  </div>

                  <section className="analysis-feedback-card analysis-feedback-card--suggestion">
                    <h3>개선 제안</h3>
                    <ul>
                      {previewResult.matchPreview.suggestions.map((suggestion) => (
                        <li key={suggestion}>{suggestion}</li>
                      ))}
                    </ul>
                  </section>

                  <div className="action-row action-row--center">
                    <button className="ghost-button" type="button" onClick={() => setCurrentStep(2)}>
                      JD 다시 수정
                    </button>
                    <button className="ghost-button" type="button" onClick={() => setCurrentStep(1)}>
                      이력서 다시 수정
                    </button>
                  </div>
                </section>
              ) : (
                <ResultPanel ref={resultRef} result={result} />
              )}

              {previewResult.status === 'loading' ? (
                <StatusMessage
                  badge="Preparing"
                  title={previewResult.title}
                  message={previewResult.message}
                  tone="active"
                  withLoadingBar
                />
              ) : null}

              {previewResult.status === 'error' ? (
                <StatusMessage
                  badge="Check Input"
                  title={previewResult.title}
                  message={`${previewResult.message} JD 본문을 직접 붙여넣어 주세요.`}
                  tone="danger"
                />
              ) : null}
            </div>
          ) : null}
        </section>
      </main>
    </div>
  )
}

export default App

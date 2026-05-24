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
  const activeStep =
    previewResult.status === 'success' ||
    previewResult.status === 'loading' ||
    previewResult.status === 'error'
      ? 3
      : jdText.trim() || jdUrl.trim() || result.status === 'success'
        ? 2
        : 1

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
        <section className="hero-card">
          <div className="hero-copy">
            <p className="hero-eyebrow">JDSnack Report Flow</p>
            <h1>이력서에서 JD 비교까지 리포트 흐름으로 정리합니다</h1>
            <p className="hero-description">
              이력서 입력, JD 본문 준비, 분석 리포트를 한 화면에서 단계형으로
              이어서 확인할 수 있습니다. 먼저 분석 결과를 읽고, 다음에 JD 비교를
              이어가는 흐름이 더 잘 보이도록 정리했습니다.
            </p>
          </div>
          <div className="hero-stats" aria-label="현재 MVP 범위">
            <div className="stat-card">
              <span className="stat-label">입력 기준</span>
              <strong>50 - 10,000자</strong>
            </div>
            <div className="stat-card">
              <span className="stat-label">분석 모드</span>
              <strong>Stub / Fixture / AI Local</strong>
            </div>
            <div className="stat-card">
              <span className="stat-label">현재 화면 흐름</span>
              <strong>이력서 입력 / JD 입력 / 분석 리포트</strong>
            </div>
          </div>
        </section>

        <section className="stepper-card" aria-label="현재 진행 단계">
          <ol className="flow-steps">
            {[
              ['이력서', '이력서 입력과 1차 분석'],
              ['JD', 'JD 본문 준비와 링크 보조'],
              ['리포트', '분석 결과와 JD 비교 확인'],
            ].map(([label, description], index) => {
              const stepNumber = index + 1
              const state =
                activeStep === stepNumber
                  ? 'current'
                  : activeStep > stepNumber
                    ? 'complete'
                    : 'upcoming'

              return (
                <li key={label} className={`flow-step flow-step--${state}`}>
                  <span className="flow-step__index">{stepNumber}</span>
                  <div>
                    <strong>{label}</strong>
                    <p>{description}</p>
                  </div>
                </li>
              )
            })}
          </ol>
        </section>

        <section className="workspace-grid">
          <form className="panel input-panel" onSubmit={handleSubmit}>
            <div className="panel-header">
              <div>
                <p className="panel-eyebrow">Step 1</p>
                <h2>
                  {inputMode === 'text'
                    ? '이력서 내용을 붙여넣어 주세요'
                    : `${inputMode.toUpperCase()} 이력서를 업로드해 주세요`}
                </h2>
              </div>
              {inputMode === 'text' ? (
                <div className="counter-box" aria-live="polite">
                  <span>공백 제외</span>
                  <strong>{trimmedLength.toLocaleString()}자</strong>
                </div>
              ) : (
                <div className="counter-box" aria-live="polite">
                  <span>선택 상태</span>
                  <strong>{resumeFile ? '파일 준비됨' : '파일 필요'}</strong>
                </div>
              )}
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

            <div className="action-row">
              <p className="action-hint">
                {inputMode === 'text'
                  ? '입력값은 브라우저에만 임시 저장되고, 사용자 비밀키 입력은 받지 않습니다.'
                  : '업로드 파일은 분석 요청에만 사용되고, 사용자 비밀키 입력은 받지 않습니다.'}
              </p>
              <DiagnoseButton isSubmitting={isSubmitting} />
            </div>
          </form>

          <ResultPanel ref={resultRef} result={result} />
        </section>

        <section className="panel jd-panel">
          <div className="panel-header">
            <div>
              <p className="panel-eyebrow">Step 2</p>
              <h2>JD 본문을 준비하고 비교 기준을 맞춥니다</h2>
            </div>
            <div className="counter-box" aria-live="polite">
              <span>이력서 연결 상태</span>
              <strong>{canPreviewWithCurrentSource ? '준비됨' : '이력서 필요'}</strong>
            </div>
          </div>

          <div className="jd-source-card">
            <strong>현재 연결 소스</strong>
            <p>
              {inputMode === 'text'
                ? '텍스트 이력서는 현재 입력값을 기준으로 JD 비교 미리보기를 생성합니다.'
                : canPreviewWithCurrentSource
                  ? '업로드 이력서는 최근 분석 성공 응답의 추출 텍스트를 기준으로 JD 비교 미리보기를 생성합니다.'
                  : '파일 업로드 모드에서는 먼저 분석 요청이 성공해야 JD 비교 미리보기로 이어집니다.'}
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

            <div className="action-row jd-action-row">
              <p className="action-hint">
                기본은 규칙 기반 비교를 사용하고, `ai-local`에서는 Gemini 기준 JD 매칭 결과를 보여줍니다.
              </p>
              <DiagnoseButton
                isSubmitting={isPreviewSubmitting}
                idleLabel="JD 비교 미리보기"
                loadingLabel="JD 비교 미리보기 생성 중..."
                disabled={!canPreviewWithCurrentSource}
              />
            </div>
          </form>

          {previewResult.status === 'success' && previewResult.matchPreview ? (
            <div className="analysis-result jd-preview-result">
              <StatusMessage
                badge="Step 3"
                title={previewResult.title}
                message={previewResult.message}
                tone="success"
              />

              <div className="analysis-score-card">
                <span>JD 매칭 미리보기 점수</span>
                <strong>{previewResult.matchPreview.matchingScore}점</strong>
              </div>

              <div className="analysis-feedback-grid">
                <section className="analysis-feedback-card">
                  <h3>강점</h3>
                  <ul>
                    {previewResult.matchPreview.strengths.map((strength) => (
                      <li key={strength}>{strength}</li>
                    ))}
                  </ul>
                </section>

                <section className="analysis-feedback-card">
                  <h3>보완 포인트</h3>
                  <ul>
                    {previewResult.matchPreview.gaps.map((gap) => (
                      <li key={gap}>{gap}</li>
                    ))}
                  </ul>
                </section>
              </div>

              <section className="analysis-feedback-card jd-suggestion-card">
                <h3>다음 보완 제안</h3>
                <ul>
                  {previewResult.matchPreview.suggestions.map((suggestion) => (
                    <li key={suggestion}>{suggestion}</li>
                  ))}
                </ul>
              </section>
            </div>
          ) : null}

          {previewResult.status === 'loading' ? (
            <StatusMessage
              badge="Preparing"
              title={previewResult.title}
              message={previewResult.message}
              tone="active"
              withLoadingBar
            />
          ) : null}

          {previewResult.status === 'idle' ? (
            <StatusMessage
              badge="Next Step"
              title={previewResult.title}
              message={previewResult.message}
              tone="neutral"
            />
          ) : null}

          {previewResult.status === 'error' ? (
            <StatusMessage
              badge="Check Input"
              title={previewResult.title}
              message={previewResult.message}
              tone="danger"
            />
          ) : null}
        </section>
      </main>
    </div>
  )
}

export default App

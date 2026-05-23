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
    isSubmitting: isPreviewSubmitting,
    jdTextError,
    jdUrlError,
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
    if (previewResult.status !== 'idle' && previewResult.status !== 'loading') {
      resetPreviewResult()
    }
  }

  const handleJdUrlChange = (nextValue: string) => {
    setJdUrl(nextValue)
    if (jdTextError || jdUrlError) {
      clearJdErrors()
    }
    if (previewResult.status !== 'idle' && previewResult.status !== 'loading') {
      resetPreviewResult()
    }
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
            <p className="hero-eyebrow">JDSnack 1차 MVP</p>
            <h1>이력서 분석 흐름을 먼저 완성합니다</h1>
            <p className="hero-description">
              이력서 입력, 길이 검증, fixture 분석, 로컬 AI 분석까지 한 화면에서
              안정적으로 확인할 수 있습니다. 사용자 키 입력 없이 서버 환경변수
              기반 분석 흐름을 검증합니다.
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
              <span className="stat-label">현재 응답</span>
              <strong>200 분석 결과 / JD 미리보기</strong>
            </div>
          </div>
        </section>

        <section className="workspace-grid">
          <form className="panel input-panel" onSubmit={handleSubmit}>
            <div className="panel-header">
              <div>
                <p className="panel-eyebrow">Resume Input</p>
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
                  ? '입력값은 브라우저에만 임시 저장되고, API Key 같은 인증 정보는 받지 않습니다.'
                  : '업로드 파일은 분석 요청에만 사용되고, 사용자 인증 키 입력은 받지 않습니다.'}
              </p>
              <DiagnoseButton isSubmitting={isSubmitting} />
            </div>
          </form>

          <ResultPanel ref={resultRef} result={result} />
        </section>

        <section className="panel jd-panel">
          <div className="panel-header">
            <div>
              <p className="panel-eyebrow">JD Intake</p>
              <h2>JD 입력과 비교 요청 형식을 준비합니다</h2>
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
              jdTextError={jdTextError}
              jdUrlError={jdUrlError}
              onJdTextChange={handleJdTextChange}
              onJdUrlChange={handleJdUrlChange}
            />

            <div className="action-row jd-action-row">
              <p className="action-hint">
                현재는 AI 대신 키워드 기준 미리보기 결과를 먼저 보여줍니다.
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
                badge="Preview Result"
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

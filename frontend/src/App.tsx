import { useEffect, useRef, useState } from 'react'
import { DiagnoseButton } from './components/DiagnoseButton'
import { ResultPanel } from './components/ResultPanel'
import { ResumeInput } from './components/ResumeInput'
import { useDiagnose } from './hooks/useDiagnose'
import './App.css'

const LOCAL_STORAGE_KEY = 'jdsnack.resume-text'
const MIN_LENGTH = 50
const MAX_LENGTH = 10_000

function App() {
  const [resumeText, setResumeText] = useState(() => {
    if (typeof window === 'undefined') {
      return ''
    }

    return window.localStorage.getItem(LOCAL_STORAGE_KEY) ?? ''
  })
  const { clearInlineError, inlineError, isSubmitting, resetResult, result, submit } =
    useDiagnose()
  const resultRef = useRef<HTMLElement>(null)
  const trimmedLength = resumeText.trim().length

  useEffect(() => {
    window.localStorage.setItem(LOCAL_STORAGE_KEY, resumeText)
  }, [resumeText])

  useEffect(() => {
    if (result.status === 'not-enabled' || result.status === 'error') {
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

  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    await submit(resumeText)
  }

  return (
    <div className="app-shell">
      <main className="page">
        <section className="hero-card">
          <div className="hero-copy">
            <p className="hero-eyebrow">JDSnack 1차 MVP</p>
            <h1>이력서 분석 흐름을 먼저 완성합니다</h1>
            <p className="hero-description">
              아직 AI 분석은 연결하지 않았습니다. 대신 이력서 입력, 길이 검증, 요청
              상태, 준비중 안내까지 한 화면에서 안정적으로 확인할 수 있습니다.
            </p>
          </div>
          <div className="hero-stats" aria-label="현재 MVP 범위">
            <div className="stat-card">
              <span className="stat-label">입력 기준</span>
              <strong>50 - 10,000자</strong>
            </div>
            <div className="stat-card">
              <span className="stat-label">API 상태</span>
              <strong>No Key</strong>
            </div>
            <div className="stat-card">
              <span className="stat-label">현재 응답</span>
              <strong>501 준비중</strong>
            </div>
          </div>
        </section>

        <section className="workspace-grid">
          <form className="panel input-panel" onSubmit={handleSubmit}>
            <div className="panel-header">
              <div>
                <p className="panel-eyebrow">Resume Input</p>
                <h2>이력서 내용을 붙여넣어 주세요</h2>
              </div>
              <div className="counter-box" aria-live="polite">
                <span>공백 제외</span>
                <strong>{trimmedLength.toLocaleString()}자</strong>
              </div>
            </div>

            <ResumeInput
              value={resumeText}
              onChange={handleResumeChange}
              minLength={MIN_LENGTH}
              maxLength={MAX_LENGTH}
              currentLength={trimmedLength}
              errorMessage={inlineError}
            />

            <div className="action-row">
              <p className="action-hint">
                입력값은 브라우저에만 임시 저장되고, API Key 같은 인증 정보는 받지
                않습니다.
              </p>
              <DiagnoseButton isSubmitting={isSubmitting} />
            </div>
          </form>

          <ResultPanel ref={resultRef} result={result} />
        </section>
      </main>
    </div>
  )
}

export default App

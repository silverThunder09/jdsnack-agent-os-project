import type { FormEvent, RefObject } from 'react'
import { useEffect, useRef, useState } from 'react'
import { useDiagnose } from './hooks/useDiagnose'
import { useInterviewPreview } from './hooks/useInterviewPreview'
import { useMatchPreview } from './hooks/useMatchPreview'
import type { JdFetchResult, JdSections, ResumeInputMode, ResultState } from './types/diagnosis'
import { AppShell } from './components/AppShell'
import { DiagnoseButton } from './components/DiagnoseButton'
import { JdInputFields } from './components/JdInputFields'
import { ResumeFileInput } from './components/ResumeFileInput'
import { ResumeInput } from './components/ResumeInput'
import { ResumeModeTabs } from './components/ResumeModeTabs'
import { StatusMessage } from './components/StatusMessage'
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
  const startPattern = starts.join('|')
  const stopPattern = stops.join('|')
  const match = normalized.match(
    new RegExp(`(?:${startPattern})\\s*[:：]?\\s*([\\s\\S]*?)(?=\\n\\s*(?:${stopPattern})\\s*[:：]?|$)`, 'i'),
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

function EmptyPanel({ title, message }: { title: string; message: string }) {
  return (
    <StatusMessage
      badge="Ready"
      title={title}
      message={message}
      tone="neutral"
    />
  )
}

function ResumeResultPanel({
  result,
  resultRef,
}: {
  result: ResultState
  resultRef: RefObject<HTMLElement | null>
}) {
  const diagnosis = result.diagnosis

  return (
    <section className="dashboard-panel" aria-live="polite" ref={resultRef} tabIndex={-1}>
      <div className="dashboard-panel__header">
        <span>Resume</span>
        <h2>이력서 진단</h2>
      </div>

      {result.status === 'idle' ? (
        <EmptyPanel
          title="아직 결과가 없습니다"
          message="좌측 입력 레일에서 이력서 진단을 실행하세요."
        />
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
        <StatusMessage badge="Not Enabled" title={result.title} message={result.message} tone="success" />
      ) : null}

      {result.status === 'error' ? (
        <StatusMessage
          badge="Action Needed"
          title={result.title}
          message={`${result.message} 이력서 내용을 확인한 뒤 다시 요청해 주세요.`}
          tone="danger"
        />
      ) : null}

      {result.status === 'success' && diagnosis ? (
        <div className="dashboard-result">
          <div className="score-strip">
            <strong>{diagnosis.score}점</strong>
            <p>{diagnosis.summary}</p>
          </div>
          <div className="panel-list-grid">
            <section>
              <h3>강점</h3>
              <ul>
                {diagnosis.strengths.map((strength) => (
                  <li key={strength}>{strength}</li>
                ))}
              </ul>
            </section>
            <section>
              <h3>개선 제안</h3>
              <ul>
                {diagnosis.improvements.map((improvement) => (
                  <li key={improvement}>{improvement}</li>
                ))}
              </ul>
            </section>
          </div>
        </div>
      ) : null}
    </section>
  )
}

function MatchResultPanel({ result }: { result: ResultState }) {
  const matchPreview = result.matchPreview

  return (
    <section className="dashboard-panel" aria-live="polite">
      <div className="dashboard-panel__header">
        <span>JD Match</span>
        <h2>JD 매칭</h2>
      </div>

      {result.status === 'idle' ? (
        <EmptyPanel
          title="아직 결과가 없습니다"
          message="이력서와 JD를 준비한 뒤 JD 매칭을 실행하세요."
        />
      ) : null}

      {result.status === 'loading' ? (
        <StatusMessage
          badge="Preparing"
          title={result.title}
          message={result.message}
          tone="active"
          withLoadingBar
        />
      ) : null}

      {result.status === 'error' ? (
        <StatusMessage
          badge="Check Input"
          title={result.title}
          message={`${result.message} 입력값은 보존됩니다.`}
          tone="danger"
        />
      ) : null}

      {result.status === 'success' && matchPreview ? (
        <div className="dashboard-result">
          <div className="score-strip score-strip--match">
            <strong>{matchPreview.matchingScore}점</strong>
            <p>{matchPreview.summary}</p>
          </div>
          <div className="panel-list-grid">
            <section>
              <h3>강점</h3>
              <ul>
                {matchPreview.strengths.map((strength) => (
                  <li key={strength}>{strength}</li>
                ))}
              </ul>
            </section>
            <section>
              <h3>Gap</h3>
              <ul>
                {matchPreview.gaps.map((gap) => (
                  <li key={gap}>{gap}</li>
                ))}
              </ul>
            </section>
            <section>
              <h3>제안</h3>
              <ul>
                {matchPreview.suggestions.map((suggestion) => (
                  <li key={suggestion}>{suggestion}</li>
                ))}
              </ul>
            </section>
          </div>
        </div>
      ) : null}
    </section>
  )
}

function InterviewResultPanel({ result }: { result: ResultState }) {
  const interviewPreview = result.interviewPreview

  return (
    <section className="dashboard-panel" aria-live="polite">
      <div className="dashboard-panel__header">
        <span>Interview</span>
        <h2>모의 면접 질문</h2>
      </div>

      {result.status === 'idle' ? (
        <EmptyPanel
          title="아직 결과가 없습니다"
          message="이력서와 선택 직무 맥락으로 면접 질문을 생성하세요."
        />
      ) : null}

      {result.status === 'loading' ? (
        <StatusMessage
          badge="Preparing"
          title={result.title}
          message={result.message}
          tone="active"
          withLoadingBar
        />
      ) : null}

      {result.status === 'error' ? (
        <StatusMessage
          badge="Retry"
          title={result.title}
          message={`${result.message} 입력값은 보존됩니다.`}
          tone="danger"
        />
      ) : null}

      {result.status === 'success' && interviewPreview ? (
        <div className="dashboard-result interview-result">
          <p className="submission-guide">{interviewPreview.strategy}</p>
          <div className="interview-question-list">
            {interviewPreview.questions.map((question) => (
              <article className="interview-question-card" key={question.question}>
                <span>{question.category}</span>
                <h3>{question.question}</h3>
                <p>{question.keypoints}</p>
              </article>
            ))}
          </div>
        </div>
      ) : null}
    </section>
  )
}

function App() {
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
  const resultRef = useRef<HTMLElement>(null)
  const trimmedLength = resumeText.trim().length
  const trimmedResumeText = resumeText.trim()
  const resumeSourceForPreview =
    inputMode === 'text'
      ? trimmedResumeText
      : result.status === 'success' && result.diagnosis?.sourceText
        ? result.diagnosis.sourceText
        : ''
  const canUseCurrentSource =
    inputMode === 'text'
      ? trimmedLength >= MIN_LENGTH && trimmedLength <= MAX_LENGTH
      : Boolean(resumeSourceForPreview)
  const jdText = joinJdSections(jdSections)

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
    if (previewResult.status !== 'idle' && previewResult.status !== 'loading') {
      resetPreviewResult()
    }
    if (interviewResult.status !== 'idle' && interviewResult.status !== 'loading') {
      resetInterviewResult()
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

  const handleJobTitleChange = (nextValue: string) => {
    setJobTitle(nextValue)
    if (interviewResult.status !== 'idle' && interviewResult.status !== 'loading') {
      resetInterviewResult()
    }
  }

  const handleJdFetch = async () => {
    await fetchJd(jdUrl, {
      onBeforeChange: () => {
        if (previewResult.status !== 'idle' && previewResult.status !== 'loading') {
          resetPreviewResult()
        }
      },
      onFetched: (fetched) => {
        setJdSections((current) => mergeFetchedSections(current, fetched))
        setIsJdAutofilled(true)
      },
    })
  }

  const handleResumeSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()

    if (inputMode === 'text') {
      await submit(resumeText)
      return
    }

    await submitFile(inputMode, resumeFile)
  }

  const handleJdPreviewSubmit = async (event: FormEvent<HTMLFormElement>) => {
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

  const handleInterviewSubmit = async () => {
    await submitInterview({
      resumeSource: {
        type: inputMode === 'text' ? 'TEXT' : 'FILE',
        value: resumeSourceForPreview,
      },
      jobTitle: jobTitle.trim(),
      jdText,
    })
  }

  return (
    <AppShell>
      <section className="dashboard-layout" aria-label="JDSnack 분석 대시보드">
        <aside className="input-rail" aria-label="입력 영역">
          <div className="rail-header">
            <h1>AI 이력서 분석 대시보드</h1>
            <p>이력서, JD, 면접 질문을 한 화면에서 실행하고 결과를 바로 확인합니다.</p>
          </div>

          <form className="rail-card" onSubmit={handleResumeSubmit}>
            <div className="rail-section-header">
              <h2>이력서</h2>
              <span>{trimmedLength.toLocaleString()} / {MAX_LENGTH.toLocaleString()}</span>
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
            <DiagnoseButton
              isSubmitting={isSubmitting}
              idleLabel="이력서 진단"
              loadingLabel="이력서 확인 중..."
            />
          </form>

          <form className="rail-card" onSubmit={handleJdPreviewSubmit}>
            <div className="rail-section-header">
              <h2>JD</h2>
              <span>링크 또는 직접 입력</span>
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
            <DiagnoseButton
              isSubmitting={isPreviewSubmitting}
              idleLabel="JD 매칭"
              loadingLabel="매칭 중..."
              disabled={!canUseCurrentSource}
            />
          </form>

          <section className="rail-card">
            <div className="rail-section-header">
              <h2>모의 면접</h2>
              <span>선택 맥락</span>
            </div>
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
            <button
              className="diagnose-button"
              type="button"
              disabled={!canUseCurrentSource || isInterviewSubmitting}
              onClick={handleInterviewSubmit}
            >
              {isInterviewSubmitting ? '질문 생성 중...' : '면접 질문 생성'}
            </button>
          </section>
        </aside>

        <section className="results-stack" aria-label="결과 영역">
          <ResumeResultPanel result={result} resultRef={resultRef} />
          <MatchResultPanel result={previewResult} />
          <InterviewResultPanel result={interviewResult} />
        </section>
      </section>
    </AppShell>
  )
}

export default App

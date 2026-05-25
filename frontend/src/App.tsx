import { useEffect, useRef, useState } from 'react'
import { useDiagnose } from './hooks/useDiagnose'
import { useMatchPreview } from './hooks/useMatchPreview'
import type { JdFetchResult, JdSections, ResumeInputMode } from './types/diagnosis'
import { AppShell } from './components/AppShell'
import { JdStep } from './components/JdStep'
import { ReportStep } from './components/ReportStep'
import { ResumeStep } from './components/ResumeStep'
import { StepProgress } from './components/StepProgress'
import './App.css'

const LOCAL_STORAGE_KEY = 'jdsnack.resume-text'
const MIN_LENGTH = 50
const MAX_LENGTH = 10_000
const REPORT_PREVIEW_LIMIT = 320
const emptyJdSections: JdSections = {
  responsibilities: '',
  qualifications: '',
  preferredQualifications: '',
  experience: '',
}

function toPreviewText(value: string): string {
  const trimmed = value.trim().replace(/\s+/g, ' ')

  if (trimmed.length <= REPORT_PREVIEW_LIMIT) {
    return trimmed
  }

  return `${trimmed.slice(0, REPORT_PREVIEW_LIMIT)}...`
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
  const [isJdAutofilled, setIsJdAutofilled] = useState(false)
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
  const jdText = joinJdSections(jdSections)
  const derivedStep =
    previewResult.status === 'success' ||
    previewResult.status === 'loading' ||
    previewResult.status === 'error'
      ? 3
      : jdText.trim() || jdUrl.trim() || result.status === 'success'
        ? 2
        : 1
  const activeStep = Math.max(currentStep, derivedStep)
  const resumePreviewText = resumeSourceForPreview
    ? toPreviewText(resumeSourceForPreview)
    : '이력서 본문을 준비하면 여기에서 대조 기준으로 보여드립니다.'
  const jdPreviewText = jdText.trim()
    ? toPreviewText(jdText)
    : 'JD 본문을 준비하면 여기에서 대조 기준으로 보여드립니다.'

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
      onFetched: (fetched) => {
        setJdSections((current) => mergeFetchedSections(current, fetched))
        setIsJdAutofilled(true)
      },
    })
  }

  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()

    const goToJdStepOnSuccess = (wasSuccessful: boolean) => {
      if (wasSuccessful) {
        setCurrentStep((step) => Math.max(step, 2))
      }
    }

    if (inputMode === 'text') {
      goToJdStepOnSuccess(await submit(resumeText))
      return
    }

    goToJdStepOnSuccess(await submitFile(inputMode, resumeFile))
  }

  const handleJdPreviewSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()

    setCurrentStep(3)
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
    <AppShell>
      <StepProgress
        currentStep={currentStep}
        activeStep={activeStep}
        onStepChange={setCurrentStep}
      />

      <section className="wizard-stage">
        {currentStep === 1 ? (
          <ResumeStep
            inputMode={inputMode}
            resumeText={resumeText}
            resumeFile={resumeFile}
            trimmedLength={trimmedLength}
            maxLength={MAX_LENGTH}
            minLength={MIN_LENGTH}
            inlineError={inlineError}
            isSubmitting={isSubmitting}
            result={result}
            resultRef={resultRef}
            onModeChange={handleModeChange}
            onResumeChange={handleResumeChange}
            onFileChange={handleFileChange}
            onSubmit={handleSubmit}
            onNextStep={() => setCurrentStep(2)}
          />
        ) : null}

        {currentStep === 2 ? (
          <JdStep
            jdSections={jdSections}
            jdUrl={jdUrl}
            isJdAutofilled={isJdAutofilled}
            jdFetchStatus={jdFetchState.status}
            jdFetchTitle={jdFetchState.title}
            jdFetchMessage={jdFetchState.message}
            jdTextError={jdTextError}
            jdUrlError={jdUrlError}
            isFetchingJd={isFetchingJd}
            isPreviewSubmitting={isPreviewSubmitting}
            canPreviewWithCurrentSource={canPreviewWithCurrentSource}
            onJdSectionChange={handleJdSectionChange}
            onJdUrlChange={handleJdUrlChange}
            onJdFetch={handleJdFetch}
            onSubmit={handleJdPreviewSubmit}
            onPreviousStep={() => setCurrentStep(1)}
          />
        ) : null}

        {currentStep === 3 ? (
          <ReportStep
            result={result}
            previewResult={previewResult}
            resultRef={resultRef}
            resumePreviewText={resumePreviewText}
            jdPreviewText={jdPreviewText}
            onJdEdit={() => setCurrentStep(2)}
            onResumeEdit={() => setCurrentStep(1)}
          />
        ) : null}
      </section>
    </AppShell>
  )
}

export default App

import type { ChangeEvent, DragEvent } from 'react'
import { useEffect, useRef, useState } from 'react'
import { AppShell } from './components/AppShell'
import { AuthGate, AuthLoginAction, AuthLogoutAction } from './components/AuthGate'
import { useAuthGate } from './components/AuthGateContext'
import { useAtsPreview } from './hooks/useAtsPreview'
import { useDiagnose } from './hooks/useDiagnose'
import { useInterviewPreview } from './hooks/useInterviewPreview'
import { useMatchPreview } from './hooks/useMatchPreview'
import { useSentencePreview } from './hooks/useSentencePreview'
import { useAnalysisHistory } from './hooks/useAnalysisHistory'
import { useAnalysisProgress } from './hooks/useAnalysisProgress'
import { AnalysisInputView } from './features/analysis/AnalysisInputView'
import { AnalysisResultView } from './features/analysis/AnalysisResultView'
import { InterviewWorkspace } from './features/analysis/InterviewWorkspace'
import { AnalysisHistoryView } from './features/analysis/AnalysisHistoryView'
import { AnalysisQualityPrototype } from './features/analysis/AnalysisQualityPrototype'
import { createAnalysisHistory, createAnalysisHistoryFile } from './services/api'
import {
  ANALYSIS_OPTIONS,
  ANALYSIS_OPTION_REQUIRED_MESSAGE,
  DEFAULT_OPTIONS,
  RESUME_REQUIRED_MESSAGE,
  UNSUPPORTED_RESUME_FILE_MESSAGE,
  buildResultMarkdown,
  buildAnalysisHistoryMarkdown,
  analysisHistoryExportFileName,
  clearSavedInput,
  getPrevalidationReasons,
  inferResumeMode,
  loadSavedInput,
  saveInput,
  todayStamp,
  type AnalysisOptionKey,
  type AnalysisPhase,
  type JdTab,
  type ResumeInputTab,
} from './features/analysis/analysisUtils'
import type { AnalysisTaskKey } from './features/analysis/analysisProgressState'
import './App.css'

function PublicHomeApp() {
  const { openLogin } = useAuthGate()
  const [isSidebarOpen, setIsSidebarOpen] = useState(false)

  return (
    <AppShell
      topbarAction={<AuthLoginAction />}
      currentView="home"
      isSidebarOpen={isSidebarOpen}
      isAuthenticated={false}
      onNavigate={() => setIsSidebarOpen(false)}
      onToggleSidebar={() => setIsSidebarOpen((current) => !current)}
    >
      <section className="public-home" aria-label="JDSnack 공개 홈">
        <div className="public-home__content">
          <span className="public-home__eyebrow">JDSnack</span>
          <h1>합격을 위한<br />분석을 시작해보세요</h1>
          <p>이력서와 채용 공고를 함께 살펴보고,<br />지원 전에 보완할 점을 찾아드릴게요.</p>
          <button type="button" className="public-home__cta" onClick={openLogin}>로그인하고 분석 시작하기</button>
        </div>
      </section>
    </AppShell>
  )
}

function AuthenticatedApp() {
  const [currentView, setCurrentView] = useState<'home' | 'interview' | 'history'>('home')
  const [isSidebarOpen, setIsSidebarOpen] = useState(false)
  const [analysisPhase, setAnalysisPhase] = useState<AnalysisPhase>('input')
  const [jdTab, setJdTab] = useState<JdTab>('link')
  const [jdUrl, setJdUrl] = useState('')
  const [jdText, setJdText] = useState(() => loadSavedInput()?.jdText ?? '')
  const [resumeInputTab, setResumeInputTab] = useState<ResumeInputTab>('file')
  const [resumeText, setResumeText] = useState('')
  const [resumeFile, setResumeFile] = useState<File | null>(null)
  const [isDragging, setIsDragging] = useState(false)
  const [options, setOptions] = useState<Record<AnalysisOptionKey, boolean>>(
    () => loadSavedInput()?.options ?? { ...DEFAULT_OPTIONS },
  )
  const [formError, setFormError] = useState('')
  const [submittedOptions, setSubmittedOptions] = useState<Record<AnalysisOptionKey, boolean>>({
    jdMatch: false, ats: false, sentence: false, keyword: false,
  })
  const [jobTitle, setJobTitle] = useState('')
  const resultRef = useRef<HTMLElement>(null)

  const { result: diagnoseResult, submit, submitFile, resetResult: resetDiagnose } = useDiagnose()
  const { fetchJd, isFetchingJd, isSubmitting: isPreviewSubmitting, jdFetchState, resetResult: resetPreview, result: previewResult, submit: submitPreview } = useMatchPreview()
  const { isSubmitting: isAtsSubmitting, result: atsResult, resetResult: resetAts, submit: submitAts } = useAtsPreview()
  const { isSubmitting: isSentenceSubmitting, resetResult: resetSentence, result: sentenceResult, submit: submitSentence } = useSentencePreview()
  const { isSubmitting: isInterviewSubmitting, result: interviewResult, submit: submitInterview } = useInterviewPreview()
  const { histories, selectedHistory, isLoading: isHistoryLoading, error: historyError, load: loadHistories, select: selectHistory, retry: retryHistory, remove: removeHistory, submitFeedback: submitHistoryFeedback } = useAnalysisHistory()
  const { reset: resetAnalysisProgress, start: startAnalysisProgress, state: analysisProgress, updateTask: updateAnalysisTask } = useAnalysisProgress()
  const analysisRunStarted = useRef(false)

  const trimmedJd = jdText.trim()
  const hasResumeSource = Boolean(diagnoseResult.status === 'success' && diagnoseResult.diagnosis?.sourceText)
  const selectedOptionKeys = ANALYSIS_OPTIONS.filter((option) => options[option.key]).map((option) => option.key)
  const prevalidationReasons = getPrevalidationReasons({ resumeFile: resumeInputTab === 'file' ? resumeFile : null, resumeText: resumeInputTab === 'text' ? resumeText : '', jdText, selectedOptionCount: selectedOptionKeys.length })
  const canStart = prevalidationReasons.length === 0

  useEffect(() => {
    if (analysisPhase === 'result') resultRef.current?.focus()
  }, [analysisPhase])

  useEffect(() => {
    try {
      saveInput(jdText, options)
    } catch {
      // localStorage 비가용 시 무시
    }
  }, [jdText, options])

  const handleResetInput = () => {
    setJdText('')
    setJdUrl('')
    setResumeText('')
    setResumeInputTab('file')
    setOptions({ ...DEFAULT_OPTIONS })
    setFormError('')
    try {
      clearSavedInput()
    } catch {
      // localStorage 비가용 시 무시
    }
  }

  const handleExportResult = () => {
    const match = previewResult.matchPreview
    const ats = atsResult.atsPreview
    const sentence = sentenceResult.sentencePreview
    if (!match && !ats && !sentence) return
    const blob = new Blob([buildResultMarkdown(match, sentence, ats, submittedOptions)], { type: 'text/markdown;charset=utf-8' })
    const url = URL.createObjectURL(blob)
    const anchor = document.createElement('a')
    anchor.href = url
    anchor.download = `jdsnack-분석결과-${todayStamp()}.md`
    document.body.appendChild(anchor)
    anchor.click()
    anchor.remove()
    URL.revokeObjectURL(url)
  }

  const handleExportHistory = () => {
    if (!selectedHistory) return
    const markdown = buildAnalysisHistoryMarkdown(selectedHistory)
    if (!markdown) return
    const blob = new Blob([markdown], { type: 'text/markdown' })
    const url = URL.createObjectURL(blob)
    const anchor = document.createElement('a')
    anchor.href = url
    anchor.download = analysisHistoryExportFileName(selectedHistory)
    document.body.appendChild(anchor)
    anchor.click()
    anchor.remove()
    URL.revokeObjectURL(url)
  }

  const handleJdUrlChange = (value: string) => { setJdUrl(value); setFormError('') }
  const handleJdTextChange = (value: string) => { setJdText(value); setFormError('') }
  const handleJdFetch = async () => { await fetchJd(jdUrl, { onFetched: (fetched) => setJdText(fetched.jdText) }) }
  const setFile = (file: File | null) => { setResumeFile(file); setFormError('') }
  const handleFileInput = (event: ChangeEvent<HTMLInputElement>) => setFile(event.target.files?.[0] ?? null)
  const handleDrop = (event: DragEvent<HTMLDivElement>) => {
    event.preventDefault()
    setIsDragging(false)
    const dropped = event.dataTransfer.files?.[0]
    if (dropped) setFile(dropped)
  }
  const toggleOption = (key: AnalysisOptionKey) => { setOptions((current) => ({ ...current, [key]: !current[key] })); setFormError('') }

  const handleStartAnalysis = async () => {
    if (analysisRunStarted.current || analysisProgress.status === 'running') return
    if (resumeInputTab === 'file' && !resumeFile) { setFormError(RESUME_REQUIRED_MESSAGE); return }
    const mode = resumeFile ? inferResumeMode(resumeFile) : null
    if (resumeInputTab === 'file' && !mode) { setFormError(UNSUPPORTED_RESUME_FILE_MESSAGE); return }
    if (prevalidationReasons.length > 0) { setFormError(prevalidationReasons[0] ?? ANALYSIS_OPTION_REQUIRED_MESSAGE); return }

    setFormError('')
    analysisRunStarted.current = true
    setSubmittedOptions({ ...options })
    resetDiagnose()
    resetPreview()
    resetAts()
    resetSentence()
    const runId = startAnalysisProgress({ ...options })
    setAnalysisPhase('result')
    updateAnalysisTask(runId, 'resume', 'running')
    const outcome = resumeInputTab === 'text'
      ? await submit(resumeText)
      : await submitFile(mode!, resumeFile)
    const historyInput = {
      jd: {
        inputType: jdUrl.trim() ? 'SARAMIN_URL' as const : 'TEXT' as const,
        text: trimmedJd,
        sourceUrl: jdUrl.trim() || null,
        sourceSite: jdUrl.trim() ? 'saramin' : null,
      },
    }
    const hasExtractedResume = outcome.ok && Boolean(outcome.diagnosis?.sourceText)
    const runHistoryRequest = () => hasExtractedResume
      ? createAnalysisHistory({ resumeText: outcome.diagnosis!.sourceText, ...historyInput })
      : resumeInputTab === 'text'
        ? createAnalysisHistory({ resumeText, ...historyInput })
        : createAnalysisHistoryFile(resumeFile!, historyInput)

    const saveHistory = async () => {
      updateAnalysisTask(runId, 'history', 'running')
      try {
        await runHistoryRequest()
        updateAnalysisTask(runId, 'history', 'succeeded')
      } catch {
        updateAnalysisTask(runId, 'history', 'failed', { message: '분석 결과를 분석 내역에 저장하지 못했습니다.' })
      }
    }

    if (!outcome.ok || !outcome.diagnosis?.sourceText) {
      updateAnalysisTask(runId, 'resume', 'failed', { message: outcome.message ?? '이력서 분석을 완료하지 못했습니다.', code: 'code' in outcome ? outcome.code : undefined })
      for (const key of ['match', 'ats', 'sentence'] as AnalysisTaskKey[]) {
        updateAnalysisTask(runId, key, 'skipped', { message: '이력서 분석이 완료되지 않아 실행하지 못했습니다.' })
      }
      await saveHistory()
      return
    }
    updateAnalysisTask(runId, 'resume', 'succeeded')
    const request = { resumeSource: { type: 'FILE', value: outcome.diagnosis.sourceText }, jdText: trimmedJd, jdUrl: jdUrl.trim() } as const
    const requests: Promise<void>[] = []
    if (options.jdMatch || options.keyword) {
      updateAnalysisTask(runId, 'match', 'running')
      requests.push(submitPreview(request).then((taskOutcome) => {
        updateAnalysisTask(runId, 'match', taskOutcome.ok ? 'succeeded' : 'failed', {
          message: taskOutcome.message,
          code: taskOutcome.code,
        })
      }))
    }
    if (options.ats) {
      updateAnalysisTask(runId, 'ats', 'running')
      requests.push(submitAts(request).then((taskOutcome) => {
        updateAnalysisTask(runId, 'ats', taskOutcome.ok ? 'succeeded' : 'failed', {
          message: taskOutcome.message,
          code: taskOutcome.code,
        })
      }))
    }
    if (options.sentence) {
      updateAnalysisTask(runId, 'sentence', 'running')
      requests.push(submitSentence(request).then((taskOutcome) => {
        updateAnalysisTask(runId, 'sentence', taskOutcome.ok ? 'succeeded' : 'failed', {
          message: taskOutcome.message,
          code: taskOutcome.code,
        })
      }))
    }
    requests.push(saveHistory())
    await Promise.all(requests)
  }

  const handleNewAnalysis = () => {
    setAnalysisPhase('input')
    resetDiagnose()
    resetPreview()
    resetAts()
    resetSentence()
    analysisRunStarted.current = false
    resetAnalysisProgress()
  }

  const handleInterviewSubmit = async () => {
    const resumeSource = diagnoseResult.status === 'success' && diagnoseResult.diagnosis?.sourceText ? diagnoseResult.diagnosis.sourceText : ''
    await submitInterview({ resumeSource: { type: 'FILE', value: resumeSource }, jobTitle: jobTitle.trim(), jdText: trimmedJd })
  }

  return (
    <AppShell
      topbarAction={<AuthLogoutAction />}
      currentView={currentView}
      isSidebarOpen={isSidebarOpen}
      onNavigate={(view) => { setCurrentView(view); setIsSidebarOpen(false); if (view === 'history') void loadHistories() }}
      onToggleSidebar={() => setIsSidebarOpen((current) => !current)}
    >
      {currentView === 'home' ? (
        analysisPhase === 'input' ? (
        <AnalysisInputView {...{ jdTab, setJdTab, jdUrl, jdText, trimmedJd, resumeInputTab, setResumeInputTab, resumeText, setResumeText, resumeFile, isDragging, setIsDragging, options, formError, prevalidationReasons, canStart, isFetchingJd, isPreviewSubmitting, isAtsSubmitting, isSentenceSubmitting, jdFetchState, handleJdUrlChange, handleJdTextChange, handleJdFetch, handleFileInput, handleDrop, setFile, toggleOption, handleStartAnalysis, handleResetInput }} />
        ) : (
          <AnalysisResultView {...{ submittedOptions, previewResult, atsResult, sentenceResult, resultRef, handleExportResult, handlePrintResult: () => window.print(), handleNewAnalysis, analysisProgress }} />
        )
      ) : currentView === 'interview' ? (
        <InterviewWorkspace {...{ jobTitle, setJobTitle, hasResumeSource, trimmedJd, isInterviewSubmitting, handleInterviewSubmit, interviewResult }} />
      ) : (
        <AnalysisHistoryView
          histories={histories}
          selectedHistory={selectedHistory}
          isLoading={isHistoryLoading}
          error={historyError}
          onLoad={loadHistories}
          onSelect={selectHistory}
          onRetry={retryHistory}
          onDelete={removeHistory}
          onExport={handleExportHistory}
          onSubmitFeedback={submitHistoryFeedback}
        />
      )}
    </AppShell>
  )
}

function AppContent() {
  const { status } = useAuthGate()
  const isQualityPrototype = import.meta.env.DEV && new URLSearchParams(window.location.search).get('prototype') === 'analysis-quality'
  if (isQualityPrototype) return <AnalysisQualityPrototype />
  return status === 'authenticated' ? <AuthenticatedApp /> : <PublicHomeApp />
}

export default function App() {
  return <AuthGate><AppContent /></AuthGate>
}

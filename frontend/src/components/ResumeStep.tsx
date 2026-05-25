import type { FormEvent, RefObject } from 'react'
import { DiagnoseButton } from './DiagnoseButton'
import { ResumeFileInput } from './ResumeFileInput'
import { ResumeInput } from './ResumeInput'
import { ResumeModeTabs } from './ResumeModeTabs'
import { ResultPanel } from './ResultPanel'
import type { ResultState, ResumeInputMode } from '../types/diagnosis'

interface ResumeStepProps {
  inputMode: ResumeInputMode
  resumeText: string
  resumeFile: File | null
  trimmedLength: number
  maxLength: number
  minLength: number
  inlineError: string
  isSubmitting: boolean
  result: ResultState
  resultRef: RefObject<HTMLElement | null>
  onModeChange: (mode: ResumeInputMode) => void
  onResumeChange: (value: string) => void
  onFileChange: (file: File | null) => void
  onSubmit: (event: FormEvent<HTMLFormElement>) => void
  onNextStep: () => void
}

export function ResumeStep({
  inputMode,
  resumeText,
  resumeFile,
  trimmedLength,
  maxLength,
  minLength,
  inlineError,
  isSubmitting,
  result,
  resultRef,
  onModeChange,
  onResumeChange,
  onFileChange,
  onSubmit,
  onNextStep,
}: ResumeStepProps) {
  return (
    <form id="resume-step" className="workflow-card resume-workflow" onSubmit={onSubmit}>
      <div className="workflow-heading">
        <p>STEP 1 / 3</p>
        <h1>이력서를 입력해주세요</h1>
        <span>직접 입력하거나 PDF/DOCX 파일에서 텍스트를 추출합니다.</span>
      </div>

      <ResumeModeTabs mode={inputMode} onChange={onModeChange} />

      <div className="resume-grid">
        <section className="resume-section">
          <div className="section-title-row">
            <h2>이력서 직접 입력</h2>
            <span>{trimmedLength.toLocaleString()} / {maxLength.toLocaleString()}</span>
          </div>
          <ResumeInput
            value={resumeText}
            onChange={onResumeChange}
            minLength={minLength}
            maxLength={maxLength}
            currentLength={trimmedLength}
            errorMessage={inputMode === 'text' ? inlineError : ''}
          />
        </section>

        <section className="resume-section resume-section--upload">
          <div className="section-title-row">
            <h2>파일 첨부</h2>
            <span>{resumeFile ? '파일 준비됨' : 'PDF / DOCX'}</span>
          </div>
          <ResumeFileInput
            mode={inputMode === 'text' ? 'pdf' : inputMode}
            file={resumeFile}
            errorMessage={inputMode === 'text' ? '' : inlineError}
            onChange={onFileChange}
          />
        </section>
      </div>

      <div className="workflow-actions workflow-actions--center">
        <DiagnoseButton
          isSubmitting={isSubmitting}
          idleLabel="AI 진단 시작하기"
          loadingLabel="이력서 확인 중..."
        />
        {inputMode === 'text' && trimmedLength >= minLength ? (
          <button className="text-button" type="button" onClick={onNextStep}>
            JD 분석으로 이동
          </button>
        ) : null}
      </div>

      {result.status !== 'idle' && result.status !== 'success' ? (
        <div className="inline-result">
          <ResultPanel ref={resultRef} result={result} />
        </div>
      ) : null}
    </form>
  )
}

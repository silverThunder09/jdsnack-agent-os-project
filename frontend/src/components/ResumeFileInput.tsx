import type { ResumeInputMode } from '../types/diagnosis'

interface ResumeFileInputProps {
  mode: ResumeInputMode
  file: File | null
  errorMessage: string
  onChange: (file: File | null) => void
}

function helperText(mode: ResumeInputMode) {
  if (mode === 'pdf') {
    return 'PDF 파일을 선택하면 서버에서 텍스트를 추출해 fixture 결과와 매칭합니다.'
  }

  return 'DOCX 파일을 선택하면 서버에서 텍스트를 추출해 fixture 결과와 매칭합니다.'
}

export function ResumeFileInput({
  mode,
  file,
  errorMessage,
  onChange,
}: ResumeFileInputProps) {
  const accept = mode === 'pdf' ? '.pdf,application/pdf' : '.docx,application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  const descriptionId = errorMessage ? 'resume-file-error' : 'resume-file-helper'

  return (
    <div className="resume-input-group">
      <label className="resume-label" htmlFor="resume-file">
        {mode === 'pdf' ? 'PDF 이력서 파일' : 'DOCX 이력서 파일'}
      </label>
      <label className={`file-picker${errorMessage ? ' file-picker--error' : ''}`} htmlFor="resume-file">
        <span className="file-picker__button">파일 선택</span>
        <span className="file-picker__name">
          {file?.name ?? '아직 선택된 파일이 없습니다.'}
        </span>
      </label>
      <input
        id="resume-file"
        className="sr-only"
        name="resumeFile"
        type="file"
        accept={accept}
        aria-describedby={descriptionId}
        aria-invalid={Boolean(errorMessage)}
        onChange={(event) => onChange(event.target.files?.[0] ?? null)}
      />
      <p className="resume-helper" id="resume-file-helper">
        {helperText(mode)}
      </p>
      {errorMessage ? (
        <p className="resume-error" id="resume-file-error" role="alert">
          {errorMessage}
        </p>
      ) : null}
    </div>
  )
}

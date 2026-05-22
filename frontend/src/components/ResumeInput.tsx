interface ResumeInputProps {
  value: string
  onChange: (nextValue: string) => void
  minLength: number
  maxLength: number
  currentLength: number
  errorMessage: string
}

export function ResumeInput({
  value,
  onChange,
  minLength,
  maxLength,
  currentLength,
  errorMessage,
}: ResumeInputProps) {
  const descriptionId = errorMessage
    ? 'resume-input-error'
    : 'resume-input-helper'

  return (
    <div className="resume-input-group">
      <label className="resume-label" htmlFor="resume-text">
        이력서 내용
      </label>
      <textarea
        id="resume-text"
        className={`resume-textarea${errorMessage ? ' resume-textarea--error' : ''}`}
        name="resumeText"
        placeholder="프로젝트 경험, 기술 스택, 역할, 성과를 중심으로 이력서를 붙여넣어 주세요."
        value={value}
        onChange={(event) => onChange(event.target.value)}
        aria-describedby={descriptionId}
        aria-invalid={Boolean(errorMessage)}
      />
      <div className="resume-meta">
        <p className="resume-helper" id="resume-input-helper">
          공백 제외 기준 {minLength}자 이상, {maxLength.toLocaleString()}자 이하를
          권장합니다.
        </p>
        <output className="resume-output" htmlFor="resume-text">
          {currentLength.toLocaleString()} / {maxLength.toLocaleString()}
        </output>
      </div>
      {errorMessage ? (
        <p className="resume-error" id="resume-input-error" role="alert">
          {errorMessage}
        </p>
      ) : null}
    </div>
  )
}

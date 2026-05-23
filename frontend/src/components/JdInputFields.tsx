interface JdInputFieldsProps {
  jdText: string
  jdUrl: string
  jdTextError: string
  jdUrlError: string
  onJdTextChange: (value: string) => void
  onJdUrlChange: (value: string) => void
}

export function JdInputFields({
  jdText,
  jdUrl,
  jdTextError,
  jdUrlError,
  onJdTextChange,
  onJdUrlChange,
}: JdInputFieldsProps) {
  return (
    <div className="jd-input-group">
      <div className="resume-input-group">
        <label className="resume-label" htmlFor="jd-text">
          JD 내용
        </label>
        <textarea
          id="jd-text"
          className={`resume-textarea jd-textarea${jdTextError ? ' resume-textarea--error' : ''}`}
          name="jdText"
          placeholder="주요 업무, 자격요건, 우대사항이 보이도록 JD 본문을 붙여넣어 주세요."
          value={jdText}
          onChange={(event) => onJdTextChange(event.target.value)}
          aria-describedby={jdTextError ? 'jd-text-error' : 'jd-text-helper'}
          aria-invalid={Boolean(jdTextError)}
        />
        <p className="resume-helper" id="jd-text-helper">
          JD 링크는 선택 입력입니다. 현재는 JD 본문 텍스트를 직접 붙여넣는 방식을 기준으로 합니다.
        </p>
        {jdTextError ? (
          <p className="resume-error" id="jd-text-error" role="alert">
            {jdTextError}
          </p>
        ) : null}
      </div>

      <div className="jd-url-group">
        <label className="resume-label" htmlFor="jd-url">
          JD 링크 (선택)
        </label>
        <input
          id="jd-url"
          className={`jd-url-input${jdUrlError ? ' jd-url-input--error' : ''}`}
          name="jdUrl"
          type="text"
          placeholder="https://example.com/jobs/backend"
          value={jdUrl}
          onChange={(event) => onJdUrlChange(event.target.value)}
          aria-describedby={jdUrlError ? 'jd-url-error' : 'jd-url-helper'}
          aria-invalid={Boolean(jdUrlError)}
        />
        <p className="resume-helper" id="jd-url-helper">
          링크는 출처 메모용입니다. 현재는 링크 본문을 자동으로 읽지 않습니다.
        </p>
        {jdUrlError ? (
          <p className="resume-error" id="jd-url-error" role="alert">
            {jdUrlError}
          </p>
        ) : null}
      </div>
    </div>
  )
}

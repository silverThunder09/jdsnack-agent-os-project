import { StatusMessage } from './StatusMessage'

type JdFetchStatus = 'idle' | 'fetching' | 'fetched' | 'fetch-error'

interface JdInputFieldsProps {
  jdText: string
  jdUrl: string
  jdTextError: string
  jdUrlError: string
  jdFetchStatus: JdFetchStatus
  jdFetchTitle: string
  jdFetchMessage: string
  isFetchingJd: boolean
  onJdTextChange: (value: string) => void
  onJdUrlChange: (value: string) => void
  onJdFetch: () => void
}

function getTone(status: JdFetchStatus): 'neutral' | 'active' | 'success' | 'danger' {
  if (status === 'fetching') {
    return 'active'
  }

  if (status === 'fetched') {
    return 'success'
  }

  if (status === 'fetch-error') {
    return 'danger'
  }

  return 'neutral'
}

function getBadge(status: JdFetchStatus): string {
  if (status === 'fetching') {
    return 'Fetching'
  }

  if (status === 'fetched') {
    return 'Fetched'
  }

  if (status === 'fetch-error') {
    return 'Fallback'
  }

  return 'Link Assist'
}

export function JdInputFields({
  jdText,
  jdUrl,
  jdTextError,
  jdUrlError,
  jdFetchStatus,
  jdFetchTitle,
  jdFetchMessage,
  isFetchingJd,
  onJdTextChange,
  onJdUrlChange,
  onJdFetch,
}: JdInputFieldsProps) {
  const shouldOpenLinkAssist =
    Boolean(jdUrl) || Boolean(jdUrlError) || jdFetchStatus !== 'idle'

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
        <p className="resume-helper" id="jd-text-helper">주요 업무, 자격요건, 우대사항이 보이면 충분합니다.</p>
        {jdTextError ? (
          <p className="resume-error" id="jd-text-error" role="alert">
            {jdTextError}
          </p>
        ) : null}
      </div>

      <details className="jd-link-card" open={shouldOpenLinkAssist}>
        <summary>필요 시 링크로 JD 불러오기</summary>
        <div className="jd-url-group">
          <label className="resume-label" htmlFor="jd-url">
            JD 링크
          </label>
          <div className="jd-url-row">
            <input
              id="jd-url"
              className={`jd-url-input${jdUrlError ? ' jd-url-input--error' : ''}`}
              name="jdUrl"
              type="text"
              placeholder="https://www.saramin.co.kr/..."
              value={jdUrl}
              onChange={(event) => onJdUrlChange(event.target.value)}
              aria-describedby={jdUrlError ? 'jd-url-error' : 'jd-url-helper'}
              aria-invalid={Boolean(jdUrlError)}
            />
            <button
              className="secondary-button"
              type="button"
              onClick={onJdFetch}
              disabled={isFetchingJd}
            >
              {isFetchingJd ? '불러오는 중...' : '링크로 JD 불러오기'}
            </button>
          </div>
          <p className="resume-helper" id="jd-url-helper">
            실패하면 JD 본문을 직접 붙여넣어 주세요.
          </p>
          {jdUrlError ? (
            <p className="resume-error" id="jd-url-error" role="alert">
            {jdUrlError}
          </p>
        ) : null}
        </div>

        {jdFetchStatus !== 'idle' ? (
          <StatusMessage
            badge={getBadge(jdFetchStatus)}
            title={jdFetchTitle}
            message={
              jdFetchStatus === 'fetch-error'
                ? '불러오지 못했습니다. JD 본문을 직접 붙여넣어 주세요.'
                : jdFetchMessage
            }
            tone={getTone(jdFetchStatus)}
            withLoadingBar={jdFetchStatus === 'fetching'}
          />
        ) : null}
      </details>
    </div>
  )
}

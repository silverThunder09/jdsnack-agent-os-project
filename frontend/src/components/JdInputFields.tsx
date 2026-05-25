import { StatusMessage } from './StatusMessage'
import type { JdSections } from '../types/diagnosis'

type JdFetchStatus = 'idle' | 'fetching' | 'fetched' | 'fetch-error'

interface JdInputFieldsProps {
  jdSections: JdSections
  jdUrl: string
  isJdAutofilled: boolean
  jdTextError: string
  jdUrlError: string
  jdFetchStatus: JdFetchStatus
  jdFetchTitle: string
  jdFetchMessage: string
  isFetchingJd: boolean
  onJdSectionChange: (section: keyof JdSections, value: string) => void
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
  jdSections,
  jdUrl,
  isJdAutofilled,
  jdTextError,
  jdUrlError,
  jdFetchStatus,
  jdFetchTitle,
  jdFetchMessage,
  isFetchingJd,
  onJdSectionChange,
  onJdUrlChange,
  onJdFetch,
}: JdInputFieldsProps) {
  const sectionItems: Array<{
    key: keyof JdSections
    label: string
    helper: string
    placeholder: string
  }> = [
    {
      key: 'responsibilities',
      label: '주요업무',
      helper: '담당 업무, 프로젝트 범위, 역할을 입력합니다.',
      placeholder: '예: 백엔드 API 설계 및 운영, 서비스 성능 개선...',
    },
    {
      key: 'qualifications',
      label: '자격조건',
      helper: '필수 기술, 학력, 자격 요건을 입력합니다.',
      placeholder: '예: Java/Spring 3년 이상, REST API 개발 경험...',
    },
    {
      key: 'preferredQualifications',
      label: '우대사항',
      helper: '우대 기술, 도메인 경험, 협업 경험을 입력합니다.',
      placeholder: '예: AWS 운영 경험, MSA 아키텍처 경험...',
    },
    {
      key: 'experience',
      label: '경력사항',
      helper: '요구 경력, 고용 형태, 연차 조건을 입력합니다.',
      placeholder: '예: 경력 3~7년, 정규직, 유관 업무 경험...',
    },
  ]

  return (
    <div className="jd-input-group">
      <section className="jd-link-panel" aria-label="JD 링크 첨부">
        <div className="section-title-row">
          <h2>JD 링크 첨부</h2>
          <span>사람인 링크 우선 지원</span>
        </div>
        <div className="jd-url-row">
          <label className="sr-only" htmlFor="jd-url">
            JD 링크
          </label>
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
            {isFetchingJd ? '불러오는 중...' : 'JD 미리보기'}
          </button>
        </div>
        <p className="resume-helper" id="jd-url-helper">
          링크 수집이 실패하면 아래에 JD 본문을 직접 붙여넣어 주세요.
        </p>
        {jdUrlError ? (
          <p className="resume-error" id="jd-url-error" role="alert">
            {jdUrlError}
          </p>
        ) : null}

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
      </section>

      <div className="jd-divider">
        <span>OR 직접 입력</span>
      </div>

      <div className="jd-section-grid">
        {sectionItems.map((item) => (
          <div className="resume-input-group jd-section-field" key={item.key}>
            <label className="resume-label" htmlFor={`jd-${item.key}`}>
              {item.label}
            </label>
            <textarea
              id={`jd-${item.key}`}
              className={`resume-textarea jd-textarea${jdTextError ? ' resume-textarea--error' : ''}${isJdAutofilled ? ' jd-textarea--autofilled' : ''}`}
              name={item.key}
              placeholder={item.placeholder}
              value={jdSections[item.key]}
              onChange={(event) => onJdSectionChange(item.key, event.target.value)}
              aria-describedby={jdTextError ? 'jd-text-error' : `jd-${item.key}-helper`}
              aria-invalid={Boolean(jdTextError)}
            />
            <p className="resume-helper" id={`jd-${item.key}-helper`}>
              {isJdAutofilled
                ? '자동으로 불러온 초안입니다. 필요한 부분만 다듬어 주세요.'
                : item.helper}
            </p>
          </div>
        ))}
      </div>

      {jdTextError ? (
        <p className="resume-error" id="jd-text-error" role="alert">
          {jdTextError}
        </p>
      ) : null}
    </div>
  )
}

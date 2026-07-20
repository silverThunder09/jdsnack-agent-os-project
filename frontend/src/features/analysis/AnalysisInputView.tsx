import type { ChangeEvent, Dispatch, DragEvent, SetStateAction } from 'react'
import type { JdFetchState } from '../../hooks/useMatchPreview'
import { ACCURACY_TIPS, ANALYSIS_OPTIONS, type AnalysisOptionKey, type JdTab, type ResumeInputTab, formatFileSize, JD_MAX_LENGTH, PROGRESS_STEPS } from './analysisUtils'

interface AnalysisInputViewProps {
  jdTab: JdTab
  setJdTab: (tab: JdTab) => void
  jdUrl: string
  jdText: string
  trimmedJd: string
  resumeInputTab: ResumeInputTab
  setResumeInputTab: (tab: ResumeInputTab) => void
  resumeText: string
  setResumeText: (value: string) => void
  resumeFile: File | null
  isDragging: boolean
  setIsDragging: Dispatch<SetStateAction<boolean>>
  options: Record<AnalysisOptionKey, boolean>
  formError: string
  prevalidationReasons: string[]
  canStart: boolean
  isFetchingJd: boolean
  isPreviewSubmitting: boolean
  isAtsSubmitting: boolean
  isSentenceSubmitting: boolean
  jdFetchState: JdFetchState
  handleJdUrlChange: (value: string) => void
  handleJdTextChange: (value: string) => void
  handleJdFetch: () => Promise<void>
  handleFileInput: (event: ChangeEvent<HTMLInputElement>) => void
  handleDrop: (event: DragEvent<HTMLDivElement>) => void
  setFile: (file: File | null) => void
  toggleOption: (key: AnalysisOptionKey) => void
  handleStartAnalysis: () => Promise<void>
  handleResetInput: () => void
}

export function AnalysisInputView(props: AnalysisInputViewProps) {
  const { jdTab, setJdTab, jdUrl, jdText, trimmedJd, resumeInputTab, setResumeInputTab, resumeText, setResumeText, resumeFile, isDragging, setIsDragging, options, formError, prevalidationReasons, canStart, isFetchingJd, isPreviewSubmitting, isAtsSubmitting, isSentenceSubmitting, jdFetchState, handleJdUrlChange, handleJdTextChange, handleJdFetch, handleFileInput, handleDrop, setFile, toggleOption, handleStartAnalysis, handleResetInput } = props
  return (
    <section className="start-page" aria-label="새로운 분석 시작">
      <header className="start-page__head">
        <p className="start-page__eyebrow">분석 시작</p>
        <h1>새로운 분석 시작</h1>
        <p className="start-page__sub">채용 공고와 이력서를 연결하여 합격 가능성을 높이세요.</p>
      </header>

      <div className="start-layout">
        <div className="start-main">
          <section className="step-card" aria-label="채용 공고 입력">
            <h2 className="step-card__title">
              <span className="step-badge">1</span> 채용 공고 (JD) 입력
            </h2>
            <div className="jd-tabs" role="tablist" aria-label="JD 입력 방식">
              <button
                type="button"
                role="tab"
                aria-selected={jdTab === 'link'}
                className={`jd-tab${jdTab === 'link' ? ' jd-tab--active' : ''}`}
                onClick={() => setJdTab('link')}
              >
                JD 링크
              </button>
              <button
                type="button"
                role="tab"
                aria-selected={jdTab === 'paste'}
                className={`jd-tab${jdTab === 'paste' ? ' jd-tab--active' : ''}`}
                onClick={() => setJdTab('paste')}
              >
                JD 내용 붙여넣기
              </button>
            </div>

            {jdTab === 'link' ? (
              <div className="jd-link-row">
                <label className="field-label" htmlFor="jd-url">
                  채용 공고 URL
                </label>
                <div className="jd-link-controls">
                  <input
                    id="jd-url"
                    className="text-input"
                    type="url"
                    inputMode="url"
                    placeholder="https://careers.sample.com/jobs/123456"
                    value={jdUrl}
                    onChange={(event) => handleJdUrlChange(event.target.value)}
                  />
                  <button
                    type="button"
                    className="ghost-button"
                    onClick={handleJdFetch}
                    disabled={isFetchingJd || !jdUrl.trim()}
                  >
                    {isFetchingJd ? '불러오는 중...' : 'JD 불러오기'}
                  </button>
                </div>
                <p className="field-help">지원하는 사이트: 사람인 등 정적 채용 공고. 그 외 링크는 본문 붙여넣기로 진행하세요.</p>
                {jdFetchState.status !== 'idle' ? (
                  <p className={`field-help field-help--${jdFetchState.status}`} role={jdFetchState.status === 'fetch-error' ? 'alert' : undefined}>
                    {jdFetchState.message}
                  </p>
                ) : null}
              </div>
            ) : null}

            {jdTab === 'paste' ? (
              <div className="jd-paste-row">
                <label className="field-label" htmlFor="jd-text">
                  JD 내용 붙여넣기
                </label>
                <textarea
                  id="jd-text"
                  className="text-area"
                  placeholder="채용 공고의 전체 내용을 복사하여 붙여넣어 주세요."
                  value={jdText}
                  onChange={(event) => handleJdTextChange(event.target.value)}
                  rows={8}
                />
                <p className="char-count">
                  {jdText.length.toLocaleString()} / {JD_MAX_LENGTH.toLocaleString()}
                </p>
              </div>
            ) : null}

            {jdTab === 'link' && trimmedJd ? (
              <p className="field-help field-help--fetched">불러온 JD 본문이 준비되었습니다. ‘JD 내용 붙여넣기’ 탭에서 확인·수정할 수 있습니다.</p>
            ) : null}
          </section>

          <section className="step-card" aria-label="이력서 업로드">
            <h2 className="step-card__title">
              <span className="step-badge">2</span> 이력서 업로드
            </h2>
            <div className="input-tabs" role="tablist" aria-label="이력서 입력 방식">
              <button type="button" role="tab" aria-selected={resumeInputTab === 'text'} className={resumeInputTab === 'text' ? 'input-tab input-tab--active' : 'input-tab'} onClick={() => setResumeInputTab('text')}>
                텍스트 입력
              </button>
              <button type="button" role="tab" aria-selected={resumeInputTab === 'file'} className={resumeInputTab === 'file' ? 'input-tab input-tab--active' : 'input-tab'} onClick={() => setResumeInputTab('file')}>
                파일 업로드
              </button>
            </div>
            {resumeInputTab === 'text' ? (
              <>
                <label className="field-label" htmlFor="resume-text">이력서 내용</label>
                <textarea id="resume-text" className="text-area" placeholder="기존 이력서 내용을 붙여넣어 주세요." value={resumeText} onChange={(event) => setResumeText(event.target.value)} rows={8} />
                <p className="char-count">{resumeText.length.toLocaleString()} / 10,000</p>
              </>
            ) : (
              <div
                className={`dropzone${isDragging ? ' dropzone--active' : ''}`}
                onDragOver={(event) => {
                  event.preventDefault()
                  setIsDragging(true)
                }}
                onDragLeave={() => setIsDragging(false)}
                onDrop={handleDrop}
              >
                <span className="dropzone__icon" aria-hidden="true">⬆</span>
                <p className="dropzone__title">이력서 파일을 드래그하거나 클릭하여 업로드하세요</p>
                <p className="dropzone__hint">PDF, DOCX 파일을 지원합니다. (최대 10MB)</p>
                <label className="file-select-button" htmlFor="resume-file">파일 선택</label>
                <input id="resume-file" className="sr-only" type="file" accept=".pdf,.docx,application/pdf,application/vnd.openxmlformats-officedocument.wordprocessingml.document" onChange={handleFileInput} />
              </div>
            )}
            {resumeFile ? (
              <div className="file-chip">
                <div className="file-chip__info">
                  <span className="file-chip__name">{resumeFile.name}</span>
                  <span className="file-chip__meta">{formatFileSize(resumeFile.size)}</span>
                </div>
                <button type="button" className="file-chip__remove" aria-label="파일 제거" onClick={() => setFile(null)}>
                  ✕
                </button>
              </div>
            ) : null}
          </section>

          <section className="step-card" aria-label="분석 옵션 선택">
            <h2 className="step-card__title">
              <span className="step-badge">3</span> 분석 옵션 선택
            </h2>
            <p className="step-card__desc">필요한 분석 항목을 선택하세요. 선택한 항목에 따라 분석 결과가 제공됩니다.</p>
            <div className="option-grid">
              {ANALYSIS_OPTIONS.map((option) => (
                <label
                  key={option.key}
                  className={`option-card${options[option.key] ? ' option-card--checked' : ''}`}
                >
                  <input
                    type="checkbox"
                    checked={options[option.key]}
                    onChange={() => toggleOption(option.key)}
                  />
                  <span className="option-card__body">
                    <span className="option-card__title">
                      {option.label}
                      {option.recommended ? <span className="option-tag option-tag--rec">추천</span> : null}
                      {!option.enabled ? <span className="option-tag option-tag--soon">준비중</span> : null}
                    </span>
                    <span className="option-card__desc">{option.description}</span>
                  </span>
                </label>
              ))}
            </div>

            {formError ? (
              <p className="form-error" role="alert">
                {formError}
              </p>
            ) : null}
            {!canStart ? (
              <div className="gate-reasons" role="status" aria-live="polite">
                <p>분석 시작 전 확인이 필요합니다.</p>
                <ul>
                  {prevalidationReasons.map((reason) => (
                    <li key={reason}>{reason}</li>
                  ))}
                </ul>
              </div>
            ) : null}

            <div className="start-cta">
              <button
                type="button"
                className="cta-button"
                disabled={!canStart || isPreviewSubmitting || isAtsSubmitting || isSentenceSubmitting}
                aria-disabled={!canStart || isPreviewSubmitting || isAtsSubmitting || isSentenceSubmitting}
                onClick={handleStartAnalysis}
              >
                {isPreviewSubmitting || isAtsSubmitting || isSentenceSubmitting ? '분석 중...' : '분석 시작하기 →'}
              </button>
              <button type="button" className="text-button" onClick={handleResetInput}>
                입력 초기화
              </button>
            </div>
            <p className="start-footer">🔒 입력하신 정보는 안전하게 처리되며, 분석 후 즉시 삭제됩니다.</p>
          </section>
        </div>

        <aside className="start-rail" aria-label="분석 안내">
          <section className="rail-card">
            <h3>분석이 이렇게 진행돼요</h3>
            <ol className="rail-steps">
              {PROGRESS_STEPS.map((step, index) => (
                <li key={step.title}>
                  <span className="rail-steps__num">{index + 1}</span>
                  <div>
                    <strong>{step.title}</strong>
                    <p>{step.description}</p>
                  </div>
                </li>
              ))}
            </ol>
          </section>

          <section className="rail-card">
            <h3>💡 분석 정확도를 높이는 팁</h3>
            <ul className="rail-tips">
              {ACCURACY_TIPS.map((tip) => (
                <li key={tip}>{tip}</li>
              ))}
            </ul>
          </section>

          <section className="rail-card">
            <h3>지원 가능한 파일 형식</h3>
            <div className="format-chips">
              <span className="format-chip">PDF</span>
              <span className="format-chip">DOCX</span>
            </div>
            <p className="rail-note">최대 10MB까지 업로드 가능합니다.</p>
          </section>
        </aside>
      </div>
    </section>
  )
}

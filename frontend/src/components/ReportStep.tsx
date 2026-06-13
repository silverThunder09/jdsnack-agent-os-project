import type { RefObject } from 'react'
import { ResultPanel } from './ResultPanel'
import { StatusMessage } from './StatusMessage'
import type { ResultState } from '../types/diagnosis'

interface ReportStepProps {
  result: ResultState
  previewResult: ResultState
  interviewResult: ResultState
  resultRef: RefObject<HTMLElement | null>
  resumePreviewText: string
  jdPreviewText: string
  isInterviewSubmitting: boolean
  onInterviewSubmit: () => void
  onResumeEdit: () => void
  onJdEdit: () => void
}

function buildSubmissionGuide({
  strengths,
  gaps,
  suggestions,
}: {
  strengths: string[]
  gaps: string[]
  suggestions: string[]
}) {
  const highlight = strengths[0] ?? 'JD와 맞는 경험'
  const gap = gaps[0] ?? '부족한 근거'
  const action = suggestions[0] ?? '핵심 경험을 더 구체적으로 적어 주세요.'

  return `${highlight}를 전면에 두고, ${gap}는 이번 제출본에서 바로 보강하세요. ${action}`
}

function buildRevisedResume({
  resumePreviewText,
  strengths,
  gaps,
  suggestions,
}: {
  resumePreviewText: string
  strengths: string[]
  gaps: string[]
  suggestions: string[]
}) {
  return [
    'JD 맞춤 이력서 수정 제안본',
    '',
    `핵심 강점: ${strengths[0] ?? 'JD와 연결되는 경험을 맨 앞에 배치하세요.'}`,
    `보완 필요: ${gaps[0] ?? '부족한 요구사항을 프로젝트 경험으로 보강하세요.'}`,
    `수정 방향: ${suggestions[0] ?? '성과, 규모, 사용 기술을 한 문장에 함께 적어 주세요.'}`,
    '',
    `원본 기반 요약: ${resumePreviewText}`,
  ].join('\n')
}

function getSafePercent(value: number, fallback: number) {
  if (!Number.isFinite(value)) {
    return fallback
  }

  return Math.max(0, Math.min(100, value))
}

export function ReportStep({
  result,
  previewResult,
  interviewResult,
  resultRef,
  resumePreviewText,
  jdPreviewText,
  isInterviewSubmitting,
  onInterviewSubmit,
  onResumeEdit,
  onJdEdit,
}: ReportStepProps) {
  const matchPreview = previewResult.matchPreview
  const score = matchPreview?.matchingScore ?? 0
  const strengths = matchPreview?.strengths ?? []
  const gaps = matchPreview?.gaps ?? []
  const suggestions = matchPreview?.suggestions ?? []
  const technicalFit = getSafePercent(score + 5, 92)
  const experienceFit = getSafePercent(score, 85)
  const qualificationFit = getSafePercent(score - 8, 78)
  const preferredFit = getSafePercent(score + 2, 90)
  const revisedResume = buildRevisedResume({
    resumePreviewText,
    strengths,
    gaps,
    suggestions,
  })

  return (
    <section id="report-step" className="report-workspace">
      {previewResult.status === 'success' && matchPreview ? (
        <>
          <div className="report-title-row">
            <div>
              <p>STEP 3 / 3</p>
              <h1>매칭 분석 리포트</h1>
              <span>이력서와 JD를 기준으로 정리한 AI 분석 결과입니다.</span>
            </div>
            <div className="report-actions">
              <button className="ghost-button" type="button" onClick={onJdEdit}>
                JD 다시 수정
              </button>
              <button className="ghost-button" type="button" onClick={onResumeEdit}>
                이력서 다시 수정
              </button>
            </div>
          </div>

          <section className="report-dashboard" aria-label="AI 분석 리포트">
            <article className="metric-card score-card">
              <span>종합 매칭 점수</span>
              <strong>{score}점</strong>
              <p>/ 100</p>
            </article>

            <article className="metric-card fit-card">
              <span>세부 적합도 분석</span>
              {[
                ['기술 적합도', technicalFit],
                ['경력 적합도', experienceFit],
                ['자격 적합도', qualificationFit],
                ['우대사항', preferredFit],
              ].map(([label, value]) => (
                <div className="fit-row" key={label}>
                  <b>{label}</b>
                  <div className="fit-track">
                    <span style={{ width: `${value}%` }} />
                  </div>
                  <em>{value}%</em>
                </div>
              ))}
            </article>

            <article className="metric-card insight-card">
              <span>주요 인사이트</span>
              <ul>
                {strengths.slice(0, 2).map((strength) => (
                  <li key={strength}>강점: {strength}</li>
                ))}
                {gaps.slice(0, 2).map((gap) => (
                  <li key={gap}>보완: {gap}</li>
                ))}
              </ul>
            </article>
          </section>

          <section className="report-main-grid">
            <article className="report-document-card">
              <div className="document-card__header">
                <h2>원본과 수정본 비교</h2>
                <span>JD 맞춤 개선 초안</span>
              </div>
              <div className="resume-compare-grid">
                <section className="resume-paper resume-paper--original">
                  <h3>원본 이력서</h3>
                  <p>{resumePreviewText}</p>
                </section>

                <section className="resume-paper resume-paper--revised">
                  <h3>AI 수정 제안본</h3>
                  <p>{revisedResume}</p>
                </section>
              </div>
            </article>

            <aside className="coach-card">
              <h2>AI 코치</h2>
              <p>이 매칭률을 더 높이려면 아래 항목부터 고쳐보세요.</p>
              <ol>
                {suggestions.map((suggestion) => (
                  <li key={suggestion}>{suggestion}</li>
                ))}
              </ol>
            </aside>
          </section>

          <section className="analysis-feedback-card analysis-feedback-card--submission">
            <h2>최종 제출용 정리</h2>
            <p className="submission-guide">{buildSubmissionGuide(matchPreview)}</p>
          </section>

          <section className="analysis-feedback-card interview-preview-card" aria-live="polite">
            <div className="document-card__header">
              <div>
                <h2>모의 면접 질문</h2>
                <span>이력서와 JD 맥락으로 예상 질문을 생성합니다.</span>
              </div>
              <button
                className="secondary-button"
                type="button"
                onClick={onInterviewSubmit}
                disabled={isInterviewSubmitting}
              >
                {isInterviewSubmitting ? '질문 생성 중...' : '모의 면접 질문 생성'}
              </button>
            </div>

            {interviewResult.status === 'loading' ? (
              <StatusMessage
                badge="Preparing"
                title={interviewResult.title}
                message={interviewResult.message}
                tone="active"
                withLoadingBar
              />
            ) : null}

            {interviewResult.status === 'error' ? (
              <StatusMessage
                badge="Retry"
                title={interviewResult.title}
                message={interviewResult.message}
                tone="danger"
              />
            ) : null}

            {interviewResult.status === 'success' && interviewResult.interviewPreview ? (
              <div className="interview-result">
                <p className="submission-guide">{interviewResult.interviewPreview.strategy}</p>
                <div className="interview-question-list">
                  {interviewResult.interviewPreview.questions.map((question) => (
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

          <details className="analysis-source-card">
            <summary>원문/대조 기준 보기</summary>
            <div className="source-grid">
              <article>
                <h3>이력서 기준</h3>
                <p>{resumePreviewText}</p>
              </article>
              <article>
                <h3>JD 기준</h3>
                <p>{jdPreviewText}</p>
              </article>
            </div>
          </details>
        </>
      ) : (
        <ResultPanel ref={resultRef} result={result} />
      )}

      {previewResult.status === 'loading' ? (
        <StatusMessage
          badge="Preparing"
          title={previewResult.title}
          message={previewResult.message}
          tone="active"
          withLoadingBar
        />
      ) : null}

      {previewResult.status === 'error' ? (
        <StatusMessage
          badge="Check Input"
          title={previewResult.title}
          message={`${previewResult.message} JD 본문을 직접 붙여넣어 주세요.`}
          tone="danger"
        />
      ) : null}
    </section>
  )
}

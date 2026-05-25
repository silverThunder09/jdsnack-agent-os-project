import type { RefObject } from 'react'
import { ResultPanel } from './ResultPanel'
import { StatusMessage } from './StatusMessage'
import type { ResultState } from '../types/diagnosis'

interface ReportStepProps {
  result: ResultState
  previewResult: ResultState
  resultRef: RefObject<HTMLElement | null>
  resumePreviewText: string
  jdPreviewText: string
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

function getSafePercent(value: number, fallback: number) {
  if (!Number.isFinite(value)) {
    return fallback
  }

  return Math.max(0, Math.min(100, value))
}

export function ReportStep({
  result,
  previewResult,
  resultRef,
  resumePreviewText,
  jdPreviewText,
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
                <h2>AI 추천 수정 이력서</h2>
                <span>JD 맞춤 개선 초안</span>
              </div>
              <div className="resume-paper">
                <h3>핵심 요약</h3>
                <p>{previewResult.message}</p>
                <h3>강조할 강점</h3>
                <ul>
                  {strengths.map((strength) => (
                    <li key={strength}>{strength}</li>
                  ))}
                </ul>
                <h3>보완할 부분</h3>
                <ul>
                  {gaps.map((gap) => (
                    <li key={gap}>{gap}</li>
                  ))}
                </ul>
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

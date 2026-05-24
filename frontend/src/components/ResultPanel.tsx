import { forwardRef } from 'react'
import { StatusMessage } from './StatusMessage'
import type { ResultState } from '../types/diagnosis'

interface ResultPanelProps {
  result: ResultState
}

export const ResultPanel = forwardRef<HTMLElement, ResultPanelProps>(
  function ResultPanel({ result }, ref) {
    const improvements = result.diagnosis?.improvements ?? []

    return (
      <section
        ref={ref}
        className="panel result-panel"
        aria-live="polite"
        tabIndex={-1}
      >
        <div className="panel-header">
          <div>
            <p className="panel-eyebrow">Analysis Report</p>
            <h2>분석 리포트</h2>
          </div>
        </div>

        {result.status === 'loading' ? (
          <StatusMessage
            badge="Processing"
            title={result.title}
            message={result.message}
            tone="active"
            withLoadingBar
          />
        ) : null}

        {result.status === 'idle' ? (
          <StatusMessage
            badge="Report"
            title="리포트 대기 중"
            message="이력서와 JD를 입력하면 리포트가 표시됩니다."
            tone="neutral"
          />
        ) : null}

        {result.status === 'not-enabled' ? (
          <StatusMessage
            badge="Not Enabled"
            title={result.title}
            message={result.message}
            tone="success"
          />
        ) : null}

        {result.status === 'success' && result.diagnosis ? (
          <div className="analysis-result">
            <section className="report-hero-card">
              <div className="analysis-score-card analysis-score-card--circle">
                <strong>{result.diagnosis.score}점</strong>
                <span>종합 점수</span>
              </div>
              <div className="report-summary-card">
                <span className="report-summary-label">핵심 요약</span>
                <h3>{result.title}</h3>
                <p>{result.message}</p>
              </div>
            </section>

            <div className="analysis-feedback-grid analysis-feedback-grid--report">
              <section className="analysis-feedback-card analysis-feedback-card--strength">
                <h3>강점</h3>
                <ul>
                  {result.diagnosis.strengths.map((strength) => (
                    <li key={strength}>{strength}</li>
                  ))}
                </ul>
              </section>

              <section className="analysis-feedback-card analysis-feedback-card--improve">
                <h3>부족한 역량과 개선 제안</h3>
                <ul>
                  {improvements.map((improvement) => (
                    <li key={improvement}>{improvement}</li>
                  ))}
                </ul>
              </section>
            </div>

            <details className="analysis-source-card" aria-label="분석 기준 이력서 본문">
              <summary>분석 기준 원문 보기</summary>
              <p>{result.diagnosis.sourceText}</p>
            </details>
          </div>
        ) : null}

        {result.status === 'error' ? (
          <StatusMessage
            badge="Action Needed"
            title={result.title}
            message={`${result.message} 이력서 내용을 확인한 뒤 다시 요청해 주세요.`}
            tone="danger"
          />
        ) : null}
      </section>
    )
  },
)

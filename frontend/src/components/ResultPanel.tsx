import { forwardRef } from 'react'
import { StatusMessage } from './StatusMessage'
import type { ResultState } from '../types/diagnosis'

interface ResultPanelProps {
  result: ResultState
}

export const ResultPanel = forwardRef<HTMLElement, ResultPanelProps>(
  function ResultPanel({ result }, ref) {
    return (
      <section
        ref={ref}
        className="panel result-panel"
        aria-live="polite"
        tabIndex={-1}
      >
        <div className="panel-header">
          <div>
            <p className="panel-eyebrow">Result State</p>
            <h2>현재 요청 상태</h2>
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
            badge="Ready"
            title={result.title}
            message={result.message}
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
            <StatusMessage
              badge="Analysis Result"
              title={result.title}
              message={result.message}
              tone="success"
            />

            <div className="analysis-score-card">
              <span>분석 점수</span>
              <strong>{result.diagnosis.score}점</strong>
            </div>

            <div className="analysis-feedback-grid">
              <section className="analysis-feedback-card">
                <h3>강점</h3>
                <ul>
                  {result.diagnosis.strengths.map((strength) => (
                    <li key={strength}>{strength}</li>
                  ))}
                </ul>
              </section>

              <section className="analysis-feedback-card">
                <h3>개선 포인트</h3>
                <ul>
                  {result.diagnosis.improvements.map((improvement) => (
                    <li key={improvement}>{improvement}</li>
                  ))}
                </ul>
              </section>
            </div>

            <section className="analysis-source-card" aria-label="분석 기준 이력서 본문">
              <h3>분석 기준 본문</h3>
              <p>{result.diagnosis.sourceText}</p>
            </section>
          </div>
        ) : null}

        {result.status === 'error' ? (
          <StatusMessage
            badge="Action Needed"
            title={result.title}
            message={result.message}
            tone="danger"
          />
        ) : null}

        <div className="result-meta">
          <div className="result-meta-card">
            <span>응답 모드</span>
            <strong>Stub / Fixture / AI Local</strong>
          </div>
          <div className="result-meta-card">
            <span>클라이언트 검증 기준</span>
            <strong>빈 입력 / 50자 미만 / 10,000자 초과</strong>
          </div>
        </div>
      </section>
    )
  },
)

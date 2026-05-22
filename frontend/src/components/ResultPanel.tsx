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
            <span>정상 준비중 상태</span>
            <strong>`501 AI_ANALYSIS_NOT_ENABLED`</strong>
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

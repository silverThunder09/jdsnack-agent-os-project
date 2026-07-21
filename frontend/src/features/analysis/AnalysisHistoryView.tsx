import type { AnalysisHistoryDetail, AnalysisHistorySummary } from '../../types/diagnosis'

interface AnalysisHistoryViewProps {
  histories: AnalysisHistorySummary[]
  selectedHistory: AnalysisHistoryDetail | null
  isLoading: boolean
  error: string
  onLoad: () => Promise<void>
  onSelect: (historyId: string) => Promise<void>
  onRetry: (historyId: string) => Promise<void>
  onDelete: (historyId: string) => Promise<void>
  onExport: () => void
}

function formatDate(value: string): string {
  return new Intl.DateTimeFormat('ko-KR', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value))
}

function statusLabel(status: AnalysisHistorySummary['status']): string {
  if (status === 'SUCCEEDED') return '성공'
  if (status === 'FAILED') return '실패'
  return '분석 중'
}

export function AnalysisHistoryView({ histories, selectedHistory, isLoading, error, onLoad, onSelect, onRetry, onDelete, onExport }: AnalysisHistoryViewProps) {
  const handleDelete = async () => {
    if (!selectedHistory || !window.confirm('이 분석 이력과 입력 데이터를 삭제할까요? 삭제 후 복구할 수 없습니다.')) return
    await onDelete(selectedHistory.id)
  }

  return (
    <section className="history-page" aria-label="분석 내역">
      <header className="history-page__head">
        <div>
          <p className="start-page__eyebrow">분석 내역</p>
          <h1>지난 분석을 다시 확인하세요</h1>
          <p className="history-page__sub">성공·실패 결과와 제출 당시 입력을 보관하고 재시도할 수 있습니다.</p>
        </div>
        <button type="button" className="ghost-button" onClick={() => void onLoad()} disabled={isLoading}>
          {isLoading ? '불러오는 중...' : '새로고침'}
        </button>
      </header>

      {error ? <p className="form-error" role="alert">{error}</p> : null}

      <div className="history-layout">
        <section className="history-list" aria-label="분석 이력 목록">
          <h2>최근 분석</h2>
          {histories.length === 0 ? (
            <p className="history-empty">아직 저장된 분석 내역이 없습니다.</p>
          ) : (
            <div className="history-list__items">
              {histories.map((history) => (
                <button
                  key={history.id}
                  type="button"
                  className={`history-list__item${selectedHistory?.id === history.id ? ' history-list__item--active' : ''}`}
                  onClick={() => void onSelect(history.id)}
                >
                  <span className={`history-status history-status--${history.status.toLowerCase()}`}>{statusLabel(history.status)}</span>
                  <strong>{history.jdLabel}</strong>
                  <span>{formatDate(history.createdAt)}</span>
                  <small>{history.summary ?? '분석 결과 요약이 없습니다.'}</small>
                </button>
              ))}
            </div>
          )}
        </section>

        <section className="history-detail" aria-label="분석 이력 상세">
          {selectedHistory ? (
            <>
              <div className="history-detail__head">
                <div>
                  <span className={`history-status history-status--${selectedHistory.status.toLowerCase()}`}>
                    {statusLabel(selectedHistory.status)}
                  </span>
                  <h2>{selectedHistory.input.sourceSite ?? '직접 입력 JD'}</h2>
                  <p>{formatDate(selectedHistory.createdAt)}</p>
                </div>
                <div className="history-detail__actions">
                  <button
                    type="button"
                    className="ghost-button"
                    onClick={onExport}
                    disabled={isLoading || selectedHistory.status !== 'SUCCEEDED' || !selectedHistory.result?.diagnosis && !selectedHistory.result?.match}
                    aria-disabled={selectedHistory.status !== 'SUCCEEDED' || !selectedHistory.result?.diagnosis && !selectedHistory.result?.match}
                  >
                    내보내기
                  </button>
                  <button type="button" className="ghost-button" onClick={() => void onRetry(selectedHistory.id)} disabled={isLoading}>
                    재시도
                  </button>
                  <button type="button" className="danger-button" onClick={() => void handleDelete()} disabled={isLoading}>
                    삭제
                  </button>
                </div>
              </div>
              {selectedHistory.status !== 'SUCCEEDED' ? (
                <p className="history-empty" role="status">분석이 완료된 이력만 내보낼 수 있습니다.</p>
              ) : !selectedHistory.result?.diagnosis && !selectedHistory.result?.match ? (
                <p className="history-empty" role="status">저장된 분석 결과가 없어 내보낼 수 없습니다.</p>
              ) : null}
              <div className="history-detail__input">
                <h3>제출한 JD</h3>
                <p>{selectedHistory.input.jdText}</p>
                {selectedHistory.input.sourceUrl ? <a href={selectedHistory.input.sourceUrl} target="_blank" rel="noreferrer">원본 공고 열기</a> : null}
              </div>
              {selectedHistory.result?.diagnosis ? (
                <div className="history-result-card">
                  <h3>이력서 진단</h3>
                  <strong>{selectedHistory.result.diagnosis.score}점</strong>
                  <p>{selectedHistory.result.diagnosis.summary}</p>
                </div>
              ) : null}
              {selectedHistory.result?.match ? (
                <div className="history-result-card">
                  <h3>JD 적합도</h3>
                  <strong>{selectedHistory.result.match.matchingScore}점</strong>
                  <p>{selectedHistory.result.match.summary}</p>
                </div>
              ) : null}
              {selectedHistory.failure ? <p className="form-error" role="alert">{selectedHistory.failure.message}</p> : null}
            </>
          ) : (
            <p className="history-empty">목록에서 분석 이력을 선택하면 상세 내용을 확인할 수 있습니다.</p>
          )}
        </section>
      </div>
    </section>
  )

}

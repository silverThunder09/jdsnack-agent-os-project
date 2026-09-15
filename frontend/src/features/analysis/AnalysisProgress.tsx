import {
  ANALYSIS_TASK_LABELS,
  type AnalysisProgressState,
  type AnalysisTaskKey,
  type AnalysisProgressTask,
} from './analysisProgressState'

const taskStatusLabels: Record<AnalysisProgressTask['status'], string> = {
  pending: '대기 중',
  running: '진행 중',
  succeeded: '완료',
  failed: '실패',
  skipped: '실행되지 않음',
}

const taskStatusIcons: Record<AnalysisProgressTask['status'], string> = {
  pending: '·',
  running: '…',
  succeeded: '✓',
  failed: '! ',
  skipped: '–',
}

function overallTitle(state: AnalysisProgressState): string {
  if (state.status === 'succeeded') return '분석이 완료되었습니다'
  if (state.status === 'partial-failure') return '일부 분석을 완료하지 못했습니다'
  if (state.status === 'failed') return '분석을 완료하지 못했습니다'
  if (state.currentStage === 'preparing') return '이력서와 입력을 확인하고 있습니다'
  if (state.currentStage === 'saving') return '분석 결과를 저장하고 있습니다'
  return '선택한 분석을 진행하고 있습니다'
}

function overallMessage(state: AnalysisProgressState): string {
  if (state.status === 'succeeded') return '모든 선택 항목과 분석 이력 저장을 마쳤습니다.'
  if (state.status === 'partial-failure') return '완료된 결과는 확인할 수 있습니다. 실패한 항목은 안내를 확인해 주세요.'
  if (state.status === 'failed') return '이력서 분석을 완료하지 못했습니다. 입력을 확인한 뒤 새 분석을 시작해 주세요.'
  if (state.currentStage === 'preparing') return '이력서 내용을 읽고 분석에 필요한 정보를 준비하고 있습니다.'
  if (state.currentStage === 'saving') return '결과를 정리해 분석 내역에 저장하고 있습니다.'
  return '선택한 분석을 실제 요청 상태에 맞춰 처리하고 있습니다.'
}

function taskEntries(state: AnalysisProgressState): [AnalysisTaskKey, AnalysisProgressTask][] {
  return Object.entries(state.tasks) as [AnalysisTaskKey, AnalysisProgressTask][]
}

export function AnalysisProgress({ state }: { state: AnalysisProgressState }) {
  if (state.status === 'idle') return null

  const isRunning = state.status === 'running'
  return (
    <section
      className={`analysis-progress analysis-progress--${state.status}`}
      aria-label="분석 진행 상태"
      aria-live="polite"
      aria-busy={isRunning}
    >
      <div className="analysis-progress__header">
        <div>
          <span className="analysis-progress__eyebrow">ANALYSIS STATUS</span>
          <h2>{overallTitle(state)}</h2>
          <p>{overallMessage(state)}</p>
        </div>
        <span className="analysis-progress__run-badge">{isRunning ? 'Processing' : state.status === 'succeeded' ? 'Complete' : 'Review'}</span>
      </div>

      {isRunning ? <div className="analysis-progress__bar" aria-hidden="true" /> : null}

      <ol className="analysis-progress__tasks">
        {taskEntries(state).map(([key, task]) => (
          <li key={key} className={`analysis-progress__task analysis-progress__task--${task.status}`}>
            <span className="analysis-progress__task-icon" aria-hidden="true">{taskStatusIcons[task.status]}</span>
            <div className="analysis-progress__task-content">
              <div className="analysis-progress__task-line">
                <strong>{ANALYSIS_TASK_LABELS[key]}</strong>
                <span>{taskStatusLabels[task.status]}</span>
              </div>
              {task.message && task.status !== 'running' ? <p>{task.message}</p> : null}
            </div>
          </li>
        ))}
      </ol>
    </section>
  )
}

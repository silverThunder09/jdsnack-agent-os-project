import type { ApiErrorCode } from '../../types/diagnosis'
import type { AnalysisOptionKey } from './analysisUtils'

export type AnalysisTaskKey = 'resume' | 'match' | 'ats' | 'sentence' | 'history'
export type AnalysisTaskStatus = 'pending' | 'running' | 'succeeded' | 'failed' | 'skipped'
export type AnalysisRunStatus = 'idle' | 'running' | 'succeeded' | 'partial-failure' | 'failed'
export type AnalysisProgressStage = 'preparing' | 'analyzing' | 'saving' | 'terminal'

export interface AnalysisProgressTask {
  status: AnalysisTaskStatus
  message?: string
  code?: ApiErrorCode
}

export interface AnalysisProgressState {
  runId: number
  status: AnalysisRunStatus
  currentStage: AnalysisProgressStage
  tasks: Partial<Record<AnalysisTaskKey, AnalysisProgressTask>>
}

export type AnalysisProgressOptions = Record<AnalysisOptionKey, boolean>

export const ANALYSIS_TASK_LABELS: Record<AnalysisTaskKey, string> = {
  resume: '이력서 분석',
  match: 'JD 적합도·키워드 분석',
  ats: 'ATS 분석',
  sentence: '문장 첨삭',
  history: '결과 저장',
}

const FEATURE_TASK_KEYS: AnalysisTaskKey[] = ['match', 'ats', 'sentence']
const TERMINAL_TASK_STATUSES: AnalysisTaskStatus[] = ['succeeded', 'failed', 'skipped']

function isTerminalTask(task: AnalysisProgressTask | undefined): boolean {
  return task ? TERMINAL_TASK_STATUSES.includes(task.status) : true
}

function isPendingOrRunning(task: AnalysisProgressTask | undefined): boolean {
  return task?.status === 'pending' || task?.status === 'running'
}

export function getAnalysisTaskKeys(options: AnalysisProgressOptions): AnalysisTaskKey[] {
  const keys: AnalysisTaskKey[] = ['resume']
  if (options.jdMatch || options.keyword) keys.push('match')
  if (options.ats) keys.push('ats')
  if (options.sentence) keys.push('sentence')
  keys.push('history')
  return keys
}

export function createIdleAnalysisProgressState(): AnalysisProgressState {
  return {
    runId: 0,
    status: 'idle',
    currentStage: 'terminal',
    tasks: {},
  }
}

export function createAnalysisProgressState(
  runId: number,
  options: AnalysisProgressOptions,
): AnalysisProgressState {
  const tasks: Partial<Record<AnalysisTaskKey, AnalysisProgressTask>> = {}
  for (const key of getAnalysisTaskKeys(options)) {
    tasks[key] = { status: 'pending' }
  }

  return {
    runId,
    status: 'running',
    currentStage: 'preparing',
    tasks,
  }
}

function deriveStage(state: AnalysisProgressState): AnalysisProgressStage {
  if (isPendingOrRunning(state.tasks.resume)) return 'preparing'

  if (FEATURE_TASK_KEYS.some((key) => isPendingOrRunning(state.tasks[key]))) {
    return 'analyzing'
  }

  if (isPendingOrRunning(state.tasks.history)) return 'saving'
  return 'terminal'
}

function deriveStatus(state: AnalysisProgressState): AnalysisRunStatus {
  const tasks = Object.values(state.tasks)
  if (tasks.some((task) => !isTerminalTask(task))) return 'running'

  if (state.tasks.resume?.status === 'failed') return 'failed'

  const featureTasks = FEATURE_TASK_KEYS
    .map((key) => state.tasks[key])
    .filter((task): task is AnalysisProgressTask => Boolean(task))
  const hasFailure = [...featureTasks, state.tasks.history]
    .some((task) => task?.status === 'failed')

  if (hasFailure) {
    return featureTasks.some((task) => task.status === 'succeeded')
      ? 'partial-failure'
      : 'failed'
  }

  return 'succeeded'
}

export function updateAnalysisTask(
  state: AnalysisProgressState,
  key: AnalysisTaskKey,
  status: AnalysisTaskStatus,
  details: Pick<AnalysisProgressTask, 'message' | 'code'> = {},
): AnalysisProgressState {
  if (!state.tasks[key]) return state

  const nextState: AnalysisProgressState = {
    ...state,
    tasks: {
      ...state.tasks,
      [key]: {
        status,
        message: details.message,
        code: details.code,
      },
    },
  }

  return {
    ...nextState,
    status: deriveStatus(nextState),
    currentStage: deriveStage(nextState),
  }
}

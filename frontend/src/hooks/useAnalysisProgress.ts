import { useCallback, useRef, useState } from 'react'
import {
  createAnalysisProgressState,
  createIdleAnalysisProgressState,
  type AnalysisProgressOptions,
  type AnalysisProgressState,
  type AnalysisTaskKey,
  type AnalysisTaskStatus,
  updateAnalysisTask,
} from '../features/analysis/analysisProgressState'
import type { ApiErrorCode } from '../types/diagnosis'

export function useAnalysisProgress() {
  const nextRunId = useRef(0)
  const [state, setState] = useState<AnalysisProgressState>(createIdleAnalysisProgressState)

  const start = useCallback((options: AnalysisProgressOptions) => {
    const runId = nextRunId.current + 1
    nextRunId.current = runId
    setState(createAnalysisProgressState(runId, options))
    return runId
  }, [])

  const updateTask = useCallback((
    runId: number,
    key: AnalysisTaskKey,
    status: AnalysisTaskStatus,
    details: { message?: string; code?: ApiErrorCode } = {},
  ) => {
    setState((current) => current.runId === runId
      ? updateAnalysisTask(current, key, status, details)
      : current)
  }, [])

  const reset = useCallback(() => {
    setState(createIdleAnalysisProgressState())
  }, [])

  return { reset, start, state, updateTask }
}

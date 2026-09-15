import { describe, expect, it } from 'vitest'
import {
  createAnalysisProgressState,
  updateAnalysisTask,
  type AnalysisProgressOptions,
} from './analysisProgressState'

const allOptions: AnalysisProgressOptions = {
  jdMatch: true,
  ats: true,
  sentence: true,
  keyword: true,
}

function completeTask(state: ReturnType<typeof createAnalysisProgressState>, key: Parameters<typeof updateAnalysisTask>[1]) {
  return updateAnalysisTask(state, key, 'succeeded')
}

describe('analysis progress state', () => {
  it('selects one shared match task for JD match and keyword analysis', () => {
    const state = createAnalysisProgressState(1, allOptions)

    expect(Object.keys(state.tasks)).toEqual(['resume', 'match', 'ats', 'sentence', 'history'])
  })

  it('stays running until every selected task is terminal', () => {
    let state = createAnalysisProgressState(1, allOptions)
    state = updateAnalysisTask(state, 'resume', 'running')
    state = completeTask(state, 'resume')
    state = updateAnalysisTask(state, 'match', 'running')
    state = completeTask(state, 'match')
    state = updateAnalysisTask(state, 'ats', 'succeeded')
    state = updateAnalysisTask(state, 'sentence', 'running')

    expect(state.status).toBe('running')
    expect(state.currentStage).toBe('analyzing')
  })

  it('reports partial failure while preserving successful feature results', () => {
    let state = createAnalysisProgressState(1, allOptions)
    for (const key of ['resume', 'match', 'ats'] as const) state = completeTask(state, key)
    state = updateAnalysisTask(state, 'sentence', 'failed', { message: '문장 첨삭 요청이 실패했습니다.' })
    state = completeTask(state, 'history')

    expect(state.status).toBe('partial-failure')
    expect(state.tasks.match?.status).toBe('succeeded')
    expect(state.tasks.sentence?.message).toBe('문장 첨삭 요청이 실패했습니다.')
  })

  it('reports a failed run when resume analysis fails', () => {
    let state = createAnalysisProgressState(1, allOptions)
    state = updateAnalysisTask(state, 'resume', 'failed', { message: '이력서 분석 실패' })
    for (const key of ['match', 'ats', 'sentence'] as const) state = updateAnalysisTask(state, key, 'skipped')
    state = completeTask(state, 'history')

    expect(state.status).toBe('failed')
    expect(state.currentStage).toBe('terminal')
  })
})

import { cleanup, render, screen } from '@testing-library/react'
import { afterEach, describe, expect, it } from 'vitest'
import { AnalysisProgress } from './AnalysisProgress'
import { createAnalysisProgressState, updateAnalysisTask } from './analysisProgressState'

const options = { jdMatch: true, ats: true, sentence: false, keyword: false }

describe('AnalysisProgress', () => {
  afterEach(() => cleanup())

  it('shows current work and accessible busy state', () => {
    let state = createAnalysisProgressState(1, options)
    state = updateAnalysisTask(state, 'resume', 'running')

    render(<AnalysisProgress state={state} />)

    expect(screen.getByRole('region', { name: '분석 진행 상태' })).toHaveAttribute('aria-busy', 'true')
    expect(screen.getByRole('heading', { name: '이력서와 입력을 확인하고 있습니다' })).toBeInTheDocument()
    expect(screen.getByText('이력서 분석')).toBeInTheDocument()
    expect(screen.getByText('JD 적합도·키워드 분석')).toBeInTheDocument()
    expect(screen.queryByText('문장 첨삭')).not.toBeInTheDocument()
  })

  it('shows terminal text instead of a fake percentage', () => {
    let state = createAnalysisProgressState(1, options)
    for (const key of ['resume', 'match', 'ats', 'history'] as const) state = updateAnalysisTask(state, key, 'succeeded')

    render(<AnalysisProgress state={state} />)

    expect(screen.getByRole('heading', { name: '분석이 완료되었습니다' })).toBeInTheDocument()
    expect(screen.getByRole('region', { name: '분석 진행 상태' })).toHaveAttribute('aria-busy', 'false')
    expect(screen.queryByText(/%/)).not.toBeInTheDocument()
  })
})

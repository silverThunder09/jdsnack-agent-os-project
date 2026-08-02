import { cleanup, render, screen } from '@testing-library/react'
import { afterEach, describe, expect, it } from 'vitest'
import { AnalysisQualityPrototype } from './AnalysisQualityPrototype'

describe('AnalysisQualityPrototype', () => {
  afterEach(() => {
    cleanup()
    window.history.replaceState({}, '', '/')
  })

  it('AC-02/TC-03: 평가 기준 버전만 표시하고 내부 모델·프롬프트 버전은 노출하지 않는다', () => {
    window.history.replaceState({}, '', '/?prototype=analysis-quality&variant=C')

    render(<AnalysisQualityPrototype />)

    expect(screen.getByText('quality-v1')).toBeInTheDocument()
    expect(screen.queryAllByText(/model|prompt|모델|프롬프트/i)).toHaveLength(0)
    expect(screen.queryAllByText(/gemini-2\.5|diagnosis-v3/i)).toHaveLength(0)
  })

  it('86점은 품질 상태 계약에 따라 일부 확인 필요로 안내한다', () => {
    window.history.replaceState({}, '', '/?prototype=analysis-quality&variant=B')

    render(<AnalysisQualityPrototype />)

    expect(screen.getByText('일부 확인 필요')).toBeInTheDocument()
    expect(screen.getByText('일부 확인이 필요합니다.')).toBeInTheDocument()
    expect(screen.queryByText('GOOD')).not.toBeInTheDocument()
    expect(screen.queryByText('좋은 상태입니다.')).not.toBeInTheDocument()
  })
})

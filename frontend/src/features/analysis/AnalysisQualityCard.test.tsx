import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { AnalysisQualityCard } from './AnalysisQualityCard'

describe('AnalysisQualityCard', () => {
  it('quality-v1의 세 평가 항목만 표시한다', () => {
    render(
      <AnalysisQualityCard
        quality={{
          score: 86,
          evaluatorVersion: 'quality-v1',
          metrics: [
            { label: '응답 형식 준수', value: 100, note: '형식이 유효합니다.' },
            { label: '근거 연결성', value: 82, note: '근거가 연결됩니다.' },
            { label: '결과 완성도', value: 88, note: '결과가 완성되었습니다.' },
          ],
        }}
      />,
    )

    const card = screen.getByRole('region', { name: 'AI 분석 품질' })
    expect(card).toHaveTextContent('86/100')
    expect(card).toHaveTextContent('응답 형식 준수')
    expect(card).toHaveTextContent('근거 연결성')
    expect(card).toHaveTextContent('결과 완성도')
    expect(card).not.toHaveTextContent('분석 일관성')
  })
})

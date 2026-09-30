import { cleanup, render, screen } from '@testing-library/react'
import { afterEach, describe, expect, it } from 'vitest'
import type { ResultState } from '../../types/diagnosis'
import { AnalysisPanel } from './AnalysisPanels'

const panelProps = {
  badge: 'AI 진단',
  title: 'AI 진단',
  description: '이력서 분석 결과를 확인합니다.',
  successContent: null,
}

describe('AnalysisPanel 상태 접근성', () => {
  afterEach(() => cleanup())

  it('분석 진행 상태를 배지와 정중한 라이브 영역으로 표시한다', () => {
    const result: ResultState = {
      status: 'loading',
      title: '요청을 확인하고 있습니다',
      message: '분석을 진행하고 있습니다.',
    }

    render(<AnalysisPanel {...panelProps} result={result} />)

    const badge = screen.getByText('분석 중')
    expect(badge).toBeInTheDocument()
    expect(badge.closest('[aria-live="polite"]')).toBeInTheDocument()
  })

  it('오류 상태를 확인 필요 배지와 alert로 전달한다', () => {
    const result: ResultState = {
      status: 'error',
      title: 'AI 분석 설정을 확인해주세요',
      message: '관리자에게 AI 설정을 확인해달라고 알려주세요.',
    }

    render(<AnalysisPanel {...panelProps} result={result} />)

    const alert = screen.getByRole('alert')
    expect(alert).toHaveTextContent('확인 필요')
    expect(alert).toHaveTextContent('AI 분석 설정을 확인해주세요')
    expect(alert).toHaveTextContent('관리자에게 AI 설정을 확인해달라고 알려주세요.')
  })
})

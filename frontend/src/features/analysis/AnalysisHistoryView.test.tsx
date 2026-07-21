import { cleanup, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, describe, expect, it, vi } from 'vitest'
import type { AnalysisHistoryDetail } from '../../types/diagnosis'
import { AnalysisHistoryView } from './AnalysisHistoryView'

function detail(status: AnalysisHistoryDetail['status'], hasResult = true): AnalysisHistoryDetail {
  return {
    id: 'history-1', status, createdAt: '2026-07-19T12:00:00Z',
    input: { resumeText: 'resume', jdInputType: 'TEXT', jdText: 'jd', sourceUrl: null, sourceSite: null },
    result: hasResult ? {
      diagnosis: { score: 84, summary: '요약', strengths: [], improvements: [], sourceText: '원문' },
      match: null,
    } : null,
    failure: status === 'FAILED' ? { code: 'INTERNAL_ERROR', message: '실패' } : null,
  }
}

function renderView(selectedHistory: AnalysisHistoryDetail) {
  return render(
    <AnalysisHistoryView
      histories={[]}
      selectedHistory={selectedHistory}
      isLoading={false}
      error=""
      onLoad={async () => undefined}
      onSelect={async () => undefined}
      onRetry={async () => undefined}
      onDelete={async () => undefined}
      onExport={vi.fn()}
    />,
  )
}

describe('AnalysisHistoryView 내보내기', () => {
  afterEach(() => cleanup())

  it('성공 이력에서 내보내기 버튼을 활성화한다', () => {
    renderView(detail('SUCCEEDED'))
    expect(screen.getByRole('button', { name: '내보내기' })).toBeEnabled()
  })

  it('진행 중·실패 이력에서는 내보내기를 비활성화하고 안내한다', () => {
    const { rerender } = renderView(detail('RUNNING'))
    expect(screen.getByRole('button', { name: '내보내기' })).toBeDisabled()
    expect(screen.getByRole('status')).toHaveTextContent('분석이 완료된 이력만 내보낼 수 있습니다.')

    rerender(
      <AnalysisHistoryView
        histories={[]}
        selectedHistory={detail('FAILED')}
        isLoading={false}
        error=""
        onLoad={async () => undefined}
        onSelect={async () => undefined}
        onRetry={async () => undefined}
        onDelete={async () => undefined}
        onExport={vi.fn()}
      />,
    )
    expect(screen.getByRole('button', { name: '내보내기' })).toBeDisabled()
  })

  it('저장 결과가 없으면 내보내기를 비활성화한다', () => {
    renderView(detail('SUCCEEDED', false))
    expect(screen.getByRole('button', { name: '내보내기' })).toBeDisabled()
    expect(screen.getByRole('status')).toHaveTextContent('저장된 분석 결과가 없어 내보낼 수 없습니다.')
  })

  it('성공 이력의 내보내기 클릭을 부모에 위임한다', async () => {
    const onExport = vi.fn()
    const user = userEvent.setup()
    render(
      <AnalysisHistoryView
        histories={[]}
        selectedHistory={detail('SUCCEEDED')}
        isLoading={false}
        error=""
        onLoad={async () => undefined}
        onSelect={async () => undefined}
        onRetry={async () => undefined}
        onDelete={async () => undefined}
        onExport={onExport}
      />,
    )

    await user.click(screen.getByRole('button', { name: '내보내기' }))
    expect(onExport).toHaveBeenCalledOnce()
  })
})

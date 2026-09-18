import { cleanup, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, describe, expect, it, vi } from 'vitest'
import type { AnalysisHistoryDetail } from '../../types/diagnosis'
import { AnalysisHistoryView } from './AnalysisHistoryView'

function detail(
  status: AnalysisHistoryDetail['status'],
  hasResult = true,
  feedback: AnalysisHistoryDetail['feedback'] = null,
  sourceSite: string | null = null,
  fetchMode: string | null = null,
): AnalysisHistoryDetail {
  return {
    id: 'history-1', status, createdAt: '2026-07-19T12:00:00Z',
    input: { resumeText: 'resume', jdInputType: sourceSite === 'jobkorea' ? 'JOBKOREA_URL' : 'TEXT', jdText: 'jd', sourceUrl: null, sourceSite, fetchMode },
    result: hasResult ? {
      diagnosis: { score: 84, summary: '요약', strengths: [], improvements: [], sourceText: '원문' },
      match: null,
    } : null,
    failure: status === 'FAILED' ? { code: 'INTERNAL_ERROR', message: '실패' } : null,
    feedback,
  }
}

function renderView(selectedHistory: AnalysisHistoryDetail, onSubmitFeedback = vi.fn()) {
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
      onSubmitFeedback={onSubmitFeedback}
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
        onSubmitFeedback={vi.fn()}
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
        onSubmitFeedback={vi.fn()}
      />,
    )

    await user.click(screen.getByRole('button', { name: '내보내기' }))
    expect(onExport).toHaveBeenCalledOnce()
  })

  it('잡코리아 OCR 이력은 출처와 OCR 저장 사실을 표시한다', () => {
    renderView(detail('SUCCEEDED', true, null, 'jobkorea', 'image-ocr'))

    expect(screen.getByRole('heading', { name: '잡코리아' })).toBeInTheDocument()
    expect(screen.getByText('이미지 공고를 OCR로 인식해 저장한 JD')).toBeInTheDocument()
  })
})

/** TC-13 (AC-04~AC-06) 피드백 위젯 */
describe('AnalysisHistoryView 피드백 위젯', () => {
  afterEach(() => cleanup())

  it('성공 이력에서 좋아요·별로예요 버튼을 노출한다', () => {
    renderView(detail('SUCCEEDED'))
    expect(screen.getByRole('button', { name: '좋아요' })).toBeEnabled()
    expect(screen.getByRole('button', { name: '별로예요' })).toBeEnabled()
  })

  it('평가를 고르기 전에는 제출 버튼을 비활성화한다', () => {
    renderView(detail('SUCCEEDED'))
    expect(screen.getByRole('button', { name: '피드백 보내기' })).toBeDisabled()
  })

  it('평가와 코멘트를 담아 제출을 부모에 위임하고 저장 결과를 알린다', async () => {
    const onSubmitFeedback = vi.fn().mockResolvedValue(undefined)
    const user = userEvent.setup()
    renderView(detail('SUCCEEDED'), onSubmitFeedback)

    await user.click(screen.getByRole('button', { name: '좋아요' }))
    await user.type(screen.getByRole('textbox'), '도움이 되었어요')
    await user.click(screen.getByRole('button', { name: '피드백 보내기' }))

    expect(onSubmitFeedback).toHaveBeenCalledWith('history-1', 'LIKE', '도움이 되었어요')
    expect(screen.getByText('피드백이 저장되었습니다.')).toBeInTheDocument()
  })

  it('기존 피드백을 선택 상태와 코멘트로 미리 채운다', () => {
    renderView(detail('SUCCEEDED', true, {
      rating: 'DISLIKE',
      comment: '아쉬웠어요',
      updatedAt: '2026-07-21T12:00:00Z',
    }))

    expect(screen.getByRole('button', { name: '별로예요' })).toHaveAttribute('aria-pressed', 'true')
    expect(screen.getByRole('button', { name: '좋아요' })).toHaveAttribute('aria-pressed', 'false')
    expect(screen.getByRole('textbox')).toHaveValue('아쉬웠어요')
  })

  it('진행 중·실패 이력에는 위젯 대신 안내를 보여준다', () => {
    const { rerender } = renderView(detail('RUNNING'))
    expect(screen.queryByRole('button', { name: '좋아요' })).not.toBeInTheDocument()
    expect(screen.getByText('완료된 분석 결과가 없어 아직 평가할 수 없습니다.')).toBeInTheDocument()

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
        onSubmitFeedback={vi.fn()}
      />,
    )
    expect(screen.queryByRole('button', { name: '피드백 보내기' })).not.toBeInTheDocument()
  })

  it('제출 실패 시 서버 오류 메시지를 그대로 보여준다', async () => {
    const onSubmitFeedback = vi.fn().mockRejectedValue(new Error('분석이 완료된 이력에만 피드백을 남길 수 있습니다.'))
    const user = userEvent.setup()
    renderView(detail('SUCCEEDED'), onSubmitFeedback)

    await user.click(screen.getByRole('button', { name: '좋아요' }))
    await user.click(screen.getByRole('button', { name: '피드백 보내기' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('분석이 완료된 이력에만 피드백을 남길 수 있습니다.')
  })
})

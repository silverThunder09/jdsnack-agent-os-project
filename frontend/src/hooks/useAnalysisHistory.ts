import { useState } from 'react'
import {
  deleteAnalysisHistory,
  getAnalysisHistory,
  listAnalysisHistories,
  retryAnalysisHistory,
  submitAnalysisFeedback,
  NetworkError,
} from '../services/api'
import type {
  AnalysisFeedbackRating,
  AnalysisHistoryDetail,
  AnalysisHistorySummary,
} from '../types/diagnosis'

export function useAnalysisHistory() {
  const [histories, setHistories] = useState<AnalysisHistorySummary[]>([])
  const [selectedHistory, setSelectedHistory] = useState<AnalysisHistoryDetail | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState('')

  const run = async (request: () => Promise<void>) => {
    setIsLoading(true)
    setError('')
    try {
      await request()
    } catch (reason) {
      setError(reason instanceof NetworkError ? reason.message : '분석 이력을 불러오지 못했습니다.')
    } finally {
      setIsLoading(false)
    }
  }

  const load = async () => {
    await run(async () => {
      setHistories(await listAnalysisHistories())
    })
  }

  const select = async (historyId: string) => {
    await run(async () => {
      setSelectedHistory(await getAnalysisHistory(historyId))
    })
  }

  const retry = async (historyId: string) => {
    await run(async () => {
      const next = await retryAnalysisHistory(historyId)
      setSelectedHistory(next)
      setHistories(await listAnalysisHistories())
    })
  }

  const remove = async (historyId: string) => {
    await run(async () => {
      await deleteAnalysisHistory(historyId)
      setHistories((current) => current.filter((history) => history.id !== historyId))
      setSelectedHistory((current) => current?.id === historyId ? null : current)
    })
  }

  // run()은 오류를 삼키고 공용 메시지로 바꾸므로 피드백 제출에는 쓰지 않는다.
  // 위젯이 409/400 같은 서버 메시지를 그대로 보여줄 수 있도록 오류를 그대로 던진다.
  const submitFeedback = async (
    historyId: string,
    rating: AnalysisFeedbackRating,
    comment: string | null,
  ) => {
    const saved = await submitAnalysisFeedback(historyId, rating, comment)
    setSelectedHistory((current) => current?.id === historyId
      ? { ...current, feedback: { rating: saved.rating, comment: saved.comment, updatedAt: saved.updatedAt } }
      : current)
  }

  return { histories, selectedHistory, isLoading, error, load, select, retry, remove, submitFeedback }
}

import { useState } from 'react'
import {
  deleteAnalysisHistory,
  getAnalysisHistory,
  listAnalysisHistories,
  retryAnalysisHistory,
  NetworkError,
} from '../services/api'
import type { AnalysisHistoryDetail, AnalysisHistorySummary } from '../types/diagnosis'

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

  return { histories, selectedHistory, isLoading, error, load, select, retry, remove }
}

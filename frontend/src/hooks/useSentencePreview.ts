import { useState } from 'react'
import { NetworkError, previewSentence } from '../services/api'
import type { MatchPreviewRequest, ResultState } from '../types/diagnosis'

const idleState: ResultState = {
  status: 'idle',
  title: '문장 첨삭 단계입니다',
  message: '이력서와 JD를 입력하면 문장별 개선안을 확인할 수 있습니다.',
}

export function useSentencePreview() {
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [result, setResult] = useState<ResultState>(idleState)

  const resetResult = () => setResult(idleState)

  const submit = async (request: MatchPreviewRequest) => {
    setIsSubmitting(true)
    setResult({
      status: 'loading',
      title: '문장을 첨삭하고 있습니다',
      message: '이력서 문장을 JD 요구사항에 맞춰 다듬고 있습니다.',
    })

    try {
      const outcome = await previewSentence(request)
      if (outcome.kind === 'success') {
        setResult({
          status: 'success',
          title: '문장 첨삭을 완료했습니다',
          message: '원문과 개선문, 개선 사유를 확인하세요.',
          sentencePreview: outcome.result,
        })
        return
      }

      setResult({
        status: 'error',
        title: outcome.kind === 'validation-error' ? '입력 확인이 필요합니다' : '문장 첨삭을 완료하지 못했습니다',
        message: outcome.message,
        code: outcome.code,
      })
    } catch (error) {
      setResult({
        status: 'error',
        title: '문장 첨삭을 완료하지 못했습니다',
        message:
          error instanceof NetworkError
            ? error.message
            : '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
      })
    } finally {
      setIsSubmitting(false)
    }
  }

  return { isSubmitting, resetResult, result, submit }
}

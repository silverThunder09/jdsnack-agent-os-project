import { useState } from 'react'
import { NetworkError, previewAts } from '../services/api'
import { validateJdText, validateJdUrl } from './useMatchPreview'
import type { ApiErrorCode, MatchPreviewRequest, ResultState } from '../types/diagnosis'

const idleState: ResultState = {
  status: 'idle',
  title: 'ATS 진단 단계입니다',
  message: '이력서와 JD를 기준으로 ATS가 읽을 수 있는 신호를 점검합니다.',
}

const loadingState: ResultState = {
  status: 'loading',
  title: 'ATS 진단을 생성하고 있습니다',
  message: '섹션 구조, 키워드, 성과 수치와 연락처 단서를 확인하고 있습니다.',
}

export function useAtsPreview() {
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [result, setResult] = useState<ResultState>(idleState)

  const resetResult = () => setResult(idleState)

  const submit = async (request: MatchPreviewRequest) => {
    const validationMessage = validateJdText(request.jdText) || validateJdUrl(request.jdUrl ?? '')
    if (validationMessage) {
      setResult({ status: 'error', title: 'ATS 진단 입력을 확인해 주세요', message: validationMessage })
      return
    }

    setIsSubmitting(true)
    setResult(loadingState)

    try {
      const outcome = await previewAts(request)
      if (outcome.kind === 'success') {
        setResult({
          status: 'success',
          title: 'ATS 진단을 완료했습니다',
          message: outcome.result.summary,
          atsPreview: outcome.result,
        })
        return
      }

      setResult({
        status: 'error',
        title: outcome.kind === 'validation-error' ? 'ATS 진단 입력을 확인해 주세요' : 'ATS 진단을 완료하지 못했습니다',
        message: outcome.message,
        code: outcome.code as ApiErrorCode,
      })
    } catch (error) {
      setResult({
        status: 'error',
        title: 'ATS 진단을 완료하지 못했습니다',
        message: error instanceof NetworkError ? error.message : '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
      })
    } finally {
      setIsSubmitting(false)
    }
  }

  return { isSubmitting, result, submit, resetResult }
}

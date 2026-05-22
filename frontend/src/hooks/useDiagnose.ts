import { useState } from 'react'
import { diagnoseResume, NetworkError } from '../services/api'
import type { ResultState } from '../types/diagnosis'

const idleState: ResultState = {
  status: 'idle',
  title: '입력 대기 상태입니다',
  message:
    '이력서를 붙여넣고 진단 요청을 누르면 입력 검증 결과와 1차 MVP 준비 상태를 확인할 수 있습니다.',
}

const loadingState: ResultState = {
  status: 'loading',
  title: '요청을 확인하고 있습니다',
  message:
    '입력 길이와 요청 형식을 검증하는 중입니다. 1차 MVP에서는 성공 후 준비중 안내로 이어집니다.',
}

const validationMessages = {
  empty: '이력서 내용을 입력해주세요.',
  tooShort: '이력서 내용이 너무 짧습니다. 최소 50자 이상 입력해주세요.',
  tooLong: '이력서 내용이 너무 깁니다. 10,000자 이내로 입력해주세요.',
}

export function validateResumeText(resumeText: string): string | null {
  const trimmedText = resumeText.trim()

  if (!trimmedText) {
    return validationMessages.empty
  }

  if (trimmedText.length < 50) {
    return validationMessages.tooShort
  }

  if (trimmedText.length > 10_000) {
    return validationMessages.tooLong
  }

  return null
}

export function useDiagnose() {
  const [inlineError, setInlineError] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [result, setResult] = useState<ResultState>(idleState)

  const clearInlineError = () => setInlineError('')

  const resetResult = () => {
    setResult(idleState)
  }

  const submit = async (resumeText: string) => {
    const validationError = validateResumeText(resumeText)

    if (validationError) {
      setInlineError(validationError)
      setResult({
        status: 'error',
        title: '입력 확인이 필요합니다',
        message: validationError,
      })
      return
    }

    setInlineError('')
    setIsSubmitting(true)
    setResult(loadingState)

    try {
      const outcome = await diagnoseResume({ resumeText })

      if (outcome.kind === 'not-enabled') {
        setResult({
          status: 'not-enabled',
          title: 'AI 분석 기능은 준비 중입니다',
          message: outcome.message,
          code: outcome.code,
        })
        return
      }

      setInlineError(outcome.message)
      setResult({
        status: 'error',
        title: '입력 확인이 필요합니다',
        message: outcome.message,
        code: outcome.code,
      })
    } catch (error) {
      const message =
        error instanceof NetworkError
          ? error.message
          : '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.'

      setResult({
        status: 'error',
        title: '요청을 완료하지 못했습니다',
        message,
      })
    } finally {
      setIsSubmitting(false)
    }
  }

  return {
    clearInlineError,
    inlineError,
    isSubmitting,
    resetResult,
    result,
    submit,
  }
}

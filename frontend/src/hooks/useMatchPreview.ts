import { useState } from 'react'
import { NetworkError, previewMatch } from '../services/api'
import type { ApiErrorCode, MatchPreviewRequest, ResultState } from '../types/diagnosis'

const idleState: ResultState = {
  status: 'idle',
  title: 'JD 비교 미리보기 단계입니다',
  message:
    '이력서 다음 단계로 JD를 입력하면 키워드 기준 비교 미리보기를 먼저 확인할 수 있습니다.',
}

const loadingState: ResultState = {
  status: 'loading',
  title: 'JD 비교 미리보기를 생성하고 있습니다',
  message:
    'JD 본문과 링크 형식을 검증하고, 이력서와의 키워드 겹침을 정리하고 있습니다.',
}

const textValidationMessages = {
  empty: 'JD 내용을 입력해주세요.',
  tooShort: 'JD 내용이 너무 짧습니다. 핵심 자격요건이 드러나도록 더 입력해주세요.',
  tooLong: 'JD 내용이 너무 깁니다. 핵심 본문만 정리해서 입력해주세요.',
}

const invalidUrlMessage = '올바른 JD 링크 형식을 입력해주세요.'

function isValidHttpUrl(value: string): boolean {
  try {
    const parsed = new URL(value)
    return parsed.protocol === 'http:' || parsed.protocol === 'https:'
  } catch {
    return false
  }
}

export function validateJdText(value: string): string {
  const trimmed = value.trim()
  if (!trimmed) {
    return textValidationMessages.empty
  }

  if (trimmed.length < 50) {
    return textValidationMessages.tooShort
  }

  if (trimmed.length > 10_000) {
    return textValidationMessages.tooLong
  }

  return ''
}

export function validateJdUrl(value: string): string {
  const trimmed = value.trim()
  if (!trimmed) {
    return ''
  }

  return isValidHttpUrl(trimmed) ? '' : invalidUrlMessage
}

export function useMatchPreview() {
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [jdTextError, setJdTextError] = useState('')
  const [jdUrlError, setJdUrlError] = useState('')
  const [result, setResult] = useState<ResultState>(idleState)

  const clearErrors = () => {
    setJdTextError('')
    setJdUrlError('')
  }

  const resetResult = () => {
    setResult(idleState)
  }

  const handleValidationError = (code: ApiErrorCode, message: string) => {
    if (
      code === 'EMPTY_JD' ||
      code === 'JD_TEXT_TOO_SHORT' ||
      code === 'JD_TEXT_TOO_LONG'
    ) {
      setJdTextError(message)
    }

    if (code === 'INVALID_JD_URL') {
      setJdUrlError(message)
    }

    setResult({
      status: 'error',
      title: 'JD 입력 확인이 필요합니다',
      message,
      code,
    })
  }

  const submit = async (request: MatchPreviewRequest) => {
    const nextTextError = validateJdText(request.jdText)
    const nextUrlError = validateJdUrl(request.jdUrl ?? '')

    clearErrors()

    if (nextTextError || nextUrlError) {
      setJdTextError(nextTextError)
      setJdUrlError(nextUrlError)
      setResult({
        status: 'error',
        title: 'JD 입력 확인이 필요합니다',
        message: nextTextError || nextUrlError,
      })
      return
    }

    setIsSubmitting(true)
    setResult(loadingState)

    try {
      const outcome = await previewMatch(request)

      if (outcome.kind === 'success') {
        setResult({
          status: 'success',
          title: 'JD 비교 미리보기를 만들었습니다',
          message: outcome.result.summary,
          matchPreview: outcome.result,
        })
        return
      }

      if (outcome.kind === 'validation-error') {
        handleValidationError(outcome.code, outcome.message)
        return
      }

      if (outcome.kind === 'error') {
        setResult({
          status: 'error',
          title: 'JD 비교 요청을 완료하지 못했습니다',
          message: outcome.message,
          code: outcome.code,
        })
        return
      }

      setResult({
        status: 'error',
        title: 'JD 비교 요청을 완료하지 못했습니다',
        message: '예상하지 못한 응답 형식입니다.',
      })
    } catch (error) {
      const message =
        error instanceof NetworkError
          ? error.message
          : '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.'

      setResult({
        status: 'error',
        title: 'JD 비교 요청을 완료하지 못했습니다',
        message,
      })
    } finally {
      setIsSubmitting(false)
    }
  }

  return {
    clearErrors,
    isSubmitting,
    jdTextError,
    jdUrlError,
    resetResult,
    result,
    submit,
  }
}

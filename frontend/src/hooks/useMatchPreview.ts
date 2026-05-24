import { useState } from 'react'
import { fetchJdFromUrl, NetworkError, previewMatch } from '../services/api'
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
    'JD 본문과 링크 형식을 검증하고, 이력서와의 키워드 또는 AI 기준 비교 결과를 정리하고 있습니다.',
}

const textValidationMessages = {
  empty: 'JD 내용을 입력해주세요.',
  tooShort: 'JD 내용이 너무 짧습니다. 핵심 자격요건이 드러나도록 더 입력해주세요.',
  tooLong: 'JD 내용이 너무 깁니다. 핵심 본문만 정리해서 입력해주세요.',
}

const invalidUrlMessage = '올바른 JD 링크 형식을 입력해주세요.'

type JdFetchStatus = 'idle' | 'fetching' | 'fetched' | 'fetch-error'

interface JdFetchState {
  status: JdFetchStatus
  title: string
  message: string
}

const jdFetchIdleState: JdFetchState = {
  status: 'idle',
  title: 'JD 링크에서 본문을 불러올 수 있습니다',
  message:
    '채용공고 링크를 넣고 불러오기를 누르면 자동 수집을 먼저 시도합니다. 실패하면 아래 JD 본문 칸에 직접 붙여넣으면 됩니다.',
}

const jdFetchLoadingState: JdFetchState = {
  status: 'fetching',
  title: 'JD 링크에서 본문을 불러오고 있습니다',
  message:
    '사람인 정적 HTML 기준으로 공고 본문을 확인하고 있습니다. 실패하면 직접 붙여넣기 안내로 이어집니다.',
}

function getJdFetchErrorMessage(code: ApiErrorCode, fallbackMessage: string): string {
  if (code === 'JD_FETCH_UNSUPPORTED_SOURCE') {
    return '이 링크에서는 JD 본문을 확실히 추출하지 못했습니다. JD 내용 칸에 핵심 본문을 직접 붙여넣어 주세요.'
  }

  if (code === 'JD_FETCH_EMPTY_CONTENT') {
    return '링크는 읽었지만 JD 본문이 충분하지 않았습니다. 주요 업무와 자격요건을 직접 붙여넣어 주세요.'
  }

  if (code === 'JD_FETCH_FAILED') {
    return 'JD 링크를 지금은 읽어오지 못했습니다. 잠시 후 다시 시도하거나 JD 본문을 직접 붙여넣어 주세요.'
  }

  if (code === 'INVALID_JD_URL') {
    return invalidUrlMessage
  }

  return fallbackMessage
}

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
  const [isFetchingJd, setIsFetchingJd] = useState(false)
  const [jdTextError, setJdTextError] = useState('')
  const [jdUrlError, setJdUrlError] = useState('')
  const [result, setResult] = useState<ResultState>(idleState)
  const [jdFetchState, setJdFetchState] = useState<JdFetchState>(jdFetchIdleState)

  const clearErrors = () => {
    setJdTextError('')
    setJdUrlError('')
  }

  const resetResult = () => {
    setResult(idleState)
  }

  const resetJdFetchState = () => {
    setJdFetchState(jdFetchIdleState)
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
        const isGeminiError =
          outcome.code === 'GEMINI_API_KEY_MISSING' ||
          outcome.code === 'GEMINI_API_REQUEST_FAILED' ||
          outcome.code === 'GEMINI_API_RESPONSE_INVALID'

        setResult({
          status: 'error',
          title: isGeminiError
            ? 'JD AI 매칭을 완료하지 못했습니다'
            : 'JD 비교 요청을 완료하지 못했습니다',
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

  const fetchJd = async (
    jdUrl: string,
    handlers: {
      onFetched: (jdText: string) => void
      onBeforeChange?: () => void
    },
  ) => {
    const nextUrlError = validateJdUrl(jdUrl)

    if (nextUrlError) {
      setJdUrlError(nextUrlError)
      setJdFetchState({
        status: 'fetch-error',
        title: 'JD 링크 형식을 확인해 주세요',
        message: nextUrlError,
      })
      return
    }

    clearErrors()
    handlers.onBeforeChange?.()
    setIsFetchingJd(true)
    setJdFetchState(jdFetchLoadingState)

    try {
      const outcome = await fetchJdFromUrl(jdUrl.trim())

      if (outcome.kind === 'success') {
        handlers.onFetched(outcome.result.jdText)
        setJdFetchState({
          status: 'fetched',
          title: 'JD 본문을 불러왔습니다',
          message: '자동 수집된 본문을 JD 내용 칸에 채웠습니다. 필요하면 문구를 다듬은 뒤 비교를 진행해 주세요.',
        })
        return
      }

      const message = getJdFetchErrorMessage(outcome.code, outcome.message)
      if (outcome.code === 'INVALID_JD_URL') {
        setJdUrlError(message)
      }

      setJdFetchState({
        status: 'fetch-error',
        title: 'JD 링크에서 본문을 가져오지 못했습니다',
        message,
      })
    } catch (error) {
      const message =
        error instanceof NetworkError
          ? error.message
          : 'JD 링크를 읽는 중 서버 오류가 발생했습니다. 직접 붙여넣기로 이어서 진행해 주세요.'

      setJdFetchState({
        status: 'fetch-error',
        title: 'JD 링크에서 본문을 가져오지 못했습니다',
        message,
      })
    } finally {
      setIsFetchingJd(false)
    }
  }

  return {
    clearErrors,
    fetchJd,
    isSubmitting,
    isFetchingJd,
    jdFetchState,
    jdTextError,
    jdUrlError,
    resetJdFetchState,
    resetResult,
    result,
    submit,
  }
}

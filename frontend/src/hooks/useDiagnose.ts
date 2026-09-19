import { useState } from 'react'
import { diagnoseResume, diagnoseResumeFile, NetworkError } from '../services/api'
import type { ApiErrorCode, ResultState, ResumeInputMode } from '../types/diagnosis'

type GeminiErrorCode = Extract<
  ApiErrorCode,
  | 'GEMINI_API_KEY_MISSING'
  | 'GEMINI_API_REQUEST_FAILED'
  | 'GEMINI_API_RESPONSE_INVALID'
>

interface DiagnosisErrorGuidance {
  title: string
  message: string
}

const geminiErrorGuidance: Record<GeminiErrorCode, DiagnosisErrorGuidance> = {
  GEMINI_API_KEY_MISSING: {
    title: 'AI 분석 설정을 확인해주세요',
    message:
      'AI 연결 설정이 없어 분석을 시작하지 못했어요. 이력서 내용을 다시 입력하기보다 관리자에게 AI 설정을 확인해달라고 알려주세요.',
  },
  GEMINI_API_REQUEST_FAILED: {
    title: 'AI 서비스가 잠시 바쁩니다',
    message:
      'AI 서비스가 일시적으로 응답하지 않아 분석을 끝내지 못했어요. 입력한 이력서에는 문제가 없으니 잠시 후 다시 시도해주세요.',
  },
  GEMINI_API_RESPONSE_INVALID: {
    title: 'AI 결과를 읽지 못했어요',
    message:
      'AI가 분석 결과를 완성하지 못해 결과를 표시할 수 없어요. 잠시 후 다시 시도해주세요. 같은 문제가 계속되면 관리자에게 알려주세요.',
  },
}

export function getDiagnosisErrorGuidance(
  code: GeminiErrorCode,
  fallbackMessage: string,
): DiagnosisErrorGuidance {
  return (
    geminiErrorGuidance[code] ?? {
      title: 'AI 분석을 완료하지 못했어요',
      message: fallbackMessage,
    }
  )
}

const idleState: ResultState = {
  status: 'idle',
  title: '입력 대기 상태입니다',
  message:
    '이력서를 붙여넣고 진단 요청을 누르면 입력 검증 뒤 분석 결과를 확인할 수 있습니다.',
}

const loadingState: ResultState = {
  status: 'loading',
  title: '요청을 확인하고 있습니다',
  message:
    '잠시만 기다려주세요. 이력서 내용을 확인한 뒤 분석을 진행하고 있습니다.',
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

export function validateResumeFile(
  mode: ResumeInputMode,
  file: File | null,
): string | null {
  if (!file) {
    return mode === 'pdf'
      ? 'PDF 파일을 선택해주세요.'
      : 'DOCX 파일을 선택해주세요.'
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

  const handleOutcome = (outcome: Awaited<ReturnType<typeof diagnoseResume>>) => {
    if (outcome.kind === 'success') {
      setResult({
        status: 'success',
        title: '이력서 분석 결과입니다',
        message: outcome.result.summary,
        diagnosis: outcome.result,
      })
      return {
        ok: true as const,
        diagnosis: outcome.result,
      }
    }

    if (outcome.kind === 'not-enabled') {
      setResult({
        status: 'not-enabled',
        title: 'AI 분석 기능은 준비 중입니다',
        message: outcome.message,
        code: outcome.code,
      })
      return { ok: false as const, message: outcome.message, code: outcome.code }
    }

    if (outcome.kind === 'validation-error') {
      setInlineError(outcome.message)
      setResult({
        status: 'error',
        title: '입력 확인이 필요합니다',
        message: outcome.message,
        code: outcome.code,
      })
      return { ok: false as const, message: outcome.message, code: outcome.code }
    }

    if (
      outcome.code === 'UNSUPPORTED_FILE_TYPE' ||
      outcome.code === 'FILE_TEXT_EXTRACTION_FAILED'
    ) {
      setResult({
        status: 'error',
        title: '파일 확인이 필요합니다',
        message: outcome.message,
        code: outcome.code,
      })
      return { ok: false as const, message: outcome.message, code: outcome.code }
    }

    if (
      outcome.code === 'GEMINI_API_KEY_MISSING' ||
      outcome.code === 'GEMINI_API_REQUEST_FAILED' ||
      outcome.code === 'GEMINI_API_RESPONSE_INVALID'
    ) {
      const guidance = getDiagnosisErrorGuidance(outcome.code, outcome.message)
      setResult({
        status: 'error',
        title: guidance.title,
        message: guidance.message,
        code: outcome.code,
      })
      return { ok: false as const, message: guidance.message, code: outcome.code }
    }

    setResult({
      status: 'error',
      title: '테스트 분석 결과를 찾지 못했습니다',
      message: outcome.message,
      code: outcome.code,
    })
    return { ok: false as const, message: outcome.message, code: outcome.code }
  }

  const handleRequest = async (request: Promise<Awaited<ReturnType<typeof diagnoseResume>>>) => {
    setInlineError('')
    setIsSubmitting(true)
    setResult(loadingState)

    try {
      const outcome = await request
      return handleOutcome(outcome)
    } catch (error) {
      const message =
        error instanceof NetworkError
          ? error.message
          : '요청을 처리하지 못했어요. 잠시 후 다시 시도해주세요.'

      setResult({
        status: 'error',
        title: '요청을 완료하지 못했습니다',
        message,
      })
      return { ok: false as const, message }
    } finally {
      setIsSubmitting(false)
    }
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
      return { ok: false as const, message: validationError }
    }

    return handleRequest(diagnoseResume({ resumeText }))
  }

  const submitFile = async (mode: ResumeInputMode, file: File | null) => {
    const validationError = validateResumeFile(mode, file)

    if (validationError) {
      setInlineError(validationError)
      setResult({
        status: 'error',
        title: '파일 확인이 필요합니다',
        message: validationError,
      })
      return { ok: false as const, message: validationError }
    }

    return handleRequest(diagnoseResumeFile(file as File))
  }

  return {
    clearInlineError,
    inlineError,
    isSubmitting,
    resetResult,
    result,
    submit,
    submitFile,
  }
}

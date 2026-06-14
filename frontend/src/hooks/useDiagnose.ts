import { useState } from 'react'
import { diagnoseResume, diagnoseResumeFile, NetworkError } from '../services/api'
import type { ResultState, ResumeInputMode } from '../types/diagnosis'

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
    '입력 길이와 요청 형식을 검증하고 있습니다. 모드에 따라 stub, fixture, ai-local 결과를 반환합니다.',
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
      return { ok: false as const }
    }

    if (outcome.kind === 'validation-error') {
      setInlineError(outcome.message)
      setResult({
        status: 'error',
        title: '입력 확인이 필요합니다',
        message: outcome.message,
        code: outcome.code,
      })
      return { ok: false as const }
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
      return { ok: false as const }
    }

    if (
      outcome.code === 'GEMINI_API_KEY_MISSING' ||
      outcome.code === 'GEMINI_API_REQUEST_FAILED' ||
      outcome.code === 'GEMINI_API_RESPONSE_INVALID'
    ) {
      setResult({
        status: 'error',
        title: '로컬 AI 분석을 완료하지 못했습니다',
        message: outcome.message,
        code: outcome.code,
      })
      return { ok: false as const }
    }

    setResult({
      status: 'error',
      title: '테스트 분석 결과를 찾지 못했습니다',
      message: outcome.message,
      code: outcome.code,
    })
    return { ok: false as const }
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
          : '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.'

      setResult({
        status: 'error',
        title: '요청을 완료하지 못했습니다',
        message,
      })
      return { ok: false as const }
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
      return { ok: false as const }
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
      return { ok: false as const }
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

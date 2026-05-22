import { useState } from 'react'
import { diagnoseResume, diagnoseResumeFile, NetworkError } from '../services/api'
import type { ResultState, ResumeInputMode } from '../types/diagnosis'

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
    '입력 길이와 요청 형식을 검증하고 있습니다. fixture 모드에서는 준비된 분석 결과를 바로 보여줍니다.',
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
      return
    }

    if (outcome.kind === 'not-enabled') {
      setResult({
        status: 'not-enabled',
        title: 'AI 분석 기능은 준비 중입니다',
        message: outcome.message,
        code: outcome.code,
      })
      return
    }

    if (outcome.kind === 'validation-error') {
      setInlineError(outcome.message)
      setResult({
        status: 'error',
        title: '입력 확인이 필요합니다',
        message: outcome.message,
        code: outcome.code,
      })
      return
    }

    setResult({
      status: 'error',
      title: '분석 결과를 찾지 못했습니다',
      message: outcome.message,
      code: outcome.code,
    })
  }

  const handleRequest = async (request: Promise<Awaited<ReturnType<typeof diagnoseResume>>>) => {
    setInlineError('')
    setIsSubmitting(true)
    setResult(loadingState)

    try {
      const outcome = await request
      handleOutcome(outcome)
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

    await handleRequest(diagnoseResume({ resumeText }))
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
      return
    }

    await handleRequest(diagnoseResumeFile(file as File))
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

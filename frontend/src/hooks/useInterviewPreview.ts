import { useState } from 'react'
import { NetworkError, previewInterview } from '../services/api'
import type { InterviewPreviewRequest, ResultState } from '../types/diagnosis'

const idleState: ResultState = {
  status: 'idle',
  title: '모의 면접 질문을 생성할 수 있습니다',
  message: '이력서와 선택한 JD 맥락을 기준으로 예상 질문과 답변 키포인트를 준비합니다.',
}

const loadingState: ResultState = {
  status: 'loading',
  title: '모의 면접 질문을 생성하고 있습니다',
  message: '이력서 경험과 직무 맥락을 기준으로 질문과 답변 전략을 정리하고 있습니다.',
}

export function useInterviewPreview() {
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [result, setResult] = useState<ResultState>(idleState)

  const resetResult = () => {
    setResult(idleState)
  }

  const submit = async (request: InterviewPreviewRequest) => {
    setIsSubmitting(true)
    setResult(loadingState)

    try {
      const outcome = await previewInterview(request)

      if (outcome.kind === 'success') {
        setResult({
          status: 'success',
          title: '모의 면접 질문을 생성했습니다',
          message: outcome.result.summary,
          interviewPreview: outcome.result,
        })
        return
      }

      setResult({
        status: 'error',
        title:
          outcome.kind === 'not-enabled'
            ? '모의 면접 질문 생성은 준비 중입니다'
            : '모의 면접 질문 생성을 완료하지 못했습니다',
        message: outcome.message,
        code: outcome.code,
      })
    } catch (error) {
      setResult({
        status: 'error',
        title: '모의 면접 질문 생성을 완료하지 못했습니다',
        message:
          error instanceof NetworkError
            ? error.message
            : '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
      })
    } finally {
      setIsSubmitting(false)
    }
  }

  return {
    isSubmitting,
    resetResult,
    result,
    submit,
  }
}

import { describe, expect, it } from 'vitest'
import { getDiagnosisErrorGuidance } from './useDiagnose'

describe('AI 분석 오류 안내', () => {
  it('AI 서비스의 일시적인 요청 실패를 재시도 안내로 바꾼다', () => {
    const guidance = getDiagnosisErrorGuidance(
      'GEMINI_API_REQUEST_FAILED',
      '서버의 원본 오류',
    )

    expect(guidance.title).toBe('AI 서비스가 잠시 바쁩니다')
    expect(guidance.message).toContain('입력한 이력서에는 문제가 없으니')
    expect(guidance.message).toContain('다시 시도해주세요')
  })

  it('AI 연결 설정 누락을 관리자 확인 안내로 구분한다', () => {
    const guidance = getDiagnosisErrorGuidance(
      'GEMINI_API_KEY_MISSING',
      '서버의 원본 오류',
    )

    expect(guidance.title).toBe('AI 분석 설정을 확인해주세요')
    expect(guidance.message).toContain('관리자에게 AI 설정을 확인해달라고')
  })

  it('읽을 수 없는 AI 응답은 결과 표시 실패로 안내한다', () => {
    const guidance = getDiagnosisErrorGuidance(
      'GEMINI_API_RESPONSE_INVALID',
      '서버의 원본 오류',
    )

    expect(guidance.title).toBe('AI 결과를 읽지 못했어요')
    expect(guidance.message).toContain('결과를 표시할 수 없어요')
  })
})

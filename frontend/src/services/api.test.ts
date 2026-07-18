import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import {
  diagnoseResume,
  diagnoseResumeFile,
  fetchJdFromUrl,
  previewInterview,
  previewMatch,
  previewSentence,
} from './api'

function successResponse() {
  return {
    ok: true,
    json: async () => ({
      success: true,
      data: {},
      error: null,
      timestamp: '',
    }),
  } as Response
}

describe('보호 API 서비스 계층', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(successResponse()))
  })

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('모든 보호 API 요청에 세션 쿠키 credentials를 포함한다', async () => {
    const requestCases = [
      {
        path: '/api/diagnose',
        invoke: () => diagnoseResume({ resumeText: '충분히 긴 이력서 본문입니다. 보호 API 요청을 검증합니다.' }),
      },
      {
        path: '/api/diagnose/file',
        invoke: () => diagnoseResumeFile(new File(['resume'], 'resume.pdf', { type: 'application/pdf' })),
      },
      {
        path: '/api/match/preview',
        invoke: () => previewMatch({ resumeSource: { type: 'TEXT', value: 'resume' }, jdText: 'jd' }),
      },
      {
        path: '/api/sentence/preview',
        invoke: () => previewSentence({ resumeSource: { type: 'TEXT', value: 'resume' }, jdText: 'jd' }),
      },
      {
        path: '/api/jd/fetch',
        invoke: () => fetchJdFromUrl('https://example.com/jobs/backend'),
      },
      {
        path: '/api/interview/preview',
        invoke: () => previewInterview({ resumeSource: { type: 'TEXT', value: 'resume' }, jdText: 'jd' }),
      },
    ]

    for (const request of requestCases) {
      await request.invoke()
      expect(globalThis.fetch).toHaveBeenLastCalledWith(
        request.path,
        expect.objectContaining({ credentials: 'include' }),
      )
    }
  })
})

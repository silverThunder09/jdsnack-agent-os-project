import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import {
  ApiContractError,
  createAnalysisHistoryFile,
  createAnalysisHistory,
  deleteAnalysisHistory,
  diagnoseResume,
  diagnoseResumeFile,
  fetchJdFromUrl,
  getAnalysisHistory,
  listAnalysisHistories,
  previewInterview,
  previewMatch,
  previewAts,
  previewSentence,
  retryAnalysisHistory,
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
        path: '/api/ats/preview',
        invoke: () => previewAts({ resumeSource: { type: 'TEXT', value: 'resume' }, jdText: 'jd' }),
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
      {
        path: '/api/analysis-histories',
        invoke: () => createAnalysisHistory({ resumeText: 'resume', jd: { inputType: 'TEXT', text: 'jd' } }),
      },
      {
        path: '/api/analysis-histories/file',
        invoke: () => createAnalysisHistoryFile(
          new File(['resume'], 'resume.pdf', { type: 'application/pdf' }),
          { jd: { inputType: 'TEXT', text: 'jd' } },
        ),
      },
      {
        path: '/api/analysis-histories',
        invoke: () => listAnalysisHistories(),
      },
      {
        path: '/api/analysis-histories/history-1',
        invoke: () => getAnalysisHistory('history-1'),
      },
      {
        path: '/api/analysis-histories/history-1/retry',
        invoke: () => retryAnalysisHistory('history-1'),
      },
    ]

    for (const request of requestCases) {
      await request.invoke()
      expect(globalThis.fetch).toHaveBeenLastCalledWith(
        request.path,
        expect.objectContaining({ credentials: 'include' }),
      )
    }

    await deleteAnalysisHistory('history-1')
    expect(globalThis.fetch).toHaveBeenLastCalledWith(
      '/api/analysis-histories/history-1',
      expect.objectContaining({ credentials: 'include', method: 'DELETE' }),
    )
  })

  it('분석 이력 요청에 idempotency key를 전달한다', async () => {
    await createAnalysisHistory(
      { resumeText: 'resume', jd: { inputType: 'TEXT', text: 'jd' } },
      ' key ',
    )

    expect(globalThis.fetch).toHaveBeenLastCalledWith(
      '/api/analysis-histories',
      expect.objectContaining({
        headers: expect.objectContaining({ 'Idempotency-Key': 'key' }),
      }),
    )

    await createAnalysisHistoryFile(
      new File(['resume'], 'resume.pdf', { type: 'application/pdf' }),
      { jd: { inputType: 'TEXT', text: 'jd' } },
      'file-key',
    )

    expect(globalThis.fetch).toHaveBeenLastCalledWith(
      '/api/analysis-histories/file',
      expect.objectContaining({
        headers: expect.objectContaining({ 'Idempotency-Key': 'file-key' }),
      }),
    )
  })

  it('429 quota errors preserve metadata for the UI', async () => {
    const error = {
      code: 'AI_QUOTA_EXCEEDED',
      message: '오늘 사용할 수 있는 AI 분석 횟수를 초과했습니다.',
      metadata: { limit: 20, remaining: 0, resetAt: '2026-09-18T00:00:00+09:00' },
    }
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: false,
      status: 429,
      json: async () => ({ success: false, data: null, error, timestamp: '' }),
    } as Response))

    const request = createAnalysisHistory({
      resumeText: 'resume',
      jd: { inputType: 'TEXT', text: 'jd' },
    })

    await expect(request).rejects.toBeInstanceOf(ApiContractError)
    await expect(request).rejects.toMatchObject({
      code: 'AI_QUOTA_EXCEEDED',
      metadata: error.metadata,
    })
  })
})

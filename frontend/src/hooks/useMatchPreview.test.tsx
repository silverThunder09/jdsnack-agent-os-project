import { act, renderHook } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { useMatchPreview } from './useMatchPreview'

function successResponse() {
  return {
    ok: true,
    json: async () => ({
      success: true,
      data: {
        jdText: 'Spring Boot 기반 백엔드 API 개발과 운영 경험이 필요합니다. 테스트 자동화와 장애 대응 경험을 우대합니다.',
        sourceUrl: 'https://www.jobkorea.co.kr/Recruit/GI_Read/777777',
        title: '백엔드 엔지니어 | 잡코리아',
        fetchMode: 'image-ocr',
        sourceSite: 'jobkorea',
      },
      error: null,
      timestamp: '',
    }),
  } as Response
}

describe('useMatchPreview JD fetch 안내', () => {
  beforeEach(() => vi.stubGlobal('fetch', vi.fn().mockResolvedValue(successResponse())))
  afterEach(() => vi.unstubAllGlobals())

  it('image-ocr 성공을 OCR 인식 안내로 표시하고 수집 결과를 전달한다', async () => {
    const onFetched = vi.fn()
    const { result } = renderHook(() => useMatchPreview())

    await act(async () => {
      await result.current.fetchJd('https://www.jobkorea.co.kr/Recruit/GI_Read/777777', { onFetched })
    })

    expect(onFetched).toHaveBeenCalledWith(expect.objectContaining({ fetchMode: 'image-ocr', sourceSite: 'jobkorea' }))
    expect(result.current.jdFetchState.status).toBe('fetched')
    expect(result.current.jdFetchState.message).toContain('OCR로 인식')
  })

  it('OCR을 포함한 수집 실패는 직접 붙여넣기 대안으로 안내한다', async () => {
    vi.mocked(globalThis.fetch).mockResolvedValueOnce({
      ok: false,
      json: async () => ({
        success: false,
        data: null,
        error: { code: 'JD_FETCH_FAILED', message: 'fetch failed' },
        timestamp: '',
      }),
    } as Response)
    const { result } = renderHook(() => useMatchPreview())

    await act(async () => {
      await result.current.fetchJd('https://www.jobkorea.co.kr/Recruit/GI_Read/777777', { onFetched: vi.fn() })
    })

    expect(result.current.jdFetchState.status).toBe('fetch-error')
    expect(result.current.jdFetchState.message).toContain('직접 붙여넣어')
  })
})

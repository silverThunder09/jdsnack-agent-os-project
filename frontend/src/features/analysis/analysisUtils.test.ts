import { describe, expect, it } from 'vitest'
import type { AnalysisHistoryDetail } from '../../types/diagnosis'
import { analysisHistoryExportFileName, buildAnalysisHistoryMarkdown, inferJdSourceMetadata } from './analysisUtils'

function history(overrides: Partial<NonNullable<AnalysisHistoryDetail['result']>> = {}): AnalysisHistoryDetail {
  return {
    id: 'history-42',
    status: 'SUCCEEDED',
    createdAt: '2026-07-19T12:00:00Z',
    input: { resumeText: 'resume', jdInputType: 'TEXT', jdText: 'jd', sourceUrl: null, sourceSite: null, fetchMode: null },
    result: { diagnosis: null, match: null, ...overrides },
    failure: null,
    feedback: null,
  }
}

describe('분석 이력 Markdown 내보내기', () => {
  it('저장된 diagnosis만 포함하고 없는 match 섹션은 생략한다', () => {
    const markdown = buildAnalysisHistoryMarkdown(history({
      diagnosis: { score: 84, summary: '진단 요약', strengths: ['강점'], improvements: ['개선점'], sourceText: '원문' },
    }))

    expect(markdown).toContain('## 이력서 진단 점수: 84점')
    expect(markdown).toContain('- 강점')
    expect(markdown).not.toContain('JD 적합도')
    expect(markdown).not.toContain('원문')
  })

  it('diagnosis와 match 결과를 포함하고 저장되지 않은 옵션은 포함하지 않는다', () => {
    const markdown = buildAnalysisHistoryMarkdown(history({
      diagnosis: { score: 84, summary: '진단 요약', strengths: [], improvements: [], sourceText: 'resume' },
      match: {
        matchingScore: 79,
        summary: '적합도 요약',
        strengths: [], gaps: [], suggestions: [],
        matchedKeywords: ['Spring Boot'], partialKeywords: [], missingKeywords: ['Kubernetes'],
      },
    }))

    expect(markdown).toContain('## JD 적합도 점수: 79점')
    expect(markdown).toContain('- Spring Boot')
    expect(markdown).not.toContain('ATS')
    expect(markdown).not.toContain('문장 첨삭')
  })

  it('파일명에 이력 ID와 생성일을 포함한다', () => {
    expect(analysisHistoryExportFileName(history())).toBe('jdsnack-분석결과-history-42-20260719.md')
  })

  it('진행 중·실패·결과 없음 이력은 빈 리포트를 만든다', () => {
    expect(buildAnalysisHistoryMarkdown({ ...history(), status: 'RUNNING' })).toBe('')
    expect(buildAnalysisHistoryMarkdown({ ...history(), status: 'FAILED' })).toBe('')
    expect(buildAnalysisHistoryMarkdown(history())).toBe('')
  })
})

describe('JD 출처 메타데이터', () => {
  it('잡코리아 URL을 JOBKOREA_URL과 jobkorea로 식별한다', () => {
    expect(inferJdSourceMetadata('https://www.jobkorea.co.kr/Recruit/GI_Read/777777')).toEqual({
      inputType: 'JOBKOREA_URL',
      sourceSite: 'jobkorea',
    })
  })

  it('사람인 URL을 기존 SARAMIN_URL 계약으로 유지한다', () => {
    expect(inferJdSourceMetadata('https://www.saramin.co.kr/zf_user/jobs/view?rec_idx=123')).toEqual({
      inputType: 'SARAMIN_URL',
      sourceSite: 'saramin',
    })
  })

  it('지원하지 않는 링크나 직접 입력은 URL 출처로 가장하지 않는다', () => {
    expect(inferJdSourceMetadata('https://example.com/jobs/backend')).toEqual({
      inputType: 'TEXT',
      sourceSite: null,
    })
    expect(inferJdSourceMetadata('')).toEqual({ inputType: 'TEXT', sourceSite: null })
  })
})

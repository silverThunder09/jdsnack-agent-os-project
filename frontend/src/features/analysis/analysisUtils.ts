import type { AtsPreviewResult, MatchPreviewResult, ResumeInputMode, SentencePreviewResult } from '../../types/diagnosis'
import { validateJdText } from '../../hooks/useMatchPreview'

export type JdTab = 'link' | 'paste'
export type ResumeInputTab = 'text' | 'file'
export type AnalysisPhase = 'input' | 'result'
export type AnalysisOptionKey = 'jdMatch' | 'ats' | 'sentence' | 'keyword'

export const JD_MAX_LENGTH = 10_000
export const RESUME_REQUIRED_MESSAGE = '이력서 파일을 업로드해 주세요.'
export const UNSUPPORTED_RESUME_FILE_MESSAGE = '지원하지 않는 파일 형식입니다. PDF 또는 DOCX 파일을 올려 주세요.'
export const ANALYSIS_OPTION_REQUIRED_MESSAGE = '분석 항목을 1개 이상 선택해 주세요.'

export const ANALYSIS_OPTIONS: {
  key: AnalysisOptionKey
  label: string
  description: string
  recommended: boolean
  enabled: boolean
}[] = [
  { key: 'jdMatch', label: 'JD 적합도', description: '이력서와 JD의 핵심 키워드 및 역량 적합도를 분석합니다.', recommended: true, enabled: true },
  { key: 'ats', label: 'ATS 분석', description: 'ATS 통과 가능성과 포맷, 키워드 최적화 여부를 분석합니다.', recommended: true, enabled: true },
  { key: 'sentence', label: '문장 첨삭', description: '문장 표현, 가독성, 문법 및 전문성 향상을 제안합니다.', recommended: false, enabled: true },
  { key: 'keyword', label: '키워드 분석', description: '주요 키워드 누락 여부와 활용도를 분석합니다.', recommended: false, enabled: true },
]

export const PROGRESS_STEPS = [
  { title: '채용 공고(JD) 수집', description: '링크 또는 내용을 통해 JD를 분석합니다.' },
  { title: '이력서 파싱', description: '이력서의 경력, 스킬, 경험을 추출합니다.' },
  { title: 'AI 종합 분석', description: '적합도, ATS, 첨삭 등 항목별 분석 수행' },
  { title: '결과 제공', description: '맞춤형 인사이트와 개선안을 제공합니다.' },
]

export const ACCURACY_TIPS = [
  '원본 JD 전체 내용을 제공해 주세요.',
  '최신 이력서를 업로드해 주세요.',
  '경력 및 성과는 구체적으로 작성된 이력서일수록 정확도가 높아집니다.',
]

export const DEFAULT_OPTIONS: Record<AnalysisOptionKey, boolean> = {
  jdMatch: true,
  ats: true,
  sentence: true,
  keyword: true,
}

export function loadSavedInput(): { jdText: string; options: Record<AnalysisOptionKey, boolean> } | null {
  if (typeof window === 'undefined') return null
  try {
    const raw = window.localStorage.getItem('jdsnack.analysis-input')
    if (!raw) return null
    const parsed = JSON.parse(raw) as { jdText?: unknown; options?: unknown }
    const savedOptions = (parsed.options ?? {}) as Partial<Record<AnalysisOptionKey, boolean>>
    return { jdText: typeof parsed.jdText === 'string' ? parsed.jdText : '', options: { ...DEFAULT_OPTIONS, ...savedOptions } }
  } catch {
    return null
  }
}

export function saveInput(jdText: string, options: Record<AnalysisOptionKey, boolean>) {
  window.localStorage.setItem('jdsnack.analysis-input', JSON.stringify({ jdText, options }))
}

export function clearSavedInput() {
  window.localStorage.removeItem('jdsnack.analysis-input')
}

export function buildResultMarkdown(
  match: MatchPreviewResult | undefined,
  sentence: SentencePreviewResult | undefined,
  ats: AtsPreviewResult | undefined,
  submittedOptions: Record<AnalysisOptionKey, boolean>,
): string {
  const list = (items: string[]) => (items.length ? items.map((item) => `- ${item}`).join('\n') : '- (없음)')
  const sections = ['# JDSnack 분석 결과', '']
  if (submittedOptions.jdMatch && match) sections.push(`## JD 적합도 점수: ${match.matchingScore}점`, '', '### 요약', match.summary, '', '### 강점', list(match.strengths), '', '### Gap', list(match.gaps), '', '### 제안', list(match.suggestions), '')
  if (submittedOptions.keyword && match) sections.push('## 키워드 분석', '', '### 매칭 키워드', list(match.matchedKeywords), '', '### 부분 매칭', list(match.partialKeywords), '', '### 누락 키워드', list(match.missingKeywords), '')
  if (submittedOptions.sentence) {
    sections.push('## 문장 첨삭', '')
    if (!sentence?.edits.length) sections.push('- (없음)', '')
    else sentence.edits.forEach((edit, index) => sections.push(`### 첨삭 ${index + 1}`, `- 원문: ${edit.original}`, `- 개선문: ${edit.improved}`, `- 개선 사유: ${edit.reason}`, ''))
  }
  if (submittedOptions.ats && ats) {
    sections.push(
      `## ATS 점수·포맷 진단: ${ats.atsScore}점`,
      '',
      '### 요약',
      ats.summary,
      '',
      '### 포맷 점검',
      ...ats.formatChecks.map((check) => `- ${check.passed ? '통과' : '보완'}: ${check.label} — ${check.message}`),
      '',
      '### 누락 키워드',
      list(ats.missingKeywords),
      '',
      '### 제안',
      list(ats.suggestions),
      '',
    )
  }
  return sections.join('\n')
}

export function todayStamp(): string {
  const date = new Date()
  return `${date.getFullYear()}${String(date.getMonth() + 1).padStart(2, '0')}${String(date.getDate()).padStart(2, '0')}`
}

export function inferResumeMode(file: File): ResumeInputMode | null {
  const name = file.name.toLowerCase()
  if (name.endsWith('.pdf')) return 'pdf'
  if (name.endsWith('.docx')) return 'docx'
  return null
}

export function formatFileSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
}

export function getPrevalidationReasons({ resumeFile, resumeText = '', jdText, selectedOptionCount }: { resumeFile: File | null; resumeText?: string; jdText: string; selectedOptionCount: number }): string[] {
  const reasons: string[] = []
  if (!resumeFile && !resumeText.trim()) reasons.push(RESUME_REQUIRED_MESSAGE)
  else if (resumeFile && !inferResumeMode(resumeFile)) reasons.push(UNSUPPORTED_RESUME_FILE_MESSAGE)
  else if (!resumeFile && resumeText.trim().length < 50) reasons.push('이력서 내용이 너무 짧습니다. 최소 50자 이상 입력해주세요.')
  else if (!resumeFile && resumeText.trim().length > 10_000) reasons.push('이력서 내용이 너무 깁니다. 10,000자 이내로 입력해주세요.')
  const jdError = validateJdText(jdText)
  if (jdError) reasons.push(jdError)
  if (selectedOptionCount === 0) reasons.push(ANALYSIS_OPTION_REQUIRED_MESSAGE)
  return reasons
}

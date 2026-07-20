export type AnalysisStatus = 'idle' | 'loading' | 'success' | 'not-enabled' | 'error'
export type ResumeInputMode = 'text' | 'pdf' | 'docx'

export type ApiErrorCode =
  | 'AUTHENTICATION_REQUIRED'
  | 'EMPTY_RESUME'
  | 'TEXT_TOO_SHORT'
  | 'TEXT_TOO_LONG'
  | 'EMPTY_JD'
  | 'JD_TEXT_TOO_SHORT'
  | 'JD_TEXT_TOO_LONG'
  | 'INVALID_JD_URL'
  | 'JD_FETCH_EMPTY_CONTENT'
  | 'JD_FETCH_UNSUPPORTED_SOURCE'
  | 'JD_FETCH_FAILED'
  | 'UNSUPPORTED_FILE_TYPE'
  | 'FILE_TEXT_EXTRACTION_FAILED'
  | 'GEMINI_API_KEY_MISSING'
  | 'GEMINI_API_REQUEST_FAILED'
  | 'GEMINI_API_RESPONSE_INVALID'
  | 'FIXTURE_NOT_FOUND'
  | 'AI_ANALYSIS_NOT_ENABLED'
  | 'JD_MATCH_PREVIEW_NOT_ENABLED'
  | 'MOCK_INTERVIEW_NOT_ENABLED'
  | 'INTERVIEW_QUESTION_GENERATION_FAILED'
  | 'INVALID_ANALYSIS_INPUT'
  | 'ANALYSIS_HISTORY_NOT_FOUND'
  | 'INTERNAL_ERROR'

export interface DiagnoseRequest {
  resumeText: string
}

export interface DiagnosisResult {
  score: number
  summary: string
  strengths: string[]
  improvements: string[]
  sourceText: string
}

export interface MatchPreviewRequest {
  resumeSource: {
    type: 'TEXT' | 'FILE'
    value: string
  }
  jdText: string
  jdUrl?: string
}

export interface JdSections {
  responsibilities: string
  qualifications: string
  preferredQualifications: string
  experience: string
}

export interface MatchPreviewResult {
  matchingScore: number
  summary: string
  strengths: string[]
  gaps: string[]
  suggestions: string[]
  matchedKeywords: string[]
  partialKeywords: string[]
  missingKeywords: string[]
}

export interface AtsFormatCheck {
  label: string
  passed: boolean
  message: string
}

export interface AtsPreviewResult {
  atsScore: number
  summary: string
  strengths: string[]
  risks: string[]
  suggestions: string[]
  matchedKeywords: string[]
  missingKeywords: string[]
  formatChecks: AtsFormatCheck[]
}

export interface SentenceEdit {
  original: string
  improved: string
  reason: string
}

export interface SentencePreviewResult {
  edits: SentenceEdit[]
}

export interface InterviewPreviewRequest {
  resumeSource: {
    type: 'TEXT' | 'FILE'
    value: string
  }
  jobTitle?: string
  jdText?: string
}

export interface InterviewQuestion {
  question: string
  category: 'experience' | 'technical' | 'behavioral'
  keypoints: string
}

export interface InterviewPreviewResult {
  questions: InterviewQuestion[]
  strategy: string
  summary: string
}

export interface JdFetchResult {
  jdText: string
  sourceUrl: string
  title: string
  fetchMode: string
  sourceSite: string
  sections?: Partial<JdSections>
}

export interface AnalysisHistoryCreateRequest {
  resumeText: string
  jd: {
    inputType: 'TEXT' | 'SARAMIN_URL'
    text?: string
    sourceUrl?: string | null
    sourceSite?: string | null
  }
}

export interface AnalysisHistorySummary {
  id: string
  status: 'RUNNING' | 'SUCCEEDED' | 'FAILED'
  createdAt: string
  jdLabel: string
  jdSourceUrl: string | null
  summary: string | null
}

export interface AnalysisHistoryDetail {
  id: string
  status: 'RUNNING' | 'SUCCEEDED' | 'FAILED'
  createdAt: string
  input: {
    resumeText: string
    jdInputType: 'TEXT' | 'SARAMIN_URL'
    jdText: string
    sourceUrl: string | null
    sourceSite: string | null
  }
  result: {
    diagnosis: DiagnosisResult | null
    match: MatchPreviewResult | null
  } | null
  failure: ApiError | null
}

export interface ApiError {
  code: ApiErrorCode
  message: string
}

export interface ApiResponse<T> {
  success: boolean
  data: T | null
  error?: ApiError | null
  timestamp: string
}

export type DiagnoseOutcome =
  | {
      kind: 'success'
      result: DiagnosisResult
    }
  | {
      kind: 'not-enabled' | 'validation-error' | 'error'
      code: ApiErrorCode
      message: string
    }

export type MatchPreviewOutcome =
  | {
      kind: 'success'
      result: MatchPreviewResult
    }
  | {
      kind: 'validation-error' | 'error'
      code: ApiErrorCode
      message: string
    }

export type AtsPreviewOutcome =
  | {
      kind: 'success'
      result: AtsPreviewResult
    }
  | {
      kind: 'validation-error' | 'error'
      code: ApiErrorCode
      message: string
    }

export type SentencePreviewOutcome =
  | {
      kind: 'success'
      result: SentencePreviewResult
    }
  | {
      kind: 'validation-error' | 'error'
      code: ApiErrorCode
      message: string
    }

export type InterviewPreviewOutcome =
  | {
      kind: 'success'
      result: InterviewPreviewResult
    }
  | {
      kind: 'validation-error' | 'not-enabled' | 'error'
      code: ApiErrorCode
      message: string
    }

export type JdFetchOutcome =
  | {
      kind: 'success'
      result: JdFetchResult
    }
  | {
      kind: 'validation-error' | 'error'
      code: ApiErrorCode
      message: string
    }

export interface ResultState {
  status: AnalysisStatus
  title: string
  message: string
  code?: ApiErrorCode
  diagnosis?: DiagnosisResult
  matchPreview?: MatchPreviewResult
  atsPreview?: AtsPreviewResult
  sentencePreview?: SentencePreviewResult
  interviewPreview?: InterviewPreviewResult
}

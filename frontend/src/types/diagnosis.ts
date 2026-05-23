export type AnalysisStatus = 'idle' | 'loading' | 'success' | 'not-enabled' | 'error'
export type ResumeInputMode = 'text' | 'pdf' | 'docx'

export type ApiErrorCode =
  | 'EMPTY_RESUME'
  | 'TEXT_TOO_SHORT'
  | 'TEXT_TOO_LONG'
  | 'EMPTY_JD'
  | 'JD_TEXT_TOO_SHORT'
  | 'JD_TEXT_TOO_LONG'
  | 'INVALID_JD_URL'
  | 'UNSUPPORTED_FILE_TYPE'
  | 'FILE_TEXT_EXTRACTION_FAILED'
  | 'GEMINI_API_KEY_MISSING'
  | 'GEMINI_API_REQUEST_FAILED'
  | 'GEMINI_API_RESPONSE_INVALID'
  | 'FIXTURE_NOT_FOUND'
  | 'AI_ANALYSIS_NOT_ENABLED'
  | 'JD_MATCH_PREVIEW_NOT_ENABLED'
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

export interface MatchPreviewResult {
  matchingScore: number
  summary: string
  strengths: string[]
  gaps: string[]
  suggestions: string[]
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

export interface ResultState {
  status: AnalysisStatus
  title: string
  message: string
  code?: ApiErrorCode
  diagnosis?: DiagnosisResult
  matchPreview?: MatchPreviewResult
}

export type AnalysisStatus = 'idle' | 'loading' | 'success' | 'not-enabled' | 'error'
export type ResumeInputMode = 'text' | 'pdf' | 'docx'

export type ApiErrorCode =
  | 'EMPTY_RESUME'
  | 'TEXT_TOO_SHORT'
  | 'TEXT_TOO_LONG'
  | 'UNSUPPORTED_FILE_TYPE'
  | 'FILE_TEXT_EXTRACTION_FAILED'
  | 'FIXTURE_NOT_FOUND'
  | 'AI_ANALYSIS_NOT_ENABLED'
  | 'INTERNAL_ERROR'

export interface DiagnoseRequest {
  resumeText: string
}

export interface DiagnosisResult {
  score: number
  summary: string
  strengths: string[]
  improvements: string[]
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

export interface ResultState {
  status: AnalysisStatus
  title: string
  message: string
  code?: ApiErrorCode
  diagnosis?: DiagnosisResult
}

export type AnalysisStatus = 'idle' | 'loading' | 'not-enabled' | 'error'

export type ApiErrorCode =
  | 'EMPTY_RESUME'
  | 'TEXT_TOO_SHORT'
  | 'TEXT_TOO_LONG'
  | 'AI_ANALYSIS_NOT_ENABLED'
  | 'INTERNAL_ERROR'

export interface DiagnoseRequest {
  resumeText: string
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

export interface DiagnoseOutcome {
  kind: 'not-enabled' | 'validation-error'
  code: ApiErrorCode
  message: string
}

export interface ResultState {
  status: AnalysisStatus
  title: string
  message: string
  code?: ApiErrorCode
}

import type {
  ApiErrorCode,
  AnalysisHistoryCreateRequest,
  AnalysisHistoryDetail,
  AnalysisHistorySummary,
  ApiResponse,
  AtsPreviewOutcome,
  AtsPreviewResult,
  DiagnoseOutcome,
  DiagnoseRequest,
  DiagnosisResult,
  InterviewPreviewOutcome,
  InterviewPreviewRequest,
  InterviewPreviewResult,
  JdFetchOutcome,
  JdFetchResult,
  MatchPreviewOutcome,
  MatchPreviewRequest,
  MatchPreviewResult,
  SentencePreviewOutcome,
  SentencePreviewResult,
} from '../types/diagnosis'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? ''
const NETWORK_ERROR_MESSAGE = '네트워크 연결을 확인해주세요.'
const DEFAULT_SERVER_ERROR_MESSAGE = '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.'

export class NetworkError extends Error {
  constructor(message = NETWORK_ERROR_MESSAGE) {
    super(message)
    this.name = 'NetworkError'
  }
}

const KNOWN_ERROR_CODES: ApiErrorCode[] = [
  'AUTHENTICATION_REQUIRED',
  'EMPTY_RESUME',
  'TEXT_TOO_SHORT',
  'TEXT_TOO_LONG',
  'EMPTY_JD',
  'JD_TEXT_TOO_SHORT',
  'JD_TEXT_TOO_LONG',
  'INVALID_JD_URL',
  'JD_FETCH_EMPTY_CONTENT',
  'JD_FETCH_UNSUPPORTED_SOURCE',
  'JD_FETCH_FAILED',
  'UNSUPPORTED_FILE_TYPE',
  'FILE_TEXT_EXTRACTION_FAILED',
  'GEMINI_API_KEY_MISSING',
  'GEMINI_API_REQUEST_FAILED',
  'GEMINI_API_RESPONSE_INVALID',
  'FIXTURE_NOT_FOUND',
  'AI_ANALYSIS_NOT_ENABLED',
  'JD_MATCH_PREVIEW_NOT_ENABLED',
  'MOCK_INTERVIEW_NOT_ENABLED',
  'INTERVIEW_QUESTION_GENERATION_FAILED',
  'INVALID_ANALYSIS_INPUT',
  'ANALYSIS_HISTORY_NOT_FOUND',
  'INTERNAL_ERROR',
]

async function parseJson<T>(response: Response): Promise<ApiResponse<T> | null> {
  try {
    return (await response.json()) as ApiResponse<T>
  } catch {
    return null
  }
}

function normalizeOutcome(
  payload: ApiResponse<DiagnosisResult> | null,
): DiagnoseOutcome | null {
  if (payload?.success && payload.data) {
    return {
      kind: 'success',
      result: payload.data,
    }
  }

  if (!payload?.error || !KNOWN_ERROR_CODES.includes(payload.error.code)) {
    return null
  }

  if (payload.error.code === 'AI_ANALYSIS_NOT_ENABLED') {
    return {
      kind: 'not-enabled',
      code: payload.error.code,
      message: payload.error.message,
    }
  }

  if (
    payload.error.code === 'EMPTY_RESUME' ||
    payload.error.code === 'TEXT_TOO_SHORT' ||
    payload.error.code === 'TEXT_TOO_LONG'
  ) {
    return {
      kind: 'validation-error',
      code: payload.error.code,
      message: payload.error.message,
    }
  }

  return {
    kind: 'error',
    code: payload.error.code,
    message: payload.error.message,
  }
}

export async function diagnoseResume(
  request: DiagnoseRequest,
): Promise<DiagnoseOutcome> {
  let response: Response

  try {
    response = await fetch(`${API_BASE_URL}/api/diagnose`, {
      method: 'POST',
      credentials: 'include',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify(request),
    })
  } catch {
    throw new NetworkError()
  }

  const payload = await parseJson<DiagnosisResult>(response)
  const outcome = normalizeOutcome(payload)

  if (outcome) {
    return outcome
  }

  throw new Error(payload?.error?.message ?? DEFAULT_SERVER_ERROR_MESSAGE)
}

export async function diagnoseResumeFile(file: File): Promise<DiagnoseOutcome> {
  const formData = new FormData()
  formData.append('resumeFile', file)

  let response: Response

  try {
    response = await fetch(`${API_BASE_URL}/api/diagnose/file`, {
      method: 'POST',
      credentials: 'include',
      body: formData,
    })
  } catch {
    throw new NetworkError()
  }

  const payload = await parseJson<DiagnosisResult>(response)
  const outcome = normalizeOutcome(payload)

  if (outcome) {
    return outcome
  }

  throw new Error(payload?.error?.message ?? DEFAULT_SERVER_ERROR_MESSAGE)
}

export async function previewMatch(
  request: MatchPreviewRequest,
): Promise<MatchPreviewOutcome> {
  let response: Response

  try {
    response = await fetch(`${API_BASE_URL}/api/match/preview`, {
      method: 'POST',
      credentials: 'include',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify(request),
    })
  } catch {
    throw new NetworkError()
  }

  const payload = await parseJson<MatchPreviewResult>(response)

  if (payload?.success && payload.data) {
    return {
      kind: 'success',
      result: {
        ...payload.data,
        matchedKeywords: Array.isArray(payload.data.matchedKeywords)
          ? payload.data.matchedKeywords
          : [],
        partialKeywords: Array.isArray(payload.data.partialKeywords)
          ? payload.data.partialKeywords
          : [],
        missingKeywords: Array.isArray(payload.data.missingKeywords)
          ? payload.data.missingKeywords
          : [],
      },
    }
  }

  if (!payload?.error || !KNOWN_ERROR_CODES.includes(payload.error.code)) {
    throw new Error(payload?.error?.message ?? DEFAULT_SERVER_ERROR_MESSAGE)
  }

  if (
    payload.error.code === 'EMPTY_JD' ||
    payload.error.code === 'JD_TEXT_TOO_SHORT' ||
    payload.error.code === 'JD_TEXT_TOO_LONG' ||
    payload.error.code === 'INVALID_JD_URL'
  ) {
    return {
      kind: 'validation-error',
      code: payload.error.code,
      message: payload.error.message,
    }
  }

  return {
    kind: 'error',
    code: payload.error.code,
    message: payload.error.message,
  }
}

export async function previewAts(
  request: MatchPreviewRequest,
): Promise<AtsPreviewOutcome> {
  let response: Response

  try {
    response = await fetch(`${API_BASE_URL}/api/ats/preview`, {
      method: 'POST',
      credentials: 'include',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify(request),
    })
  } catch {
    throw new NetworkError()
  }

  const payload = await parseJson<AtsPreviewResult>(response)
  if (payload?.success && payload.data) {
    return {
      kind: 'success',
      result: {
        ...payload.data,
        strengths: Array.isArray(payload.data.strengths) ? payload.data.strengths : [],
        risks: Array.isArray(payload.data.risks) ? payload.data.risks : [],
        suggestions: Array.isArray(payload.data.suggestions) ? payload.data.suggestions : [],
        matchedKeywords: Array.isArray(payload.data.matchedKeywords) ? payload.data.matchedKeywords : [],
        missingKeywords: Array.isArray(payload.data.missingKeywords) ? payload.data.missingKeywords : [],
        formatChecks: Array.isArray(payload.data.formatChecks) ? payload.data.formatChecks : [],
      },
    }
  }

  if (!payload?.error || !KNOWN_ERROR_CODES.includes(payload.error.code)) {
    throw new Error(payload?.error?.message ?? DEFAULT_SERVER_ERROR_MESSAGE)
  }

  if (
    payload.error.code === 'EMPTY_RESUME' ||
    payload.error.code === 'TEXT_TOO_SHORT' ||
    payload.error.code === 'TEXT_TOO_LONG' ||
    payload.error.code === 'EMPTY_JD' ||
    payload.error.code === 'JD_TEXT_TOO_SHORT' ||
    payload.error.code === 'JD_TEXT_TOO_LONG' ||
    payload.error.code === 'INVALID_JD_URL'
  ) {
    return {
      kind: 'validation-error',
      code: payload.error.code,
      message: payload.error.message,
    }
  }

  return {
    kind: 'error',
    code: payload.error.code,
    message: payload.error.message,
  }
}

export async function previewSentence(
  request: MatchPreviewRequest,
): Promise<SentencePreviewOutcome> {
  let response: Response

  try {
    response = await fetch(`${API_BASE_URL}/api/sentence/preview`, {
      method: 'POST',
      credentials: 'include',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify(request),
    })
  } catch {
    throw new NetworkError()
  }

  const payload = await parseJson<SentencePreviewResult>(response)
  if (payload?.success && payload.data) {
    return {
      kind: 'success',
      result: {
        ...payload.data,
        edits: Array.isArray(payload.data.edits) ? payload.data.edits : [],
      },
    }
  }

  if (!payload?.error || !KNOWN_ERROR_CODES.includes(payload.error.code)) {
    throw new Error(payload?.error?.message ?? DEFAULT_SERVER_ERROR_MESSAGE)
  }

  if (
    payload.error.code === 'EMPTY_RESUME' ||
    payload.error.code === 'TEXT_TOO_SHORT' ||
    payload.error.code === 'TEXT_TOO_LONG' ||
    payload.error.code === 'EMPTY_JD' ||
    payload.error.code === 'JD_TEXT_TOO_SHORT' ||
    payload.error.code === 'JD_TEXT_TOO_LONG' ||
    payload.error.code === 'INVALID_JD_URL'
  ) {
    return {
      kind: 'validation-error',
      code: payload.error.code,
      message: payload.error.message,
    }
  }

  return {
    kind: 'error',
    code: payload.error.code,
    message: payload.error.message,
  }
}

export async function fetchJdFromUrl(jdUrl: string): Promise<JdFetchOutcome> {
  let response: Response

  try {
    response = await fetch(`${API_BASE_URL}/api/jd/fetch`, {
      method: 'POST',
      credentials: 'include',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({ jdUrl }),
    })
  } catch {
    throw new NetworkError()
  }

  const payload = await parseJson<JdFetchResult>(response)

  if (payload?.success && payload.data) {
    return {
      kind: 'success',
      result: payload.data,
    }
  }

  if (!payload?.error || !KNOWN_ERROR_CODES.includes(payload.error.code)) {
    throw new Error(payload?.error?.message ?? DEFAULT_SERVER_ERROR_MESSAGE)
  }

  if (payload.error.code === 'INVALID_JD_URL') {
    return {
      kind: 'validation-error',
      code: payload.error.code,
      message: payload.error.message,
    }
  }

  return {
    kind: 'error',
    code: payload.error.code,
    message: payload.error.message,
  }
}

export async function previewInterview(
  request: InterviewPreviewRequest,
): Promise<InterviewPreviewOutcome> {
  let response: Response

  try {
    response = await fetch(`${API_BASE_URL}/api/interview/preview`, {
      method: 'POST',
      credentials: 'include',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify(request),
    })
  } catch {
    throw new NetworkError()
  }

  const payload = await parseJson<InterviewPreviewResult>(response)

  if (payload?.success && payload.data) {
    return {
      kind: 'success',
      result: payload.data,
    }
  }

  if (!payload?.error || !KNOWN_ERROR_CODES.includes(payload.error.code)) {
    throw new Error(payload?.error?.message ?? DEFAULT_SERVER_ERROR_MESSAGE)
  }

  if (
    payload.error.code === 'EMPTY_RESUME' ||
    payload.error.code === 'TEXT_TOO_SHORT' ||
    payload.error.code === 'TEXT_TOO_LONG'
  ) {
    return {
      kind: 'validation-error',
      code: payload.error.code,
      message: payload.error.message,
    }
  }

  if (payload.error.code === 'MOCK_INTERVIEW_NOT_ENABLED') {
    return {
      kind: 'not-enabled',
      code: payload.error.code,
      message: payload.error.message,
    }
  }

  return {
    kind: 'error',
    code: payload.error.code,
    message: payload.error.message,
  }
}

export async function createAnalysisHistory(
  request: AnalysisHistoryCreateRequest,
): Promise<AnalysisHistoryDetail> {
  let response: Response

  try {
    response = await fetch(`${API_BASE_URL}/api/analysis-histories`, {
      method: 'POST',
      credentials: 'include',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify(request),
    })
  } catch {
    throw new NetworkError()
  }

  const payload = await parseJson<AnalysisHistoryDetail>(response)
  if (payload?.success && payload.data) {
    return payload.data
  }

  throw new Error(payload?.error?.message ?? DEFAULT_SERVER_ERROR_MESSAGE)
}

export async function createAnalysisHistoryFile(
  resumeFile: File,
  request: Omit<AnalysisHistoryCreateRequest, 'resumeText'>,
): Promise<AnalysisHistoryDetail> {
  const formData = new FormData()
  formData.append('resumeFile', resumeFile)
  formData.append('inputType', request.jd.inputType)
  if (request.jd.text) formData.append('text', request.jd.text)
  if (request.jd.sourceUrl) formData.append('sourceUrl', request.jd.sourceUrl)
  if (request.jd.sourceSite) formData.append('sourceSite', request.jd.sourceSite)

  let response: Response
  try {
    response = await fetch(`${API_BASE_URL}/api/analysis-histories/file`, {
      method: 'POST',
      credentials: 'include',
      headers: { Accept: 'application/json' },
      body: formData,
    })
  } catch {
    throw new NetworkError()
  }

  const payload = await parseJson<AnalysisHistoryDetail>(response)
  if (payload?.success && payload.data) {
    return payload.data
  }

  throw new Error(payload?.error?.message ?? DEFAULT_SERVER_ERROR_MESSAGE)
}

export async function listAnalysisHistories(): Promise<AnalysisHistorySummary[]> {
  let response: Response

  try {
    response = await fetch(`${API_BASE_URL}/api/analysis-histories`, {
      credentials: 'include',
      headers: { Accept: 'application/json' },
    })
  } catch {
    throw new NetworkError()
  }

  const payload = await parseJson<AnalysisHistorySummary[]>(response)
  if (payload?.success && payload.data) {
    return payload.data
  }

  throw new Error(payload?.error?.message ?? DEFAULT_SERVER_ERROR_MESSAGE)
}

export async function getAnalysisHistory(historyId: string): Promise<AnalysisHistoryDetail> {
  let response: Response

  try {
    response = await fetch(`${API_BASE_URL}/api/analysis-histories/${historyId}`, {
      credentials: 'include',
      headers: { Accept: 'application/json' },
    })
  } catch {
    throw new NetworkError()
  }

  const payload = await parseJson<AnalysisHistoryDetail>(response)
  if (payload?.success && payload.data) {
    return payload.data
  }

  throw new Error(payload?.error?.message ?? DEFAULT_SERVER_ERROR_MESSAGE)
}

export async function retryAnalysisHistory(historyId: string): Promise<AnalysisHistoryDetail> {
  let response: Response

  try {
    response = await fetch(`${API_BASE_URL}/api/analysis-histories/${historyId}/retry`, {
      method: 'POST',
      credentials: 'include',
      headers: { Accept: 'application/json' },
    })
  } catch {
    throw new NetworkError()
  }

  const payload = await parseJson<AnalysisHistoryDetail>(response)
  if (payload?.success && payload.data) {
    return payload.data
  }

  throw new Error(payload?.error?.message ?? DEFAULT_SERVER_ERROR_MESSAGE)
}

export async function deleteAnalysisHistory(historyId: string): Promise<void> {
  let response: Response

  try {
    response = await fetch(`${API_BASE_URL}/api/analysis-histories/${historyId}`, {
      method: 'DELETE',
      credentials: 'include',
      headers: { Accept: 'application/json' },
    })
  } catch {
    throw new NetworkError()
  }

  if (response.ok) {
    return
  }

  const payload = await parseJson<unknown>(response)
  throw new Error(payload?.error?.message ?? DEFAULT_SERVER_ERROR_MESSAGE)
}

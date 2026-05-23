import type {
  ApiErrorCode,
  ApiResponse,
  DiagnoseOutcome,
  DiagnoseRequest,
  DiagnosisResult,
  MatchPreviewOutcome,
  MatchPreviewRequest,
  MatchPreviewResult,
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
  'EMPTY_RESUME',
  'TEXT_TOO_SHORT',
  'TEXT_TOO_LONG',
  'EMPTY_JD',
  'JD_TEXT_TOO_SHORT',
  'JD_TEXT_TOO_LONG',
  'INVALID_JD_URL',
  'UNSUPPORTED_FILE_TYPE',
  'FILE_TEXT_EXTRACTION_FAILED',
  'FIXTURE_NOT_FOUND',
  'AI_ANALYSIS_NOT_ENABLED',
  'JD_MATCH_PREVIEW_NOT_ENABLED',
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
      result: payload.data,
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

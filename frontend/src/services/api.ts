import type {
  ApiErrorCode,
  ApiResponse,
  DiagnoseOutcome,
  DiagnoseRequest,
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
  'AI_ANALYSIS_NOT_ENABLED',
  'INTERNAL_ERROR',
]

async function parseJson<T>(response: Response): Promise<ApiResponse<T> | null> {
  try {
    return (await response.json()) as ApiResponse<T>
  } catch {
    return null
  }
}

function normalizeOutcome<T>(
  payload: ApiResponse<T> | null,
): DiagnoseOutcome | null {
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

  return null
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

  const payload = await parseJson<null>(response)
  const outcome = normalizeOutcome(payload)

  if (outcome) {
    return outcome
  }

  throw new Error(payload?.error?.message ?? DEFAULT_SERVER_ERROR_MESSAGE)
}

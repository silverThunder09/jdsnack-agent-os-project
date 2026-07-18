import type { ReactNode } from 'react'
import { useAuth } from '../hooks/useAuth'

export function AuthGate({ children }: { children: ReactNode }) {
  const { status, message, startGoogleLogin } = useAuth()

  if (status === 'loading') {
    return (
      <main className="auth-gate" aria-live="polite">
        <p>로그인 상태를 확인하고 있습니다...</p>
      </main>
    )
  }

  if (status !== 'authenticated') {
    return (
      <main className="auth-gate" aria-label="Google 로그인">
        <section className="auth-card">
          <span className="auth-card__eyebrow">JDSnack</span>
          <h1>분석을 시작하려면 로그인해 주세요.</h1>
          <p>{message || '기존 이력서와 JD를 안전하게 분석 이력으로 관리합니다.'}</p>
          <button type="button" className="cta-button" onClick={startGoogleLogin}>
            Google로 로그인
          </button>
          <small>Google 인증 정보와 provider token은 브라우저에 저장하지 않습니다.</small>
        </section>
      </main>
    )
  }

  return <>{children}</>
}

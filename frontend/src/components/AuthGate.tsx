import type { ReactNode } from 'react'
import { useState } from 'react'
import { useAuth } from '../hooks/useAuth'

export function AuthGate({ children }: { children: ReactNode }) {
  const { status, message, startGoogleLogin } = useAuth()
  const [isLoginOpen, setIsLoginOpen] = useState(false)

  if (status === 'authenticated') {
    return <>{children}</>
  }

  const isLoading = status === 'loading'

  return (
    <div className="auth-shell">
      {children}
      {isLoginOpen ? (
        <div className="auth-modal-layer">
          <div className="auth-modal-backdrop" aria-hidden="true" />
          <section className="auth-card" role="dialog" aria-modal="true" aria-label="Google 로그인">
            <button
              type="button"
              className="auth-card__close"
              aria-label="로그인 창 닫기"
              onClick={() => setIsLoginOpen(false)}
            >
              ×
            </button>
            <div className="auth-card__logo" aria-hidden="true">
              JDSnack
            </div>
            <span className="auth-card__eyebrow">JDSnack</span>
            <h1 aria-label="합격을 위한 분석을 시작해보세요">
              <span>합격을 위한</span>
              <span>분석을 시작해보세요</span>
            </h1>
            <p>
              이력서와 채용 공고를 함께 살펴보고,
              <br />
              지원 전에 보완할 점을 찾아드릴게요.
            </p>
            {isLoading ? (
              <p className="auth-card__status" aria-live="polite">
                로그인 상태를 확인하고 있습니다...
              </p>
            ) : (
              <button type="button" className="auth-card__google-button" onClick={startGoogleLogin}>
                <span className="auth-card__google-mark" aria-hidden="true">
                  G
                </span>
                Google로 시작하기
              </button>
            )}
            {message ? <p className="auth-card__error" role="alert">{message}</p> : null}
            <small>Google 인증 정보와 provider token은 브라우저에 저장하지 않습니다.</small>
            <div className="auth-card__divider" aria-hidden="true">
              <span />
              <em>또는</em>
              <span />
            </div>
            <p className="auth-card__legal">계속하면 JDSnack의 서비스 이용약관 및 개인정보 처리방침에 동의하게 됩니다.</p>
          </section>
        </div>
      ) : (
        <button type="button" className="auth-login-button" onClick={() => setIsLoginOpen(true)}>
          로그인
        </button>
      )}
    </div>
  )
}

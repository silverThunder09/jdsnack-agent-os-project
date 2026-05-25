import type { ReactNode } from 'react'

interface AppShellProps {
  children: ReactNode
}

export function AppShell({ children }: AppShellProps) {
  return (
    <div className="app-shell">
      <header className="top-nav">
        <a className="brand-mark" href="/" aria-label="JDSnack AI 홈">
          <span className="brand-icon">J</span>
          <strong>JDSnack <span>AI</span></strong>
        </a>
        <nav className="top-nav__links" aria-label="주요 단계">
          <a href="#resume-step">이력서 입력</a>
          <a href="#jd-step">JD 분석</a>
          <a href="#report-step">리포트</a>
        </nav>
        <button className="profile-button" type="button" aria-label="사용자 메뉴">
          <span>김</span>
        </button>
      </header>
      <main className="page">{children}</main>
    </div>
  )
}

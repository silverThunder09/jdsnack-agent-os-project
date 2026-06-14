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
      </header>
      <main className="page">{children}</main>
    </div>
  )
}

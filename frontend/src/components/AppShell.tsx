import type { ReactNode } from 'react'

type AppView = 'home' | 'interview' | 'history'

interface AppShellProps {
  children: ReactNode
  topbarAction?: ReactNode
  currentView: AppView
  isSidebarOpen: boolean
  isAuthenticated?: boolean
  onNavigate: (view: AppView) => void
  onToggleSidebar: () => void
}

const lockedItems = [
  '이력서 관리',
  '요금제',
]

export function AppShell({
  children,
  topbarAction,
  currentView,
  isSidebarOpen,
  isAuthenticated = true,
  onNavigate,
  onToggleSidebar,
}: AppShellProps) {
  return (
    <div className={`saas-shell${isSidebarOpen ? ' saas-shell--sidebar-open' : ''}`}>
      <aside className="saas-sidebar" aria-label="주요 내비게이션">
        <button
          type="button"
          className="saas-sidebar__brand"
          aria-label="JDSnack 홈"
          onClick={() => onNavigate('home')}
        >
          <span className="brand-icon">J</span>
          <div>
            <strong>JDSnack</strong>
            <p>AI Resume Copilot</p>
          </div>
        </button>

        <nav className="saas-sidebar__nav" aria-label="서비스 메뉴">
          <button
            type="button"
            className={`saas-nav-item${currentView === 'home' ? ' saas-nav-item--active' : ''}`}
            onClick={() => onNavigate('home')}
          >
            <span className="saas-nav-item__icon" aria-hidden="true">
              ▣
            </span>
            <span>홈</span>
          </button>

          <button
            type="button"
            className={`saas-nav-item${currentView === 'interview' ? ' saas-nav-item--active' : ''}${!isAuthenticated ? ' saas-nav-item--locked' : ''}`}
            aria-disabled={!isAuthenticated}
            disabled={!isAuthenticated}
            onClick={() => onNavigate('interview')}
          >
            <span className="saas-nav-item__icon" aria-hidden="true">
              ▸
            </span>
            <span>모의 면접</span>
          </button>

          <button
            type="button"
            className={`saas-nav-item${currentView === 'history' ? ' saas-nav-item--active' : ''}${!isAuthenticated ? ' saas-nav-item--locked' : ''}`}
            aria-disabled={!isAuthenticated}
            disabled={!isAuthenticated}
            onClick={() => onNavigate('history')}
          >
            <span className="saas-nav-item__icon" aria-hidden="true">
              ◷
            </span>
            <span>분석 내역</span>
          </button>

          <div className="saas-sidebar__divider" />

          {lockedItems.map((item) => (
            <button
              key={item}
              type="button"
              className="saas-nav-item saas-nav-item--locked"
              aria-disabled="true"
              disabled
            >
              <span className="saas-nav-item__icon" aria-hidden="true">
                🔒
              </span>
              <span>{item}</span>
            </button>
          ))}
        </nav>

      </aside>

      <div className="saas-main">
        <header className="saas-topbar">
          <div className="saas-topbar__left">
            <button
              type="button"
              className="saas-menu-button"
              onClick={onToggleSidebar}
              aria-label="사이드바 열기 또는 닫기"
            >
              ☰
            </button>
          </div>
          <div className="saas-topbar__right">
            <span className="saas-help-pill">도움말</span>
            <span className="saas-bell" aria-label="알림 3개">
              🔔
              <span className="saas-bell__badge">3</span>
            </span>
            {topbarAction}
          </div>
        </header>

        <main className="saas-content">{children}</main>
      </div>
    </div>
  )
}

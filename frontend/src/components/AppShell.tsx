import type { ReactNode } from 'react'

type AppView = 'home' | 'interview'

interface AppShellProps {
  children: ReactNode
  currentView: AppView
  isSidebarOpen: boolean
  onNavigate: (view: AppView) => void
  onToggleSidebar: () => void
}

const lockedItems = [
  '분석 내역',
  '이력서 관리',
  '템플릿',
  '키워드 사전',
  '맞춤 첨삭',
  '요금제',
]

export function AppShell({
  children,
  currentView,
  isSidebarOpen,
  onNavigate,
  onToggleSidebar,
}: AppShellProps) {
  return (
    <div className={`saas-shell${isSidebarOpen ? ' saas-shell--sidebar-open' : ''}`}>
      <aside className="saas-sidebar" aria-label="주요 내비게이션">
        <div className="saas-sidebar__brand">
          <span className="brand-icon">J</span>
          <div>
            <strong>JDSnack</strong>
            <p>AI Resume Copilot</p>
          </div>
        </div>

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
            className={`saas-nav-item${currentView === 'interview' ? ' saas-nav-item--active' : ''}`}
            onClick={() => onNavigate('interview')}
          >
            <span className="saas-nav-item__icon" aria-hidden="true">
              ▸
            </span>
            <span>모의 면접</span>
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

        <div className="saas-sidebar__profile" aria-label="계정 정보">
          <div className="plan-card">
            <strong>프로 플랜</strong>
            <span>만료일 2025.06.30</span>
            <button type="button" className="plan-card__manage" disabled aria-disabled="true">
              플랜 관리
            </button>
          </div>
          <div className="profile-row">
            <span className="profile-avatar" aria-hidden="true">
              HJ
            </span>
            <div className="profile-row__info">
              <strong>김현준</strong>
              <span>hyunjun.kim@example.com</span>
            </div>
          </div>
        </div>
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
            <a className="brand-mark" href="/" aria-label="JDSnack 홈">
              <strong>JDSnack</strong>
            </a>
          </div>
          <div className="saas-topbar__right">
            <span className="saas-help-pill">도움말</span>
            <span className="saas-bell" aria-label="알림 3개">
              🔔
              <span className="saas-bell__badge">3</span>
            </span>
          </div>
        </header>

        <main className="saas-content">{children}</main>
      </div>
    </div>
  )
}

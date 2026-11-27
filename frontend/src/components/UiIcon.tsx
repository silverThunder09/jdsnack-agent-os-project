import type { ReactNode } from 'react'

type IconName = 'file' | 'chat' | 'history' | 'lock' | 'menu' | 'upload' | 'check-circle' | 'circle' | 'info'

const paths: Record<IconName, ReactNode> = {
  file: <><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8zM14 2v6h6M8 13h8M8 17h5" /></>,
  chat: <path d="M21 11.5a8.5 8.5 0 0 1-12.3 7.6L3 21l1.9-5.7A8.5 8.5 0 1 1 21 11.5Z" />,
  history: <><path d="M3 12a9 9 0 1 0 3-7M3 4v5h5M12 7v5l3 2" /></>,
  lock: <><rect x="5" y="10" width="14" height="11" rx="2" /><path d="M8 10V7a4 4 0 0 1 8 0v3" /></>,
  menu: <path d="M4 6h16M4 12h16M4 18h16" />,
  upload: <path d="M12 16V4m-5 5 5-5 5 5M4 16v4h16v-4" />,
  'check-circle': <><circle cx="12" cy="12" r="9" /><path d="m8 12 3 3 5-6" /></>,
  circle: <circle cx="12" cy="12" r="9" />,
  info: <><circle cx="12" cy="12" r="9" /><path d="M12 11v5M12 7h.01" /></>,
}

export function UiIcon({ name }: { name: IconName }) {
  return <svg className="ui-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false">{paths[name]}</svg>
}

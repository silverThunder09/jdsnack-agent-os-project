interface StatusMessageProps {
  badge: string
  title: string
  message: string
  tone: 'neutral' | 'active' | 'success' | 'danger'
  withLoadingBar?: boolean
}

export function StatusMessage({
  badge,
  title,
  message,
  tone,
  withLoadingBar = false,
}: StatusMessageProps) {
  return (
    <div className={`status-message status-message--${tone}`}>
      <span className="status-badge">{badge}</span>
      <h3>{title}</h3>
      <p>{message}</p>
      {withLoadingBar ? <div className="loading-bar" aria-hidden="true" /> : null}
    </div>
  )
}

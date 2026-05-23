interface DiagnoseButtonProps {
  isSubmitting: boolean
  idleLabel?: string
  loadingLabel?: string
}

export function DiagnoseButton({
  isSubmitting,
  idleLabel = '진단 요청',
  loadingLabel = '요청 확인 중...',
}: DiagnoseButtonProps) {
  return (
    <button className="diagnose-button" type="submit" disabled={isSubmitting}>
      {isSubmitting ? loadingLabel : idleLabel}
    </button>
  )
}

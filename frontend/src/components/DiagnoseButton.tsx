interface DiagnoseButtonProps {
  isSubmitting: boolean
  idleLabel?: string
  loadingLabel?: string
  disabled?: boolean
}

export function DiagnoseButton({
  isSubmitting,
  idleLabel = '진단 요청',
  loadingLabel = '요청 확인 중...',
  disabled = false,
}: DiagnoseButtonProps) {
  return (
    <button className="diagnose-button" type="submit" disabled={isSubmitting || disabled}>
      {isSubmitting ? loadingLabel : idleLabel}
    </button>
  )
}

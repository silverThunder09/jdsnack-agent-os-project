interface DiagnoseButtonProps {
  isSubmitting: boolean
}

export function DiagnoseButton({ isSubmitting }: DiagnoseButtonProps) {
  return (
    <button className="diagnose-button" type="submit" disabled={isSubmitting}>
      {isSubmitting ? '요청 확인 중...' : '진단 요청'}
    </button>
  )
}

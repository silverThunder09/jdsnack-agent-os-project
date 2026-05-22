import type { ResumeInputMode } from '../types/diagnosis'

interface ResumeModeTabsProps {
  mode: ResumeInputMode
  onChange: (mode: ResumeInputMode) => void
}

const tabItems: Array<{ mode: ResumeInputMode; label: string }> = [
  { mode: 'text', label: 'Text' },
  { mode: 'pdf', label: 'PDF' },
  { mode: 'docx', label: 'DOCX' },
]

export function ResumeModeTabs({ mode, onChange }: ResumeModeTabsProps) {
  return (
    <div className="mode-tabs" role="tablist" aria-label="이력서 입력 방식">
      {tabItems.map((item) => (
        <button
          key={item.mode}
          type="button"
          role="tab"
          className={`mode-tab${mode === item.mode ? ' mode-tab--active' : ''}`}
          aria-selected={mode === item.mode}
          onClick={() => onChange(item.mode)}
        >
          {item.label}
        </button>
      ))}
    </div>
  )
}

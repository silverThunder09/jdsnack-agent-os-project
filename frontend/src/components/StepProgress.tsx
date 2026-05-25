interface StepProgressProps {
  currentStep: number
  activeStep: number
  onStepChange: (step: number) => void
}

const steps = [
  { number: 1, title: '이력서 입력', eyebrow: 'STEP 1 / 3' },
  { number: 2, title: 'JD 분석', eyebrow: 'STEP 2 / 3' },
  { number: 3, title: '리포트 확인', eyebrow: 'STEP 3 / 3' },
]

export function StepProgress({ currentStep, activeStep, onStepChange }: StepProgressProps) {
  return (
    <section className="step-progress" aria-label="현재 진행 단계">
      {steps.map((step) => {
        const state =
          currentStep === step.number
            ? 'current'
            : activeStep > step.number
              ? 'complete'
              : 'upcoming'

        return (
          <button
            key={step.number}
            className={`step-progress__item step-progress__item--${state}`}
            type="button"
            onClick={() => onStepChange(step.number)}
            disabled={step.number === 3 && activeStep < 3}
          >
            <span className="step-progress__circle">
              {state === 'complete' ? '✓' : step.number}
            </span>
            <span>
              <small>{step.eyebrow}</small>
              <strong>{step.title}</strong>
            </span>
          </button>
        )
      })}
    </section>
  )
}

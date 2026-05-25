import type { FormEvent } from 'react'
import { DiagnoseButton } from './DiagnoseButton'
import { JdInputFields } from './JdInputFields'
import type { JdSections } from '../types/diagnosis'

type JdFetchStatus = 'idle' | 'fetching' | 'fetched' | 'fetch-error'

interface JdStepProps {
  jdSections: JdSections
  jdUrl: string
  isJdAutofilled: boolean
  jdFetchStatus: JdFetchStatus
  jdFetchTitle: string
  jdFetchMessage: string
  jdTextError: string
  jdUrlError: string
  isFetchingJd: boolean
  isPreviewSubmitting: boolean
  canPreviewWithCurrentSource: boolean
  onJdSectionChange: (section: keyof JdSections, value: string) => void
  onJdUrlChange: (value: string) => void
  onJdFetch: () => void
  onSubmit: (event: FormEvent<HTMLFormElement>) => void
  onPreviousStep: () => void
}

export function JdStep({
  jdSections,
  jdUrl,
  isJdAutofilled,
  jdFetchStatus,
  jdFetchTitle,
  jdFetchMessage,
  jdTextError,
  jdUrlError,
  isFetchingJd,
  isPreviewSubmitting,
  canPreviewWithCurrentSource,
  onJdSectionChange,
  onJdUrlChange,
  onJdFetch,
  onSubmit,
  onPreviousStep,
}: JdStepProps) {
  return (
    <section id="jd-step" className="workflow-card jd-workflow">
      <div className="workflow-heading workflow-heading--left">
        <p>STEP 2 / 3</p>
        <h1>채용 공고를 입력해주세요</h1>
        <span>JD 링크를 먼저 불러오고, 부족하면 직접 본문을 보완합니다.</span>
      </div>

      <form className="jd-form" onSubmit={onSubmit}>
        <JdInputFields
          jdSections={jdSections}
          jdUrl={jdUrl}
          isJdAutofilled={isJdAutofilled}
          jdFetchStatus={jdFetchStatus}
          jdFetchTitle={jdFetchTitle}
          jdFetchMessage={jdFetchMessage}
          jdTextError={jdTextError}
          jdUrlError={jdUrlError}
          isFetchingJd={isFetchingJd}
          onJdSectionChange={onJdSectionChange}
          onJdUrlChange={onJdUrlChange}
          onJdFetch={onJdFetch}
        />

        <div className="workflow-actions workflow-actions--split">
          <button className="ghost-button" type="button" onClick={onPreviousStep}>
            이전 단계
          </button>
          <DiagnoseButton
            isSubmitting={isPreviewSubmitting}
            idleLabel="분석 리포트 생성"
            loadingLabel="리포트 생성 중..."
            disabled={!canPreviewWithCurrentSource}
          />
        </div>
      </form>
    </section>
  )
}

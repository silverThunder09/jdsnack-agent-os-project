import { AnalysisPanel } from './AnalysisPanels'
import type { ResultState } from '../../types/diagnosis'

interface InterviewWorkspaceProps {
  jobTitle: string
  setJobTitle: (value: string) => void
  hasResumeSource: boolean
  trimmedJd: string
  isInterviewSubmitting: boolean
  handleInterviewSubmit: () => Promise<void>
  interviewResult: ResultState
}

export function InterviewWorkspace(props: InterviewWorkspaceProps) {
  const { jobTitle, setJobTitle, hasResumeSource, trimmedJd, isInterviewSubmitting, handleInterviewSubmit, interviewResult } = props
  return (
        <section className="interview-shell" aria-label="모의 면접 화면">
          <section className="hero-card hero-card--compact">
            <p className="hero-card__eyebrow">Mock Interview</p>
            <h1>현재 이력서와 JD 맥락으로 예상 질문을 빠르게 준비하세요.</h1>
            <p className="hero-card__copy">
              분석에서 추출한 이력서 본문과 JD를 그대로 이어받고, 직무명만 보강해 질문 세트를 만듭니다.
            </p>
          </section>

          <div className="interview-layout">
            <section className="workspace-card">
              <div className="workspace-card__header">
                <div>
                  <span>Interview Input</span>
                  <h2>질문 생성 준비</h2>
                </div>
                <p>분석 단계에서 만든 이력서·JD 맥락을 이어받아 질문을 생성합니다.</p>
              </div>

              <div className="interview-form">
                <label className="resume-input-group" htmlFor="job-title">
                  <span className="resume-label">대상 직무</span>
                  <input
                    id="job-title"
                    className="text-input"
                    type="text"
                    value={jobTitle}
                    placeholder="예: 백엔드 개발자"
                    onChange={(event) => setJobTitle(event.target.value)}
                  />
                </label>

                <div className="context-note">
                  <h3>연결된 분석 맥락</h3>
                  <ul>
                    <li>이력서 소스: {hasResumeSource ? '준비됨' : '먼저 홈에서 분석을 실행해 주세요.'}</li>
                    <li>JD 본문: {trimmedJd ? '준비됨' : '홈에서 JD를 입력해 주세요.'}</li>
                  </ul>
                </div>

                <button
                  className="diagnose-button"
                  type="button"
                  disabled={!hasResumeSource || isInterviewSubmitting}
                  onClick={handleInterviewSubmit}
                >
                  {isInterviewSubmitting ? '질문 생성 중...' : '면접 질문 생성'}
                </button>
              </div>
            </section>

            <AnalysisPanel
              badge="Interview"
              title="모의 면접 질문"
              description="질문 목록, 답변 전략, 요약을 한 번에 확인합니다."
              result={interviewResult}
              successContent={
                <div className="interview-result">
                  <p className="strategy-card">{interviewResult.interviewPreview?.strategy}</p>
                  <div className="question-grid">
                    {interviewResult.interviewPreview?.questions.map((question) => (
                      <article className="question-card" key={question.question}>
                        <span>{question.category}</span>
                        <h3>{question.question}</h3>
                        <p>{question.keypoints}</p>
                      </article>
                    ))}
                  </div>
                </div>
              }
            />
          </div>
        </section>
  )
}

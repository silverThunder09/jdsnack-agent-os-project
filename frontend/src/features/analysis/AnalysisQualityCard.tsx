import type { AnalysisQualityResult } from '../../types/diagnosis'

const qualityCriteria = [
  { label: '응답 형식 준수', note: '필수 필드와 데이터 형식을 확인합니다.' },
  { label: '근거 연결성', note: '이력서·JD 근거와 제안의 연결을 확인합니다.' },
  { label: '결과 완성도', note: '요약·강점·개선안의 누락 여부를 확인합니다.' },
]

interface AnalysisQualityCardProps {
  quality: AnalysisQualityResult
}

export function AnalysisQualityCard({ quality }: AnalysisQualityCardProps) {
  return (
    <section className="analysis-quality-card" aria-label="AI 분석 품질">
      <div className="analysis-quality-card__title">
        <div>
          <span className="analysis-quality-card__label">AI QUALITY</span>
          <h2>이 분석, 얼마나 믿을 수 있나요?</h2>
        </div>
        <div className="analysis-quality-card__badge">
          <span>AI 분석 품질</span>
          <strong>{quality.score}<small>/100</small></strong>
          <small>평가기준 · {quality.evaluatorVersion}</small>
        </div>
      </div>

      <div className="analysis-quality-card__metrics">
        {qualityCriteria.map((criterion) => {
          const metric = quality.metrics.find((item) => item.label === criterion.label)
          return (
            <div key={criterion.label}>
              <span>{criterion.label}</span>
              <strong>{metric ? metric.value : '검증 중'}</strong>
              {metric ? <div className="analysis-quality-card__bar"><i style={{ width: `${metric.value}%` }} /></div> : <p>{criterion.note}</p>}
            </div>
          )
        })}
      </div>

      <p className="analysis-quality-card__disclaimer">
        품질점수는 이력서 점수가 아니라 AI 응답의 형식·근거·완성도를 평가한 별도 지표입니다.
      </p>
    </section>
  )
}

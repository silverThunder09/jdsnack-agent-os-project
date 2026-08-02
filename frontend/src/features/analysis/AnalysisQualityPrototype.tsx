import { useEffect, useState } from 'react'

type VariantKey = 'A' | 'B' | 'C'

const metrics = [
  { label: '응답 형식 준수', value: 100, note: 'JSON 스키마와 필수 필드가 모두 맞습니다.' },
  { label: '근거 연결성', value: 82, note: '이력서와 JD 근거가 결과에 연결됩니다.' },
  { label: '결과 완성도', value: 88, note: '요약·강점·개선안이 빠짐없이 채워졌습니다.' },
]

const variants: Record<VariantKey, string> = {
  A: '균형형 카드',
  B: '대시보드형',
  C: '리포트형',
}

function scoreClass(value: number): string {
  if (value >= 90) return 'quality-prototype__score quality-prototype__score--high'
  if (value >= 80) return 'quality-prototype__score quality-prototype__score--mid'
  return 'quality-prototype__score quality-prototype__score--low'
}

function PrototypeSwitcher({ variant, onChange }: { variant: VariantKey; onChange: (next: VariantKey) => void }) {
  const keys = Object.keys(variants) as VariantKey[]
  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement | null
      if (target?.matches('input, textarea, [contenteditable="true"]')) return
      if (event.key !== 'ArrowLeft' && event.key !== 'ArrowRight') return
      event.preventDefault()
      const currentIndex = keys.indexOf(variant)
      const offset = event.key === 'ArrowRight' ? 1 : -1
      onChange(keys[(currentIndex + offset + keys.length) % keys.length])
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [keys, onChange, variant])

  const currentIndex = keys.indexOf(variant)
  const move = (offset: number) => onChange(keys[(currentIndex + offset + keys.length) % keys.length])

  return (
    <nav className="quality-prototype-switcher" aria-label="품질 점수 프로토타입 변형 선택">
      <button type="button" onClick={() => move(-1)} aria-label="이전 변형">←</button>
      <span><strong>{variant}</strong> · {variants[variant]}</span>
      <button type="button" onClick={() => move(1)} aria-label="다음 변형">→</button>
    </nav>
  )
}

function PrototypeHeader() {
  return (
    <header className="quality-prototype__header">
      <div>
        <span className="quality-prototype__eyebrow">PROTOTYPE · AI QUALITY</span>
        <h1>분석 결과</h1>
        <p>기존 사용자 점수와 AI 분석 품질 점수를 함께 배치한 화면 목업입니다.</p>
      </div>
      <span className="quality-prototype__version">결정론적 품질 검증</span>
    </header>
  )
}

function QualityBadge({ compact = false }: { compact?: boolean }) {
  return (
    <div className={`quality-prototype__badge${compact ? ' quality-prototype__badge--compact' : ''}`}>
      <span>AI 분석 품질</span>
      <strong>86<span>/100</span></strong>
      <small>내부 평가 기준 · quality-v1</small>
    </div>
  )
}

function VariantA() {
  return (
    <div className="quality-prototype quality-prototype--a">
      <PrototypeHeader />
      <div className="quality-prototype__user-scores">
        <article><span>JD 적합도</span><strong>35점</strong><p>직무 핵심 경험과 기술 스택의 일치도</p></article>
        <article><span>ATS 점수</span><strong>48점</strong><p>ATS가 이력서를 읽을 수 있는 구조와 키워드</p></article>
      </div>
      <section className="quality-prototype__card quality-prototype__quality-card">
        <div className="quality-prototype__card-title"><div><span className="quality-prototype__label">AI QUALITY</span><h2>이 분석, 얼마나 믿을 수 있나요?</h2></div><QualityBadge /></div>
        <div className="quality-prototype__metric-grid">
          {metrics.map((metric) => <div key={metric.label}><span>{metric.label}</span><strong>{metric.value}</strong><div className="quality-prototype__bar"><i style={{ width: `${metric.value}%` }} /></div></div>)}
        </div>
      </section>
      <p className="quality-prototype__disclaimer">품질점수는 이력서 점수가 아니라 AI 응답의 형식·근거·완성도를 평가한 내부 지표입니다.</p>
    </div>
  )
}

function VariantB() {
  return (
    <div className="quality-prototype quality-prototype--b">
      <PrototypeHeader />
      <section className="quality-prototype__dashboard">
        <aside className="quality-prototype__score-rail"><span>ANALYSIS QUALITY</span><strong>86</strong><em>GOOD</em><p>분석 결과의 신뢰 신호가 안정적입니다.</p></aside>
        <div className="quality-prototype__dashboard-main"><div className="quality-prototype__card-title"><div><span className="quality-prototype__label">QUALITY BREAKDOWN</span><h2>품질을 만든 세 가지 신호</h2></div><QualityBadge compact /></div><div className="quality-prototype__metric-list">{metrics.map((metric) => <div key={metric.label}><div><strong>{metric.label}</strong><span>{metric.note}</span></div><b className={scoreClass(metric.value)}>{metric.value}</b></div>)}</div></div>
      </section>
      <div className="quality-prototype__insight"><span>✓</span><p><strong>좋은 상태입니다.</strong> 다음 분석부터도 같은 평가 기준으로 비교할 수 있습니다.</p></div>
    </div>
  )
}

function VariantC() {
  return (
    <div className="quality-prototype quality-prototype--c">
      <PrototypeHeader />
      <section className="quality-prototype__report">
        <div className="quality-prototype__report-top"><div><span className="quality-prototype__label">ANALYSIS REPORT / 2026.07.22</span><h2>이 결과의 품질 리포트</h2><p>사용자 결과 점수와 별개로, AI 응답 자체를 검증한 기록입니다.</p></div><div className="quality-prototype__ring"><strong>86</strong><span>품질점수</span></div></div>
        <div className="quality-prototype__report-body"><div><span className="quality-prototype__label">결과에 반영된 평가 기준</span><dl><div><dt>평가 기준</dt><dd>quality-v1</dd></div></dl></div><div className="quality-prototype__evidence"><span className="quality-prototype__label">평가 요약</span><ul><li><b>형식</b><span>필수 필드와 데이터 형식이 정확합니다.</span><strong>100</strong></li><li><b>근거</b><span>입력 문서와 제안의 연결이 양호합니다.</span><strong>82</strong></li><li><b>완성도</b><span>요약과 필수 결과 영역이 모두 채워졌습니다.</span><strong>88</strong></li></ul></div></div>
      </section>
    </div>
  )
}

export function AnalysisQualityPrototype() {
  const [variant, setVariant] = useState<VariantKey>(() => {
    const value = new URLSearchParams(window.location.search).get('variant')
    return value === 'B' || value === 'C' ? value : 'A'
  })
  const changeVariant = (next: VariantKey) => {
    const url = new URL(window.location.href)
    url.searchParams.set('prototype', 'analysis-quality')
    url.searchParams.set('variant', next)
    window.history.replaceState({}, '', url)
    setVariant(next)
  }

  return (
    <>
      {variant === 'A' ? <VariantA /> : variant === 'B' ? <VariantB /> : <VariantC />}
      <PrototypeSwitcher variant={variant} onChange={changeVariant} />
    </>
  )
}

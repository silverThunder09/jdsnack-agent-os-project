import type { ReactNode, RefObject } from 'react'
import { StatusMessage } from '../../components/StatusMessage'
import type { ResultState } from '../../types/diagnosis'

export function SummaryCard({ label, score, summary, description }: { label: string; score?: number; summary?: string; description: string }) {
  return <article className="summary-card"><span>{label}</span>{typeof score === 'number' ? <><strong>{score}점</strong><p>{summary}</p></> : <><strong className="summary-card__empty">-</strong><p>{description}</p></>}</article>
}

export function AnalysisPanel({ badge, title, description, result, resultRef, successContent }: { badge: string; title: string; description: string; result: ResultState; resultRef?: RefObject<HTMLElement | null>; successContent: ReactNode }) {
  return <section className="preview-panel" aria-live="polite" ref={resultRef} tabIndex={resultRef ? -1 : undefined}>
    <div className="preview-panel__header"><span>{badge}</span><div><h2>{title}</h2><p>{description}</p></div></div>
    {result.status === 'idle' ? <StatusMessage badge="Ready" title="아직 결과가 없습니다" message={description} tone="neutral" /> : null}
    {result.status === 'loading' ? <StatusMessage badge="Processing" title={result.title} message={result.message} tone="active" withLoadingBar /> : null}
    {result.status === 'not-enabled' ? <StatusMessage badge="Not Enabled" title={result.title} message={result.message} tone="success" /> : null}
    {result.status === 'error' ? <StatusMessage badge="Action Needed" title={result.title} message={result.message} tone="danger" /> : null}
    {result.status === 'success' ? successContent : null}
  </section>
}

export function ComingSoonPanel({ title, description }: { title: string; description: string }) {
  return <section className="preview-panel"><div className="preview-panel__header"><span>준비중</span><div><h2>{title}</h2><p>{description}</p></div></div><StatusMessage badge="Coming Soon" title="준비 중인 분석입니다" message="이 분석 항목은 현재 준비 중입니다. 곧 제공될 예정이에요." tone="neutral" /></section>
}

export function KeywordList({ items }: { items: string[] }) {
  return items.length === 0 ? <p className="keyword-empty">해당 키워드가 없습니다.</p> : <ul className="keyword-list">{items.map((item) => <li key={item}>{item}</li>)}</ul>
}

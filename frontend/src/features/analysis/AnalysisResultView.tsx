import type { RefObject } from 'react'
import { AnalysisPanel, FormatCheckList, KeywordList, SummaryCard } from './AnalysisPanels'
import type { ResultState } from '../../types/diagnosis'
import type { AnalysisOptionKey } from './analysisUtils'

interface AnalysisResultViewProps {
  submittedOptions: Record<AnalysisOptionKey, boolean>
  previewResult: ResultState
  atsResult: ResultState
  sentenceResult: ResultState
  resultRef: RefObject<HTMLElement | null>
  handleExportResult: () => void
  handlePrintResult: () => void
  handleNewAnalysis: () => void
}

export function AnalysisResultView(props: AnalysisResultViewProps) {
  const { submittedOptions, previewResult, atsResult, sentenceResult, resultRef, handleExportResult, handlePrintResult, handleNewAnalysis } = props
  return (
    <section className="result-page" aria-label="분석 결과" ref={resultRef} tabIndex={-1}>
      <header className="result-page__head">
        <div>
          <p className="start-page__eyebrow">분석 결과</p>
          <h1>분석 결과</h1>
        </div>
        <div className="result-actions">
          {((submittedOptions.jdMatch || submittedOptions.keyword) && previewResult.status === 'success')
          || (submittedOptions.ats && atsResult.status === 'success')
          || (submittedOptions.sentence && sentenceResult.status === 'success') ? (
            <>
              <button type="button" className="ghost-button" onClick={handleExportResult}>
                내보내기
              </button>
              <button type="button" className="ghost-button" onClick={handlePrintResult}>
                인쇄
              </button>
            </>
          ) : null}
          <button type="button" className="ghost-button" onClick={handleNewAnalysis}>
            새 분석
          </button>
        </div>
      </header>

      {submittedOptions.jdMatch ? (
        <div className="summary-grid">
          <SummaryCard
            label="JD 적합도"
            score={previewResult.matchPreview?.matchingScore}
            summary={previewResult.matchPreview?.summary}
            description="JD와 이력서 적합도를 계산하고 있습니다."
          />
        </div>
      ) : null}

      {submittedOptions.ats ? (
        <div className="summary-grid">
          <SummaryCard
            label="ATS 점수"
            score={atsResult.atsPreview?.atsScore}
            summary={atsResult.atsPreview?.summary}
            description="이력서가 ATS에서 읽힐 수 있는 신호를 점검하고 있습니다."
          />
        </div>
      ) : null}

      <div className="preview-grid">
        {submittedOptions.jdMatch ? (
          <AnalysisPanel
            badge="JD Match"
            title="JD 적합도"
            description="공고 강점과 gap, 보강 제안을 함께 확인하세요."
            result={previewResult}
            successContent={
              <div className="detail-list-grid detail-list-grid--triple">
                <section className="detail-card">
                  <h3>강점</h3>
                  <ul>{previewResult.matchPreview?.strengths.map((item) => <li key={item}>{item}</li>)}</ul>
                </section>
                <section className="detail-card">
                  <h3>Gap</h3>
                  <ul>{previewResult.matchPreview?.gaps.map((item) => <li key={item}>{item}</li>)}</ul>
                </section>
                <section className="detail-card">
                  <h3>제안</h3>
                  <ul>{previewResult.matchPreview?.suggestions.map((item) => <li key={item}>{item}</li>)}</ul>
                </section>
              </div>
            }
          />
        ) : null}

        {submittedOptions.ats ? (
          <AnalysisPanel
            badge="ATS Check"
            title="ATS 점수·포맷 진단"
            description="추출된 텍스트 기준으로 ATS가 읽을 수 있는 신호와 보완점을 확인하세요."
            result={atsResult}
            successContent={
              <div className="detail-list-grid detail-list-grid--triple" aria-label="ATS 진단 결과">
                <section className="detail-card">
                  <h3>포맷 점검</h3>
                  <FormatCheckList checks={atsResult.atsPreview?.formatChecks ?? []} />
                </section>
                <section className="detail-card">
                  <h3>강점·위험</h3>
                  <KeywordList items={[...(atsResult.atsPreview?.strengths ?? []), ...(atsResult.atsPreview?.risks ?? [])]} />
                </section>
                <section className="detail-card">
                  <h3>개선 제안</h3>
                  <KeywordList items={atsResult.atsPreview?.suggestions ?? []} />
                </section>
              </div>
            }
          />
        ) : null}
        {submittedOptions.sentence ? (
          <AnalysisPanel
            badge="Sentence Edit"
            title="문장 첨삭"
            description="JD에 맞춘 문장별 개선안과 이유를 확인하세요."
            result={sentenceResult}
            successContent={
              sentenceResult.sentencePreview?.edits.length ? (
                <div className="sentence-edit-list" aria-label="문장 첨삭 결과">
                  {sentenceResult.sentencePreview.edits.map((edit, index) => (
                    <article className="sentence-edit-card" key={`${edit.original}-${index}`}>
                      <div>
                        <span>원문</span>
                        <p>{edit.original || '(내용 없음)'}</p>
                      </div>
                      <div>
                        <span>개선문</span>
                        <p>{edit.improved || '(내용 없음)'}</p>
                      </div>
                      <div>
                        <span>개선 사유</span>
                        <p>{edit.reason || '(내용 없음)'}</p>
                      </div>
                    </article>
                  ))}
                </div>
              ) : (
                <p className="sentence-edit-empty">첨삭할 문장이 없습니다.</p>
              )
            }
          />
        ) : null}
        {submittedOptions.keyword ? (
          <AnalysisPanel
            badge="Keyword Match"
            title="키워드 분석"
            description="JD 핵심 키워드가 이력서에 얼마나 반영됐는지 확인하세요."
            result={previewResult}
            successContent={
              <div className="detail-list-grid detail-list-grid--triple" aria-label="키워드 분석 결과">
                <section className="detail-card">
                  <h3>매칭 키워드</h3>
                  <KeywordList items={previewResult.matchPreview?.matchedKeywords ?? []} />
                </section>
                <section className="detail-card">
                  <h3>부분 매칭</h3>
                  <KeywordList items={previewResult.matchPreview?.partialKeywords ?? []} />
                </section>
                <section className="detail-card">
                  <h3>누락 키워드</h3>
                  <KeywordList items={previewResult.matchPreview?.missingKeywords ?? []} />
                </section>
              </div>
            }
          />
        ) : null}
      </div>
    </section>
  )
}

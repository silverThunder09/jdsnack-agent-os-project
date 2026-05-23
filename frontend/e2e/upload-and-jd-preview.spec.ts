import { expect, test } from '@playwright/test'
import { fileURLToPath } from 'node:url'
import path from 'node:path'

const currentDir = path.dirname(fileURLToPath(import.meta.url))
const fixturePdf = path.resolve(currentDir, 'fixtures/resume-fixture.pdf')
const fixtureDocx = path.resolve(currentDir, 'fixtures/resume-fixture.docx')
const jdText =
  'Spring Boot 기반 REST API 개발과 운영 경험, 테스트 자동화, 배포 경험을 요구합니다.'
const resumeSummary = '백엔드 중심 경험은 분명하지만 성과 수치가 더 필요합니다.'

async function mockFixtureFlow(page: import('@playwright/test').Page) {
  await page.route('**/api/diagnose/file', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        success: true,
        data: {
          score: 78,
          summary: resumeSummary,
          strengths: ['Spring Boot API 구현 경험이 보입니다.'],
          improvements: ['프로젝트 결과를 수치로 보강해 주세요.'],
          sourceText:
            'Experienced backend engineer with Spring Boot REST API development, validation handling, and test automation delivery across projects.',
        },
        timestamp: '2026-05-23T10:00:00.000+09:00',
      }),
    })
  })

  await page.route('**/api/match/preview', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        success: true,
        data: {
          matchingScore: 76,
          summary:
            'Spring Boot와 테스트 자동화 키워드는 잘 맞지만 배포 경험 근거를 더 드러내면 좋습니다.',
          strengths: ['Spring Boot 관련 표현이 JD와 겹칩니다.'],
          gaps: ['배포 관련 경험 또는 성과 근거가 이력서에서 약하게 보입니다.'],
          suggestions: ['배포 경험이 있다면 프로젝트 맥락, 사용 기술, 결과를 함께 적어 보세요.'],
        },
        timestamp: '2026-05-23T10:01:00.000+09:00',
      }),
    })
  })
}

test('PDF 업로드 후 JD 매칭 결과까지 확인한다', async ({ page }) => {
  await mockFixtureFlow(page)
  await page.goto('/')

  await page.getByRole('tab', { name: 'PDF' }).click()
  await page.locator('#resume-file').setInputFiles(fixturePdf)
  await page.getByRole('button', { name: '진단 요청' }).click()

  await expect(page.getByText('이력서 분석 결과입니다')).toBeVisible()
  await expect(page.getByText(resumeSummary)).toBeVisible()
  await expect(page.getByText('78점')).toBeVisible()

  await page.getByRole('textbox', { name: 'JD 내용' }).fill(jdText)
  await page.getByRole('button', { name: 'JD 비교 미리보기' }).click()

  await expect(page.getByText('JD 비교 미리보기를 만들었습니다')).toBeVisible()
  await expect(page.getByText('JD 매칭 미리보기 점수')).toBeVisible()
  await expect(page.locator('.jd-preview-result')).toContainText(/점/)
})

test('DOCX 업로드 후 fixture 분석 결과를 확인한다', async ({ page }) => {
  await mockFixtureFlow(page)
  await page.goto('/')

  await page.getByRole('tab', { name: 'DOCX' }).click()
  await page.locator('#resume-file').setInputFiles(fixtureDocx)
  await page.getByRole('button', { name: '진단 요청' }).click()

  await expect(page.getByText('이력서 분석 결과입니다')).toBeVisible()
  await expect(page.getByText(resumeSummary)).toBeVisible()
  await expect(page.getByText('78점')).toBeVisible()
  await expect(page.getByRole('region', { name: '분석 기준 이력서 본문' })).toContainText(
    'Experienced backend engineer with Spring Boot REST API development',
  )
})

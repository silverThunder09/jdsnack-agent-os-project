import { expect, test } from '@playwright/test'
import { fileURLToPath } from 'node:url'
import path from 'node:path'

const currentDir = path.dirname(fileURLToPath(import.meta.url))
const fixturePdf = path.resolve(currentDir, 'fixtures/resume-fixture.pdf')
const fixtureDocx = path.resolve(currentDir, 'fixtures/resume-fixture.docx')
const jdText =
  'Spring Boot 기반 REST API 개발과 운영 경험, 테스트 자동화, 배포 경험을 요구하며 협업과 문서화 역량을 중요하게 봅니다.'
const fetchedJdText =
  '백엔드 API 설계와 운영을 담당합니다. Spring Boot와 MySQL 경험이 필요하고 테스트 자동화와 협업 경험을 우대합니다.'

async function mockFixtureFlow(page: import('@playwright/test').Page) {
  await page.route('**/api/diagnose/file', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        success: true,
        data: {
          score: 78,
          summary: '백엔드 중심 경험은 분명하지만 성과 수치가 더 필요합니다.',
          strengths: ['Spring Boot API 구현 경험이 보입니다.'],
          improvements: ['프로젝트 결과를 수치로 보강해 주세요.'],
          sourceText:
            'Experienced backend engineer with Spring Boot REST API development, validation handling, and test automation delivery across projects.',
        },
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
          matchedKeywords: ['Spring Boot', 'REST API'],
          partialKeywords: [],
          missingKeywords: ['Kubernetes'],
        },
      }),
    })
  })

  await page.route('**/api/sentence/preview', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        success: true,
        data: {
          edits: [
            {
              original: 'Spring Boot 기반 API를 개발했습니다.',
              improved: 'Spring Boot REST API를 설계하고 테스트 자동화로 안정성을 높였습니다.',
              reason: 'JD 핵심 역량과 성과를 구체적으로 연결했습니다.',
            },
          ],
        },
      }),
    })
  })

  await page.route('**/api/interview/preview', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        success: true,
        data: {
          questions: [
            {
              question: 'Spring Boot API 설계 경험을 설명해 주세요.',
              category: 'technical',
              keypoints: '설계 이유, 테스트 방식, 운영 결과를 함께 말하세요.',
            },
          ],
          strategy: '기술 질문은 의사결정 근거와 검증 방법 중심으로 답변하세요.',
          summary: '백엔드 직무 맥락의 모의 면접 질문을 생성했습니다.',
        },
      }),
    })
  })
}

async function mockJdFetchSuccess(page: import('@playwright/test').Page) {
  await page.route('**/api/jd/fetch', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        success: true,
        data: {
          jdText: fetchedJdText,
          sourceUrl: 'https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=1',
          title: '백엔드 엔지니어 채용',
          fetchMode: 'static-html',
          sourceSite: 'saramin',
        },
      }),
    })
  })
}

async function mockJdFetchFailure(page: import('@playwright/test').Page) {
  await page.route('**/api/jd/fetch', async (route) => {
    await route.fulfill({
      status: 422,
      contentType: 'application/json',
      body: JSON.stringify({
        success: false,
        error: {
          code: 'JD_FETCH_UNSUPPORTED_SOURCE',
          message: '지원하지 않는 JD 소스입니다.',
        },
      }),
    })
  })
}

test('PDF 업로드 + JD 붙여넣기 후 JD 적합도 결과를 확인한다', async ({ page }) => {
  await mockFixtureFlow(page)
  await page.goto('/')

  await page.getByRole('tab', { name: 'JD 내용 붙여넣기' }).click()
  await page.getByLabel('JD 내용 붙여넣기').fill(jdText)
  await page.locator('#resume-file').setInputFiles(fixturePdf)
  await page.getByRole('button', { name: '분석 시작하기 →' }).click()

  await expect(page.getByText('76점')).toBeVisible()
  await expect(page.getByText('Spring Boot 관련 표현이 JD와 겹칩니다.')).toBeVisible()
  await expect(page.getByRole('heading', { name: '키워드 분석' })).toBeVisible()
  await expect(page.getByText('Kubernetes')).toBeVisible()
  await expect(page.getByRole('heading', { name: '문장 첨삭' })).toBeVisible()
  await expect(page.getByText('Spring Boot REST API를 설계하고 테스트 자동화로 안정성을 높였습니다.')).toBeVisible()
})

test('키워드 분석만 선택해도 매칭 요청과 키워드 결과를 제공한다', async ({ page }) => {
  await mockFixtureFlow(page)
  await page.goto('/')

  await page.getByRole('tab', { name: 'JD 내용 붙여넣기' }).click()
  await page.getByLabel('JD 내용 붙여넣기').fill(jdText)
  await page.locator('#resume-file').setInputFiles(fixturePdf)
  await page.getByRole('checkbox', { name: /JD 적합도/ }).uncheck()
  await page.getByRole('checkbox', { name: /맞춤 첨삭/ }).uncheck()
  await page.getByRole('button', { name: '분석 시작하기 →' }).click()

  await expect(page.getByRole('heading', { name: '키워드 분석' })).toBeVisible()
  await expect(page.getByText('REST API')).toBeVisible()
  await expect(page.getByText('해당 키워드가 없습니다.')).toBeVisible()
  await expect(page.getByText('76점')).toHaveCount(0)
  await expect(page.getByRole('button', { name: '내보내기' })).toBeVisible()
})

test('맞춤 첨삭만 선택해도 독립 호출과 Before→After 결과를 제공한다', async ({ page }) => {
  await mockFixtureFlow(page)
  await page.goto('/')

  await page.getByRole('tab', { name: 'JD 내용 붙여넣기' }).click()
  await page.getByLabel('JD 내용 붙여넣기').fill(jdText)
  await page.locator('#resume-file').setInputFiles(fixturePdf)
  await page.getByRole('checkbox', { name: /JD 적합도/ }).uncheck()
  await page.getByRole('checkbox', { name: /키워드 분석/ }).uncheck()
  await page.getByRole('button', { name: '분석 시작하기 →' }).click()

  await expect(page.getByRole('heading', { name: '문장 첨삭' })).toBeVisible()
  await expect(page.getByText('Spring Boot 기반 API를 개발했습니다.')).toBeVisible()
  await expect(page.getByText('Spring Boot REST API를 설계하고 테스트 자동화로 안정성을 높였습니다.')).toBeVisible()
  await expect(page.getByText('76점')).toHaveCount(0)
  await expect(page.getByRole('button', { name: '내보내기' })).toBeVisible()
})

test('짧은 JD에서는 분석 시작 전 업로드와 매칭 요청을 차단한다', async ({ page }) => {
  let diagnoseFileRequests = 0
  let matchPreviewRequests = 0
  let sentencePreviewRequests = 0

  await page.route('**/api/diagnose/file', async (route) => {
    diagnoseFileRequests += 1
    await route.abort()
  })
  await page.route('**/api/match/preview', async (route) => {
    matchPreviewRequests += 1
    await route.abort()
  })
  await page.route('**/api/sentence/preview', async (route) => {
    sentencePreviewRequests += 1
    await route.abort()
  })
  await page.goto('/')

  await page.getByRole('tab', { name: 'JD 내용 붙여넣기' }).click()
  await page.getByLabel('JD 내용 붙여넣기').fill('짧은 JD')
  await page.locator('#resume-file').setInputFiles(fixturePdf)

  await expect(page.getByRole('button', { name: '분석 시작하기 →' })).toBeDisabled()
  await expect(
    page.getByText('JD 내용이 너무 짧습니다. 핵심 자격요건이 드러나도록 더 입력해주세요.'),
  ).toBeVisible()
  expect(diagnoseFileRequests).toBe(0)
  expect(matchPreviewRequests).toBe(0)
  expect(sentencePreviewRequests).toBe(0)
})

test('분석 후 모의 면접 목적지에서 질문을 생성한다', async ({ page }) => {
  await mockFixtureFlow(page)
  await page.goto('/')

  await page.getByRole('tab', { name: 'JD 내용 붙여넣기' }).click()
  await page.getByLabel('JD 내용 붙여넣기').fill(jdText)
  await page.locator('#resume-file').setInputFiles(fixtureDocx)
  await page.getByRole('button', { name: '분석 시작하기 →' }).click()
  await expect(page.getByText('76점')).toBeVisible()

  await page.getByRole('button', { name: '모의 면접' }).click()
  await page.getByLabel('대상 직무').fill('백엔드 개발자')
  await page.getByRole('button', { name: '면접 질문 생성' }).click()

  await expect(page.getByText('Spring Boot API 설계 경험을 설명해 주세요.')).toBeVisible()
  await expect(
    page.getByText('기술 질문은 의사결정 근거와 검증 방법 중심으로 답변하세요.'),
  ).toBeVisible()
})

test('JD 링크 불러오기 성공 후 분석으로 이어진다', async ({ page }) => {
  await mockFixtureFlow(page)
  await mockJdFetchSuccess(page)
  await page.goto('/')

  await page
    .getByLabel('채용 공고 URL')
    .fill('https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=1')
  await page.getByRole('button', { name: 'JD 불러오기' }).click()

  await page.getByRole('tab', { name: 'JD 내용 붙여넣기' }).click()
  await expect(page.getByLabel('JD 내용 붙여넣기')).toHaveValue(fetchedJdText)

  await page.locator('#resume-file').setInputFiles(fixturePdf)
  await page.getByRole('button', { name: '분석 시작하기 →' }).click()
  await expect(page.getByText('76점')).toBeVisible()
})

test('JD 링크 실패 후 직접 붙여넣기로 복구한다', async ({ page }) => {
  await mockFixtureFlow(page)
  await mockJdFetchFailure(page)
  await page.goto('/')

  await page
    .getByLabel('채용 공고 URL')
    .fill('https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=2')
  await page.getByRole('button', { name: 'JD 불러오기' }).click()

  await expect(page.getByRole('alert')).toContainText('붙여넣어')

  await page.getByRole('tab', { name: 'JD 내용 붙여넣기' }).click()
  await page.getByLabel('JD 내용 붙여넣기').fill(jdText)
  await page.locator('#resume-file').setInputFiles(fixturePdf)
  await page.getByRole('button', { name: '분석 시작하기 →' }).click()
  await expect(page.getByText('76점')).toBeVisible()
})

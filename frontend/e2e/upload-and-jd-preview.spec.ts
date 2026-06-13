import { expect, test } from '@playwright/test'
import { fileURLToPath } from 'node:url'
import path from 'node:path'

const currentDir = path.dirname(fileURLToPath(import.meta.url))
const fixturePdf = path.resolve(currentDir, 'fixtures/resume-fixture.pdf')
const fixtureDocx = path.resolve(currentDir, 'fixtures/resume-fixture.docx')
const jdText =
  'Spring Boot 기반 REST API 개발과 운영 경험, 테스트 자동화, 배포 경험을 요구합니다.'
const fetchedJdText =
  '백엔드 API 설계와 운영을 담당합니다. Spring Boot와 MySQL 경험이 필요합니다.'
const resumeSummary = '백엔드 중심 경험은 분명하지만 성과 수치가 더 필요합니다.'

async function expectJdStepReady(page: import('@playwright/test').Page) {
  await expect(page.getByRole('heading', { name: '채용 공고를 입력해주세요' })).toBeVisible()
  await expect(page.getByRole('textbox', { name: '주요업무' })).toBeVisible()
}

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
        timestamp: '2026-05-25T10:02:00.000+09:00',
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
        timestamp: '2026-05-25T10:03:00.000+09:00',
      }),
    })
  })
}

test('PDF 업로드 후 JD 매칭 결과까지 확인한다', async ({ page }) => {
  await mockFixtureFlow(page)
  await page.goto('/')

  await page.getByRole('tab', { name: 'PDF' }).click()
  await page.locator('#resume-file').setInputFiles(fixturePdf)
  await page.getByRole('button', { name: 'AI 진단 시작하기' }).click()

  await expectJdStepReady(page)

  await page.getByRole('textbox', { name: '주요업무' }).fill(jdText)
  await page.getByRole('button', { name: '분석 리포트 생성' }).click()

  await expect(page.getByRole('heading', { name: '매칭 분석 리포트' })).toBeVisible()
  await expect(page.getByText('종합 매칭 점수')).toBeVisible()
  await expect(page.getByText('76점')).toBeVisible()
})

test('JD 링크 불러오기 성공 후 매칭 결과까지 확인한다', async ({ page }) => {
  await mockFixtureFlow(page)
  await mockJdFetchSuccess(page)
  await page.goto('/')

  await page.getByRole('tab', { name: 'PDF' }).click()
  await page.locator('#resume-file').setInputFiles(fixturePdf)
  await page.getByRole('button', { name: 'AI 진단 시작하기' }).click()

  await expectJdStepReady(page)

  await page.getByRole('textbox', { name: 'JD 링크' }).fill(
    'https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=1',
  )
  await page.getByRole('button', { name: 'JD 미리보기' }).click()

  await expect(page.getByText('JD 본문을 불러왔습니다')).toBeVisible()
  await expect(page.getByRole('textbox', { name: '주요업무' })).toHaveValue(fetchedJdText)
  await expect(page.locator('.status-message[aria-live="polite"]')).toContainText(
    'JD 본문을 불러왔습니다',
  )

  await page
    .getByRole('textbox', { name: '주요업무' })
    .fill('수정한 JD 본문입니다. Spring Boot와 MySQL 운영 경험, 테스트 자동화 경험을 요구합니다.')

  await page.getByRole('button', { name: '분석 리포트 생성' }).click()

  await expect(page.getByRole('heading', { name: '매칭 분석 리포트' })).toBeVisible()
  await expect(page.getByText('종합 매칭 점수')).toBeVisible()
  await expect(page.getByText('76점')).toBeVisible()
})

test('JD 링크 실패 후 직접 입력으로 매칭 결과까지 복구한다', async ({ page }) => {
  await mockFixtureFlow(page)
  await mockJdFetchFailure(page)
  await page.goto('/')

  await page.getByRole('tab', { name: 'PDF' }).click()
  await page.locator('#resume-file').setInputFiles(fixturePdf)
  await page.getByRole('button', { name: 'AI 진단 시작하기' }).click()

  await expectJdStepReady(page)

  const jdTextarea = page.getByRole('textbox', { name: '주요업무' })
  await jdTextarea.fill(jdText)
  await page.getByRole('textbox', { name: 'JD 링크' }).fill(
    'https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=2',
  )
  await page.getByRole('button', { name: 'JD 미리보기' }).click()

  await expect(
    page.getByText('불러오지 못했습니다. JD 본문을 직접 붙여넣어 주세요.'),
  ).toBeVisible()
  await expect(page.getByRole('alert')).toContainText(
    '불러오지 못했습니다. JD 본문을 직접 붙여넣어 주세요.',
  )
  await expect(jdTextarea).toHaveValue(jdText)

  await page.getByRole('button', { name: '분석 리포트 생성' }).click()

  await expect(page.getByRole('heading', { name: '매칭 분석 리포트' })).toBeVisible()
  await expect(page.getByText('76점')).toBeVisible()
})

test('DOCX 업로드 후 JD 입력 단계로 이동한다', async ({ page }) => {
  await mockFixtureFlow(page)
  await page.goto('/')

  await page.getByRole('tab', { name: 'DOCX' }).click()
  await page.locator('#resume-file').setInputFiles(fixtureDocx)
  await page.getByRole('button', { name: 'AI 진단 시작하기' }).click()

  await expectJdStepReady(page)
})

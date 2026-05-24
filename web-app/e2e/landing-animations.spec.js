import { expect, test } from '@playwright/test'

test.describe('Landing page animations and layout', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/')
    await expect(page.getByTestId('hero-section')).toBeVisible({
      timeout: 30_000,
    })
  })

  test('hero renders animated headline and screenshot', async ({ page }) => {
    await expect(page.getByRole('heading', { level: 1 })).toContainText(
      'AI-assisted work',
    )
    await expect(page.getByTestId('hero-screenshot')).toBeVisible()
    await expect(
      page.getByRole('link', { name: /download for macos/i }).first(),
    ).toBeVisible()
    await expect(page.getByText(/mit licensed/i).first()).toBeVisible()
  })

  test('key animated sections are visible', async ({ page }) => {
    await expect(
      page.getByRole('heading', { name: 'Why local-first matters' }),
    ).toBeVisible()
    await expect(
      page.getByRole('heading', { name: 'Capabilities at a glance' }),
    ).toBeVisible()
    await expect(page.getByTestId('agent-showcase')).toBeVisible()
    await expect(page.getByTestId('workflow-section')).toBeVisible()
    await expect(page.getByRole('heading', { name: 'FAQ' })).toBeVisible()
  })

  test('product tour section anchors and scroll region exist', async ({
    page,
  }) => {
    const tour = page.locator('#tour')
    await tour.scrollIntoViewIfNeeded()
    await expect(tour).toBeVisible()
    await expect(
      page.getByRole('heading', { name: 'Product overview' }),
    ).toBeVisible()
    await expect(tour).toHaveAttribute('style', /vh/)
  })

  test('final CTA is centered and visible after scroll', async ({ page }) => {
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight))
    await expect(
      page.getByRole('heading', {
        name: 'Install DeepThink for macOS',
      }),
    ).toBeVisible()
    await expect(
      page.getByRole('link', { name: /download latest release/i }),
    ).toBeVisible()
  })

  test('respects reduced motion preference', async ({ page }) => {
    await page.emulateMedia({ reducedMotion: 'reduce' })
    await page.reload()
    await expect(page.getByTestId('hero-section')).toBeVisible()
    await expect(page.getByRole('heading', { level: 1 })).toContainText(
      'AI-assisted work',
    )
  })
})

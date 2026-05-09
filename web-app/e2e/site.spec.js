import { expect, test } from '@playwright/test'

test.describe('Marketing site', () => {
  test('home loads with open-source stats link', async ({ page }) => {
    await page.goto('/')
    await expect(page.getByRole('heading', { level: 1 })).toContainText(
      'grounded knowledge',
    )

    await expect(
      page.getByRole('heading', { name: 'Why local-first matters' }),
    ).toBeVisible()
    await expect(page.getByRole('heading', { name: 'FAQ' })).toBeVisible()
    await expect(
      page.getByRole('heading', { name: 'Core capabilities' }),
    ).toBeVisible()

    const footerNav = page.getByRole('navigation', { name: 'Footer links' })
    await expect(
      footerNav.getByRole('link', { name: 'Documentation' }),
    ).toBeVisible()
    await expect(footerNav.getByRole('link', { name: 'FAQ' })).toHaveAttribute(
      'href',
      '/#faq',
    )
    await expect(footerNav.getByRole('link', { name: 'Tour' })).toHaveAttribute(
      'href',
      '/#tour',
    )

    const repo = page
      .locator('a[href="https://github.com/aagam-headout/deepthink"]')
      .filter({ visible: true })
      .first()
    await expect(repo).toBeVisible()
    await expect(repo).toHaveAttribute('target', '_blank')
    await expect(repo).toHaveAttribute('rel', 'noopener noreferrer')

    const download = page
      .getByRole('link', { name: /download for macos/i })
      .first()
    await expect(download).toHaveAttribute(
      'href',
      /github\.com\/aagam-headout\/deepthink\/releases/,
    )
    await expect(download).toHaveAttribute('target', '_blank')

    await expect(page.getByText(/mit licensed/i).first()).toBeVisible()
  })

  test('client-side routes work (Vercel-style SPA)', async ({ page }) => {
    await page.goto('/documentation')
    await expect(page.getByPlaceholder('Search docs...')).toBeVisible({
      timeout: 30_000,
    })
  })

  test('architecture page loads diagram shell', async ({ page }) => {
    await page.goto('/architecture')
    await expect(page.getByRole('heading', { level: 1 })).toContainText(
      'fits together',
    )
    await expect(page.locator('.react-flow')).toBeVisible()
  })

  test('repository pill links include external-window affordance', async ({
    page,
  }) => {
    await page.goto('/architecture')
    const repoLink = page.getByRole('link', { name: /Repo & source/i })
    await expect(repoLink).toHaveAttribute('target', '_blank')
    await expect(repoLink).toHaveAttribute('rel', /noopener/)
  })
})

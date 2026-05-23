import { expect, test } from '@playwright/test'

async function gotoHomeStable(page) {
  await page.goto('/')
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible({
    timeout: 30_000,
  })
}

test.describe('Responsive layout', () => {
  test.describe.configure({ timeout: 90_000 })

  test('header matches viewport: nav, GitHub, Download, menu', async ({
    page,
  }, testInfo) => {
    const isMobile = testInfo.project.name === 'mobile'
    await gotoHomeStable(page)

    const header = page.locator('header').first()

    if (isMobile) {
      await expect(
        header.getByRole('button', { name: /open menu|close menu/i }),
      ).toBeVisible()
      await expect(
        header.getByRole('link', { name: /DeepThink on GitHub/i }),
      ).toBeHidden()
      await expect(
        header.getByRole('link', { name: /^Download$/ }),
      ).toBeHidden()
      await expect(
        header.getByRole('link', { name: 'Documentation' }).first(),
      ).toBeHidden()
    } else {
      await expect(
        header.getByRole('button', { name: /open menu|close menu/i }),
      ).toBeHidden()
      await expect(
        header.getByRole('link', { name: /DeepThink on GitHub/i }),
      ).toBeVisible()
      await expect(
        header.getByRole('link', { name: /^Download$/ }),
      ).toBeVisible()
      await expect(
        header.getByRole('link', { name: 'Documentation' }).first(),
      ).toBeVisible()
    }
  })

  test('mobile menu exposes GitHub and Download', async ({
    page,
  }, testInfo) => {
    test.skip(
      testInfo.project.name !== 'mobile',
      'Only relevant for mobile project',
    )

    await gotoHomeStable(page)
    const header = page.locator('header').first()
    await header
      .getByRole('button', { name: 'Open menu' })
      .click({ force: true })

    await expect(
      header
        .locator('a[href="https://github.com/getlost01/deepthink"]')
        .filter({ visible: true }),
    ).toHaveCount(1)
    await expect(
      header
        .getByRole('link', { name: /^Download$/ })
        .filter({ visible: true }),
    ).toHaveCount(1)
  })

  test('documentation page: search and article on all viewports', async ({
    page,
  }) => {
    await page.goto('/documentation')
    await expect(page.getByPlaceholder('Search docs...')).toBeVisible({
      timeout: 30_000,
    })
    await expect(page.locator('article').first()).toBeVisible()

    await page.getByPlaceholder('Search docs...').fill('docs/storage.md')
    await page.getByRole('button', { name: 'Storage' }).click()
    await expect(
      page.getByRole('heading', { level: 1, name: /Data Storage/i }),
    ).toBeVisible()
    await expect(
      page.getByRole('columnheader', { name: /^Column$/i }),
    ).toBeVisible()
    await expect(page.locator('article pre code').first()).toBeVisible()
    await expect(page.locator('article p code').first()).toBeVisible()
  })

  test('architecture page: diagram on all viewports', async ({ page }) => {
    await page.goto('/architecture')
    await expect(page.locator('.react-flow')).toBeVisible()
  })
})

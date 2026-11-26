import { describe, it, expect, afterAll, beforeAll } from 'vitest'
import puppeteer from 'puppeteer'
import { createServer } from 'http'
import { readFileSync } from 'fs'
import { resolve } from 'path'

const SPA_PATH = resolve(__dirname, '../../../tmp/diff_spa.html')

let server: ReturnType<typeof createServer>
let baseUrl: string

beforeAll(async () => {
  server = createServer((req, res) => {
    res.writeHead(200, { 'content-type': 'text/html' })
    res.end(readFileSync(SPA_PATH))
  })
  await new Promise<void>(done => server.listen(0, done))
  baseUrl = `http://127.0.0.1:${(server.address() as any).port}`
})

afterAll(async () => {
  server.close()
})

describe('diff view over a generated v1→v2 SPA', () => {
  it('groups changes by category with the summary chips', async () => {
    const browser = await puppeteer.launch({ headless: true })
    try {
      const page = await browser.newPage()
      await page.goto(`${baseUrl}/#/diff`, { waitUntil: 'networkidle0' })

      await page.waitForSelector('.diff-group', { timeout: 15000 })
      const titles = await page.$$eval('.diff-group-title', els =>
        els.map(e => e.textContent?.trim())
      )
      expect(titles).toContain('Added')
      expect(titles).toContain('Modified')
      expect(titles).toContain('Renamed')

      const chips = await page.$$eval('.diff-summary-chip', els =>
        els.map(e => e.textContent?.trim())
      )
      expect(chips.some(c => c?.startsWith('Added 2'))).toBe(true)
    } finally {
      await browser.close()
    }
  })

  it('renders modifications and click-through routes to detail', async () => {
    const browser = await puppeteer.launch({ headless: true })
    try {
      const page = await browser.newPage()
      await page.goto(`${baseUrl}/#/diff`, { waitUntil: 'networkidle0' })
      await page.waitForSelector('.change-row', { timeout: 15000 })

      const modText = await page.$$eval('.change-mods li', els =>
        els.map(e => e.textContent)
      )
      expect(modText.some(t => t?.includes('enumeration=medium'))).toBe(true)

      // the renamed row shows the old identity
      const renamed = await page.$$eval('.change-renamed', els =>
        els.map(e => e.textContent)
      )
      expect(renamed.some(t => t?.includes('OldNameType'))).toBe(true)

      // click-through on a present component opens the detail panel
      await page.click('.change-name:not(.static)')
      await page.waitForFunction(
        () => !!document.querySelector('.detail-panel'),
        { timeout: 10000 }
      )
    } finally {
      await browser.close()
    }
  })
})

import { describe, it, expect, afterAll, beforeAll } from 'vitest'
import puppeteer from 'puppeteer'
import { createServer } from 'http'
import { readFileSync } from 'fs'
import { resolve } from 'path'

const SPA_PATH = resolve(__dirname, '../../../tmp/metaschema_spa.html')

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

describe('graphs view over the generated metaschema SPA', () => {
  it('renders usage rows ranked by reference count and routes to type detail', async () => {
    const browser = await puppeteer.launch({ headless: true })
    try {
      const page = await browser.newPage()
      await page.goto(`${baseUrl}/#/graphs`, { waitUntil: 'networkidle0' })

      await page.waitForSelector('.usage-row', { timeout: 15000 })
      const rowCount = await page.$$eval('.usage-row', rows => rows.length)
      expect(rowCount).toBeGreaterThan(5)

      // ranked: first row count >= second row count
      const counts = await page.$$eval('.usage-count', els =>
        els.map(e => Number(e.textContent?.trim()))
      )
      expect(counts[0]).toBeGreaterThanOrEqual(counts[1])

      // expand the first row's used_by list
      await page.click('.usage-row .usage-toggle')
      await page.waitForSelector('.usage-ref', { timeout: 5000 })
      const refCount = await page.$$eval('.usage-ref', els => els.length)
      expect(refCount).toBe(counts[0])

      // click-through routes to the type detail panel
      await page.click('.usage-ref')
      await page.waitForFunction(
        () => !!document.querySelector('.detail-panel.open, .detail-panel:not([style*="none"])'),
        { timeout: 10000 }
      )
    } finally {
      await browser.close()
    }
  })

  it('renders derivation chains', async () => {
    const browser = await puppeteer.launch({ headless: true })
    try {
      const page = await browser.newPage()
      await page.goto(`${baseUrl}/#/graphs`, { waitUntil: 'networkidle0' })
      await page.waitForSelector('.usage-row', { timeout: 15000 })

      await page.click('.graphs-tabs .tab-btn:nth-child(2)')
      await page.waitForSelector('.chain-row', { timeout: 5000 })
      const hopCount = await page.$$eval('.chain-hop', els => els.length)
      expect(hopCount).toBeGreaterThan(0)
      const multiHop = await page.$$eval('.chain-steps', els =>
        els.some(el => el.textContent?.includes('→'))
      )
      expect(multiHop).toBe(true)
    } finally {
      await browser.close()
    }
  })
})

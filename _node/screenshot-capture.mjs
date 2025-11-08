#!/usr/bin/env node

import { chromium } from '@playwright/test';
import { promises as fs } from 'fs';
import path from 'path';

const DEFAULT_PORT = 8080;
const DEFAULT_TIMEOUT = 30000;
const VIEWPORT = { width: 1920, height: 1080 };

async function captureScreenshot(browser, site, port, outputDir) {
  const url = `http://${site.subdomain}.binaryage.org:${port}`;
  const context = await browser.newContext({ viewport: VIEWPORT });
  const page = await context.newPage();

  try {
    await page.goto(url, {
      timeout: DEFAULT_TIMEOUT,
      waitUntil: 'networkidle'
    });

    // Disable animations for consistency
    await page.addStyleTag({
      content: '*, *::before, *::after { animation: none !important; transition: none !important; }'
    });

    // Small delay to let any remaining JS settle
    await page.waitForTimeout(500);

    // Take full-page screenshot
    const filename = `${site.subdomain}.png`;
    const filepath = path.join(outputDir, filename);

    await page.screenshot({
      path: filepath,
      fullPage: true,
      type: 'png',
      animations: 'disabled',
      caret: 'hide'
    });

    return {
      site: site.name,
      subdomain: site.subdomain,
      success: true,
      path: filepath
    };
  } catch (error) {
    return {
      site: site.name,
      subdomain: site.subdomain,
      success: false,
      error: error.message
    };
  } finally {
    await context.close();
  }
}

async function captureAll(sites, port, outputDir) {
  console.log(`Capturing screenshots for ${sites.length} site(s)...\n`);

  // Ensure output directory exists
  await fs.mkdir(outputDir, { recursive: true });

  const browser = await chromium.launch({ headless: true });
  const results = [];

  for (const site of sites) {
    process.stdout.write(`  Capturing ${site.name.padEnd(20)} `);
    const result = await captureScreenshot(browser, site, port, outputDir);
    results.push(result);

    if (result.success) {
      console.log('✅');
    } else {
      console.log(`❌ ${result.error}`);
    }
  }

  await browser.close();

  const succeeded = results.filter(r => r.success).length;
  const failed = results.filter(r => !r.success).length;

  console.log(`\nResults: ${succeeded} captured, ${failed} failed`);

  // Write results JSON for rake task
  const resultsPath = path.join(outputDir, '.capture-results.json');
  await fs.writeFile(resultsPath, JSON.stringify(results, null, 2));

  return { results, succeeded, failed };
}

async function main() {
  const args = process.argv.slice(2);

  if (args.length < 2) {
    console.error('Usage: node screenshot-capture.mjs <sites-json> <output-dir> [port]');
    process.exit(1);
  }

  const sites = JSON.parse(args[0]);
  const outputDir = args[1];
  const port = args[2] ? parseInt(args[2]) : DEFAULT_PORT;

  const { failed } = await captureAll(sites, port, outputDir);
  process.exit(failed > 0 ? 1 : 0);
}

main().catch(error => {
  console.error(`Fatal error: ${error.message}`);
  process.exit(1);
});

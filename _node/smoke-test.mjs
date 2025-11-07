#!/usr/bin/env node

import { chromium } from '@playwright/test';

const DEFAULT_PORT = 8080;
const DEFAULT_TIMEOUT = 10000;

async function testSite(browser, site, port) {
  const url = `http://${site.subdomain}.binaryage.org:${port}`;
  const context = await browser.newContext();
  const page = await context.newPage();

  const errors = [];
  const warnings = [];

  const result = {
    site: site.name,
    subdomain: site.subdomain,
    url: url,
    passed: false,
    status: null,
    error: null,
    consoleErrors: [],
    consoleWarnings: []
  };

  try {
    page.on('console', msg => {
      const text = msg.text();
      // Filter out non-critical console messages
      const isPermissionsPolicyWarning = text.includes('Potential permissions policy violation');
      const isResourceLoadFailure = text.includes('Failed to load resource');

      if (msg.type() === 'error' && !isPermissionsPolicyWarning && !isResourceLoadFailure) {
        errors.push(text);
      } else if (msg.type() === 'warning' && !isPermissionsPolicyWarning) {
        warnings.push(text);
      }
    });

    page.on('pageerror', error => {
      errors.push(`Uncaught exception: ${error.message}`);
    });

    const response = await page.goto(url, {
      timeout: DEFAULT_TIMEOUT,
      waitUntil: 'domcontentloaded'
    });

    // Accept redirects (3xx) as valid
    result.status = response.status();

    if (result.status >= 400) {
      result.error = `HTTP ${result.status}`;
    }

    // Wait a bit for any dynamic content
    await page.waitForTimeout(1000);

    // Try to get the title, but handle navigation errors gracefully
    try {
      const title = await page.title();
      if (!title || title.trim() === '') {
        result.error = result.error ? `${result.error}, Empty title` : 'Empty title';
      }
    } catch (titleError) {
      // If title fails due to navigation (like redirects), that's okay
      if (!titleError.message.includes('Execution context was destroyed')) {
        throw titleError;
      }
    }

    result.consoleErrors = errors;
    result.consoleWarnings = warnings;

    if (result.status < 400 && errors.length === 0) {
      result.passed = true;
    }

  } catch (error) {
    result.error = error.message;
  } finally {
    await context.close();
  }

  return result;
}

async function runSmokeTests(sites, port = DEFAULT_PORT) {
  console.log(`Starting smoke tests for ${sites.length} site(s) on port ${port}...\n`);

  const browser = await chromium.launch({ headless: true });
  const results = [];

  for (const site of sites) {
    process.stdout.write(`Testing ${site.name.padEnd(20)} `);
    const result = await testSite(browser, site, port);
    results.push(result);

    if (result.passed) {
      console.log('✅ PASS');
    } else {
      console.log('❌ FAIL');
      if (result.error) {
        console.log(`  Error: ${result.error}`);
      }
      if (result.consoleErrors.length > 0) {
        console.log(`  Console errors (${result.consoleErrors.length}):`);
        result.consoleErrors.forEach(err => console.log(`    - ${err}`));
      }
    }
  }

  await browser.close();

  console.log('\n' + '='.repeat(60));
  const passed = results.filter(r => r.passed).length;
  const failed = results.filter(r => !r.passed).length;

  console.log(`Results: ${passed} passed, ${failed} failed (${sites.length} total)`);
  console.log('='.repeat(60) + '\n');

  if (failed > 0) {
    console.log('Failed sites:');
    results.filter(r => !r.passed).forEach(r => {
      console.log(`  - ${r.site}: ${r.error || 'Unknown error'}`);
    });
    console.log('');
  }

  return { results, passed, failed, total: sites.length };
}

async function main() {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    console.error('Error: No sites provided');
    console.error('Usage: node smoke-test.mjs <sites-json> [port]');
    console.error('Example: node smoke-test.mjs \'[{"name":"www","subdomain":"www"}]\' 8080');
    process.exit(1);
  }

  let sites;
  try {
    sites = JSON.parse(args[0]);
  } catch (error) {
    console.error(`Error parsing sites JSON: ${error.message}`);
    process.exit(1);
  }

  const port = args[1] ? parseInt(args[1]) : DEFAULT_PORT;

  if (!Array.isArray(sites) || sites.length === 0) {
    console.error('Error: Sites must be a non-empty array');
    process.exit(1);
  }

  const { passed, failed } = await runSmokeTests(sites, port);

  process.exit(failed > 0 ? 1 : 0);
}

main().catch(error => {
  console.error(`Fatal error: ${error.message}`);
  process.exit(1);
});

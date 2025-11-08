#!/usr/bin/env node

import { compare } from 'odiff-bin';
import { promises as fs } from 'fs';
import path from 'path';

async function compareSite(site, baselineDir, currentDir, diffDir) {
  const baselinePath = path.join(baselineDir, `${site.subdomain}.png`);
  const currentPath = path.join(currentDir, `${site.subdomain}.png`);
  const diffPath = path.join(diffDir, `${site.subdomain}-diff.png`);

  try {
    // Check if files exist
    await fs.access(baselinePath);
    await fs.access(currentPath);

    const result = await compare(
      baselinePath,
      currentPath,
      diffPath,
      {
        threshold: 0.1,
        diffPixel: [255, 0, 255], // Magenta highlighting
        antialiasing: true
      }
    );

    // Copy baseline and current images to diff directory for HTML report
    const baselineCopyPath = path.join(diffDir, `${site.subdomain}-baseline.png`);
    const currentCopyPath = path.join(diffDir, `${site.subdomain}-current.png`);
    await fs.copyFile(baselinePath, baselineCopyPath);
    await fs.copyFile(currentPath, currentCopyPath);

    return {
      site: site.name,
      subdomain: site.subdomain,
      matched: result.match,
      diffCount: result.match ? 0 : (result.diffCount || 0),
      diffPercentage: result.match ? 0 : (result.diffPercentage || 0),
      baselinePath: baselineCopyPath,
      currentPath: currentCopyPath,
      diffPath: result.match ? null : diffPath
    };
  } catch (error) {
    return {
      site: site.name,
      subdomain: site.subdomain,
      error: error.message
    };
  }
}

async function compareAll(sites, baselineDir, currentDir, diffDir) {
  console.log(`Comparing screenshots for ${sites.length} site(s)...\n`);

  await fs.mkdir(diffDir, { recursive: true });

  const results = [];

  for (const site of sites) {
    process.stdout.write(`  Comparing ${site.name.padEnd(20)} `);
    const result = await compareSite(site, baselineDir, currentDir, diffDir);
    results.push(result);

    if (result.error) {
      console.log(`❌ ${result.error}`);
    } else if (result.matched) {
      console.log('✓ unchanged');
    } else {
      const diffCount = result.diffCount.toLocaleString();
      console.log(`● CHANGED (${diffCount} pixels)`);
    }
  }

  const unchanged = results.filter(r => !r.error && r.matched).length;
  const changed = results.filter(r => !r.error && !r.matched).length;
  const errors = results.filter(r => r.error).length;

  console.log(`\nResults: ${unchanged} unchanged, ${changed} changed, ${errors} errors`);

  // Write results JSON for HTML report generation
  const resultsPath = path.join(diffDir, 'results.json');
  await fs.writeFile(resultsPath, JSON.stringify(results, null, 2));

  return { results, unchanged, changed, errors };
}

async function main() {
  const args = process.argv.slice(2);

  if (args.length < 4) {
    console.error('Usage: node screenshot-diff.mjs <sites-json> <baseline-dir> <current-dir> <diff-dir>');
    process.exit(1);
  }

  const sites = JSON.parse(args[0]);
  const baselineDir = args[1];
  const currentDir = args[2];
  const diffDir = args[3];

  const { changed, errors } = await compareAll(sites, baselineDir, currentDir, diffDir);

  process.exit(changed > 0 || errors > 0 ? 1 : 0);
}

main().catch(error => {
  console.error(`Fatal error: ${error.message}`);
  process.exit(1);
});

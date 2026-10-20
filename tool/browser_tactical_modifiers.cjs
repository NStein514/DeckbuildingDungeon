// Run against a release build with fixtures from smoke_checkpoints.dart.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROME_EXECUTABLE || '/usr/bin/chromium', headless: true, args: ['--no-sandbox', '--enable-unsafe-swiftshader'] });
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  const fixtures = JSON.parse(fs.readFileSync(process.env.CHECKPOINTS, 'utf8'));
  const output = path.join(require('node:os').tmpdir(), 'deckbound-modifiers');
  fs.mkdirSync(output, { recursive: true });
  await page.goto(process.env.BASE_URL || 'http://127.0.0.1:8080');
  async function resume() {
    await page.reload();
    await page.locator('flt-semantics-placeholder').waitFor({ state: 'attached' });
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await page.getByRole('button', { name: 'Continue run', exact: true }).click();
  }
  for (const modifier of ['rallying', 'mending']) {
    await page.evaluate(data => localStorage.setItem('deckbound.run.v1', JSON.stringify(data)), fixtures[modifier]);
    await resume();
    await page.getByText('The path is revealed', { exact: true }).waitFor();
    await page.getByText('Dungeon Rat · battle plan', { exact: true }).click();
    const plan = await page.locator('body').ariaSnapshot();
    assert(plan.includes(modifier === 'rallying' ? '1 strength on itself' : 'heal itself by 3'));
    await page.screenshot({ path: path.join(output, modifier + '-reveal.png') });
    await page.getByRole('button', { name: 'Enter encounter', exact: true }).click();
    await page.getByText('TURN 1', { exact: true }).waitFor();
    await page.getByRole('button', { name: /^Strike\. Cost/ }).click();
    await page.getByRole('button', { name: /^Dungeon Rat\./ }).click();
    await page.getByRole('button', { name: 'End turn', exact: true }).click();
    await page.getByText('TURN 2', { exact: true }).waitFor();
    await page.waitForTimeout(550);
    const battle = await page.locator('body').ariaSnapshot();
    assert(battle.includes(modifier === 'rallying' ? '6 damage' : 'Dungeon Rat. 19 health'));
    await page.screenshot({ path: path.join(output, modifier + '-battle.png') });
    await resume();
    await page.getByRole('button', { name: 'Resume encounter', exact: true }).click();
    await page.getByText('TURN 1', { exact: true }).waitFor();
    const reset = await page.locator('body').ariaSnapshot();
    assert(reset.includes('Dungeon Rat. 22 health'));
    assert(reset.includes(modifier === 'rallying' ? '5 damage' : 'heal itself by 3'));
    console.log('PASS: ' + modifier + ' reveal, plan, combat effect and entry-checkpoint reload.');
  }
  assert.deepEqual(errors, []);
  await browser.close();
})().catch(e => { console.error(e); process.exit(1); });

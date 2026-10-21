const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
(async () => {
  const browser = await chromium.launch({executablePath: process.env.CHROME_EXECUTABLE || '/usr/bin/chromium', headless:true, args:['--no-sandbox','--enable-unsafe-swiftshader']});
  const page = await browser.newPage({viewport:{width:390,height:844}});
  const errors=[]; page.on('pageerror', e => errors.push(e.message));
  const fixtures = JSON.parse(fs.readFileSync(process.env.CHECKPOINTS,'utf8'));
  const output = '/tmp/deckbound-defensive-fusions'; fs.mkdirSync(output,{recursive:true});
  await page.goto(process.env.BASE_URL || 'http://127.0.0.1:8080');
  async function restore(data) {
    await page.evaluate(data => localStorage.setItem('deckbound.run.v1',JSON.stringify(data)),data);
    await page.reload();
    await page.locator('flt-semantics-placeholder').waitFor({state:'attached'});
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await page.getByRole('button',{name:'Continue run',exact:true}).click();
  }
  for (const [name,id] of [['Venom Ward','venom_ward'],['Bloomguard','bloomguard']]) {
    const shrine=structuredClone(fixtures.shrine);
    if(id==='venom_ward') shrine.run.deck[0].definitionId='poison_edge';
    await restore(shrine);
    await page.getByRole('checkbox',{name,exact:true}).click();
    await page.getByRole('button',{name:'Fuse cards',exact:true}).click();
    await page.waitForTimeout(350);
    await page.screenshot({path:path.join(output,id+'-preview.png')});
    await page.getByRole('button',{name:'Cancel',exact:true}).click();
    assert.equal((await page.evaluate(() => JSON.parse(localStorage.getItem('deckbound.run.v1')))).run.deck.length,12);
    await page.getByRole('button',{name:'Fuse cards',exact:true}).click();
    await page.getByRole('button',{name:'Confirm fusion',exact:true}).click();
    await page.getByText('Choose your path',{exact:true}).waitFor();
    const fused=await page.evaluate(() => JSON.parse(localStorage.getItem('deckbound.run.v1')));
    assert.equal(fused.run.deck.length,11); assert.equal(fused.run.deck.at(-1).definitionId,id);
    assert(fused.run.discovered.includes(id));
    const combat=structuredClone(fixtures.effects); combat.run.deck[0].definitionId=id;
    await restore(combat);
    await page.getByRole('button',{name:'Resume encounter',exact:true}).click();
    await page.getByText('TURN 1',{exact:true}).waitFor();
    await page.getByRole('button',{name:new RegExp('^'+name+'\\. Cost')}).click();
    if(id==='venom_ward') await page.getByRole('button',{name:/^Dungeon Rat\./}).click();
    else await page.getByRole('button',{name:'Play card',exact:true}).click();
    await page.waitForTimeout(550);
    const played=await page.locator('body').ariaSnapshot();
    assert(played.includes(id==='venom_ward'?'poison 3':'39 / 50 HP'));
    await page.screenshot({path:path.join(output,id+'-combat.png')});
    await page.getByRole('button',{name:'End turn',exact:true}).click();
    await page.getByText('TURN 2',{exact:true}).waitFor();
    const turn=await page.locator('body').ariaSnapshot();
    assert(turn.includes(id==='venom_ward'?'Dungeon Rat. 19 health':'YOUR HAND · 0 / 10'));
    console.log('PASS: '+name+' preview, cancellation, fusion persistence and combat behavior.');
  }
  assert.deepEqual(errors,[]); await browser.close();
})().catch(e => {console.error(e);process.exit(1)});

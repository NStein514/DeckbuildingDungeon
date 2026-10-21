const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROME_EXECUTABLE||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--enable-unsafe-swiftshader']});
 const page=await browser.newPage({viewport:{width:390,height:844}});
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 const output='/tmp/deckbound-specialist-builds';fs.mkdirSync(output,{recursive:true});
 const standard=JSON.parse(fs.readFileSync('assets/data/balance.json','utf8')).startingDeck;
 async function camp(){
  await page.reload();await page.locator('flt-semantics-placeholder').waitFor({state:'attached'});
  await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());
 }
 await page.goto(process.env.BASE_URL||'http://127.0.0.1:8080');
 for(const [name,unlock,swaps] of [['Gravewarden','bloomguard',[[5,'brace'],[8,'enfeeble']]],['Embercaller','flaming_strike',[[6,'cinder_storm'],[9,'firebolt']]]]){
  await page.evaluate(()=>localStorage.clear());await camp();
  await page.getByText('Starting build · Wanderer',{exact:true}).click();
  await page.getByRole('button',{name:'Inspect '+name+' deck',exact:true}).click();
  await page.getByText('Your deck · 12',{exact:true}).waitFor();
  await page.waitForTimeout(1500);
  await page.screenshot({path:output+'/'+name+'-locked-preview.png'});
  await page.getByRole('button',{name:'Back',exact:true}).click();
  assert((await page.locator('body').ariaSnapshot()).includes('Locked'));
  const profile={version:1,contentVersion:2,profile:{deepestFloor:0,bestRooms:0,bestBosses:0,cards:[unlock],relics:[]}};
  await page.evaluate(p=>localStorage.setItem('deckbound.profile.v1',JSON.stringify(p)),profile);
  await camp();
  await page.getByText('Starting build · Wanderer',{exact:true}).click();
  await page.getByRole('button',{name:new RegExp('^'+name+' Trade')}).click();
  await page.screenshot({path:output+'/'+name+'-selected.png'});
  await page.getByRole('textbox').fill('514');
  await page.getByRole('button',{name:'New run',exact:true}).click();
  await page.getByText('Choose your path',{exact:true}).waitFor();
  const run=await page.evaluate(()=>JSON.parse(localStorage.getItem('deckbound.run.v1')));
  const expected=[...standard];for(const [i,id] of swaps)expected[i]=id;
  assert.deepEqual(run.run.deck.map(c=>c.definitionId),expected);
  assert.equal(run.run.health,50);assert.equal(run.run.gold,0);
  assert(run.run.deck.every(c=>c.upgrade===0));
  await camp();await page.getByRole('button',{name:'Continue run',exact:true}).click();
  await page.getByText('Choose your path',{exact:true}).waitFor();
  assert.deepEqual(await page.evaluate(()=>JSON.parse(localStorage.getItem('deckbound.run.v1'))),run);
  console.log('PASS: '+name+' locked inspection, legacy journal unlock, selection, exact starter and continuation.');
 }
 assert.deepEqual(errors,[]);await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});

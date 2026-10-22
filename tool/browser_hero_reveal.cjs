const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
(async()=>{
 const browser=await chromium.launch({executablePath:'/usr/bin/chromium',args:['--no-sandbox','--enable-unsafe-swiftshader']});
 const page=await browser.newPage({viewport:{width:390,height:844}}), errors=[];
 page.on('pageerror',e=>errors.push(e.message));
 page.on('response',r=>{if(r.status()>=400&&r.url().includes('/assets/'))errors.push(r.url());});
 const base=process.env.BASE_URL||'http://127.0.0.1:8107';
 const out='/tmp/deckbound-hero-reveal';fs.mkdirSync(out,{recursive:true});
 async function enable(){await page.locator('flt-semantics-placeholder').waitFor({state:'attached'});await page.evaluate(()=>document.querySelector('flt-semantics-placeholder').click());}
 async function capture(n){await page.screenshot({path:out+'/'+n+'.png'});}
 await page.goto(base);await enable();
 await page.getByRole('textbox').fill('514');
 await page.getByRole('button',{name:'New run',exact:true}).click();
 await page.getByRole('button',{name:'Unexplored path 1 · floor 1',exact:true}).waitFor();
 await page.waitForTimeout(400);await capture('map');
 await page.getByRole('button',{name:'Unexplored path 1 · floor 1',exact:true}).click();
 await page.waitForTimeout(150);await capture('flip');
 await page.waitForTimeout(350);await capture('grow');
 await page.waitForTimeout(900);await capture('revealed');
 const saved=await page.evaluate(()=>JSON.parse(localStorage.getItem('deckbound.run.v1')));
 assert.equal(saved.run.phase,'reveal');assert.equal(saved.run.startingBuild,'wanderer');
 await page.reload();await enable();
 await page.getByRole('button',{name:'Continue run',exact:true}).click();
 await page.getByText('The path is revealed',{exact:true}).waitFor();
 assert.deepEqual(await page.evaluate(()=>JSON.parse(localStorage.getItem('deckbound.run.v1'))),saved);
 const fixture=JSON.parse(fs.readFileSync(process.env.CHECKPOINTS,'utf8')).guardian;
 for(const name of ['wanderer','stormweaver','venomblade','gravewarden','embercaller']){
  const run=structuredClone(fixture);run.run.startingBuild=name;
  await page.evaluate(p=>localStorage.setItem('deckbound.run.v1',JSON.stringify(p)),run);
  await page.reload();await enable();
  await page.getByRole('button',{name:'Continue run',exact:true}).click();
  await page.mouse.move(195,450);await page.mouse.wheel(0,600);
  await page.getByRole('button',{name:'Enter encounter',exact:true}).click();
  await page.getByText('TURN 1',{exact:true}).waitFor();await page.waitForTimeout(900);
  await page.getByRole('img',{name:name[0].toUpperCase()+name.slice(1)+' hero',exact:true}).waitFor();
  const endTurn = page.getByRole('button',{name:'End turn',exact:true});
  const before = await endTurn.boundingBox();
  assert(before && before.y >= 0 && before.y + before.height <= 844, 'Turn controls must fit on the phone');
  await capture(name);
  await page.mouse.move(195,600);await page.mouse.wheel(0,500);await page.waitForTimeout(350);
  const after = await endTurn.boundingBox();
  assert(Math.abs(before.y - after.y) < 1, 'Turn controls must stay fixed while scrolling');
  if(name === 'wanderer') await capture('hand-controls');

  assert.equal((await page.evaluate(()=>JSON.parse(localStorage.getItem('deckbound.run.v1')))).run.startingBuild,name);
 }
 await page.setViewportSize({width:1280,height:900});await page.waitForTimeout(700);await capture('boss-desktop');
 assert.deepEqual(errors,[]);
 console.log('PASS: map/reveal flight, saved reveal reload, all five hero identities and boss portraits render without browser or asset errors.');
 await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});

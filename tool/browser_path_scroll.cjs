const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROME_EXECUTABLE||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--enable-unsafe-swiftshader']});
 const page=await browser.newPage({viewport:{width:390,height:844}});
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 const output='/tmp/deckbound-path-scroll';fs.mkdirSync(output,{recursive:true});
 async function enable(){
  await page.locator('flt-semantics-placeholder').waitFor({state:'attached'});
  await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());
 }
 async function inView(label){
  const card=page.getByText(label,{exact:true});
  await card.waitFor();
  const box=await card.boundingBox();
  assert(box && box.y>=56 && box.y+box.height<=844,`${label} should be fully visible: ${JSON.stringify(box)}`);
 }
 await page.goto(process.env.BASE_URL||'http://127.0.0.1:8080');await enable();
 await page.getByRole('textbox').fill('514');
 await page.getByRole('button',{name:'New run',exact:true}).click();
 await page.getByText('Choose your path',{exact:true}).waitFor();
 await page.waitForTimeout(400);
 await inView('Unexplored path 1 · floor 1');
 await page.screenshot({path:output+'/entrance.png'});
 // Scroll upward through the map to verify the guardian lies above the entrance.
 await page.mouse.move(190,400);await page.mouse.wheel(0,-2500);await page.waitForTimeout(500);
 await page.screenshot({path:output+'/boss.png'});
 await inView('Unexplored path 1 · floor 6');
 // Load a valid pending sanctuary; resolving it must focus its next floor.
 const fixture=JSON.parse(fs.readFileSync(process.env.CHECKPOINTS,'utf8')).sanctuary;
 await page.evaluate(p=>localStorage.setItem('deckbound.run.v1',JSON.stringify(p)),fixture);
 await page.reload();await enable();
 await page.getByRole('button',{name:'Continue run',exact:true}).click();
 await page.getByRole('button',{name:'Rest · heal up to 15 HP',exact:true}).click();
 await page.getByText('Choose your path',{exact:true}).waitFor();
 await page.waitForTimeout(500);
 const result=await page.evaluate(()=>JSON.parse(localStorage.getItem('deckbound.run.v1')).run);
 const next=result.rooms.find(r=>r.depth===result.completed.length);
 const label=`Unexplored path ${next.lane+1} · floor ${next.depth+1}`;
 await inView(label);
 await page.screenshot({path:output+'/next-floor.png'});
 await page.reload();await enable();
 await page.getByRole('button',{name:'Continue run',exact:true}).click();
 await page.getByText('Choose your path',{exact:true}).waitFor();
 await page.waitForTimeout(400);await inView(label);
 assert.deepEqual(errors,[]);
 console.log('PASS: entrance starts visible, boss above, completed sanctuary focuses next floor, reload restores active choices.');
 await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});

const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
(async()=>{
 const browser=await chromium.launch({executablePath:'/usr/bin/chromium',args:['--no-sandbox','--enable-unsafe-swiftshader']});
 const page=await browser.newPage(), errors=[];
 page.on('pageerror',e=>errors.push(e.message));
 page.on('response',r=>{if(r.status()>=400&&r.url().includes('/assets/'))errors.push(r.url());});
 const out='/tmp/deckbound-battlefield';fs.mkdirSync(out,{recursive:true});
 for(const width of [1280,820,390,360,320]){
  await page.setViewportSize({width,height:900});
  for(const enemies of [['Dungeon Warden'],['Dungeon Rat','Skeleton Soldier']]){
   await page.goto(process.env.BASE_URL||'http://127.0.0.1:8110');
   await page.locator('flt-semantics-placeholder').waitFor({state:'attached'});
   await page.evaluate(()=>document.querySelector('flt-semantics-placeholder').click());
   await page.mouse.move(width/2,450);await page.mouse.wheel(0,600);
   await page.getByRole('checkbox',{name:enemies.length===2?'Crypt ambush · 2 enemies':enemies[0],exact:true}).click();
   await page.getByRole('button',{name:'Enter the crypt',exact:true}).click();
   await page.getByText('TURN 1',{exact:true}).waitFor();await page.waitForTimeout(1400);
   const end=page.getByRole('button',{name:'End turn',exact:true});
   const bounds=await end.boundingBox();assert(bounds.y+bounds.height<=900);
   await page.screenshot({path:`${out}/${width}-${enemies.length}-enemies.png`});
   await end.click();await page.getByText('TURN 2',{exact:true}).waitFor();
  }
 }
 assert.deepEqual(errors,[]);await browser.close();
 console.log('PASS: single boss and double enemy layouts at desktop and phone sizes; turn controls remain visible and advance combat.');
})().catch(e=>{console.error(e);process.exit(1)});

const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROME_EXECUTABLE||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--enable-unsafe-swiftshader']});
 const page=await browser.newPage({viewport:{width:390,height:844}}), errors=[];
 page.on('pageerror',e=>errors.push(e.message));
 page.on('response',r=>{if(r.status()>=400&&r.url().includes('/assets/'))errors.push(r.status()+': '+r.url());});
 const output='/tmp/deckbound-starter-art';fs.mkdirSync(output,{recursive:true});
 const base=process.env.BASE_URL||'http://127.0.0.1:8080';
 async function camp(){
  await page.goto(base);await page.locator('flt-semantics-placeholder').waitFor({state:'attached'});
  await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());
 }
 async function capture(name){await page.waitForTimeout(1500);await page.screenshot({path:output+'/'+name+'.png'});}
 await camp();
 await page.getByText('Starting build · Wanderer',{exact:true}).click();
 await page.getByRole('button',{name:'Inspect Wanderer deck',exact:true}).click();
 await capture('starter-cards-top');
 await page.mouse.move(195,420);await page.mouse.wheel(0,400);await capture('starter-cards-middle');
 await page.mouse.wheel(0,350);await capture('starter-cards-bottom');
 for(const [id,name] of [['rat','Dungeon Rat'],['skeleton','Skeleton Soldier'],['mage','Cursed Mage'],['warden','Dungeon Warden']]){
  await camp();
  await page.mouse.move(195,450);await page.mouse.wheel(0,500);
  await page.getByRole('checkbox',{name,exact:true}).click();
  await page.getByRole('button',{name:'Enter the crypt',exact:true}).click();
  await page.getByText('TURN 1',{exact:true}).waitFor();
  await capture(id);
  await page.getByRole('button',{name:'End turn',exact:true}).click();
  await page.getByText('TURN 2',{exact:true}).waitFor();
 }
 await page.setViewportSize({width:1280,height:900});
 await capture('warden-desktop');
 // Fetch and decode every new asset independently of lazy list visibility.
 const paths=[...['guard','quick_slash','heavy_blow','mend','firebolt','frost_ward','spark','preparation'].map(n=>'cards/'+n),...['rat','skeleton','mage','warden'].map(n=>'enemies/'+n)];
 for(const path of paths){
  const size=await page.evaluate(async url=>{const r=await fetch(url);if(!r.ok)throw new Error(url);const bitmap=await createImageBitmap(await r.blob());const size=[bitmap.width,bitmap.height];bitmap.close();return size;},base+'/assets/assets/images/'+path+'.png');
  assert(size[0]>=512&&size[1]>=512);
 }
 assert.deepEqual(errors,[]);
 console.log('PASS: all 12 new illustrations decode; starter collection and all four enemy battles render and advance without page errors.');
 await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});

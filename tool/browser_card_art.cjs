const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
(async()=>{
 const browser=await chromium.launch({executablePath:'/usr/bin/chromium',args:['--no-sandbox','--enable-unsafe-swiftshader']});
 const page=await browser.newPage(), errors=[];
 page.on('pageerror',e=>errors.push(e.message));
 page.on('response',r=>{if(r.status()>=400&&r.url().includes('/assets/'))errors.push(r.url());});
 const cards=JSON.parse(fs.readFileSync('assets/data/cards.json','utf8'));
 const base=process.env.BASE_URL||'http://127.0.0.1:8121';
 const out='/tmp/deckbound-card-art';fs.mkdirSync(out,{recursive:true});
 for(const width of [390,1280]){
  await page.setViewportSize({width,height:900});
  await page.goto(base);await page.locator('flt-semantics-placeholder').waitFor({state:'attached'});
  await page.evaluate(()=>document.querySelector('flt-semantics-placeholder').click());
  await page.getByRole('button',{name:'Collection',exact:true}).click();
  await page.getByText('The card archive',{exact:true}).waitFor();
  const seen=new Set();
  for(let i=0;i<(width===390?Math.ceil(cards.length/3)+1:Math.ceil(cards.length/10)+1);i++){
   await page.waitForTimeout(650);
   const snapshot=await page.locator('body').ariaSnapshot();
   for(const card of cards) if(snapshot.includes(card.name+'. Cost'))seen.add(card.id);
   await page.screenshot({path:`${out}/${width}-${i}.png`});
   await page.mouse.move(width/2,500);await page.mouse.wheel(0,600);
  }
  assert.equal(seen.size,cards.length,'Every card must render while browsing the archive');
 }
 for(const card of cards){
  const size=await page.evaluate(async url=>{
   const response=await fetch(url);if(!response.ok)throw new Error(url);
   const bitmap=await createImageBitmap(await response.blob());
   const size=[bitmap.width,bitmap.height];bitmap.close();return size;
  },`${base}/assets/assets/images/cards/${card.id}.png`);
  assert.deepEqual(size,[1536,1024],card.id);
 }
 assert.deepEqual(errors,[]);await browser.close();
 console.log('PASS: all '+cards.length+' card illustrations decode at 1536x1024; full phone and desktop archive browsing has no page or asset errors.');
})().catch(e=>{console.error(e);process.exit(1)});

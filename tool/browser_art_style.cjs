const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROME_EXECUTABLE||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--enable-unsafe-swiftshader']});
 const page=await browser.newPage({viewport:{width:390,height:844}}), errors=[];
 page.on('pageerror',e=>errors.push(e.message));
 page.on('response',r=>{if(r.status()>=400&&r.url().includes('/assets/'))errors.push(r.status()+': '+r.url());});
 const output='/tmp/deckbound-art-style';fs.mkdirSync(output,{recursive:true});
 await page.goto(process.env.BASE_URL||'http://127.0.0.1:8080');
 await page.locator('flt-semantics-placeholder').waitFor({state:'attached'});
 await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());
 async function capture(name){await page.waitForTimeout(900);await page.screenshot({path:output+'/'+name+'.png'});}
 await page.waitForTimeout(2000);await capture('camp');
 await page.getByRole('button',{name:'Collection',exact:true}).click();
 await capture('archive');
 await page.getByRole('button',{name:'Back',exact:true}).click();
 await page.getByRole('textbox').fill('5');
 await page.getByRole('button',{name:'New run',exact:true}).click();
 await page.getByText('Choose your path',{exact:true}).waitFor();
 await capture('entrance');
 for(const name of ['The sunken cistern','The sealed archive','The ember forge','The rooted vault','The guardian hall']){
  for(let i=0;i<15;i++){
   const box=await page.getByText(name,{exact:true}).boundingBox();
   if(box && box.y>=70 && box.y<260)break;
   await page.mouse.move(190,420);await page.mouse.wheel(0,box && box.y>260?250:-250);await page.waitForTimeout(250);
  }
  await capture(name.replaceAll(' ','-'));
 }
 await page.getByRole('button',{name:'Inspect deck',exact:true}).click();await capture('deck');
 await page.getByRole('button',{name:'Back',exact:true}).click();
 await page.getByRole('button',{name:'Journey journal',exact:true}).click();await capture('journal');
 await page.getByRole('button',{name:'Back',exact:true}).click();
 await page.getByRole('button',{name:'Unexplored path 1 · floor 1',exact:true}).click();await capture('reveal');
 await page.mouse.move(195,450);await page.mouse.wheel(0,400);
 await page.getByRole('button',{name:'Enter encounter',exact:true}).click();
 await page.getByText('TURN 1',{exact:true}).waitFor();await capture('battle');
 await page.setViewportSize({width:1280,height:900});await capture('desktop-battle');
 assert.deepEqual(errors,[]);
 console.log('PASS: all floor themes, camp, archive, deck, journal, reveal and combat render without missing assets or page errors.');
 await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});

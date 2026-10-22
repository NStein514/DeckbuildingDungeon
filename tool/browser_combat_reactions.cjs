const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
(async()=>{
 const browser=await chromium.launch({executablePath:'/usr/bin/chromium',args:['--no-sandbox','--enable-unsafe-swiftshader']});
 const page=await browser.newPage({viewport:{width:1280,height:900}}), errors=[];
 page.on('pageerror',e=>errors.push(e.message));
 const out='/tmp/deckbound-reactions';fs.mkdirSync(out,{recursive:true});
 await page.goto(process.env.BASE_URL||'http://127.0.0.1:8117');
 await page.locator('flt-semantics-placeholder').waitFor({state:'attached'});
 await page.evaluate(()=>document.querySelector('flt-semantics-placeholder').click());
 await page.getByRole('checkbox',{name:'Crypt ambush · 2 enemies',exact:true}).click();
 await page.getByRole('button',{name:'Enter the crypt',exact:true}).click();
 await page.getByText('TURN 1',{exact:true}).waitFor();await page.waitForTimeout(800);
 let defeated=false, hits=0;
 for(let i=0;i<20;i++){
  const attacks=await page.getByRole('button',{name:/\. Cost \d+\. Deal/}).all();
  let card;
  for(const candidate of attacks){
   const label=await candidate.ariaSnapshot();
   if(label&&!label.includes('Not enough energy')){card=candidate;break;}
  }
  if(!card){
   await page.getByRole('button',{name:'End turn',exact:true}).click();
   await page.waitForTimeout(80);await page.screenshot({path:out+'/player-hit.png'});
   await page.waitForTimeout(500);continue;
  }
  await card.click();
  await page.getByRole('button',{name:/^Dungeon Rat\./}).click();
  await page.waitForTimeout(90);await page.screenshot({path:out+'/hit-'+(++hits)+'.png'});
  await page.waitForTimeout(500);
  if(!(await page.locator('body').ariaSnapshot()).includes('Dungeon Rat.')){defeated=true;break;}
 }
 assert(defeated,'Rat must depart after taking lethal damage');
 assert((await page.locator('body').ariaSnapshot()).includes('Skeleton Soldier.'));
 await page.screenshot({path:out+'/survivor.png'});
 await page.getByRole('button',{name:'End turn',exact:true}).click();
 await page.waitForTimeout(600);
 assert.deepEqual(errors,[]);
 console.log('PASS: attacks, incoming damage, defeated rat removal, and continued combat with surviving skeleton.');
 await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});

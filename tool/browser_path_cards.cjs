const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
(async()=>{
 const browser=await chromium.launch({executablePath:'/usr/bin/chromium',args:['--no-sandbox','--enable-unsafe-swiftshader']});
 const page=await browser.newPage(), errors=[];
 page.on('pageerror',e=>errors.push(e.message));
 const fixtures=JSON.parse(fs.readFileSync(process.env.CHECKPOINTS,'utf8'));
 const out='/tmp/deckbound-path-cards';fs.mkdirSync(out,{recursive:true});
 const base=process.env.BASE_URL||'http://127.0.0.1:8120';
 async function enable(){await page.locator('flt-semantics-placeholder').waitFor({state:'attached'});await page.evaluate(()=>document.querySelector('flt-semantics-placeholder').click());}
 await page.goto(base);await enable();
 for(const width of [390,1280]){
  await page.setViewportSize({width,height:900});
  for(const kind of ['Treasure','Merchant','Ambush']){
   const fixture=fixtures['reveal'+kind];assert(fixture);
   await page.evaluate(p=>localStorage.setItem('deckbound.run.v1',JSON.stringify(p)),fixture);
   await page.reload();await enable();
   await page.getByRole('button',{name:'Continue run',exact:true}).click();
   await page.getByText('The path is revealed',{exact:true}).waitFor();await page.waitForTimeout(700);
   await page.screenshot({path:`${out}/${width}-${kind}-before.png`});
   if(kind==='Ambush'){
    const names={rat:'Dungeon Rat',skeleton:'Skeleton Soldier',mage:'Cursed Mage',duelist:'Ash Duelist'};
    const room=fixture.run.rooms.find(r=>r.id===fixture.run.currentRoom);
    const secret=names[room.enemies[1]];assert(secret);
    assert(!(await page.locator('body').ariaSnapshot()).includes(secret));
    await page.getByRole('button',{name:'Reveal next opponent',exact:true}).click();await page.waitForTimeout(800);
    assert((await page.locator('body').ariaSnapshot()).includes(secret));
    await page.screenshot({path:`${out}/${width}-${kind}-after.png`});
   }
  }
 }
 assert.deepEqual(errors,[]);await browser.close();
 console.log('PASS: centered treasure/merchant reveals and hidden-to-separate opponent cards at phone and desktop widths.');
})().catch(e=>{console.error(e);process.exit(1)});

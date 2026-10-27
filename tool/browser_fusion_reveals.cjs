const {chromium}=require('playwright');
const assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{
 const browser=await chromium.launch({executablePath:'/usr/bin/chromium',args:['--no-sandbox','--enable-unsafe-swiftshader']});
 const page=await browser.newPage(),errors=[];
 page.on('pageerror',e=>errors.push(e.message));page.on('response',r=>{if(r.status()>=400&&r.url().includes('/assets/'))errors.push(r.url())});
 const fixtures=JSON.parse(fs.readFileSync(process.env.CHECKPOINTS,'utf8'));
 const base=process.env.BASE_URL||'http://127.0.0.1:8127',out='/tmp/deckbound-fusion-reveals';fs.mkdirSync(out,{recursive:true});
 await page.goto(base);
 async function restore(data){await page.evaluate(p=>localStorage.setItem('deckbound.run.v1',JSON.stringify(p)),data);await page.reload();await page.locator('flt-semantics-placeholder').waitFor({state:'attached'});await page.evaluate(()=>document.querySelector('flt-semantics-placeholder').click());await page.getByRole('button',{name:'Continue run',exact:true}).click();}
 async function clickBelow(role,name){const target=page.getByRole(role,{name,exact:true});for(let i=0;i<16;i++){if(await target.count()){await target.click();return;}await page.mouse.move(350,750);await page.mouse.wheel(0,450);await page.waitForTimeout(250);}throw new Error('Missing '+name);}
 const roomNames={merchant:'The crypt merchant',treasure:'A forgotten reliquary',shrine:'The fusion shrine',rest:'A moment by the embers',emberForge:'The ember forge',memoryWell:'The memory well',bloodAltar:'The hungry altar',wanderingHealer:'The wandering healer'};
 for(const width of (process.env.ONLY_FUSIONS?[]:[390,1280])){
  await page.setViewportSize({width,height:900});
  for(const [key,title] of Object.entries(roomNames)){
   await restore(fixtures[key]);await page.getByText('The path is revealed',{exact:true}).waitFor();await page.waitForTimeout(350);
   await page.screenshot({path:`${out}/${width}-${key}-reveal.png`});
   await page.getByRole('button',{name:'Continue to room',exact:true}).click();await page.getByText(title,{exact:false}).or(page.getByRole('group',{name:new RegExp('^'+title)})).first().waitFor().catch(async e=>{await page.screenshot({path:`${out}/failure.png`});fs.writeFileSync(`${out}/failure.txt`,await page.locator('body').ariaSnapshot());throw e});await page.waitForTimeout(350);
   await page.screenshot({path:`${out}/${width}-${key}-room.png`});
   const exit=key==='merchant'?'Leave merchant':key==='shrine'?'Leave shrine':key==='treasure'?'Claim treasure':key==='rest'?'Rest · heal up to 15 HP':'Leave safely';
   await clickBelow('button',exit);await page.getByText('Choose your path',{exact:true}).waitFor();
  }
 }
 if(!process.env.ONLY_FUSIONS)console.log('PASS: all eight illustrated reveals and room actions at phone and desktop widths.');
 await page.setViewportSize({width:390,height:900});
 const cards=JSON.parse(fs.readFileSync('assets/data/cards.json','utf8')).filter(c=>(c.tags||[]).includes('archetype_fusion'));
 for(const card of cards){
  await restore(fixtures['fusion_'+card.id]);
  await clickBelow('checkbox',card.name);
  await clickBelow('button','Fuse cards');
  await page.screenshot({path:`${out}/${card.id}-confirm.png`});
  await page.getByRole('button',{name:'Cancel',exact:true}).click();
  assert.equal((await page.evaluate(()=>JSON.parse(localStorage.getItem('deckbound.run.v1')))).run.deck.length,12);
  await clickBelow('button','Fuse cards');await page.getByRole('button',{name:'Confirm fusion',exact:true}).click();await page.getByText('Choose your path',{exact:true}).waitFor();
  const saved=await page.evaluate(()=>JSON.parse(localStorage.getItem('deckbound.run.v1')));assert.equal(saved.run.deck.length,11);assert.equal(saved.run.deck.at(-1).definitionId,card.id);
  const combat=structuredClone(fixtures.combat);combat.run.deck=[{id:'card-12',definitionId:card.id,upgrade:0}];combat.run.nextCardId=13;
  await restore(combat);await page.getByRole('button',{name:'Resume encounter',exact:true}).click();await page.getByText('TURN 1',{exact:true}).waitFor();
  await page.mouse.move(200,700);await page.mouse.wheel(0,450);await page.waitForTimeout(900);
  await page.screenshot({path:`${out}/${card.id}-hand.png`});
  await page.getByRole('button',{name:new RegExp('^'+card.name+'\\. Cost')}).click();
  if(card.effects.some(e=>e.target==='enemy'))await page.getByRole('button',{name:/^Dungeon Rat\./}).click();else await page.getByRole('button',{name:'Play card',exact:true}).click();
  await page.waitForTimeout(550);await page.getByRole('button',{name:'End turn',exact:true}).click();await page.getByText('TURN 2',{exact:true}).waitFor();
 }
 assert.deepEqual(errors,[]);await browser.close();console.log('PASS: all five fusion confirmations, cancellations, persisted results and combat plays; no page or asset errors.');
})().catch(e=>{console.error(e);process.exit(1)});

const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
(async()=>{
 const browser=await chromium.launch({executablePath:'/usr/bin/chromium',args:['--no-sandbox','--enable-unsafe-swiftshader']});
 const page=await browser.newPage({viewport:{width:1280,height:1000}}), errors=[];
 page.on('pageerror',e=>errors.push(e.message));
 const base=process.env.BASE_URL||'http://127.0.0.1:8122';
 const out='/tmp/deckbound-expansion';fs.mkdirSync(out,{recursive:true});
 async function enable(){await page.locator('flt-semantics-placeholder').waitFor({state:'attached'});await page.evaluate(()=>document.querySelector('flt-semantics-placeholder').click());}
 await page.goto(base);await enable();await page.getByRole('textbox').fill('514');
 await page.getByRole('button',{name:'New run',exact:true}).click();
 await page.getByRole('button',{name:'Unexplored path 1 · floor 1',exact:true}).click();
 await page.getByText('The path is revealed',{exact:true}).waitFor();await page.waitForTimeout(1200);
 const checkpoint=await page.evaluate(()=>JSON.parse(localStorage.getItem('deckbound.run.v1')));
 assert.equal(checkpoint.run.cardPoolVersion,4);
 const pairs=[["wanderer", ["trail_rations"]], ["stormweaver", ["winter_circuit"]], ["venomblade", ["nightshade_mantle"]], ["gravewarden", ["graven_resolve"]], ["embercaller", ["cinder_insight"]]];
 const cards=JSON.parse(fs.readFileSync('assets/data/cards.json','utf8'));
 for(const [build,ids] of pairs){
  const fixture=structuredClone(checkpoint);fixture.run.startingBuild=build;
  fixture.run.deck=ids.map((definitionId,i)=>({id:'card-'+(12+i),definitionId,upgrade:0}));fixture.run.nextCardId=14;
  await page.evaluate(p=>localStorage.setItem('deckbound.run.v1',JSON.stringify(p)),fixture);
  await page.reload();await enable();await page.getByRole('button',{name:'Continue run',exact:true}).click();
  await page.getByRole('button',{name:'Enter encounter',exact:true}).click();await page.getByText('TURN 1',{exact:true}).waitFor();
  await page.waitForTimeout(700);await page.screenshot({path:`${out}/${build}-hand.png`});
  for(const id of ids){
   const card=cards.find(c=>c.id===id);
   await page.getByRole('button',{name:new RegExp('^'+card.name+'\\. Cost')}).click();
   if(card.effects.some(e=>e.target==='enemy'))await page.getByRole('button',{name:/^Dungeon Rat\./}).click();
   else await page.getByRole('button',{name:'Play card',exact:true}).click();
   await page.waitForTimeout(550);
  }
  await page.screenshot({path:`${out}/${build}-played.png`});
  await page.getByRole('button',{name:'End turn',exact:true}).click();await page.getByText('TURN 2',{exact:true}).waitFor();
 }
 assert.deepEqual(errors,[]);await browser.close();
 console.log('PASS: all five endurance cards render and play in five build-themed encounters, with saved pool version 4 and working turn advancement.');
})().catch(e=>{console.error(e);process.exit(1)});

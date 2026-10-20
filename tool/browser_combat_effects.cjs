// Run against the release web build with CHECKPOINTS from smoke_checkpoints.dart.
const {chromium}=require('playwright');
const fs=require('node:fs');
const path=require('node:path');
const assert=require('node:assert/strict');
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROME_EXECUTABLE || '/usr/bin/chromium',headless:true,args:['--no-sandbox','--enable-unsafe-swiftshader']});
 const context=await browser.newContext({viewport:{width:390,height:844},...(process.env.COMBAT_RECORD_VIDEO ? {recordVideo:{dir:process.env.COMBAT_RECORD_VIDEO,size:{width:390,height:844}}} : {})});
 const page=await context.newPage();
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 const output=path.join(require('node:os').tmpdir(),'deckbound-effects');fs.mkdirSync(output,{recursive:true});
 const fixture=JSON.parse(fs.readFileSync(process.env.CHECKPOINTS,'utf8')).effects;
 await page.goto(process.env.BASE_URL || 'http://127.0.0.1:8080');
 for (const [id,name,targeted] of [['strike','Strike',true],['guard','Guard',false],['firebolt','Firebolt',true],['spark','Spark',true],['poison_edge','Poison Edge',true],['mend','Mend',false],['preparation','Preparation',false]]) {
   const data=structuredClone(fixture);data.run.deck[0].definitionId=id;
   if(id==='guard'){data.run.health=25;data.run.relics.push('lastEmber');}
   await page.evaluate(data=>localStorage.setItem('deckbound.run.v1',JSON.stringify(data)),data);
   await page.reload();await page.locator('flt-semantics-placeholder').waitFor({state:'attached'});
   await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());
   await page.getByRole('button',{name:'Continue run',exact:true}).click();
   await page.getByRole('button',{name:'Resume encounter',exact:true}).click();
   await page.getByText('TURN 1',{exact:true}).waitFor();
   if(id==='guard'){await page.getByText('+1 Last Ember',{exact:true}).waitFor();await page.getByText('4',{exact:true}).waitFor();}
   await page.getByRole('button',{name:new RegExp('^'+name+'\\. Cost')}).click();
   if (targeted) await page.getByRole('button',{name:/^Dungeon Rat\./}).click();
   else await page.getByRole('button',{name:'Play card',exact:true}).click();
   await page.screenshot({path:path.join(output,id+'-impact.png')});
   await page.waitForTimeout(500);
   if (id==='strike') assert((await page.locator('body').ariaSnapshot()).includes('Dungeon Rat. 16 health'));
   if (id==='mend') assert((await page.locator('body').ariaSnapshot()).includes('40 / 50 HP'));
   console.log('PASS: '+name+' resolves with transient visual feedback.');
 }
 assert.deepEqual(errors,[]);await context.close();await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});

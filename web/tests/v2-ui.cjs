const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const root = path.resolve(__dirname, '..');
const dist = path.join(root, 'dist');
const { chromium } = require(path.join(root, 'node_modules', 'playwright-core'));
const out = path.resolve(__dirname, '../artifacts/round2-layout');
fs.mkdirSync(out, { recursive: true });
const result = { pages: [], pageErrors: [], consoleErrors: [], warnings: [], failedRequests: [], badResponses: [], blockedHttp: [], blockedSockets: 0, served: 0 };
const mime = { '.html':'text/html', '.js':'text/javascript', '.css':'text/css', '.json':'application/json', '.png':'image/png', '.svg':'image/svg+xml', '.moc3':'application/octet-stream', '.wasm':'application/wasm' };
function staticFile(url) {
  const p = decodeURIComponent(new URL(url).pathname);
  const f = path.resolve(dist, '.' + (p === '/' ? '/index.html' : p));
  return f.startsWith(dist + path.sep) && fs.existsSync(f) && fs.statSync(f).isFile() ? f : null;
}
const server = http.createServer((req,res) => {
  const f = staticFile('http://127.0.0.1' + req.url);
  if(req.method !== 'GET' || !f){res.writeHead(404).end();return;}
  res.setHeader('Content-Type', mime[path.extname(f)] || 'application/octet-stream');
  res.setHeader('Content-Security-Policy', "connect-src 'self'; object-src 'none'");
  result.served++; fs.createReadStream(f).pipe(res);
});
let browser;
(async()=>{
 try {
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const origin = `http://127.0.0.1:${server.address().port}`;
  result.origin = origin;
  browser = await chromium.launch({channel:'msedge',headless:true,args:['--disable-background-networking','--disable-component-update','--disable-sync','--no-first-run','--mute-audio']});
  const ctx = await browser.newContext({viewport:{width:1440,height:1000},serviceWorkers:'block',permissions:[]});
  await ctx.route('**/*',route=>{
   const req=route.request(),u=new URL(req.url());
   if(u.origin === origin && req.method()==='GET' && staticFile(u.href)) return route.continue();
   result.blockedHttp.push({kind:u.origin===origin?'non-static-local':'external',method:req.method()});
   return route.abort('blockedbyclient');
  });
  await ctx.routeWebSocket('**/*',ws=>{result.blockedSockets++;ws.close();});
  await ctx.addInitScript(()=>{
   // Test-context isolation only: no source or existing profile changes.
   localStorage.clear(); sessionStorage.clear();
   if(window.speechSynthesis){window.speechSynthesis.speak=()=>{};window.speechSynthesis.getVoices=()=>[];}
   if(navigator.mediaDevices) navigator.mediaDevices.getUserMedia=async()=>{throw new Error('Baseline denies camera/microphone');};
   navigator.geolocation.getCurrentPosition=(_,reject)=>reject?.({message:'Baseline denies location'});
  });
  const page=await ctx.newPage(); page.setDefaultTimeout(5000);
  page.on('pageerror',e=>result.pageErrors.push(e.message));
  page.on('console',m=>{if(m.type()==='error')result.consoleErrors.push(m.text());else if(m.type()==='warning')result.warnings.push(m.text());});
  page.on('requestfailed',r=>result.failedRequests.push({path:new URL(r.url()).pathname,error:r.failure()?.errorText}));
  page.on('response',r=>{if(r.status()>=400)result.badResponses.push({path:new URL(r.url()).pathname,status:r.status()});});
  await page.goto(origin,{waitUntil:'networkidle',timeout:30000});
  await page.waitForFunction(()=>window.neuro?.player.session && document.querySelector('.nd-hero'),{timeout:15000});
  await page.waitForFunction(()=>document.querySelector('[data-live2d="ready"]') || document.querySelector('[data-live2d-error]'),{timeout:20000});
  result.initial = await page.evaluate(()=>({bridge:!!window.neuroDesktop,mqttSaved:localStorage.getItem('nd-mqtt'),live2d:!!document.querySelector('[data-live2d="ready"]')}));
  async function snap(name){await page.screenshot({path:path.join(out,name+'.png'),fullPage:true});result.pages.push({name,title:await page.title(),horizontalOverflow:await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth)});}
  const assert=require('node:assert/strict');
  await page.setViewportSize({width:1440,height:900});await snap('home-1440');assert.ok((await page.locator('.nd-main').boundingBox()).width>1000,'main width');await snap('island-collapsed');await page.locator('.v2-island-toggle').click();await snap('island-expanded');await page.locator('.v2-island-toggle').click();
  await page.locator('#v2-prompt').fill('明天下午三点送两瓶水和一份曲奇到 A 区取餐点。');
  await page.locator('#v2-intent button').click();
  assert.equal(await page.locator('#v2-booking').evaluate(e=>e.open),true);
  assert.equal(await page.locator('[data-v2-qty]').count(),2);assert.equal(await page.locator('[data-v2-qty=water]').inputValue(),'2');
  assert.equal(await page.locator('[data-v2-qty=cookie]').inputValue(),'1');
  assert.equal(await page.locator('#v2-time').inputValue(),'15:00');
  await page.locator('[data-v2-qty=cookie]').fill('2');
  assert.equal(await page.locator('#v2-total').textContent(),'¥28.00');
  await page.locator('#v2-time').fill('15:12');await snap('booking-1440');
  await page.locator('#v2-pay').click();
  await page.waitForSelector('#v2-car');await snap('delivery-1440');
  await page.locator('[data-v2=details]').click();
  await page.locator('[data-v2=pause]').click();
  const stage=await page.locator('.v2-stages [aria-current=step]').textContent();
  await page.waitForTimeout(3700);assert.equal(await page.locator('.v2-stages [aria-current=step]').textContent(),stage);
  await page.locator('[data-v2=fail]').click();assert.match(await page.locator('#v2-service').textContent(),/异常/);
  await page.locator('[data-v2=resume]').click();
  assert.equal(await page.locator('#v2-order-detail').isVisible(),true);
  await page.waitForFunction(()=>document.querySelector('#v2-service .v2-order-summary')?.textContent.includes('已领取'),undefined,{timeout:30000});
  await snap('delivery-complete');
  await page.locator('.nd-nav[data-action=supply]').click();assert.match(await page.locator('#v2-service').textContent(),/¥28.00/);await snap('supply-1440');
  await page.locator('[data-v2=generate]').click();assert.match(await page.locator('#v2-shop-feedback').textContent(),/暂未识别/);
  await page.locator('.nd-nav[data-action=home]').click();assert.match(await page.locator('#v2-home-summary').textContent(),/已领取/);
  await page.locator('.v2-account').click();await snap('login-1440');
  await page.locator('[data-auth=register]').click();assert.equal(await page.locator('#v2-confirm-wrap').isVisible(),true);
  await page.locator('[data-auth=guest]').click();
  await page.locator('.nd-nav[data-action=chat]').click();await page.locator('.nd-chat-avatar').click();await page.locator('[data-action=companion]').first().click();await page.locator('[data-action=close-companions]').click();assert.equal(await page.locator('#gallery .pet-card:not(.upload)').count(),8);await snap('pets-1440');
  await page.locator('#gallery .pet-card').nth(1).click();assert.equal(await page.evaluate(()=>window.neuro.hub.def.id),'cat');
  await page.locator('.nd-nav[data-action=health]').click();await snap('health-1440');
  await page.locator('.nd-nav[data-action=chat]').click();await snap('chat-1440');
  await page.locator('.nd-nav[data-action=home]').click();await page.locator('.nd-quick-actions [data-action=coffee]').click();assert.equal(await page.locator('#v2-booking').evaluate(e=>e.open),true);await page.locator('[data-v2-close]').click();
  for(const size of [[1280,711],[980,660]]){await page.setViewportSize({width:size[0],height:size[1]});await page.locator('.nd-nav[data-action=home]').click();assert.ok((await page.locator('.nd-main').boundingBox()).width>size[0]*.7,'responsive main width');await snap('home-'+size[0]);await page.locator('.nd-nav[data-action=supply]').click();await snap('supply-'+size[0]);}
  result.completed=true;
 }catch(e){result.failure=e.stack;process.exitCode=1;}
 finally{if(browser)await browser.close();server.closeAllConnections();await new Promise(r=>server.close(r));fs.writeFileSync(path.join(out,'result.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result,null,2));}
})();

// Headless Edge test uses an artificial camera; it never accesses the user's camera.
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
const root=fileURLToPath(new URL('../',import.meta.url));
const bridge=spawn(process.execPath,[`${root}camera/server.cjs`],{windowsHide:true,stdio:'ignore'});
for(let i=0;i<50;i++) {
  try{if((await fetch('http://127.0.0.1:19751/status')).ok) break;}catch{}
  await new Promise(r=>setTimeout(r,100));
}
const profile=`${root}.runtime/edge-smoke`;
await fs.mkdir(profile,{recursive:true});
const edge=spawn('C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',[
  '--headless=new','--no-first-run','--no-default-browser-check','--remote-debugging-port=19752',
  `--user-data-dir=${profile}`,'--use-fake-device-for-media-stream','--use-fake-ui-for-media-stream',
  'about:blank'
],{windowsHide:true,stdio:'ignore'});
let ws;let next=0;const pending=new Map();
const call=(method,params={})=>new Promise((resolve,reject)=>{
  const id=++next;const timeout=setTimeout(()=>{pending.delete(id);reject(new Error(`Timeout: ${method}`));},60000);
  pending.set(id,{resolve,reject,timeout});ws.send(JSON.stringify({id,method,params}));
});
try {
  let targets;
  for(let i=0;i<100;i++) {
    try {targets=await (await fetch('http://127.0.0.1:19752/json')).json();if(targets.some(t=>t.type==='page')) break;}catch{}
    await new Promise(r=>setTimeout(r,100));
  }
  const target=targets.find(t=>t.type==='page');assert(target,'Test browser page must open');
  ws=new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve,reject)=>{ws.onopen=resolve;ws.onerror=reject;});
  ws.onmessage=event=>{const msg=JSON.parse(event.data);const task=pending.get(msg.id);if(task){clearTimeout(task.timeout);pending.delete(msg.id);msg.error?task.reject(msg.error):task.resolve(msg.result);}};
  await call('Runtime.enable');
  await call('Page.enable');
  await call('Page.navigate',{url:'http://127.0.0.1:19751/'});
  for(let i=0;i<100;i++){
    try{
      const ready=await call('Runtime.evaluate',{expression:"document.readyState==='complete' && !!document.querySelector('#start')",returnByValue:true});
      if(ready.result.value) break;
    }catch{}
    await new Promise(r=>setTimeout(r,100));
  }
  const result=await call('Runtime.evaluate',{expression:`(async()=>{
    for(let i=0;i<100;i++) {
      if(document.readyState==='complete' && document.querySelector('#start')) break;
      await new Promise(r=>setTimeout(r,100));
    }
    document.querySelector('#start').click();
    for(let i=0;i<180;i++){
      await new Promise(r=>setTimeout(r,250));
      const video=document.querySelector('video');
      if(video.srcObject && video.readyState>=2 && document.querySelector('#readout').textContent.includes('WAITING')){
        const data={status:document.querySelector('#status').textContent,readout:document.querySelector('#readout').textContent,tracks:video.srcObject.getVideoTracks().length};
        document.querySelector('#calibrate').click();
        data.calibrationOpened=!document.querySelector('#calibration').hidden;
        document.querySelector('#cancelCalibration').click();
        data.calibrationClosed=document.querySelector('#calibration').hidden;
        document.querySelector('#stop').click();
        data.stopped=video.srcObject===null;
        return data;
      }
      const status=document.querySelector('#status').textContent;
      if(status.includes('失败')||status.includes('已停止')) throw new Error(status);
    }
    throw new Error('Model/camera startup timeout: '+document.querySelector('#status').textContent);
  })()`,awaitPromise:true,returnByValue:true});
  if(result.exceptionDetails) throw new Error(JSON.stringify(result.exceptionDetails));
  assert.equal(result.result.value.tracks,1);assert.equal(result.result.value.stopped,true);
  assert.equal(result.result.value.calibrationOpened,true);assert.equal(result.result.value.calibrationClosed,true);
  console.log('BROWSER_TEST_PASS:',JSON.stringify(result.result.value));
} finally {
  if(ws?.readyState===1){try{await call('Browser.close');}catch{}}
  ws?.close();edge.kill();bridge.kill();
}

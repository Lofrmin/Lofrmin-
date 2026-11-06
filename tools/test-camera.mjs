import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import dgram from 'node:dgram';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {interpretHands} from '../camera/gestures.mjs';
const root = fileURLToPath(new URL('../', import.meta.url));
assert.equal(interpretHands([]).hands, 0);
const palm = Array.from({length:21},()=>({x:.5,y:.5}));
palm[0]={x:.5,y:.8}; palm[9]={x:.5,y:.6}; palm[4]={x:.48,y:.3};
for (const tip of [8,12,16,20]) palm[tip]={x:.5+(tip-12)*.01,y:.3};
for (const pip of [6,10,14,18]) palm[pip]={x:.5+(pip-10)*.01,y:.5};
palm[4]={x:.2,y:.5};
assert.equal(interpretHands([palm]).open,true);
palm[4]={...palm[8]};
assert.equal(interpretHands([palm]).pinch,true);
assert.equal(interpretHands([palm]).open,false);
const other = palm.map(p=>({...p,x:p.x+.6}));
assert.equal(interpretHands([palm,other]).thrust,1);
assert.equal(interpretHands([palm,palm]).thrust,0);
for (const filename of ['vision_wasm_internal.wasm','vision_wasm_nosimd_internal.wasm']) {
  const bytes = await fs.readFile(`${root}camera/wasm/${filename}`);
  assert(bytes.length>9000000,`${filename} must be complete`);
  await WebAssembly.compile(bytes);
}
for (const filename of ['vision_wasm_internal.js','vision_wasm_nosimd_internal.js']) {
  assert((await fs.stat(`${root}camera/wasm/${filename}`)).size>150000);
}
assert((await fs.stat(`${root}camera/hand_landmarker.task`)).size>7000000);
const bridge = spawn(process.execPath,[`${root}camera/server.cjs`],{windowsHide:true,stdio:'pipe'});
const mockGame = dgram.createSocket('udp4');
try {
  await new Promise((resolve,reject)=>{mockGame.once('error',reject);mockGame.bind(19750,'127.0.0.1',resolve);});
  for(let i=0;i<50;i++) {
    try { if((await fetch('http://127.0.0.1:19751/status')).ok) break; } catch {}
    await new Promise(r=>setTimeout(r,100));
  }
  const received = new Promise((resolve,reject)=>{
    const timeout=setTimeout(()=>reject(new Error('UDP packet timeout')),3000);
    mockGame.once('message',(data,peer)=>{
      clearTimeout(timeout); mockGame.send(Buffer.from('HELIOS_ACK'),peer.port,peer.address);
      resolve(JSON.parse(data));
    });
  });
  const response=await fetch('http://127.0.0.1:19751/gesture',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({hands:2,x:.7,y:.3,pinch:true,thrust:.8,view:true,spread:.55,angle:-.2,quality:.9,salvo:true,status:'test'})});
  assert.equal(response.status,200);
  const packet=await received;
  assert.equal(packet.hands,2);assert.equal(packet.x,.7);assert.equal(packet.pinch,true);assert.equal(packet.thrust,.8);
  assert.equal(packet.view,true);assert.equal(packet.spread,.55);assert.equal(packet.angle,-.2);assert.equal(packet.quality,.9);assert.equal(packet.salvo,true);
  await new Promise(r=>setTimeout(r,100));
  assert.equal((await (await fetch('http://127.0.0.1:19751/status')).json()).gameConnected,true);
  const rejected=await fetch('http://127.0.0.1:19751/gesture',{method:'POST',headers:{Origin:'https://untrusted.example'},body:'{}'});
  assert.equal(rejected.status,403);
  for(const route of ['/','/tracker.mjs','/vision_bundle.mjs','/wasm/vision_wasm_internal.wasm','/hand_landmarker.task']) {
    const asset=await fetch(`http://127.0.0.1:19751${route}`);
    assert.equal(asset.status,200);assert((await asset.arrayBuffer()).byteLength>0);
  }
  assert.equal((await fetch('http://127.0.0.1:19751/secret.txt')).status,404);
  console.log('CAMERA_TEST_PASS: gesture mapping, complete WASM, local assets, HTTP→UDP→ACK, origin checks');
} finally { mockGame.close();bridge.kill(); }

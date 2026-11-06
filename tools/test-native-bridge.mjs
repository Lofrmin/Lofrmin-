import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import dgram from 'node:dgram';
import assert from 'node:assert/strict';
const root=fileURLToPath(new URL('../',import.meta.url));
const game=spawn((process.env.GODOT_CONSOLE || 'godot'),
  ['--headless','--path',root,'--','--bridge-test'],{windowsHide:true,
  env:{...process.env,APPDATA:`${root}.runtime/roaming`,LOCALAPPDATA:`${root}.runtime/local`},stdio:['ignore','pipe','pipe']});
const socket=dgram.createSocket('udp4');let output='',ack=false;
game.stdout.on('data',data=>output+=data);game.stderr.on('data',data=>output+=data);
socket.on('message',data=>{if(data.toString()==='HELIOS_ACK')ack=true;});
const packet=Buffer.from(JSON.stringify({hands:2,x:.6,y:.4,pinch:true,open:false,thrust:.8,status:'native test'}));
const wave=Buffer.from(JSON.stringify({hands:1,wave:true,x:.5,y:.5,status:'native wake test'}));
const interval=setInterval(()=>{socket.send(wave,19750,'127.0.0.1');socket.send(packet,19750,'127.0.0.1');},100);
const timeout=setTimeout(()=>game.kill(),15000);
try{
  const code=await new Promise(resolve=>game.on('close',resolve));
  assert.equal(code,0,output);assert(output.includes('NATIVE_BRIDGE_TEST_PASS'),output);assert(ack,'Godot must acknowledge packet');
  console.log(output.trim());
}finally{clearInterval(interval);clearTimeout(timeout);socket.close();game.kill();}

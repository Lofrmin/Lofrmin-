import {FilesetResolver,HandLandmarker} from './vision_bundle.mjs';
import {GestureTracker,describeHand,distance} from './gestures.mjs';
const $=selector=>document.querySelector(selector);
const video=$('#video'),canvas=$('#overlay'),ctx=canvas.getContext('2d');
const status=$('#status'),start=$('#start'),stop=$('#stop');
let profile={};try{profile=JSON.parse(localStorage.getItem('helios-calibration-v2')||'{}');}catch{}
const tracker=new GestureTracker(profile);
let model,stream,running=false,busy=false,lastFrame=-1,lastGame=0,frameHandle,interval;
let calibration=null,inferenceMs=0,frames=0,fps=0,fpsAt=performance.now();
const connections=[[0,1],[1,2],[2,3],[3,4],[0,5],[5,6],[6,7],[7,8],[5,9],[9,10],[10,11],[11,12],[9,13],[13,14],[14,15],[15,16],[13,17],[0,17],[17,18],[18,19],[19,20]];
const prompts=['张开你的惯用手，在画面中央保持静止','拇指与食指自然捏合，保持静止','伸出食指，移到舒适操作范围的左上角，保持静止','移到舒适操作范围的右下角，保持静止'];
$('#profile').textContent=profile.bounds?'已载入个人校准':'使用默认参数 · 建议先校准';
async function send(data){
  const response=await fetch('/gesture',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)});
  if(!response.ok)throw new Error('本机手势服务连接失败');
  return response.json();
}
async function createModel(){
  if(model)return;
  status.textContent='正在初始化本机手势模型…';
  const files=await FilesetResolver.forVisionTasks('/wasm');
  const options={baseOptions:{modelAssetPath:'/hand_landmarker.task',delegate:'GPU'},runningMode:'VIDEO',numHands:2,minHandDetectionConfidence:.65,minHandPresenceConfidence:.65,minTrackingConfidence:.65};
  try{model=await HandLandmarker.createFromOptions(files,options);}
  catch{options.baseOptions.delegate='CPU';model=await HandLandmarker.createFromOptions(files,options);}
}
function schedule(){
  if(!running)return;
  if('requestVideoFrameCallback' in video)frameHandle=video.requestVideoFrameCallback(async()=>{await tick();schedule();});
}
start.addEventListener('click',async()=>{
  start.disabled=true;
  try{
    await createModel();
    stream=await navigator.mediaDevices.getUserMedia({video:{width:{ideal:960},height:{ideal:720},frameRate:{ideal:30,max:30},facingMode:'user'},audio:false});
    video.srcObject=stream;await video.play();
    running=true;stop.disabled=false;$('#calibrate').disabled=false;tracker.reset();lastGame=performance.now();
    $('#placeholder').hidden=true;
    if('requestVideoFrameCallback' in video)schedule();else interval=setInterval(tick,33);
    status.textContent='连接就绪。建议点击「个人校准」，然后切回游戏。';
  }catch(error){
    shutdown();
    status.textContent=error.name==='NotAllowedError'?'摄像头未授权。你可以重新开启并授权，或使用鼠标键盘。':error.name==='NotFoundError'?'未找到摄像头。':error.name==='NotReadableError'?'摄像头被其他程序占用，请关闭占用程序重试。':`初始化失败：${error.message}`;
  }
});
$('#calibrate').addEventListener('click',()=>{
  if(!running)return;
  calibration={step:0,samples:[],stageAt:performance.now(),profile:{},upper:null};
  tracker.reset();$('#calibration').hidden=false;
});
$('#cancelCalibration').addEventListener('click',()=>{calibration=null;$('#calibration').hidden=true;tracker.reset();});
$('#reset').addEventListener('click',()=>{
  localStorage.removeItem('helios-calibration-v2');profile={};tracker.profile=profile;tracker.reset();
  $('#profile').textContent='已恢复默认参数';
});
function calibrate(hands,now){
  const c=calibration;
  $('#calibrationText').textContent=`${c.step+1} / 4  ${prompts[c.step]}`;
  if(hands.length!==1){c.samples=[];$('#calibrationHint').textContent='只保留惯用手在画面中';return;}
  const hand=describeHand(hands[0]);
  const valid=c.step===0?hand.extended>=4&&hand.ratio>.75:c.step===1?hand.ratio<.42:hand.extended>=1&&hand.ratio>.55;
  if(!valid){c.samples=[];$('#calibrationHint').textContent='调整手型后保持约 1 秒';$('#calibrationProgress').style.width='0';return;}
  if(now-c.stageAt<900)return;
  c.samples.push({x:hand.pointer.x,y:hand.pointer.y,ratio:hand.ratio,time:now});
  const stableWindow=c.samples.filter(s=>now-s.time<950);
  const movement=Math.max(...stableWindow.map(s=>distance(s,stableWindow[0])));
  if(movement>.045){c.samples=[c.samples.at(-1)];$('#calibrationHint').textContent='请稍微保持静止';return;}
  const progress=Math.min(1,(now-c.samples[0].time)/850);
  $('#calibrationProgress').style.width=`${progress*100}%`;
  $('#calibrationHint').textContent='正在采集稳定样本…';
  if(progress<1)return;
  const median=key=>[...c.samples].sort((a,b)=>a[key]-b[key])[Math.floor(c.samples.length/2)][key];
  if(c.step===0)c.profile.openRatio=median('ratio');
  if(c.step===1){c.profile.pinchOn=Math.max(.18,Math.min(.44,median('ratio')+.15));c.profile.pinchOff=c.profile.pinchOn+.18;}
  if(c.step===2)c.upper={x:median('x'),y:median('y')};
  if(c.step===3){
    const lower={x:median('x'),y:median('y')};
    if(lower.x-c.upper.x<.24||lower.y-c.upper.y<.20){
      c.step=2;c.samples=[];c.stageAt=now;
      $('#calibrationHint').textContent='操作范围过小，重新采集两个角。';return;
    }
    c.profile.bounds={left:c.upper.x,right:lower.x,top:c.upper.y,bottom:lower.y};
    profile=c.profile;localStorage.setItem('helios-calibration-v2',JSON.stringify(profile));
    tracker.profile=profile;tracker.reset();calibration=null;$('#calibration').hidden=true;
    $('#profile').textContent='个人校准已保存 · 本机有效';status.textContent='校准完成。切回游戏，用单手捏合抓取编队。';return;
  }
  c.step++;c.samples=[];c.stageAt=now;$('#calibrationProgress').style.width='0';
}
async function tick(){
  if(!running||busy||video.readyState<2||video.currentTime===lastFrame)return;
  busy=true;
  try{
    lastFrame=video.currentTime;
    const now=performance.now(),result=model.detectForVideo(video,now);
    inferenceMs=inferenceMs*.8+(performance.now()-now)*.2;
    const hands=result.landmarks;
    let data=tracker.update(hands,now,result.handedness);
    if(calibration){calibrate(hands,now);data={hands:0,cancel:true,status:'个人校准中'};}
    const link=await send({...data,status:data.status??(data.hands?'手势追踪中':'未检测到手')});
    if(link.gameConnected)lastGame=performance.now();
    frames++;
    if(now-fpsAt>1000){fps=frames*1000/(now-fpsAt);frames=0;fpsAt=now;}
    drawHands(hands,data);
    const mode=data.view?'VIEW':data.salvo?'SALVO':data.pinch?'GRAB':data.open?'TACTICAL':'TRACK';
    $('#readout').textContent=`HANDS ${data.hands} / ${mode} / LINK ${link.gameConnected?'ONLINE':'WAITING'}`;
    $('#metrics').textContent=`${fps.toFixed(0)} FPS · 推理 ${inferenceMs.toFixed(0)} ms · 稳定度 ${Math.round((data.quality??0)*100)}%`;
    $('#power').style.width=`${(data.quality??0)*100}%`;
    if(!calibration)status.textContent=!link.gameConnected?'等待游戏连接。请打开新版游戏并按 C 启用手势。':data.hands?'已连接 · 切回游戏指挥编队；此窗口可以放在游戏后方。':'游戏已连接 · 手掌完整入镜后恢复控制。';
    if(now-lastGame>30000)shutdown('游戏连接中断，已自动关闭摄像头。');
  }catch(error){shutdown(`识别停止：${error.message}。请重新开启。`);}
  finally{busy=false;}
}
function drawHands(hands,data){
  ctx.clearRect(0,0,640,480);
  for(let i=0;i<hands.length;i++){
    const hand=hands[i];ctx.strokeStyle=i?'#7affce':'#6ee9ff';ctx.lineWidth=2;
    for(const[a,b]of connections){ctx.beginPath();ctx.moveTo(hand[a].x*640,hand[a].y*480);ctx.lineTo(hand[b].x*640,hand[b].y*480);ctx.stroke();}
    for(const point of hand){ctx.beginPath();ctx.arc(point.x*640,point.y*480,2.6,0,Math.PI*2);ctx.fillStyle='#e4ffff';ctx.fill();}
    ctx.beginPath();ctx.arc(hand[8].x*640,hand[8].y*480,data.pinch?16:10,0,Math.PI*2);ctx.stroke();
  }
}
function shutdown(message='摄像头已关闭。鼠标键盘可继续使用。'){
  running=false;clearInterval(interval);if(frameHandle&&video.cancelVideoFrameCallback)video.cancelVideoFrameCallback(frameHandle);
  stream?.getTracks().forEach(track=>track.stop());stream=null;video.srcObject=null;lastFrame=-1;
  calibration=null;tracker.reset();ctx.clearRect(0,0,640,480);
  start.disabled=false;stop.disabled=true;$('#calibrate').disabled=true;
  $('#placeholder').hidden=false;$('#calibration').hidden=true;$('#power').style.width='0';
  $('#readout').textContent='HANDS 0 / LINK STANDBY';status.textContent=message;
  send({hands:0,cancel:true,status:'摄像头已关闭'}).catch(()=>{});
}
stop.addEventListener('click',()=>shutdown());
window.addEventListener('pagehide',()=>{stream?.getTracks().forEach(track=>track.stop());});

// Adapted from XiaoQi_Interactive_V6_4.html; assets are bundled for offline desktop use.
const EXPRESSIONS = [{"key": "serious", "name": "严肃", "src": "/pets/xiaoqi/serious.webp"}, {"key": "happy", "name": "高兴", "src": "/pets/xiaoqi/happy.webp"}, {"key": "sad", "name": "伤心", "src": "/pets/xiaoqi/sad.webp"}, {"key": "confused", "name": "星星眼", "src": "/pets/xiaoqi/confused.webp"}, {"key": "question", "name": "屏幕问号", "src": "/pets/xiaoqi/question.webp"}];
const SERIOUS_RED = '/pets/xiaoqi/serious-red.webp';
const MARKUP = "<div class=\"xiaoqi-robot\" role=\"img\" aria-label=\"小七机器人\"><div class=\"robot-layer\">\n<img id=\"robotBase\" class=\"robot-base\" alt=\"小七机器人，严肃表情\" />\n<canvas id=\"cubeCanvas\" width=\"240\" height=\"240\" aria-hidden=\"true\"></canvas>\n<svg class=\"overlay\" id=\"starFaceOverlay\" viewBox=\"0 0 825 1197\" preserveAspectRatio=\"none\" xmlns=\"http://www.w3.org/2000/svg\" aria-hidden=\"true\" style=\"opacity:0;transition:opacity .16s linear;\">\n<defs><filter id=\"starEyesGlow\" x=\"-40%\" y=\"-40%\" width=\"180%\" height=\"180%\"><feGaussianBlur stdDeviation=\"4\" result=\"glow\"/><feMerge><feMergeNode in=\"glow\"/><feMergeNode in=\"SourceGraphic\"/></feMerge></filter></defs>\n<!-- stars are centered at the original screen eye line (y=448), not on the forehead -->\n<g id=\"starFaceGroup\" filter=\"url(#starEyesGlow)\">\n  <path d=\"M267.0 409.0 L277.0 433.2 L303.1 435.3 L283.2 452.3 L289.3 477.7 L267.0 464.0 L244.7 477.7 L250.8 452.3 L230.9 435.3 L257.0 433.2 Z\" fill=\"#69cbff\" stroke=\"#e4faff\" stroke-width=\"5\" stroke-linejoin=\"round\"/>\n  <path d=\"M520.0 409.0 L530.0 433.2 L556.1 435.3 L536.2 452.3 L542.3 477.7 L520.0 464.0 L497.7 477.7 L503.8 452.3 L483.9 435.3 L510.0 433.2 Z\" fill=\"#69cbff\" stroke=\"#e4faff\" stroke-width=\"5\" stroke-linejoin=\"round\"/>\n</g></svg>\n\n\n<svg class=\"overlay\" id=\"maskOverlay\" viewBox=\"0 0 825 1197\" preserveAspectRatio=\"none\" xmlns=\"http://www.w3.org/2000/svg\" aria-hidden=\"true\">\n<defs>\n <linearGradient id=\"armorGradV6\" x1=\"0\" y1=\"0\" x2=\"0.16\" y2=\"1\">\n  <stop offset=\"0\" stop-color=\"#ffffff\"/><stop offset=\".38\" stop-color=\"#f4f8ff\"/><stop offset=\".78\" stop-color=\"#cbd9eb\"/><stop offset=\"1\" stop-color=\"#a5bdd7\"/>\n </linearGradient>\n <linearGradient id=\"innerGradV6\" x1=\"0\" y1=\"0\" x2=\"0.18\" y2=\"1\">\n  <stop offset=\"0\" stop-color=\"#ecf5ff\"/><stop offset=\".42\" stop-color=\"#d6e4f5\"/><stop offset=\"1\" stop-color=\"#8ba6c8\"/>\n </linearGradient>\n <clipPath id=\"maskLowerFace\"><path d=\"M168 513 Q190 511 210 514 L615 514 Q640 510 662 514 L659 552 Q653 606 580 629 Q506 642 412 640 Q300 643 239 625 Q171 609 167 555 Z\"/></clipPath>\n <filter id=\"maskShadowV6\" x=\"-18%\" y=\"-35%\" width=\"145%\" height=\"170%\"><feDropShadow dx=\"0\" dy=\"2\" stdDeviation=\"2.8\" flood-color=\"#263f5d\" flood-opacity=\".43\"/></filter>\n</defs>\n<g clip-path=\"url(#maskLowerFace)\" filter=\"url(#maskShadowV6)\">\n  <!-- left sleeve: extends from temple to cheek first -->\n  <g id=\"leftMask\" transform=\"translate(-230 0)\">\n    <path d=\"M166 513 Q185 510 201 518 L322 520 L338 539 L338 607 Q273 642 197 604 Q169 584 166 549 Z\" fill=\"url(#armorGradV6)\" stroke=\"#718dab\" stroke-width=\"3.4\"/>\n    <path d=\"M177 523 L314 527\" fill=\"none\" stroke=\"white\" stroke-opacity=\".88\" stroke-width=\"4\"/>\n    <path d=\"M195 574 L313 596\" fill=\"none\" stroke=\"#91a9c9\" stroke-opacity=\".72\" stroke-width=\"2.6\"/>\n    <path d=\"M326 532 L326 601\" stroke=\"#6889b1\" stroke-width=\"4\"/>\n    <!-- inner telescoping plate: begins only after the sleeve reaches its outward stop -->\n    <g id=\"leftInner\" transform=\"translate(-130 0)\">\n      <path d=\"M316 523 L411 525 L411 639 Q356 637 315 621 Z\" fill=\"url(#innerGradV6)\" stroke=\"#6589b3\" stroke-width=\"3\"/>\n      <path d=\"M327 534 L395 536\" stroke=\"white\" stroke-opacity=\".86\" stroke-width=\"3.6\"/>\n      <path d=\"M344 613 L398 627\" stroke=\"#7299c1\" stroke-width=\"2.4\"/>\n      <path d=\"M400 534 L400 629\" stroke=\"#3b638b\" stroke-width=\"3.5\"/>\n    </g>\n  </g>\n  <!-- right sleeve mirrors left, only in the lower face -->\n  <g id=\"rightMask\" transform=\"translate(230 0)\">\n    <path d=\"M487 539 L503 520 L624 518 Q640 510 659 513 L659 549 Q656 584 628 604 Q552 642 487 607 Z\" fill=\"url(#armorGradV6)\" stroke=\"#718dab\" stroke-width=\"3.4\"/>\n    <path d=\"M511 527 L648 523\" fill=\"none\" stroke=\"white\" stroke-opacity=\".88\" stroke-width=\"4\"/>\n    <path d=\"M512 596 L630 574\" fill=\"none\" stroke=\"#91a9c9\" stroke-opacity=\".72\" stroke-width=\"2.6\"/>\n    <path d=\"M499 532 L499 601\" stroke=\"#6889b1\" stroke-width=\"4\"/>\n    <g id=\"rightInner\" transform=\"translate(130 0)\">\n      <path d=\"M414 525 L509 523 L510 621 Q468 637 414 639 Z\" fill=\"url(#innerGradV6)\" stroke=\"#6589b3\" stroke-width=\"3\"/>\n      <path d=\"M429 536 L498 534\" stroke=\"white\" stroke-opacity=\".86\" stroke-width=\"3.6\"/>\n      <path d=\"M427 627 L481 613\" stroke=\"#7299c1\" stroke-width=\"2.4\"/>\n      <path d=\"M425 534 L425 629\" stroke=\"#3b638b\" stroke-width=\"3.5\"/>\n    </g>\n  </g>\n</g>\n<!-- central closure line, visible only at complete lock -->\n<path id=\"centerSeal\" d=\"M412.5 526 L412.5 637\" stroke=\"#49749f\" stroke-width=\"2.5\" stroke-linecap=\"round\" opacity=\"0\"/>\n</svg>\n</div></div>";
const MOOD_STAGE = { normal: 0, focused: 0, happy: 1, tired: 2, sleepy: 2, away: 2, love: 3, curious: 4, alert: 5 };

export function createXiaoQi(host, uid) {
 const doc = host.ownerDocument, win = doc.defaultView;
 host.innerHTML = MARKUP.replace(/id="([^"]+)"/g, (_, id) => `id="${uid}${id}"`).replace(/url\(#([^)]+)\)/g, (_, id) => `url(#${uid}${id})`);
 const get = id => host.querySelector(`#${uid}${id}`);
 const robot = host.firstElementChild;
 const base = get('robotBase'), starFaceOverlay = get('starFaceOverlay');
 const leftMask = get('leftMask'), rightMask = get('rightMask'), leftInner = get('leftInner'), rightInner = get('rightInner'), centerSeal = get('centerSeal');
 const canvas = get('cubeCanvas'), ctx = canvas.getContext('2d');
 const reduced = win.matchMedia('(prefers-reduced-motion: reduce)');
 let stage = 0, bounceAnimation = null, maskAmount = 0, maskTarget = 0, maskFrom = 0, maskStartedAt = win.performance.now();
 let frame, destroyed = false;
 function setMaskTarget(value) {
   if (value === maskTarget) return;
   maskFrom = maskAmount; maskTarget = value; maskStartedAt = win.performance.now();
 }
 function setStage(value) {
   stage = value;
   setMaskTarget(stage === 5 ? 1 : 0);
   const expression = EXPRESSIONS[stage < 5 ? stage : 0];
   base.src = stage === 5 ? SERIOUS_RED : expression.src;
   base.alt = `小七机器人，${stage === 5 ? '戴面罩 · 红色警戒' : expression.name}`;
   robot.setAttribute('aria-label', base.alt);
   robot.dataset.stage = stage;
   starFaceOverlay.style.opacity = stage === 3 ? '1' : '0';
 }
function bounce(){
  if(bounceAnimation){bounceAnimation.cancel();bounceAnimation=null;}
  robot.style.transform='translateY(0) scale(1)';
  const k=reduced.matches?[
    {offset:0,transform:'translateY(0)'},{offset:.5,transform:'translateY(-4px)'},{offset:1,transform:'translateY(0)'}
  ]:[
    {offset:0,transform:'translateY(0) scale(1)'},
    {offset:.13,transform:'translateY(3px) scale(1.014,.986)'},
    {offset:.38,transform:'translateY(-15px) scale(.994,1.008)'},
    {offset:.52,transform:'translateY(-13px) scale(1)'},
    {offset:.74,transform:'translateY(0) scale(1.008,.993)'},
    {offset:.87,transform:'translateY(-3px) scale(.998,1.004)'},
    {offset:1,transform:'translateY(0) scale(1)'}
  ];
  bounceAnimation=robot.animate(k,{duration:reduced.matches?180:520,easing:'linear'});
  bounceAnimation.onfinish=()=>{bounceAnimation=null;robot.style.transform='translateY(0) scale(1)';};
}
const vertices=[[-1,-1,-1],[1,-1,-1],[1,1,-1],[-1,1,-1],[-1,-1,1],[1,-1,1],[1,1,1],[-1,1,1]];
const faces=[
 {v:[4,5,6,7],base:[169,242,255]},
 {v:[1,0,3,2],base:[34,131,242]},
 {v:[0,4,7,3],base:[76,201,255]},
 {v:[5,1,2,6],base:[64,182,255]},
 {v:[3,7,6,2],base:[204,250,255]},
 {v:[0,1,5,4],base:[19,105,211]}
];
function rotate(p, yaw,pitch){
 const [x,y,z]=p;
 const xx=x*Math.cos(yaw)+z*Math.sin(yaw);
 const zz=-x*Math.sin(yaw)+z*Math.cos(yaw);
 return [xx,y*Math.cos(pitch)-zz*Math.sin(pitch),y*Math.sin(pitch)+zz*Math.cos(pitch)];
}
function drawCube(ts){
 const w=canvas.width,h=canvas.height; // intrinsic and CSS square aspect: equal cube edges cannot be stretched
 ctx.clearRect(0,0,w,h);
 const cx=w/2,cy=h/2;

 const shell=[[25,4],[w-25,4],[w-7,25],[w-7,h-25],[w-25,h-4],[25,h-4],[7,h-25],[7,25]];
 const path=()=>{ctx.beginPath();shell.forEach(([x,y],i)=>i===0?ctx.moveTo(x,y):ctx.lineTo(x,y));ctx.closePath();};
 path();ctx.fillStyle='#061532';ctx.fill();ctx.save();path();ctx.clip();
 const alertMode = (stage===5);
 const ring=ctx.createRadialGradient(cx,cy,0,cx,cy,w*.6);
 if(alertMode){
  ring.addColorStop(0,'#8f1010');ring.addColorStop(.48,'#431010');ring.addColorStop(1,'#1c0707');
 }else{
  ring.addColorStop(0,'#063b8b');ring.addColorStop(.48,'#031c48');ring.addColorStop(1,'#020d25');
 }
 ctx.fillStyle=ring;ctx.fillRect(0,0,w,h);
 const pulse=.89 + .11*Math.sin(ts/1000*Math.PI*2/3.15); // never below 0.78 brightness
 const angle=Math.PI/4+(reduced.matches?0:ts/1000*Math.PI*2/11.5);
 const pitch=.40;
 const rot=vertices.map(v=>rotate(v,angle,pitch));
 const size=64;
 const project=p=>{const depth=3.8-p[2]*.28;const s=3.8/depth;return [cx+p[0]*size*s,cy+p[1]*size*s];};
 const prismFaces=[];
 const activeFaces = alertMode ? [
  {v:[4,5,6,7],base:[255,148,148]},
  {v:[1,0,3,2],base:[214,44,44]},
  {v:[0,4,7,3],base:[255,92,92]},
  {v:[5,1,2,6],base:[241,74,74]},
  {v:[3,7,6,2],base:[255,198,198]},
  {v:[0,1,5,4],base:[168,20,20]}
 ] : faces;
 for(const f of activeFaces){
  const v=f.v.map(i=>rot[i]);
  const a=v[0],b=v[1],c=v[2];
  const ab=[b[0]-a[0],b[1]-a[1],b[2]-a[2]],ac=[c[0]-a[0],c[1]-a[1],c[2]-a[2]];
  const normal=[ab[1]*ac[2]-ab[2]*ac[1],ab[2]*ac[0]-ab[0]*ac[2],ab[0]*ac[1]-ab[1]*ac[0]];
  // Camera faces the near +Z side; reverse normals only if orientation requires it.
  if(normal[2]<=.05) continue;
  const dot=Math.max(0,(normal[0]*-.45+normal[1]*-.5+normal[2]*1)/(Math.hypot(...normal)*1.5));
  const brightness=.66+dot*.62;
  const col=f.base.map(x=>Math.round(Math.min(255,x*brightness*pulse)));
  prismFaces.push({points:v.map(project),depth:v.reduce((s,v)=>s+v[2],0)/4,col});
 }
 prismFaces.sort((a,b)=>a.depth-b.depth);
 // Glow remains contained within the socket and no float/parallax translates the prism.
 ctx.save();ctx.globalCompositeOperation='screen';
 const halo=ctx.createRadialGradient(cx,cy,3,cx,cy,83);halo.addColorStop(0,`rgba(47,186,255,${.17+.1*pulse})`);halo.addColorStop(1,'rgba(5,40,140,0)');ctx.fillStyle=halo;ctx.beginPath();ctx.arc(cx,cy,83,0,Math.PI*2);ctx.fill();ctx.restore();
 for(const f of prismFaces){
  ctx.beginPath();f.points.forEach(([x,y],i)=>i===0?ctx.moveTo(x,y):ctx.lineTo(x,y));ctx.closePath();
  ctx.fillStyle=`rgb(${f.col.join(',')})`;ctx.fill();
  ctx.shadowColor=`rgba(66,202,255,${.55*pulse})`;ctx.shadowBlur=13;
  ctx.strokeStyle=`rgba(208,250,255,${.83+.13*pulse})`;ctx.lineWidth=3.4;ctx.stroke();ctx.shadowBlur=0;
  // Luminous inner bevel line
  ctx.strokeStyle=`rgba(74,226,255,${.55*pulse})`;ctx.lineWidth=.85;ctx.stroke();
 }
 ctx.restore();
 path();ctx.strokeStyle=`rgba(20,117,250,${.62+.15*pulse})`;ctx.lineWidth=4;ctx.stroke();
}
function update(ts){
 if (destroyed) return;
 let duration=reduced.matches?1:680;
 let t=Math.max(0,Math.min(1,(ts-maskStartedAt)/duration));
 let eased=1-Math.pow(1-t,3);
 maskAmount=maskFrom+(maskTarget-maskFrom)*eased;
 // Two-stage telescope: sleeves first (0..0.52), inner plates second (0.52..1).
 // Retract reverses exact progress: inner segments disappear before sleeves slide away.
 const sleeve = Math.min(1, maskAmount/.52);
 const inner = Math.max(0, Math.min(1, (maskAmount-.52)/.48));
 const ease = x => x*x*(3-2*x);
 const outerP=ease(sleeve), innerP=ease(inner);
 leftMask.setAttribute('transform',`translate(${(-230*(1-outerP)).toFixed(2)} 0)`);
 rightMask.setAttribute('transform',`translate(${(230*(1-outerP)).toFixed(2)} 0)`);
 leftInner.setAttribute('transform',`translate(${(-130*(1-innerP)).toFixed(2)} 0)`);
 rightInner.setAttribute('transform',`translate(${(130*(1-innerP)).toFixed(2)} 0)`);
 centerSeal.setAttribute('opacity',innerP>.98?String((innerP-.98)/.02):'0');
 drawCube(ts);
 frame = win.requestAnimationFrame(update);
}
frame = win.requestAnimationFrame(update);

 setStage(0);
 return {
   setMood(mood) { setStage(MOOD_STAGE[mood] ?? 0); },
   setStage,
   getStage: () => stage,
   poke() { setStage(stage === 6 ? 1 : stage + 1); bounce(); },
   destroy() { destroyed = true; win.cancelAnimationFrame(frame); bounceAnimation?.cancel(); host.replaceChildren(); },
 };
}

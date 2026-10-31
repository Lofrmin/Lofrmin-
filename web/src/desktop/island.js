import '../styles/desktop-island.css';
import {bindOverlayInput} from './overlay-input.js';
const b=window.neuroDesktop,$=s=>document.querySelector(s);let expanded=false;
async function expand(value){expanded=await b.islandExpand(value);$('#detail').hidden=!expanded;$('#capsule').setAttribute('aria-expanded',String(expanded));}
function update(s){$('#status').textContent=s?.headline||'安静陪伴中';$('#items').textContent=s?.items||'今天想补给点什么？';$('#meta').textContent=s?.meta||'园区工作伙伴 · DEMO';$('#controls').hidden=!s?.canControl;$('[data-action=receive]').disabled=!s?.canReceive;}
$('#hide').onclick=()=>b.setOverlays({island:false});
$('#capsule').onclick=e=>{if(e.detail===0)expand(!expanded);};
bindOverlayInput({solid:(x,y)=>{const r=$('#island').getBoundingClientRect();const inset=y<r.top+12||y>r.bottom-12?10:0;return x>=r.left+inset&&x<=r.right-inset&&y>=r.top&&y<=r.bottom;},dragTarget:t=>!!t.closest('#capsule'),onTap:()=>expand(!expanded)});
document.querySelectorAll('[data-action]').forEach(el=>el.onclick=()=>b.islandAction(el.dataset.action));
window.addEventListener('keydown',e=>{if(e.key==='Escape')expand(false);});b.onIslandCollapse(()=>{expanded=false;$('#detail').hidden=true;$('#capsule').setAttribute('aria-expanded','false');});b.onIslandState(update);update(await b.islandState());

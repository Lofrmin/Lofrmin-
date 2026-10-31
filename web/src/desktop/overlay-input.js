// Mousemove (not only pointermove) is forwarded by Electron on Windows.
export function bindOverlayInput({solid,dragTarget,onTap}){
 const b=window.neuroDesktop;let drag=null,lastHit;
 const hit=e=>{const yes=!!solid(e.clientX,e.clientY);if(yes!==lastHit){lastHit=yes;b.overlayHit(yes);}return yes;};
 b.onOverlayPointer?.(p=>{if(!drag)hit({clientX:p.x,clientY:p.y});});
 document.addEventListener('mousemove',e=>{if(drag){drag.moved ||= Math.hypot(e.screenX-drag.x,e.screenY-drag.y)>4;if(!e.buttons)end(e);}else hit(e);});
 const end=e=>{if(!drag)return;const prev=drag;drag=null;b.overlayDragEnd();hit(e);if(!prev.moved&&e.type==='pointerup')onTap?.(e);};
 document.addEventListener('pointerdown',e=>{if(e.button!==0||!solid(e.clientX,e.clientY)||!dragTarget(e.target))return;drag={x:e.screenX,y:e.screenY,moved:false};e.target.setPointerCapture?.(e.pointerId);b.overlayDragStart();});
 document.addEventListener('pointerup',end);document.addEventListener('pointercancel',end);
 window.addEventListener('blur',()=>{drag=null;b.overlayDragEnd();b.overlayHit(false);lastHit=false;});
 document.addEventListener('mouseleave',()=>{if(!drag){b.overlayHit(false);lastHit=false;}});
 document.addEventListener('contextmenu',e=>{e.preventDefault();b.overlayMenu();});
}
export function paintedPet(x,y){
 const target=document.elementFromPoint(x,y);if(!target)return false;
 if(target.closest('button,#pet-speech,#pet-state'))return true;
 const c=target.closest('canvas');if(c){const r=c.getBoundingClientRect(),gl=c.getContext('webgl2')||c.getContext('webgl');if(!gl)return false;try{const p=new Uint8Array(4);gl.readPixels(Math.floor((x-r.left)*c.width/r.width),Math.floor((r.bottom-y)*c.height/r.height),1,1,gl.RGBA,gl.UNSIGNED_BYTE,p);return p[3]>20;}catch{return false;}}
 if(target.closest('svg'))return target.tagName.toLowerCase()!=='svg';
 return !!target.closest('.pet-img');
}

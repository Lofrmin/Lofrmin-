// Renderer-facing extension interfaces only; not new Electron IPC protocols.
export class PetAssetAdapter {
 constructor({version=1,petId,displayName,rendererType,assets={},states={}}){
  if(version!==1||!['live2d','svg','spritesheet','image'].includes(rendererType))throw new Error('Unsupported pet asset adapter');
  if(Object.values(assets).some(p=>typeof p!=='string'||!p.startsWith('/')||p.includes('..')||p.startsWith('//')))throw new Error('Only trusted bundled asset paths are allowed');
  Object.assign(this,{version,petId,displayName,rendererType,assets,states});
 }
 onPointer(){} onStateChange(){} dispose(){}
}
export const VEHICLE_STATES=['idle','loading','depart','moving','arrived','error'];
// No network/provider/IPC integration. Future assets must be trusted bundled paths.
export class DeliveryVisual {
 constructor(host,{videos={}}={}){this.host=host;this.videos={};this.setVideos(videos);}
 setVideos(videos){for(const [state,url] of Object.entries(videos)){if(!VEHICLE_STATES.includes(state)||typeof url!=='string'||!/^\/workspace\/[a-zA-Z0-9_./-]+\.(mp4|webm)$/.test(url)||url.includes('..'))throw new Error('Only bundled vehicle videos are supported');}this.videos={...videos};if(this.state)this.setState(this.state);}
 setState(state){if(!VEHICLE_STATES.includes(state))throw new Error('Unknown vehicle state');this.state=state;this.host.dataset.motion=state;this.host.querySelector('video')?.remove();const fallback=this.host.querySelector('.v2-vehicle-svg');if(fallback)fallback.hidden=false;
 const src=this.videos[state];if(!src||globalThis.matchMedia?.('(prefers-reduced-motion: reduce)').matches)return;const video=document.createElement('video');video.muted=true;video.loop=!['depart','arrived'].includes(state);video.playsInline=true;video.setAttribute('aria-label','配送小车动画');video.hidden=true;video.oncanplay=()=>{if(this.host.querySelector('video')!==video)return;video.hidden=false;if(fallback)fallback.hidden=true;video.play().catch(()=>{video.hidden=true;if(fallback)fallback.hidden=false;});};video.onerror=()=>{video.remove();if(fallback)fallback.hidden=false;};video.src=src;this.host.append(video);}
 dispose(){const v=this.host.querySelector('video');if(v){v.pause();v.remove();}delete this.host.dataset.motion;}
}
export const vehicleSVG=()=>`<svg class="v2-vehicle-svg" viewBox="0 0 600 340" role="img" aria-label="园区配送小车 SVG 动画"><defs><linearGradient id="v2-car-body" x2="0" y2="1"><stop stop-color="#fffef6"/><stop offset="1" stop-color="#dbe9dc"/></linearGradient></defs><ellipse cx="300" cy="280" rx="170" ry="20" fill="#214b3c" opacity=".12"/><g class="v2-car-body"><rect x="139" y="122" width="315" height="130" rx="48" fill="url(#v2-car-body)" stroke="#b8cdbd" stroke-width="3"/><path d="M185 126v-24q0-24 28-24h118q30 0 48 48" fill="#d1e6d5" stroke="#adc6b4" stroke-width="3"/><rect x="207" y="91" width="112" height="28" rx="12" fill="#275847"/><rect x="351" y="150" width="75" height="47" rx="20" fill="#244c3e"/><circle cx="373" cy="172" r="5" fill="#c9f7ca"/><circle cx="405" cy="172" r="5" fill="#c9f7ca"/><path d="M377 184q12 8 24 0" fill="none" stroke="#c9f7ca" stroke-width="3"/><rect x="172" y="154" width="137" height="62" rx="15" fill="#edf4e9"/><text x="240" y="182" text-anchor="middle" font-size="15" fill="#416c54" font-family="sans-serif">NEURODESK</text><text x="240" y="202" text-anchor="middle" font-size="11" fill="#78947a">CAMPUS DELIVERY</text><rect x="434" y="209" width="12" height="15" rx="5" fill="#e6bc6b"/><g fill="#263d34" stroke="#f2f7ee" stroke-width="6"><circle cx="211" cy="251" r="29"/><circle cx="391" cy="251" r="29"/></g><g fill="#9ab8a0"><circle cx="211" cy="251" r="12"/><circle cx="391" cy="251" r="12"/></g><circle cx="330" cy="78" r="7" fill="#6cb48b"/></g></svg>`;
export class IslandPreview {
 constructor(host,{onSupply,onDelivery}){this.host=host;host.innerHTML='<button class="v2-island-toggle" aria-expanded="false">✦ NeuroDesk <span>安静陪伴中</span></button><div class="v2-island-detail" hidden><p>你的工位，正在被温柔照顾</p><button data-isupply>安排补给</button><button data-idelivery>查看配送</button><small>工作台内预览 · 非系统悬浮窗</small></div>';const toggle=host.querySelector('button'),detail=host.querySelector('div');this.close=()=>{detail.hidden=true;toggle.setAttribute('aria-expanded','false');};toggle.onclick=()=>{detail.hidden=!detail.hidden;toggle.setAttribute('aria-expanded',String(!detail.hidden));};host.querySelector('[data-isupply]').onclick=onSupply;host.querySelector('[data-idelivery]').onclick=onDelivery;this.key=e=>{if(e.key==='Escape')this.close();};window.addEventListener('keydown',this.key);}
 setStatus(text){this.host.querySelector('span').textContent=text;}
 setEnabled(enabled){this.host.hidden=!enabled;}
 dispose(){window.removeEventListener('keydown',this.key);this.host.remove();}
}

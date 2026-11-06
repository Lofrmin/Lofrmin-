export const distance=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y);
const clamp=(x,a=0,b=1)=>Math.max(a,Math.min(b,x));
export function describeHand(hand){
  const scale=Math.max(.035,Math.sqrt(distance(hand[0],hand[9])*distance(hand[5],hand[17])));
  const palm=[0,5,9,13,17].reduce((p,i)=>({x:p.x+hand[i].x/5,y:p.y+hand[i].y/5}),{x:0,y:0});
  const extended=[[8,6],[12,10],[16,14],[20,18]].filter(([tip,pip])=>distance(hand[tip],hand[0])>distance(hand[pip],hand[0])*1.16).length;
  return {scale,palm,ratio:distance(hand[4],hand[8])/scale,extended,
    pointer:{x:1-(hand[8].x*.65+hand[5].x*.35),y:hand[8].y*.65+hand[5].y*.35}};
}
export function interpretHands(hands){
  if(!hands.length)return {hands:0,x:.5,y:.5,pinch:false,open:false,thrust:0};
  const h=describeHand(hands[0]),spread=hands.length>1?distance(h.palm,describeHand(hands[1]).palm):0;
  return {hands:Math.min(2,hands.length),x:clamp((h.pointer.x-.15)/.7),y:clamp((h.pointer.y-.12)/.76),
    pinch:h.ratio<.34,open:h.extended>=4&&h.ratio>.5,thrust:hands.length===2?clamp((spread-.16)/.4):0};
}
class OneEuro{
  constructor(){this.reset();}
  reset(){this.value=null;this.previous=null;this.derivative=0;this.time=0;}
  filter(value,time){
    if(this.value===null){this.value=this.previous=value;this.time=time;return value;}
    const dt=clamp((time-this.time)/1000,1/120,.15);
    const alpha=cutoff=>1/(1+1/(2*Math.PI*cutoff*dt));
    this.derivative+=alpha(1.2)*((value-this.previous)/dt-this.derivative);
    this.value+=alpha(1.35+Math.abs(this.derivative)*7.5)*(value-this.value);
    this.previous=value;this.time=time;return this.value;
  }
}
class StableBoolean{
  constructor(on=75,off=90){this.on=on;this.off=off;this.reset();}
  reset(){this.value=false;this.candidate=false;this.since=0;}
  update(value,time){
    if(value!==this.candidate){this.candidate=value;this.since=time;}
    if(value!==this.value&&time-this.since>=(value?this.on:this.off))this.value=value;
    return this.value;
  }
}
export class GestureTracker{
  constructor(profile={}){
    this.profile=profile;this.fx=new OneEuro();this.fy=new OneEuro();
    this.pinchFilter=new StableBoolean();this.openFilter=new StableBoolean(160,90);
    this.viewFilter=new StableBoolean(170,100);this.salvoFilter=new StableBoolean(700,100);
    this.reset();
  }
  reset(){
    this.fx.reset();this.fy.reset();this.pinchFilter.reset();this.openFilter.reset();this.viewFilter.reset();this.salvoFilter.reset();
    this.anchor=null;this.primaryLabel=null;this.lastSeen=-1e6;this.lastOutput=null;
    this.wasPinched=false;this.grab=null;this.blockPinch=false;this.reacquired=0;this.smooth={x:.5,y:.5};this.sequence=0;
    this.previousHands=0;
    this.waveOrigin=null;this.waveDirection=0;this.waveAt=0;this.lastWave=-Infinity;
  }
  detectWave(palm,time,open){
    if(!open || time-this.lastWave<1000){this.waveOrigin=null;return false;}
    if(!this.waveOrigin || time-this.waveAt>650 || Math.abs(palm.y-this.waveOrigin.y)>.13){
      this.waveOrigin={...palm};this.waveAt=time;this.waveDirection=0;return false;
    }
    const travel=palm.x-this.waveOrigin.x;
    if(Math.abs(travel)<.105)return false;
    const direction=Math.sign(travel);
    if(this.waveDirection && direction!==this.waveDirection){
      this.lastWave=time;this.waveOrigin=null;return true;
    }
    this.waveDirection=direction;this.waveOrigin={...palm};return false;
  }
  update(hands,time,handedness=[]){
    hands=hands.filter(h=>h?.length===21&&h.every(p=>Number.isFinite(p.x)&&Number.isFinite(p.y)));
    if(!hands.length){
      const age=time-this.lastSeen;
      if(age<110&&this.lastOutput)return {...this.lastOutput,wave:false,occluded:true,quality:this.lastOutput.quality*.7,seq:++this.sequence};
      this.waveOrigin=null;
      if(this.wasPinched)this.blockPinch=true;
      this.wasPinched=false;this.grab=null;this.pinchFilter.reset();this.openFilter.reset();this.viewFilter.reset();this.salvoFilter.reset();
      this.reacquired=0;
      return {hands:0,pinch:false,open:false,view:false,salvo:false,cancel:true,quality:0,seq:++this.sequence};
    }
    const info=hands.map(describeHand);
    let index=0;
    if(this.anchor){
      let best=Infinity;
      for(let i=0;i<info.length;i++){
        const label=handedness[i]?.[0]?.categoryName;
        const penalty=(this.primaryLabel&&label&&label!==this.primaryLabel)?0.035:0;
        const total=distance(info[i].palm,this.anchor)+penalty;
        if(total<best){index=i;best=total;}
      }
    }
    const hand=info[index],other=info.length>1?info[1-index]:null;
    const currentLabel=handedness[index]?.[0];
    if(currentLabel?.score>.8)this.primaryLabel=currentLabel.categoryName;
    if(time-this.lastSeen>250){this.fx.reset();this.fy.reset();this.reacquired=time;}
    const close=clamp(this.profile.pinchOn??.34,.16,.46),release=clamp(this.profile.pinchOff??.52,close+.1,.75);
    if(this.previousHands>1&&info.length===1&&hand.ratio<release){this.blockPinch=true;this.pinchFilter.reset();}
    const candidate=this.pinchFilter.value?hand.ratio<release:hand.ratio<close;
    if(this.blockPinch&&hand.ratio>release)this.blockPinch=false;
    const pinch=this.pinchFilter.update(candidate&&!this.blockPinch&&time-this.reacquired>120,time);
    let raw={...hand.pointer};
    if(pinch&&!this.wasPinched)this.grab={pointer:{...this.smooth},palm:{...hand.palm}};
    const bounds=this.profile.bounds??{left:.13,right:.87,top:.12,bottom:.88};
    if(pinch&&this.grab){
      // Finger closure never moves a grabbed object. Move the palm to drag.
      raw={x:this.grab.pointer.x-(hand.palm.x-this.grab.palm.x)/(bounds.right-bounds.left),
        y:this.grab.pointer.y+(hand.palm.y-this.grab.palm.y)/(bounds.bottom-bounds.top)};
    }else{
      raw={x:(raw.x-bounds.left)/(bounds.right-bounds.left),y:(raw.y-bounds.top)/(bounds.bottom-bounds.top)};
    }
    if(this.wasPinched&&!pinch)raw={...this.smooth};
    const filtered={x:clamp(this.fx.filter(clamp(raw.x),time)),y:clamp(this.fy.filter(clamp(raw.y),time))};
    if(distance(filtered,this.smooth)>.0018)this.smooth=filtered;
    const open=this.openFilter.update(hand.extended>=4&&!candidate&&!pinch,time);
    const wave=this.detectWave(hand.palm,time,open&&!other&&!candidate);
    const bothOpen=!!other&&hand.extended>=3&&other.extended>=3&&hand.ratio>release&&other.ratio>release;
    const view=this.viewFilter.update(bothOpen,time);
    const salvo=this.salvoFilter.update(!!other&&hand.ratio<close&&other.ratio<close,time);
    const spread=other?distance(hand.palm,other.palm):0;
    const angle=other?Math.atan2(other.palm.y-hand.palm.y,Math.abs(other.palm.x-hand.palm.x)):0;
    const secondary=other?{x:clamp((other.pointer.x-bounds.left)/(bounds.right-bounds.left)),y:clamp((other.pointer.y-bounds.top)/(bounds.bottom-bounds.top))}:{x:.5,y:.5};
    const jitter=this.anchor?distance(hand.palm,this.anchor):0;
    const quality=clamp(.88-Math.max(0,.085-hand.scale)*4-Math.max(0,jitter-.035)*3,.1,.99);
    this.anchor={...hand.palm};this.lastSeen=time;this.wasPinched=pinch;
    this.previousHands=info.length;
    const output={protocol:2,hands:Math.min(2,hands.length),...this.smooth,x2:secondary.x,y2:secondary.y,
      pinch:pinch&&!view&&!other,open:open&&!view,view,salvo,wave,spread,angle,quality,cancel:false,
      thrust:other?clamp((spread-.16)/.4):0,seq:++this.sequence};
    this.lastOutput=output;return output;
  }
}

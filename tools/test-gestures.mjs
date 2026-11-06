import assert from 'node:assert/strict';
import {GestureTracker,describeHand,distance} from '../camera/gestures.mjs';
const clone=h=>h.map(p=>({...p}));
function hand(x=.5,y=.6){
  const h=Array.from({length:21},()=>({x,y}));
  h[0]={x,y:y+.19};h[5]={x:x-.075,y};h[9]={x:x-.025,y:y-.025};h[13]={x:x+.025,y};h[17]={x:x+.075,y:y+.015};
  for(const [tip,pip,mcp]of [[8,6,5],[12,10,9],[16,14,13],[20,18,17]]){
    h[pip]={x:h[mcp].x,y:y-.085};h[tip]={x:h[mcp].x,y:y-.19};
  }
  h[4]={x:x-.19,y:y-.025};return h;
}
function closed(h,ratio=.12){const result=clone(h);result[4]={x:result[8].x+describeHand(result).scale*ratio,y:result[8].y};return result;}
let time=0;
const tracker=new GestureTracker();
function feed(hands,count=1){let output;for(let i=0;i<count;i++){time+=33;output=tracker.update(hands,time);}return output;}
const open=hand();feed([open],15);
assert.equal(feed([closed(open)]).pinch,false,'Single-frame pinch must be suppressed');
feed([open],5);
assert.equal(feed([closed(open)],8).pinch,true,'Sustained pinch must grab');
assert.equal(feed([closed(open,.43)],8).pinch,true,'Hysteresis must hold across threshold noise');
const locked={...tracker.smooth};
const bent=closed(open);bent[8].y+=.035;bent[4].y+=.035;
feed([bent],8);
assert(distance(locked,tracker.smooth)<.012,'Closing fingers must not drag a grabbed object');
assert.equal(feed([open],8).pinch,false,'Stable release must release');
feed([closed(open)],8);
const ghost=feed([],2);assert.equal(ghost.pinch,true,'Brief dropout must preserve grab');
const lost=feed([],5);assert.equal(lost.cancel,true);assert.equal(lost.hands,0,'Long dropout must cancel');
assert.equal(feed([closed(open)],15).pinch,false,'Reacquiring a pinched hand must not create an accidental click');
feed([open],8);assert.equal(feed([closed(open)],8).pinch,true);
tracker.reset();time=0;
feed([open],20);
const samples=[];
for(let i=0;i<80;i++){
  const jitter=clone(open);for(const p of jitter){p.x+=Math.sin(i*2.3)*.003;p.y+=Math.cos(i*1.7)*.003;}
  const output=feed([jitter]);samples.push(output.x);
}
assert(Math.max(...samples)-Math.min(...samples)<.006,'Stationary jitter must be damped');
const moved=hand(.25,.6);const output=feed([moved],10);
assert(output.x>.67,'Adaptive filter must remain responsive to deliberate movement');
tracker.reset();time=0;
const left=hand(.28,.6),right=hand(.72,.6);
feed([left],20);
const before=feed([left,right],12);
assert.equal(before.view,true,'Two open hands must control the view');
const swapped=feed([right,left],8);
assert(Math.abs(swapped.x-before.x)<.03,'Detection order must not swap the controlling hand');
assert.equal(swapped.pinch,false,'View manipulation must not trigger commands');
const bothClosed=[closed(left),closed(right)];
assert.equal(feed(bothClosed,4).salvo,false,'Salvo must require a deliberate hold');
assert.equal(feed(bothClosed,24).salvo,true,'Two sustained pinches must enable salvo');
assert.equal(feed([closed(left)],12).pinch,false,'Leaving two-hand mode must require a fresh single-hand pinch');
feed([left],8);assert.equal(feed([closed(left)],8).pinch,true);
const invalid=hand();invalid[3].x=NaN;
assert.equal(feed([invalid],5).cancel,true,'Invalid landmarks must be rejected');
tracker.reset();time=0;
assert.equal(feed([open],20).wave,false,'A stationary palm cannot wake the console');
assert.equal(feed([hand(.66)],2).wave,false,'One-way hand movement cannot wake the console');
assert.equal(feed([hand(.49)]).wave,true,'A left-right reversal wakes the console');
assert.equal(feed([],1).wave,false,'An occluded frame cannot repeat the wake event');
console.log('GESTURE_TEST_PASS: debounce, hysteresis, clutch, jitter filtering, responsiveness, dropout cancellation, reacquisition, identity, bimanual view, deliberate salvo');

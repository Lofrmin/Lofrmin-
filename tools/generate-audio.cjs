const fs=require('node:fs');const path=require('node:path');
const folder=path.join(__dirname,'../assets/audio');fs.mkdirSync(folder,{recursive:true});
let seed=2075;const noise=()=>{seed=(Math.imul(seed,1664525)+1013904223)|0;return (seed>>>0)/2147483648-1;};
function wav(name,seconds,fn){const rate=22050,count=Math.floor(rate*seconds),out=Buffer.alloc(44+count*2);
  out.write('RIFF');out.writeUInt32LE(out.length-8,4);out.write('WAVEfmt ',8);out.writeUInt32LE(16,16);out.writeUInt16LE(1,20);out.writeUInt16LE(1,22);out.writeUInt32LE(rate,24);out.writeUInt32LE(rate*2,28);out.writeUInt16LE(2,32);out.writeUInt16LE(16,34);out.write('data',36);out.writeUInt32LE(count*2,40);
  for(let i=0;i<count;i++){const t=i/rate;out.writeInt16LE(Math.round(Math.max(-1,Math.min(1,fn(t,i,count)))*26000),44+i*2);}fs.writeFileSync(path.join(folder,name+'.wav'),out);
}
const tau=Math.PI*2;
wav('confirm',.2,t=>(Math.sin(t*tau*880)+Math.sin(t*tau*1320)*.25)*Math.exp(-t*24)*.25);
wav('laser',.15,t=>Math.sin(tau*(1450*t-3200*t*t))*Math.exp(-t*22)*.16);
wav('impact',.65,t=>(noise()*.4+Math.sin(t*tau*48)*.5)*Math.exp(-t*8)*.4);
wav('salvo',.7,t=>(Math.sin(tau*(110*t+130*t*t))*.2+noise()*.12)*Math.sin(Math.min(1,t/.7)*Math.PI));
wav('ambient',8,t=>Math.sin(t*tau*48)*.025+Math.sin(t*tau*62)*.018+Math.sin(t*tau*83)*.01);
console.log('Generated local audio assets');
